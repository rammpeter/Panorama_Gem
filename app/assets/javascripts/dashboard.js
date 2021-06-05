

draw_dashboard = function(unique_id, canvas_id, hours_to_cover, refresh_cycle_minutes, refresh_cycle_id, options={}) {
    var ash_data_array = [];
    var last_refresh_time_string = null;

    function remove_aged_records(data_array){
        data_array.forEach(function(col){
            var max_date_ms = col.data[col.data.length-1][0];                   // last timestamp in array
            var min_date_ms = max_date_ms - hours_to_cover*3600*1000
            while (col.data.length > 0 && col.data[0][0] < min_date_ms ){
                col.data.shift();                                               // remove first record of array
            }
        });
    }

    // load data from DB
    function load_refresh_ash_data(){
        jQuery.ajax({
            method: "POST",
            dataType: "json",
            success: function (data, status, xhr) {
                process_load_refresh_ash_data_success(data, xhr);
            },
            url: 'dba/refresh_dashboard_ash?window_width='+jQuery(window).width()+'&browser_tab_id='+browser_tab_id,
            data: { 'hours_to_cover': hours_to_cover, 'last_refresh_time_string': last_refresh_time_string}
        });
    }

    function process_load_refresh_ash_data_success(data, xhr){
        timestamps = {};
        data_to_add = {};

        var previous_timestamps = [];                                           // remember used timestamps for later tasks
        if (ash_data_array.length > 0){
            ash_data_array[0].data.forEach(function(tupel){
                previous_timestamps.push(tupel[0]);
            });
        }

        data.forEach(function(d){
            if (last_refresh_time_string == null || last_refresh_time_string < d.sample_time_string)
                last_refresh_time_string = d.sample_time_string;                // greatest known timestamp from ASH
            timestamps[d.sample_time_string] = 1;                               // remember all used timestamps
            if (data_to_add[d.wait_class] === undefined){
                data_to_add[d.wait_class] = {};
            }
            data_to_add[d.wait_class][d.sample_time_string] = d.sessions;
        });

        // copy values and generate 0-records for gaps in time series
        for (const [key, value] of Object.entries(data_to_add)) {               // iterate over wait_classes of delta
            var wait_class_object = ash_data_array.find(o => o.label == key)
            if (wait_class_object === undefined){                               // create empty object in ash_data_array is not exists
                wait_class_object = { label: key, data: []}
                // generate 0 records for previous timestamps if wait class is new in delta
                previous_timestamps.forEach(function(ts){
                    wait_class_object.data.push([ts, 0]);                       // ensure existing timestamps have a 0 record
                });
                ash_data_array.push(wait_class_object);
            }

            var col_data_to_add = data_to_add[key];
            // generate 0-records for gaps in time series
            Object.entries(timestamps).forEach(function(ts_tupel){
                if (col_data_to_add[ts_tupel[0]] === undefined)
                    col_data_to_add[ts_tupel[0]] = 0;
            });

            // Sort required because 0-records are pushed to object before
            var col_data_delta_array = Object.entries(col_data_to_add).sort(function(a,b){
                if (a[0] < b[0])
                    return -1;
                if (a[0] > b[0])
                    return 1;
                return 0;
            });

            // transform date string into ms since 1970
            col_data_delta_array.forEach(function (val_array) {
                val_array[0] = new Date(val_array[0] + " GMT").getTime();
            });

            wait_class_object['data'] = wait_class_object.data.concat(col_data_delta_array);
        }

        // build sum over wait_classes and sort by sums, so wait class with highest amount is on top in diagram
        ash_data_array.forEach(function(col){
           var sum = 0;
           col.data.forEach(function(tupel){
               sum += tupel[1];
           });
           col['session_sum'] = sum;
        });
        ash_data_array.sort(function(a,b){
            if (a.session_sum < b.session_sum)
                return -1;
            if (a.session_sum > b.session_sum)
                return 1;
            return 0;
        });

        // remove wait_classes that do not exist in delta but exists only with 0 records in previous data
        ash_data_array = ash_data_array.filter(col=>col.session_sum > 0);

        // generate dummy records with 0 for wait_classes existing in previous data but not in new delta
        ash_data_array.forEach(function(col){
            if (data_to_add[col.label] === undefined){
                var new_timestamps = Object.entries(timestamps)
                new_timestamps.sort(function(a,b){
                    if (a[0] < b[0])
                        return -1;
                    if (a[0] > b[0])
                        return 1;
                    return 0;
                });
                new_timestamps.forEach(function(ts){
                    col.data.push([new Date(ts[0] + " GMT").getTime(), 0]);
                });
            }
        });

        plot_diagram(unique_id, canvas_id, 'Wait classes of last '+hours_to_cover+' hours', ash_data_array, options);

        var selected = $('#'+refresh_cycle_id).children("option:selected").val();
        if (refresh_cycle_minutes != 0 && selected != '0'){                     // not started with refresh cycle=off and refresh cycle not changed to off in the meantime
            setTimeout(draw_refreshed_data, 1000*60*refresh_cycle_minutes, canvas_id);  // schedule for next cycle
        }
    }

    function refresh_data() {
        remove_aged_records(ash_data_array);
        load_refresh_ash_data();
    }

    function draw_refreshed_data(current_canvas_id) {
        if ($('#'+current_canvas_id).length == 0)                               // is dashboard page still open and timeout for the right dashboard?
            return;                                                             // end refresh now

        refresh_data();                                                         // load initial or delta
        // timeout for next refresh cycle is set after successful return from ajax call
    }

    const default_options = {
        series: {stack: true, lines: {show: true, fill: true}, points: {show: false}},
        canvas_height: 300,
        legend: {position: "nw", sorted: 'reverse'},
    };
    /* deep merge defaults and options, without modifying defaults */
    options = jQuery.extend(true, {}, default_options, options);
    draw_refreshed_data(canvas_id);
}

