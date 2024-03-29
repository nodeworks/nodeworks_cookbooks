resource_name :opsworks_deploy_php

property :app_path, String, name_property: true
property :app_name, String, required: true
property :repository_url, String, required: true
property :repository_key, String, required: true
property :branch, String, required: true
property :short_name, String, required: true
property :app_type, String, required: true
property :environment_vars, Object, required: true
property :app, Object, required: true
property :permission, String, required: true

action :deploy do
  this_resource = new_resource
  stage_env = this_resource.environment_vars

  # Slack Notifications

  # Update repos
  apt_update 'update'

  # Install NodeJS
  bash 'install nodejs' do
    code <<-EOH
      curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
      sudo apt-get install nodejs -y
    EOH
    not_if { ::File.exist?('/etc/apt/sources.list.d/nodesource.list') }
  end

  bash 'install node dependencies' do
    code <<-EOH
      sudo npm i -g pm2 yarn
    EOH
    not_if { ::File.exist?('/usr/bin/pm2') && ::File.exist?('/usr/bin/yarn') }
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
  end

  # Setup the php config files for the site
  template "/etc/php/7.1/fpm/php-fpm.conf" do
    source "php/php-fpm.conf.erb"
    owner "root"
    group "root"
    mode 0644
    variables( :app => this_resource.app )
  end

  template "/etc/php/7.1/fpm/php.ini" do
    source "php/php.ini.erb"
    owner "root"
    group "root"
    mode 0644
    variables( :app => this_resource.app )
  end

  template "/etc/php/7.1/fpm/pool.d/www.conf" do
    source "php/pool.d/www.conf.erb"
    owner "root"
    group "root"
    mode 0644
    variables( :app => this_resource.app )
  end

  # Reload PHP-FPM
  bash 'restarted PHP-FPM' do
    code <<-EOH
      sudo service php7.1-fpm stop
      sudo pm2 delete PHP-FPM
      sudo pm2 start --name PHP-FPM /usr/sbin/php-fpm7.1 -- --nodaemonize --fpm-config /etc/php/7.1/fpm/php-fpm.conf
    EOH
  end

  # Install NGINX
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

  # Deploy git repo from opsworks app
  application this_resource.app_path do
    owner 'www-data'
    group 'www-data'

    git do
      user 'root'
      group 'root'
      revision this_resource.branch
      repository this_resource.repository_url
      deploy_key this_resource.repository_key
    end

    execute "chown-data-www" do
      command "chown -R www-data:www-data #{this_resource.app_path}"
      user "root"
      action :run
    end

    # Setup the environment variables if applicable
    template this_resource.app_path + '/.env' do
      source 'env.erb'
      mode '0660'
      owner 'www-data'
      group 'www-data'
      variables(
          :env => stage_env
      )
      only_if { ::File.exist?(this_resource.app_path + '/.env.example') }
    end

    # Run prod JS script if there is one
    bash 'run misc scripts' do
      cwd this_resource.app_path
      code <<-EOH
        sudo yarn prod &> /dev/null
      EOH
      only_if { ::File.exist?(this_resource.app_path + '/package.json') }
    end

    # Setup the nginx config file for the site
    template "/etc/nginx/sites-enabled/#{this_resource.short_name}" do
      source "nginx/#{this_resource.app_type}.erb"
      owner "root"
      group "root"
      mode 0644
      variables( :app => this_resource.app )
    end

    # Reload/Start nginx
    bash 'restart NGINX' do
      code <<-EOH
        sudo service nginx stop
        sudo pm2 delete NGINX
        sudo pm2 start /usr/sbin/nginx --name NGINX -- -g "daemon off; master_process on;"
      EOH
    end
  end
end
