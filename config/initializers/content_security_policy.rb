# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

# TODOs:
# uncomment policy.script_src
# uncomment Rails.application.config.content_security_policy_nonce_generator
# uncomment Rails.application.config.content_security_policy_nonce_directives
# add  nonce="<%= request.content_security_policy_nonce %>" to <script> inlines
# refactor inline event handler according to https://csp.withgoogle.com/docs/adopting-csp.html

Rails.application.config.content_security_policy do |policy|
  #  policy.default_src :self
#   policy.font_src    :self, :https, :data
#   policy.img_src     :self, :https, :data
#   policy.object_src  :none #
  # policy.script_src  :self,
    policy.style_src   :self, :unsafe_inline
#   # If you are using webpack-dev-server then specify webpack-dev-server host
#   policy.connect_src :self, :https, "http://localhost:3035", "ws://localhost:3035" if Rails.env.development?

#   # Specify URI for violation reports
#   # policy.report_uri "/csp-violation-report-endpoint"
  policy.frame_ancestors :none                                                  # Ensure application is not used in iFrames
end

# If you are using UJS then enable automatic nonce generation
# Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }

# Set the nonce only to specific directives
# Rails.application.config.content_security_policy_nonce_directives = %w(script-src)

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true
