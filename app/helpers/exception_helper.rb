module ExceptionHelper
  def log_exception_backtrace(exception, line_number_limit=nil)
    Rails.logger.error "Stack-Trace for exception: #{exception.message}"
    curr_line_no=0
    exception.backtrace.each do |bt|
      Rails.logger.error bt if line_number_limit.nil? || curr_line_no < line_number_limit # report First x lines of stacktrace in log
      curr_line_no += 1
    end
  end
end

