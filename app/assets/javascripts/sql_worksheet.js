class SQL_Worksheet  {
    static get_sql_at_cursor_position(editor_id) {
        var sql_text_elem    = $("#"+editor_id);
        var sql_statement    = '';

        if (sql_text_elem.prop('selectionStart') != sql_text_elem.prop('selectionEnd')){  // text selected in textarea
            sql_statement = sql_text_elem.val().substring(sql_text_elem.prop('selectionStart'), sql_text_elem.prop('selectionEnd'));
        } else {                                                                  // no text select in textarea
            var sql_text_before_cursor =  sql_text_elem.val().substr(0, sql_text_elem.prop('selectionStart'));
            if (sql_text_before_cursor[sql_text_before_cursor.length-1] == "\n")
                sql_text_before_cursor = sql_text_before_cursor.substr(0, sql_text_before_cursor.length-1); // remove trailing linefeed if exists
            var sql_text_lines_before_cursor = sql_text_before_cursor.split("\n");

            var sql_text_after_cursor = sql_text_elem.val().substr(sql_text_elem.prop('selectionStart'));
            if (sql_text_after_cursor[0] == "\n")
                sql_text_after_cursor = sql_text_after_cursor.substr(1);        // remove leading line feed
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

        if (sql_statement[sql_statement.length-1] == ';')
            sql_statement = sql_statement.substr(0, sql_statement.length-1);      // remove trailing ; if exists

        return sql_statement;
    }
}