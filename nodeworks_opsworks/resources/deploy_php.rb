resource_name :opsworks_deploy_php

property :app_path, String, name_property: true
property :app_name, String, required: true
property :repository_url, String, required: true
property :repository_key, String, required: true
property :short_name, String, required: true
property :app_type, String, required: true
property :app, Object, required: true
property :permission, String, required: true

action :deploy do
  this_resource = new_resource

  apt_update 'update'

  # Install NGinx
  package 'nginx' do
    not_if { ::File.exist?("/etc/init.d/nginx") }
  end

  # Setup the app directory
  directory this_resource.app_path do
    owner 'www-data'
    group 'www-data'
    mode '0755'
    recursive true
  end

  slack_notify "notify_deployment_end" do
    message "App #{this_resource.app_name} deployed successfully"
    action :nothing
  end

  slack_notify "notify_nginx_reload" do
    message "Nginx has reloaded"
    action :nothing
  end

  slack_notify "notify_nginx_config" do
    message "Nginx site config has been updated for #{this_resource.app_name}"
    action :nothing
  end

  slack_notify "notify_git_deploy" do
    message "App #{this_resource.app_name} has been checkout out from git"
    action :nothing
  end

  slack_notify "notify_file_permissions" do
    message "App #{this_resource.app_name} has been given proper file permissions"
    action :nothing
  end

  # Deploy git repo from opsworks app
  application this_resource.app_path do
    owner 'www-data'
    group 'www-data'

    git do
      user 'root'
      group 'root'
      repository this_resource.repository_url
      deploy_key this_resource.repository_key
      notifies :notify, "slack_notify[notify_git_deploy]", :immediately
    end

    execute "chown-data-www" do
      command "chown -R www-data:www-data #{this_resource.app_path}"
      user "root"
      action :run
      notifies :notify, "slack_notify[notify_file_permissions]", :immediately
    end

    # Setup the nginx config file for the site
    template "/etc/nginx/sites-enabled/#{this_resource.short_name}" do
      source "#{this_resource.app_type}.erb"
      owner "root"
      group "root"
      mode 0644
      variables( :app => this_resource.app )
      notifies :notify, "slack_notify[notify_nginx_config]", :immediately
    end

    # Reload nginx
    service "nginx" do
      supports :status => true, :restart => true, :reload => true, :stop => true, :start => true
      action :reload
      notifies :notify, "slack_notify[notify_nginx_reload]", :immediately
    end
  end
end