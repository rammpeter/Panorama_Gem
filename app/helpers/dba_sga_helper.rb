
# encoding: utf-8
module DbaSgaHelper

  # Gruppierungskriterien für historic resize operations
  def historic_resize_grouping_options
    {
        second:   t(:second, :default=>'Second'),
        minute:   'Minute',
        hour:     t(:hour,  :default => 'Hour'),
        day:      t(:day,  :default => 'Day'),
        week:     t(:week, :default => 'Week')
    }

  end

  def historic_resize_link_ops(update_area, rec, value, org_value, component, oper_type)
    if org_value.nil? || org_value == 0
      value
    else
      ajax_link(value, {
          :controller    => :dba_sga,
          :action        => :list_resize_operations_historic_single_record,
          :instance      => @instance,
          component:    component,
          oper_type:    oper_type,
          time_selection_start: localeDateTime(rec.min_start_time),
          time_selection_end:   localeDateTime(rec.max_end_time),
          :update_area => update_area
      },
                :title=> "Show single resize operations for this period#{" and component = #{component}" if component}#{" and operation_type = #{oper_type}" if oper_type}")
    end
  end


end