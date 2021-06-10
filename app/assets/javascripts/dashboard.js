var dashboard_data = undefined;                                                 // controls if data exists to append with delta or initial read occurs



class DashboardData {
    constructor(unique_id, canvas_id, top_session_sql_id, update_area_id, hours_to_cover, refresh_cycle_minutes, refresh_cycle_id, refresh_button_id, options={}){
        this.unique_id                  = unique_id;
        this.canvas_id                  = canvas_id;
        this.top_session_sql_id         = top_session_sql_id;
        this.update_area_id             = update_area_id;
        this.hours_to_cover             = hours_to_cover;
        this.refresh_cycle_minutes      = refresh_cycle_minutes;
        this.refresh_cycle_id           = refresh_cycle_id;
        this.refresh_button_id          = refresh_button_id;
        this.ash_data_array             = [];
        this.last_refresh_time_string   = null;
        this.current_timeout            = null;                                 // current active timeout
        this.selection_refresh_pending  = false;                                // is there a request in transit for selection? Suppress multiple events

        const default_options = {
            series: {stack: true, lines: {show: true, fill: true}, points: {show: false}},
            canvas_height: 250,
            legend: {position: "nw", sorted: 'reverse'},
            selection: {
                mode: "x",
                color: 'gray',
                //shape: "round" or "miter" or "bevel",
                shape: "bevel",
                minSize: 4
            }
        };
        /* deep merge defaults and options, without modifying defaults */
        this.options = jQuery.extend(true, {}, default_options, options);
    }

    log(content){
        if (true)
            console.log(content);
    }

    // which refresh cycle is choosen in select list now
    selected_refresh_cycle(){
        return $('#'+this.refresh_cycle_id).children("option:selected").val();
    }

    set_refresh_cycle_off(){
        this.cancel_timeout();
        $('#'+this.refresh_cycle_id+' option[value="0"]').attr("selected", "selected");
        $('#'+this.refresh_button_id).attr('type', 'submit');                   // make refresh button visible
    }

    remove_aged_records(data_array){
        data_array.forEach((col) => {
            var max_date_ms = col.data[col.data.length-1][0];                   // last timestamp in array
            var min_date_ms = max_date_ms - this.hours_to_cover*3600*1000
            while (col.data.length > 0 && col.data[0][0] < min_date_ms ){
                col.data.shift();                                               // remove first record of array
            }
        });
    }

    // load data from DB
    load_refresh_ash_data(){
        jQuery.ajax({
            method: "POST",
            dataType: "json",
            success: (data, status, xhr)=>{
                this.process_load_refresh_ash_data_success(data, xhr);
            },
            url: 'dba/refresh_dashboard_ash?window_width='+jQuery(window).width()+'&browser_tab_id='+browser_tab_id,
            data: { 'hours_to_cover': this.hours_to_cover, 'last_refresh_time_string': this.last_refresh_time_string}
        });
    }

