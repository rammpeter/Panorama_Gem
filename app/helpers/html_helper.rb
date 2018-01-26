# encoding: utf-8

# Diverse Methoden für Client-GUI
module HtmlHelper

 # Anzeige eines start und ende-datetimepickers (alte Variante mit float_left)
  def include_start_end_timepicker_float_left(id_suffix = "default", additional_title = nil)
    start_id = "time_selection_start_#{id_suffix}"
    end_id   = "time_selection_end_#{id_suffix}"

    additional_title = "\n#{additional_title}" unless additional_title.nil?

    "
    <div class='float_left' title=\"#{t :time_selection_start_hint, :default=>"Start of considered time period in format"} '#{human_datetime_minute_mask}'#{additional_title}\">
      #{t :time_selection_start_caption, :default=>"Start"}
      #{ text_field_tag(:time_selection_start, default_time_selection_start, :size=>16, :id=>start_id) }
    </div>
    <div class='float_left' title=\"#{t :time_selection_end_hint, :default=>"End of considered time period in format"} '#{human_datetime_minute_mask}'#{additional_title}\">
      #{t :time_selection_end_caption, :default=>"End"}
      #{ text_field_tag(:time_selection_end, default_time_selection_end, :size=>16, :id=>end_id) }
    </div>

    <script type='text/javascript'>
       $('##{start_id}').datetimepicker();
       $('##{end_id}').datetimepicker();
    </script>
    ".html_safe
  end

  # Anzeige eines start und ende-datetimepickers (neue Variante für display:flex)
  def include_start_end_timepicker(id_suffix = "default", additional_title = nil)
    start_id = "time_selection_start_#{id_suffix}"
    end_id   = "time_selection_end_#{id_suffix}"

    additional_title = "\n#{additional_title}" unless additional_title.nil?

    "
    <div class='flex-element' title=\"#{t :time_selection_start_hint, :default=>"Start of considered time period in format"} '#{human_datetime_minute_mask}'#{additional_title}\">
      #{t :time_selection_start_caption, :default=>"Start"}
    #{ text_field_tag(:time_selection_start, default_time_selection_start, :size=>16, :id=>start_id) }
    </div>
    <div class='flex-element' title=\"#{t :time_selection_end_hint, :default=>"End of considered time period in format"} '#{human_datetime_minute_mask}'#{additional_title}\">
      #{t :time_selection_end_caption, :default=>"End"}
    #{ text_field_tag(:time_selection_end, default_time_selection_end, :size=>16, :id=>end_id) }
    </div>

    <script type='text/javascript'>
       $('##{start_id}').datetimepicker();
       $('##{end_id}').datetimepicker();
    </script>
    ".html_safe
  end


end

