class SQL_Worksheet  {
    static get_sql_at_cursor_position(editor_id) {
        var sql_text_elem    = $("#"+editor_id);
        var sql_statement    = '';
        var cursor_at_linefeed = false;

        if (sql_text_elem.prop('selectionStart') != sql_text_elem.prop('selectionEnd')){  // text selected in textarea
            sql_statement = sql_text_elem.val().substring(sql_text_elem.prop('selectionStart'), sql_text_elem.prop('selectionEnd'));
        } else {                                                                  // no text select in textarea
            var sql_text_before_cursor =  sql_text_elem.val().substr(0, sql_text_elem.prop('selectionStart'));
            if (sql_text_before_cursor[sql_text_before_cursor.length-1] == "\n"){          // Cursor stands after line feed
                sql_text_before_cursor = sql_text_before_cursor.substr(0, sql_text_before_cursor.length-1); // remove trailing linefeed if exists
                cursor_at_linefeed = true;
            }
            var sql_text_lines_before_cursor = sql_text_before_cursor.split("\n");

            var sql_text_after_cursor = sql_text_elem.val().substr(sql_text_elem.prop('selectionStart'));
            if (sql_text_after_cursor[0] == "\n") {
                sql_text_after_cursor = sql_text_after_cursor.substr(1);        // remove leading line feed
                cursor_at_linefeed = true;
            }
            var sql_text_lines_after_cursor  = sql_text_after_cursor.split("\n");

            sql_text_lines_before_cursor.reverse().some(function(line, index){
                var trimmed_line = line.trim();

                if ((trimmed_line[trimmed_line.length-1] == ';' && index > 0) || trimmed_line.length == 0) // break downcount if previous line ends with ; or is empty
                    return true;

                if (index > 0)
                    sql_statement = line + "\n" + sql_statement;
                else
                    sql_statement = line + sql_statement;
            });

            if (cursor_at_linefeed)
                sql_statement = sql_statement + "\n";                           // add missing line feed between before and after parts if cursor stands exactly at line feed

            sql_text_lines_after_cursor.some(function(line, index){
                var trimmed_line = line.trim();

                if (trimmed_line.length == 0)
                    return true;

                if (index > 0)
                    sql_statement = sql_statement + "\n";
                sql_statement = sql_statement + line;
                return trimmed_line[trimmed_line.length-1] == ';';                // end if line is finished with ;
            });

        }

        if (sql_statement[sql_statement.length-1] == "\n")
            sql_statement = sql_statement.substr(0, sql_statement.length-1);      // remove trailing line feed if exists
        if (sql_statement[sql_statement.length-1] == ';')
            sql_statement = sql_statement.substr(0, sql_statement.length-1);      // remove trailing ; if exists

        return sql_statement;
    }

    static init_tab_container(){
        $( "#sql_worksheet_tab_container" ).easytabs({animate: false}); // initialize tabs
        $("#sql_worksheet_tab_container > .etabs").children().css('display', 'none');   // Hide all tab header at start
    }


    static open_and_focus_tab(tab_id, controller, action){
        var tab_obj = $('#'+tab_id+'_area_sql_worksheet_id');
        tab_obj.parent().css('display', 'inline-block');                        // make tab header visible
        tab_obj.click();                                                        // bring tab in foreground

        var sql_statement = SQL_Worksheet.get_sql_at_cursor_position('sql_text');
        setTimeout(function(){
            ajax_html(tab_id+'_area_sql_worksheet', controller, action, {update_area: 'result_area_sql_worksheet', sql_statement: sql_statement});
        }, 100);                                                                  // Wait until click is processed to hit the visible div
    }

    static exec_worksheet_sql(){
        SQL_Worksheet.open_and_focus_tab('result', 'addition', 'exec_worksheet_sql');            // bring tab in front
    }


    static explain_worksheet_sql(){
        SQL_Worksheet.open_and_focus_tab('explain', 'addition', 'explain_worksheet_sql');            // bring tab in front
    }

    static sql_in_sga(){
        SQL_Worksheet.open_and_focus_tab('sga', 'dba_sga', 'list_last_sql_from_sql_worksheet');            // bring tab in front
        var sql_statement = SQL_Worksheet.get_sql_at_cursor_position('sql_text');
    }


}