    process_load_refresh_ash_data_success(data, xhr){
        let timestamps = {};
        let data_to_add = {};
        let min_time_ms = null;                                                 // start of delta time range in ms since 1970
        let max_time_ms = 0;                                                    // end of delta time range in ms since 1970
        let initial_data_load = this.ash_data_array.length == 0;                // initial or delta load

        let previous_timestamps = [];                                           // remember used timestamps for later tasks
        if (this.ash_data_array.length > 0){
            this.ash_data_array[0].data.forEach((tupel)=>{
                previous_timestamps.push(tupel[0]);
            });
        }

        data.forEach((d) => {
            if (this.last_refresh_time_string == null || this.last_refresh_time_string < d.sample_time_string)
                this.last_refresh_time_string = d.sample_time_string;           // greatest known timestamp from ASH
            timestamps[d.sample_time_string] = 1;                               // remember all used timestamps
            if (data_to_add[d.wait_class] === undefined){
                data_to_add[d.wait_class] = {};
            }
            data_to_add[d.wait_class][d.sample_time_string] = d.sessions;
        });

        // copy values and generate 0-records for gaps in time series
        for (const [key, value] of Object.entries(data_to_add)) {               // iterate over wait_classes of delta
            let wait_class_object = this.ash_data_array.find(o => o.label == key)
            if (wait_class_object === undefined){                               // create empty object in ash_data_array is not exists
                wait_class_object = { label: key, data: []}
                // generate 0 records for previous timestamps if wait class is new in delta
                previous_timestamps.forEach((ts)=>{
                    wait_class_object.data.push([ts, 0]);                       // ensure existing timestamps have a 0 record
                });
                this.ash_data_array.push(wait_class_object);
            }

            let col_data_to_add = data_to_add[key];
            // generate 0-records for gaps in time series
            Object.entries(timestamps).forEach((ts_tupel)=>{
                if (col_data_to_add[ts_tupel[0]] === undefined)
                    col_data_to_add[ts_tupel[0]] = 0;
            });

            // Sort required because 0-records are pushed to object before
            var col_data_delta_array = Object.entries(col_data_to_add).sort((a,b)=>{
                if (a[0] < b[0])
                    return -1;
                if (a[0] > b[0])
                    return 1;
                return 0;
            });

            // transform date string into ms since 1970 and remember low and high value
            col_data_delta_array.forEach((val_array)=>{
                val_array[0] = new Date(val_array[0] + " GMT").getTime();
                if (min_time_ms == null || min_time_ms > val_array[0])
                    min_time_ms = val_array[0];
                if (max_time_ms < val_array[0])
                    max_time_ms = val_array[0];
            });

            wait_class_object['data'] = wait_class_object.data.concat(col_data_delta_array);    // add the delta data to the previous data
        }

        // build sum over wait_classes and sort by sums, so wait class with highest amount is on top in diagram
        this.ash_data_array.forEach((col)=>{
            var sum = 0;
            col.data.forEach((tupel)=>{
                sum += tupel[1];
            });
            col['session_sum'] = sum;
        });
        // ensure the graph with highest sum is on top in chart
        this.ash_data_array.sort((a,b)=>{
            if (a.session_sum < b.session_sum)
                return -1;
            if (a.session_sum > b.session_sum)
                return 1;
            return 0;
        });

        // remove wait_classes that do not exist in delta but exists only with 0 records in previous data
        this.ash_data_array = this.ash_data_array.filter(col=>col.session_sum > 0);

        // generate dummy records with 0 for wait_classes existing in previous data but not in new delta
        this.ash_data_array.forEach((col)=>{
            if (data_to_add[col.label] === undefined){
                let new_timestamps = Object.entries(timestamps)
                new_timestamps.sort((a,b)=>{
                    if (a[0] < b[0])
                        return -1;
                    if (a[0] > b[0])
                        return 1;
                    return 0;
                });
                new_timestamps.forEach((ts)=>{
                    col.data.push([new Date(ts[0] + " GMT").getTime(), 0]);
                });
            }
        });

        // define colors
        this.ash_data_array.forEach((col)=> {
            let color = wait_class_color(col.label);
            if (color){
                col['color'] = color;
            }
        });

        // remove and recreate the sub_canvas object to suppress "Total canvas memory use exceeds the maximum limit"
        $('#'+this.canvas_id).html('');
        let sub_canvas_id = this.canvas_id+'_sub';
        $('#'+this.canvas_id).append('<div id="'+sub_canvas_id+'"></div>');

        let diagram = plot_diagram(this.unique_id, sub_canvas_id, 'Wait classes of last '+this.hours_to_cover+' hours', this.ash_data_array, this.options);

        // set selection in chart to delta just added in diagram
        if (!initial_data_load)
            diagram.get_plot().setSelection( { xaxis: { from: min_time_ms, to: max_time_ms}}, true);

        // react on selection in chart
        $('#'+sub_canvas_id).bind( "plotselected", ( event, ranges)=>{
            this.set_refresh_cycle_off();
            if (!this.selection_refresh_pending)
                this.log("Refreshing");
                this.load_top_sessions_and_sql(ranges.xaxis.from, ranges.xaxis.to);
            this.selection_refresh_pending = true;                              // suppress subsequent calls until ajax response is processed, set to false in Rails template _refresh_top_session_sql
        });

        if (this.refresh_cycle_minutes != 0 && this.selected_refresh_cycle() != '0'){                     // not started with refresh cycle=off and refresh cycle not changed to off in the meantime
            this.log('timeout set');
            this.current_timeout = setTimeout(function(){ this.draw_refreshed_data(this.canvas_id, 'timeout')}.bind(this), 1000*60*this.refresh_cycle_minutes);  // schedule for next cycle
        }
    }

    load_top_sessions_and_sql(start_range_ms=null, end_range_ms=null){
        ajax_html(this.top_session_sql_id, 'dba', 'refresh_top_session_sql',
            {
                'hours_to_cover':           this.hours_to_cover,
                'last_refresh_time_string': this.last_refresh_time_string,
                'start_range_ms':           start_range_ms,
                'end_range_ms':             end_range_ms,
                'update_area_id':           this.update_area_id
            });
    }

    draw_refreshed_data(current_canvas_id, caller){
        if ($('#'+current_canvas_id).length == 0)                               // is dashboard page still open and timeout for the right dashboard?
            return;                                                             // end refresh now

        if (caller == 'timeout' && this.selected_refresh_cycle() == '0')        // imediately stop timeout processing if refresh is set to off
            return;

        this.log("draw_refreshed_data "+caller);
        this.current_timeout = null;                                            // no timeout pending from now until scheduled again

        this.remove_aged_records(this.ash_data_array);
        this.load_refresh_ash_data();
        this.load_top_sessions_and_sql();

        // timeout for next refresh cycle is set after successful return from ajax call
    }

    draw_with_new_refresh_cycle(canvas_id, hours_to_cover, refresh_cycle_minutes) {
        this.hours_to_cover         = hours_to_cover;
        this.refresh_cycle_minutes  = refresh_cycle_minutes;
        this.cancel_timeout();
        this.draw_refreshed_data(canvas_id, 'new refresh cycle');
    }

    // cancel possible timeout
    cancel_timeout(){
        if (this.current_timeout) {
            this.log('clearTimeout '+this.current_timeout);
            clearTimeout(this.current_timeout);                                 // remove current aktive timeout first before
            this.current_timeout = null;
        }
    }
}

// function to be called from Rails template
refresh_dashboard = function(unique_id, canvas_id, top_session_sql_id, update_area_id, hours_to_cover, refresh_cycle_minutes, refresh_cycle_id, refresh_button_id){
    if (dashboard_data !== undefined) {
        if (dashboard_data.canvas_id != canvas_id)                              // check if dashboard_data belongs to the current element
            discard_dashboard_data();                                           // throw away old content
    }

    if (dashboard_data !== undefined) {
        dashboard_data.draw_with_new_refresh_cycle(canvas_id, hours_to_cover, refresh_cycle_minutes);
    } else {
        dashboard_data = new DashboardData(unique_id, canvas_id, top_session_sql_id, update_area_id,  hours_to_cover, refresh_cycle_minutes, refresh_cycle_id, refresh_button_id);
        dashboard_data.draw_refreshed_data(canvas_id, 'init');
    }
}

discard_dashboard_data = function(){
    if (dashboard_data !== undefined) {
        dashboard_data.cancel_timeout();
        dashboard_data = undefined;
    }
}
