var dashboard_data = undefined;                                                 // controls if data exists to append with delta or initial read occurs

class DashboardData {
    constructor(unique_id, canvas_id, hours_to_cover, refresh_cycle_minutes, refresh_cycle_id, options={}){
        this.unique_id                  = unique_id;
        this.canvas_id                  = canvas_id;
        this.hours_to_cover             = hours_to_cover;
        this.refresh_cycle_minutes      = refresh_cycle_minutes;
        this.refresh_cycle_id           = refresh_cycle_id;
        this.ash_data_array             = [];
        this.last_refresh_time_string   = null;
        this.current_timeout            = null;                                 // current active timeout

        const default_options = {
            series: {stack: true, lines: {show: true, fill: true}, points: {show: false}},
            canvas_height: 300,
            legend: {position: "nw", sorted: 'reverse'},
        };
        /* deep merge defaults and options, without modifying defaults */
        this.options = jQuery.extend(true, {}, default_options, options);
    }

    // which refresh cycle is choosen in select list now
    selected_refresh_cycle(){
        return $('#'+this.refresh_cycle_id).children("option:selected").val();
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

    process_load_refresh_ash_data_success(data, xhr){
        let timestamps = {};
        let data_to_add = {};

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

            // transform date string into ms since 1970
            col_data_delta_array.forEach((val_array)=>{
                val_array[0] = new Date(val_array[0] + " GMT").getTime();
            });

            wait_class_object['data'] = wait_class_object.data.concat(col_data_delta_array);
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

        plot_diagram(this.unique_id, this.canvas_id, 'Wait classes of last '+this.hours_to_cover+' hours', this.ash_data_array, this.options);

        if (this.refresh_cycle_minutes != 0 && this.selected_refresh_cycle() != '0'){                     // not started with refresh cycle=off and refresh cycle not changed to off in the meantime
            console.log('timeout set');
            this.current_timeout = setTimeout(function(){ this.draw_refreshed_data(this.canvas_id, 'timeout')}.bind(this), 1000*60*this.refresh_cycle_minutes);  // schedule for next cycle
        }
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

    draw_refreshed_data(current_canvas_id, caller){
        if ($('#'+current_canvas_id).length == 0)                               // is dashboard page still open and timeout for the right dashboard?
            return;                                                             // end refresh now

        if (caller == 'timeout' && this.selected_refresh_cycle() == '0')        // imediately stop timeout processing if refresh is set to off
            return;

        console.log("draw_refreshed_data "+caller);
        this.current_timeout = null;                                            // no timeout pending from now until scheduled again

        this.remove_aged_records(this.ash_data_array);
        this.load_refresh_ash_data();

        // timeout for next refresh cycle is set after successful return from ajax call
    }

    draw_with_new_refresh_cycle(canvas_id, hours_to_cover, refresh_cycle_minutes) {
        this.hours_to_cover         = hours_to_cover;
        this.refresh_cycle_minutes  = refresh_cycle_minutes;
        if (this.current_timeout)
            clearTimeout(this.current_timeout);                                 // remove current aktive timeout first before
        this.draw_refreshed_data(canvas_id, 'new refresh cycle');
    }
}

// function to be called from Rails template
refresh_dashboard = function(unique_id, canvas_id, hours_to_cover, refresh_cycle_minutes, refresh_cycle_id){
    if (dashboard_data !== undefined) {
        if (dashboard_data.canvas_id != canvas_id)                              // check if dashboard_data belongs to the current element
            dashboard_data = undefined;                                         // throw away old content
    }

    if (dashboard_data !== undefined) {
        dashboard_data.draw_with_new_refresh_cycle(canvas_id, hours_to_cover, refresh_cycle_minutes);
    } else {
        dashboard_data = new DashboardData(unique_id, canvas_id, hours_to_cover, refresh_cycle_minutes, refresh_cycle_id);
        dashboard_data.draw_refreshed_data(canvas_id, 'init');
    }
}

