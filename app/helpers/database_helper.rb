# encoding: utf-8

# Hilfsmethoden mit Bezug auf die aktuell verbundene Datenbank sowie verbundene Einstellunen wie Sprache
module DatabaseHelper

  private
  def get_salted_encryption_key
    #"#{cookies['client_salt']}#{Rails.application.config.secret_key_base}"
    "#{cookies['client_salt']}#{Rails.application.secrets.secret_key_base}"       # Position of key after siwtch to config/secrets.yml
  end

  public
  # Client-spezifisches Verschlüsseln eines Wertes, Teil des Schlüssels liegt client-spezifisch als verschlüsselter cookie im Browser des Clients
  def database_helper_encrypt_value(raw_value)
    crypt = ActiveSupport::MessageEncryptor.new(get_salted_encryption_key)
    crypt.encrypt_and_sign(raw_value)
  end

  # Client-spezifisches Entschlüsseln des Wertes,  Teil des Schlüssels liegt client-spezifisch als verschlüsselter cookie im Browser des Clients
  def database_helper_decrypt_value(encrypted_value)
    crypt = ActiveSupport::MessageEncryptor.new(get_salted_encryption_key)
    crypt.decrypt_and_verify(encrypted_value)
  end

private
  # Notation für Connect per JRuby
  def jdbc_thin_url
    current_database = read_from_client_info_store(:current_database)
    raise 'No current DB connect info set! Please reconnect to DB!' unless current_database
    "jdbc:oracle:thin:@#{current_database[:tns]}"
  end

