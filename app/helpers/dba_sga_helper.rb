
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


end