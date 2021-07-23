class SQL_Worksheet  {
    constructor(parent_element_id) {
        this.cm = CodeMirror(document.getElementById(parent_element_id), {
            value: "-- Place your SQL code here\n",
            mode:  "sql"
        });

        $(this.cm.getWrapperElement()).resizable();
        //$(this.cm.getWrapperElement()).parent().find(".ui-resizable-s").remove();  // Entfernen des rechten resizes-Cursors
        $(this.cm.getWrapperElement()).parent().find(".ui-resizable-se").remove();                   // Entfernen des rechten unteren resize-Cursors
         //    .resizable()

        $(this.cm.getWrapperElement()).bind("keydown", function(event) {
            if (event.ctrlKey == true && event.key == 'Enter'){
                sql_worksheet.exec_worksheet_sql();
                return false;
            }
            if (event.ctrlKey == true && event.key == 'e'){
                sql_worksheet.explain_worksheet_sql();
                return false;
            }
            if (event.altKey == true && event.key == 'Enter'){
                sql_worksheet.sql_in_sga();
                return false;                                                       // suppress default alt#Enter-Handling
            }
        });


        console.log('cm created');

        this.init_tab_container();
    }

    get_sql_at_cursor_position(){
        let return_sql;
        let selection = this.cm.getSelection();
        if (selection != ''){
            return_sql = selection;
        } else {
            let content             = this.cm.getValue();
            let content_lines       = content.split("\n");
            let cursor_pos_line     = this.cm.getCursor().line;
            let current_stmt_end_line;
            do {
                current_stmt_end_line = this.find_stmt_end(content_lines);
                if (current_stmt_end_line != null && current_stmt_end_line < cursor_pos_line){ // remove trailing SQLs if not current SQL
                    for (var i=0; i<=current_stmt_end_line; i++)
                        content_lines.shift();
                    cursor_pos_line = cursor_pos_line - (current_stmt_end_line+1);  // new position cursor in rest of content_lines
                }
            } while (current_stmt_end_line != null && current_stmt_end_line < cursor_pos_line);
            if (current_stmt_end_line != null){                                 // remove follwing SQLs if exist
                for (var i=current_stmt_end_line; i<content_lines.length-1; i++)
                    content_lines.pop();                                        // remove last element of array
            }
            return_sql = content_lines.join("\n");
        }
        return_sql = return_sql.trim();                                         // remove whitespaces
        if (return_sql[return_sql.length-1] == ';')
            return_sql = return_sql.slice(0, -1);                               // remove trailing ;
        return return_sql;
    }

    // find line number of the end of a stmt (;,/)
    find_stmt_end(content_lines){
        for (let i=0; i<content_lines.length; i++){
            let trimmed_line = content_lines[i].trim();
            let last_char = trimmed_line[trimmed_line.length-1];
            if (last_char == ';' || last_char == '/'){
                return i;
            }
        }
        return null;
    }

    get_sql_at_cursor_position_old(editor_id) {
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

    init_tab_container(){
        $( "#sql_worksheet_tab_container" ).easytabs({animate: false}); // initialize tabs
        $("#sql_worksheet_tab_container > .etabs").children().css('display', 'none');   // Hide all tab header at start
    }


    open_and_focus_tab(tab_id, controller, action){
        var tab_obj = $('#'+tab_id+'_area_sql_worksheet_id');
        tab_obj.parent().css('display', 'inline-block');                        // make tab header visible
        tab_obj.click();                                                        // bring tab in foreground

        // var sql_statement = this.get_sql_at_cursor_position_old('sql_text');
        var sql_statement = this.get_sql_at_cursor_position();
        setTimeout(function(){
            ajax_html(tab_id+'_area_sql_worksheet', controller, action, {update_area: 'result_area_sql_worksheet', sql_statement: sql_statement});
        }, 100);                                                                  // Wait until click is processed to hit the visible div
    }

    exec_worksheet_sql(){
        this.open_and_focus_tab('result', 'addition', 'exec_worksheet_sql');            // bring tab in front
    }


    explain_worksheet_sql(){
        this.open_and_focus_tab('explain', 'addition', 'explain_worksheet_sql');            // bring tab in front
    }

    sql_in_sga(){
        this.open_and_focus_tab('sga', 'dba_sga', 'list_last_sql_from_sql_worksheet');            // bring tab in front
        var sql_statement = this.get_sql_at_cursor_position_old('sql_text');
    }


}