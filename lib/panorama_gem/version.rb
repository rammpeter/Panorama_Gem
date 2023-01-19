require 'date' 

module PanoramaGem
  # VERSION and REL EASE_DATE should have fix syntax and positions because they are parsed from other sites
  VERSION = '2.16.9'
  RELEASE_DATE = Date.parse('2023-01-19')
  RELEASE_DAY   = "%02d" % RELEASE_DATE.day
  RELEASE_MONTH = "%02d" % RELEASE_DATE.month
  RELEASE_YEAR  = "%04d" % RELEASE_DATE.year
end


