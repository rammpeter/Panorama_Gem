# create secrets for encryption

secrets_file = File.join(Rails.root, 'config', 'secrets.yml')
content = "
# File generated by config/initializers/create_secrets.rb

development:
    secret_key_base: \"#{EnvHelper.secret_key_base}\"

test:
    secret_key_base: \"#{EnvHelper.secret_key_base}\"

production:
    secret_key_base: \"#{EnvHelper.secret_key_base}\"
"
begin
  File.write(secrets_file, content)
rescue Exception => e
  puts "Error creating secrets file '#{secrets_file}'\n#{e.class}: #{e.message}"
end

