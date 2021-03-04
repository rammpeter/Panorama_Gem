require 'date' 

module PanoramaGem
  # VERSION and RELEASE_DATE should have fix syntax and positions because they are parsed from other sites
  VERSION = '2.10.23'
  RELEASE_DATE = Date.parse('2021-03-04')

  RELEASE_DAY   = "%02d" % RELEASE_DATE.day
  RELEASE_MONTH = "%02d" % RELEASE_DATE.month
  RELEASE_YEAR  = "%04d" % RELEASE_DATE.year
end


