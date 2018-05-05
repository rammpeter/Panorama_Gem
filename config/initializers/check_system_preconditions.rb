require 'java'

Rails.logger.info "################### java.io.tmpdir = #{java.lang.System.get_property('java.io.tmpdir')}"