public

  def open_oracle_connection
    current_database = read_from_client_info_store(:current_database)

    # Unterscheiden der DB-Adapter zwischen Ruby und JRuby
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"

      begin
        config = ConnectionHolder.connection.instance_variable_get(:@config)  # Aktuelle config, kann reduziert sein auf :adapter bei NullDB
      rescue Exception => e
        Rails.logger.warn "Error: ConnectionHolder.connection.instance_variable_get(:@config): #{e.message}"
        Rails.logger.warn "Resetting connection to dummy"
        set_dummy_db_connection
        config = {}
      end
      # Connect nur ausführen wenn bisherige DB-Connection nicht der gewünschten entspricht
      if ConnectionHolder.connection.class.name != 'ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter' ||
          config[:adapter]  != 'oracle_enhanced' ||
          config[:driver]   != 'oracle.jdbc.driver.OracleDriver' ||
          config[:url]      != jdbc_thin_url ||
          config[:username] != get_current_database[:user]

        # Entschlüsseln des Passwortes
        begin
          local_password = database_helper_decrypt_value(get_current_database[:password])
        rescue Exception => e
          Rails.logger.warn "Error in open_oracle_connection decrypting pasword: #{e.message}"
          raise "One part of encryption key for stored password has changed at server side! Please connect giving username and password."
        end
        ConnectionHolder.establish_connection(
            :adapter  => "oracle_enhanced",
            :driver   => "oracle.jdbc.driver.OracleDriver",
            :url      => jdbc_thin_url,
            :username => get_current_database[:user],
            :password => local_password,
            :privilege => get_current_database[:privilege],
            :cursor_sharing => :exact             # oracle_enhanced_adapter setzt cursor_sharing per Default auf force
        )
        Rails.logger.info "Connecting database: URL='#{jdbc_thin_url}' User='#{get_current_database[:user]}'"
      else
        Rails.logger.info "Using already connected database: URL='#{jdbc_thin_url}' User='#{get_current_database[:user]}'"
      end

    else
      raise "Native ruby (RUBY_ENGINE=#{RUBY_ENGINE}) is no longer supported! Please use JRuby runtime environment! Call contact for support request if needed."
    end

    # No exception handling at this time because connection problems are raised at first access
  end

  # Format für JQuery-UI Plugin DateTimePicker
  def timepicker_dateformat
    case get_locale
      when "de" then "dd.mm.yy"
      when "en" then "yy-mm-dd"
      else "dd.mm.yy"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Tag
  def strftime_format_with_days
    case get_locale
      when "de" then "%d.%m.%Y"
      when "en" then "%Y-%m-%d"
      else "%d.%m.%Y"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf sekunden
  def strftime_format_with_seconds
    case get_locale
      when "de" then "%d.%m.%Y %H:%M:%S"
      when "en" then "%Y-%m-%d %H:%M:%S"
      else "%d.%m.%Y %H:%M:%S"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Minuten
  def strftime_format_with_minutes
    case get_locale
      when "de" then "%d.%m.%Y %H:%M"
      when "en" then "%Y-%m-%d %H:%M"
      else "%d.%m.%Y %H:%M"     # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_second_mask
    case get_locale
      when "de" then "DD.MM.YYYY HH24:MI:SS"
      when "en" then "YYYY-MM-DD HH24:MI:SS"
      else "DD.MM.YYYY HH24:MI:SS" # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_minute_mask
    case get_locale
      when "de" then "DD.MM.YYYY HH24:MI"
      when "en" then "YYYY-MM-DD HH24:MI"
      else "DD.MM.YYYY HH24:MI" # Deutsche Variante als default
    end
  end

    # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_date_mask
    case get_locale
      when "de" then "DD.MM.YYYY"
      when "en" then "YYYY-MM-DD"
      else "DD.MM.YYYY" # Deutsche Variante als default
    end
  end

  # Entscheiden auf Grund der Länge der Eingabe, welche Maske hier zu verwenden ist
  def sql_datetime_mask(datetime_string)
    return "sql_datetime_mask: Parameter=nil" if datetime_string.nil?           # Maske nicht verwendbar
    datetime_string.strip!                                                      # remove leading and trailing blanks
    case datetime_string.length
      when 10 then sql_datetime_date_mask
      when 16 then sql_datetime_minute_mask
      when 19 then sql_datetime_second_mask
      else
        raise "sql_datetime_mask: No SQL datetime mask found for '#{datetime_string}'"
    end

  end

  # Menschenlesbare Ausgabe in Hints etc
  def human_datetime_minute_mask
    case get_locale
      when "de" then "TT.MM.JJJJ HH:MI"
      when "en" then "YYYY-MM-DD HH:MI"
      else "TT.MM.JJJJ HH:MI" # Deutsche Variante als default
    end
  end

  # Menschenlesbare Ausgabe in Hints etc
  def human_datetime_day_mask
    case get_locale
      when "de" then "TT.MM.JJJJ"
      when "en" then "YYYY-MM-DD"
      else "TT.MM.JJJJ" # Deutsche Variante als default
    end
  end


  def numeric_thousands_separator
    case get_locale
      when "de" then "."
      when "en" then ","
      else "." # Deutsche Variante als default
    end
  end


  def numeric_decimal_separator
    case get_locale
      when "de" then ","
      when "en" then "."
      else "," # Deutsche Variante als default
    end
  end

  def format_sql(sql_text)
    return sql_text if sql_text["\n"]                                           # SQL is already linefeed-formatted

    sql = sql_text.clone

    # Line feed at keywords
    pos = 0
    while pos < sql.length
      cmp_str = sql[pos, 25].upcase                                             # Compare sql beginning at pos, next 25 chars

      [                                                                         # Process array with searches and stepwidth
          [ '\(SELECT\s'              , 6],
          [ '\s+SELECT\s'             , 6],
          [ '\s+FROM\s'               , 5],
          [ '\s+LEFT +OUTER +JOIN\s'  , 15],
          [ '\s+LEFT +JOIN\s'         , 9],
          [ '\s+JOIN\s'               , 4],
          [ '\s+WHERE\s'              , 5],
          [ '\s+GROUP\s+BY'           , 8],
          [ '\s+ORDER\s+BY'           , 8],
          [ '\s+CASE\s+'              , 4],
          [ '\s+WHEN\s+'              , 4],
          [ '\s+ELSE\s+'              , 4],
          [ '\s+UNION\s+'             , 5],
      ].each do |c|
        if cmp_str.match("^#{c[0]}")
          sql.insert(pos+1, "\n")
          pos += c[1]
        end
      end
      pos+=1                                                                    # Compare next char
    end

    # Hierarchy-depth

    pos         = 0
    comment     = false
    depth       = 0
    with_active = false
    with_started= false

    while pos < sql.length

      comment = true  if sql[pos, 2] == '/*'
      comment = false if sql[pos, 2] == '*/'

      unless comment
        if sql[pos] == '('
          depth += 1
        end
        if sql[pos] == ')'
          depth -= 1
        end
      end

      if with_active && with_started && depth == 0                              # end / switch to next with block
        next_new_line_pos = sql.index("\n", pos)                                # Position of next newline
        lf_pos = sql.index(/[,]/, pos)                                          # look for next comma
        if !lf_pos.nil? && sql[lf_pos+1] != "\n" &&                             # next comma not followed by newline
            (next_new_line_pos.nil? || lf_pos < next_new_line_pos)              # comma before next newline
          sql.insert(lf_pos+1, "\n")
          while sql[lf_pos+2] == ' ' do                                         # remove leading blanks from new line
            sql.slice!(lf_pos+2)
          end
          with_started = false                                                  # only one linefeed per WITH-select
        end
      end

      if pos == 0 || sql[pos-1] == "\n"                                         # New line indent
        cmp_str = sql[pos, sql.length-pos].upcase                               # Compare sql beginning at pos

        with_active = true  if cmp_str.index("WITH\s"  ) == 0                   # WITH-block active
        with_active = false if cmp_str.index("SELECT\s") == 0 && depth == 0     # First SELECT after WITH at base depth ends WITH-Block
        with_started = true if with_active && depth > 0                         # mark start of first with block

        max_line_length = 80                                                    # Check maximum line length
        # Wrap line at AND
        next_new_line_pos = cmp_str.index("\n")
        if (next_new_line_pos && next_new_line_pos > max_line_length) || ( next_new_line_pos.nil? && cmp_str.length >= max_line_length )
          rev_str = cmp_str[0, max_line_length].reverse
          lf_pos = rev_str.index(/\sDNA\s/)                                   # Look for last AND before max_line_length
          unless lf_pos.nil?                                                  # AND found before max_new_line_pos
            sql.insert(pos+max_line_length-lf_pos-4, "\n")
            cmp_str = sql[pos, sql.length-pos].upcase                         # Refresh Compare sql beginning at pos for next comparison
          else                                                                # Comma not found before max_new_line_pos
            lf_pos = cmp_str.index(/\sAND\s/, max_line_length)                # look for next comma after max_line_length
            if !lf_pos.nil? && (next_new_line_pos.nil? || lf_pos < next_new_line_pos)
              sql.insert(pos+lf_pos+1, "\n")
              cmp_str = sql[pos, sql.length-pos].upcase                         # Refresh Compare sql beginning at pos for next comparison
            end
          end
        end

        # Wrap line at maximum length
        next_new_line_pos = cmp_str.index("\n")
        if (next_new_line_pos && next_new_line_pos > max_line_length) || ( next_new_line_pos.nil? && cmp_str.length >= max_line_length )
          rev_str = cmp_str[0, max_line_length].reverse
          lf_pos = rev_str.index(/[,]/)                                       # Look for last comma before max_line_length
          unless lf_pos.nil?                                                  # Comma found before max_new_line_pos
            sql.insert(pos+max_line_length-lf_pos, "\n")
            while sql[pos+max_line_length-lf_pos+1] == ' ' do                 # remove leading blanks from new line
              sql.slice!(pos+max_line_length-lf_pos+1)
            end
          else                                                                # Comma not found before max_new_line_pos
            lf_pos = cmp_str.index(/[,]/, max_line_length)                    # look for next comma after max_line_length
            if !lf_pos.nil? && (next_new_line_pos.nil? || lf_pos < next_new_line_pos)
              sql.insert(pos+lf_pos, "\n")
              while sql[pos+lf_pos+1] == ' ' do                               # remove leading blanks from new line
                sql.slice!(pos+lf_pos+1)
              end
            end
          end
        end


        # indent normal content
        if  cmp_str.index("SELECT\s") != 0 &&
            cmp_str.index("FROM\s"  ) != 0 &&
            cmp_str.index("JOIN\s"  ) != 0 &&
            cmp_str.index("UNION\s" ) != 0 &&
            cmp_str.index("LEFT\s"  ) != 0 &&
            cmp_str.index("OUTER\s" ) != 0 &&
            cmp_str.index("WHERE\s" ) != 0 &&
            cmp_str.index("WITH\s"  ) != 0 &&
            cmp_str.index("GROUP\s" ) != 0 &&
            cmp_str.index("ORDER\s" ) != 0 &&
            !(with_active && depth == 0)
          sql.insert(pos, '    ')
          pos += 4
        end

        # Indent hierarchy
        depth.downto(1) do
          sql.insert(pos, '    ')
          pos += 4
        end
      end

      pos+=1                                                                    # Compare next char
    end




    "/* single line SQL-text formatted by Panorama */\n#{sql}"
  end

end