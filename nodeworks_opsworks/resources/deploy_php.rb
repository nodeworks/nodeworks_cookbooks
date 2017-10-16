resource_name :opsworks_deploy_php

property :app_path, String, name_property: true
property :app_name, String, required: true
property :repository_url, String, required: true
property :repository_key, String, required: true
property :short_name, String, required: true
property :app_type, String, required: true
property :environment_vars, Object, required: true
property :app, Object, required: true
property :permission, String, required: true

action :deploy do
  this_resource = new_resource

  # Slack Notifications
  slack_notify "notify_nodejs_installed" do
    message "NodeJS has been installed"
    action :nothing
  end

  slack_notify "notify_nodejs_dependencies" do
    message "NodeJS dependencies have been installed"
    action :nothing
  end

  slack_notify "notify_pm2_slack_installed" do
    message "PM2 slack has been installed/updated"
    action :nothing
  end

  slack_notify "notify_deployment_end" do
    message "App #{this_resource.app_name} deployed successfully"
    action :nothing
  end

  slack_notify "notify_php_restart" do
    message "PHP-FPM has been restarted"
    action :nothing
  end

  slack_notify "notify_php_installed" do
    message "PHP-FPM has been installed"
    action :nothing
  end

  slack_notify "notify_php_config" do
    message "PHP-FPM - php-fpm.conf has been updated for #{this_resource.app_name}"
    action :nothing
  end

  slack_notify "notify_php_ini" do
    message "PHP-FPM - php.ini config has been updated for #{this_resource.app_name}"
    action :nothing
  end

  slack_notify "notify_php_pool" do
    message "PHP-FPM - pool www.conf has been updated for #{this_resource.app_name}"
    action :nothing
  end

  slack_notify "notify_nginx_installed" do
    message "NGINX has been installed"
    action :nothing
  end

  slack_notify "notify_nginx_reload" do
    message "NGINX has reloaded"
    action :nothing
  end

  slack_notify "notify_nginx_config" do
    message "NGINX site config has been updated for #{this_resource.app_name}"
    action :nothing
  end

  slack_notify "notify_git_deploy" do
    message "App #{this_resource.app_name} has been checked out from git"
    action :nothing
  end

  slack_notify "notify_file_permissions" do
    message "App #{this_resource.app_name} has been given proper file permissions"
    action :nothing
  end

  # Update repos
  apt_update 'update'

  # Install NodeJS
  bash 'install nodejs' do
    code <<-EOH
      curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
      sudo apt-get install nodejs -y
    EOH
    not_if { ::File.exist?('/etc/apt/sources.list.d/nodesource.list') }
    notifies :notify, "slack_notify[notify_nodejs_installed]", :immediately
  end

  bash 'install node dependencies' do
    code <<-EOH
      sudo npm i -g pm2 yarn
    EOH
    not_if { ::File.exist?('/usr/bin/pm2') && ::File.exist?('/usr/bin/yarn') }
    notifies :notify, "slack_notify[notify_nodejs_dependencies]", :immediately
  end

  # Setup PM2 Slack
  bash 'setup PM2 Slack' do
    code <<-EOH
      sudo pm2 install pm2-slack
      sudo pm2 set pm2-slack:slack_url #{this_resource.environment_vars['SLACK_WEBHOOK'] ? this_resource.environment_vars['SLACK_WEBHOOK'] : ''}
      sudo pm2 set pm2-slack:username #{this_resource.environment_vars['SLACK_USER'] ? this_resource.environment_vars['SLACK_USER'] : 'ProcessManager'}
      sudo pm2 set pm2-slack:start true
      sudo pm2 set pm2-slack:restart true
      sudo pm2 set pm2-slack:reload true
      sudo pm2 set pm2-slack:online true
      sudo pm2 set pm2-slack:stop true
    EOH
    notifies :notify, "slack_notify[notify_pm2_slack_installed]", :immediately
  end

  # Install PHP-FPM
  bash 'install PHP-FPM' do
    code <<-EOH
      sudo apt-get install -y python-software-properties
      sudo add-apt-repository -y ppa:ondrej/php
      sudo apt-get update -y
      sudo apt-get install -y php7.1 \
      php7.1-cli \
      php7.1-common \
      php7.1-curl \
      php7.1-fpm \
      php7.1-gd \
      php7.1-intl \
      php7.1-json \
      php7.1-mbstring \
      php7.1-mcrypt \
      php7.1-mysql \
      php7.1-opcache \
      php7.1-readline \
      php7.1-xml \
      php7.1-bcmath \
      php7.1-zip
    EOH
    not_if { ::File.exist?('/etc/php/7.1/fpm/php.ini') }
    notifies :notify, "slack_notify[notify_php_installed]", :immediately
  end

  # Setup the php config files for the site
  template "/etc/php/7.1/fpm/php-fpm.conf" do
    source "php/php-fpm.conf.erb"
    owner "root"
    group "root"
    mode 0644
    variables( :app => this_resource.app )
    notifies :notify, "slack_notify[notify_php_config]", :immediately
  end

  template "/etc/php/7.1/fpm/php.ini" do
    source "php/php.ini.erb"
    owner "root"
    group "root"
    mode 0644
    variables( :app => this_resource.app )
    notifies :notify, "slack_notify[notify_php_ini]", :immediately
  end

  template "/etc/php/7.1/fpm/pool.d/www.conf" do
    source "php/pool.d/www.conf.erb"
    owner "root"
    group "root"
    mode 0644
    variables( :app => this_resource.app )
    notifies :notify, "slack_notify[notify_php_pool]", :immediately
  end

  # Reload PHP-FPM
  bash 'restarted PHP-FPM' do
    code <<-EOH
      sudo service php7.1-fpm stop
      sudo pm2 delete PHP-FPM
      sudo pm2 start --name PHP-FPM /usr/sbin/php-fpm7.1 -- --nodaemonize --fpm-config /etc/php/7.1/fpm/php-fpm.conf
    EOH
    notifies :notify, "slack_notify[notify_php_restart]", :immediately
  end

  # Install NGINX
  package 'nginx' do
    not_if { ::File.exist?("/etc/init.d/nginx") }
    notifies :notify, "slack_notify[notify_nginx_installed]", :immediately
  end

  # Setup the app directory
  directory this_resource.app_path do
    owner 'www-data'
    group 'www-data'
    mode '0755'
    recursive true
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
      source "nginx/#{this_resource.app_type}.erb"
      owner "root"
      group "root"
      mode 0644
      variables( :app => this_resource.app )
      notifies :notify, "slack_notify[notify_nginx_config]", :immediately
    end

    # Reload/Start nginx
    bash 'restart NGINX' do
      code <<-EOH
        sudo service nginx stop
        sudo pm2 delete NGINX
        sudo pm2 start /usr/sbin/nginx --name NGINX -- -g "daemon off; master_process on;"
      EOH
      notifies :notify, "slack_notify[notify_nginx_reload]", :immediately
    end
  end
end