class PackLicense

  DIAGNOSTIC_PACK            = PackLicense.new(:diagnostic_pack)
  DIAGNOSTIC_AND_TUNING_PACK = PackLicense.new(:diagnostic_and_tuning_pack)
  DIAGNOSTIC_AND_TUNING_PACK = PackLicense.new(:none)

  def initialize(license_type)
    raise "Unknown license type #{license_type}" unless [:diagnostic_pack, :diagnostic_and_tuning_pack, :none].include?(license_type)
    @license_type = license_type

  end


end