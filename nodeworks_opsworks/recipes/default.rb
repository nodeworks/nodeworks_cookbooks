#
# Cookbook:: nodeworks_opsworks
# Recipe:: default
#
# Copyright:: 2017, Rob Lee, All Rights Reserved.

# Setup the variables.
command = search(:aws_opsworks_command).first
deploy_app = command[:args][:app_ids].first
app = search(:aws_opsworks_app, "app_id:#{deploy_app}").first
app_path = "/var/www/" + app[:shortname]

if ['drupal7', 'drupal8', 'wordpress'].include? app[:environment][:APP_TYPE]
  # Deploy the PHP based application.
  opsworks_deploy_php app_path do
    app_name app[:name]
    app_type app[:environment][:APP_TYPE]
    repository_url app[:app_source][:url]
    repository_key app[:app_source][:ssh_key]
    branch app[:app_source][:revision]
    short_name app[:shortname]
    environment_vars app[:environment]
    app app
    permission '0755'
  end
end

if ['react', 'node', 'angularjs', 'angular2', 'angular4'].include? app[:environment][:APP_TYPE]
  # Deploy the NodeJS based application.
  opsworks_deploy_node app_path do
    app_name app[:name]
    app_type app[:environment][:APP_TYPE]
    repository_url app[:app_source][:url]
    repository_key app[:app_source][:ssh_key]
    branch app[:app_source][:revision]
    short_name app[:shortname]
    environment_vars app[:environment]
    app app
    permission '0755'
  end
end

# Log the events to Slack.
