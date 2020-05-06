# encoding: utf-8

# Diverse Methoden für Client-GUI
module HtmlHelper

  # Anzeige eines start und ende-datetimepickers (neue Variante für display:flex)
  def include_start_end_timepicker(id_suffix = "default", additional_title = nil)
    start_id = "time_selection_start_#{id_suffix}"
    end_id   = "time_selection_end_#{id_suffix}"

    additional_title = "\n#{additional_title}" unless additional_title.nil?

    "
    <div class='flex-row-element' title=\"#{t :time_selection_start_hint, :default=>"Start of considered time period in format"} '#{human_datetime_minute_mask}'#{additional_title}\">
      #{t :time_selection_start_caption, :default=>"Start"}
    #{ text_field_tag(:time_selection_start, default_time_selection_start, :size=>16, :id=>start_id) }
    </div>
    <div class='flex-row-element' title=\"#{t :time_selection_end_hint, :default=>"End of considered time period in format"} '#{human_datetime_minute_mask}'#{additional_title}\">
      #{t :time_selection_end_caption, :default=>"End"}
    #{ text_field_tag(:time_selection_end, default_time_selection_end, :size=>16, :id=>end_id) }
    </div>

    <script type='text/javascript'>
       $('##{start_id}').datetimepicker();
       $('##{end_id}').datetimepicker();
    </script>
    ".html_safe
  end

  def instance_tag(required = false)
    if required
      instance = read_from_client_info_store(:instance)
      instance = 1 if instance.nil?
    end

    "<div class='flex-row-element' title='#{t(:instance_filter_hint, default: 'Filter on specific RAC instance')} (#{required ? "#{t(:mandatory, default: 'mandatory')}" : 'Optional'})'>
       Instance
       #{text_field_tag(:instance, instance, size: 1, style: "text-align:right;")}
    </div>".html_safe
  end

end

