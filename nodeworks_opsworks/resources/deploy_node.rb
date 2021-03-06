resource_name :opsworks_deploy_node

property :app_path, String, name_property: true
property :app_name, String, required: true
property :repository_url, String, required: true
property :repository_key, String, required: true
property :branch, String, required: true
property :short_name, String, required: true
property :port, String, required: true
property :app_type, String, required: true
property :environment_vars, Object, required: true
property :app, Object, required: true
property :permission, String, required: true

action :deploy do
  this_resource = new_resource
  stage_path = "#{this_resource.app_path}_stage"
  stage_port = port_open?(this_resource.app[:environment][:PORT]) ? this_resource.app[:environment][:PORT] : this_resource.app[:environment][:PORT].reverse

  stage_env = this_resource.environment_vars
  stage_env[:PORT] = stage_port

  stage_app = this_resource.app
  stage_app[:environment] = stage_env

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

  slack_notify "notify_nginx_installed" do
    message "NGINX has been installed"
    action :nothing
  end

  slack_notify "notify_redis_installed" do
    message "Redis has been installed"
    action :nothing
  end

  slack_notify "notify_nginx_reload" do
    message "NGINX has reloaded"
    action :nothing
  end

  slack_notify "notify_redis_reload" do
    message "Redis has reloaded"
    action :nothing
  end

  slack_notify "notify_prod_moved" do
    message "App directory temporarily moved"
    action :nothing
  end

  slack_notify "notify_pm2_renamed" do
    message "Running PM2 temporarily renamed"
    action :nothing
  end

  slack_notify "notify_delete_old" do
    message "Old app deleted"
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
      sudo npm i -g npm-run-all rimraf cross-env pm2 yarn
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

  # Install NGinx
  package 'nginx' do
    not_if { ::File.exist?("/etc/init.d/nginx") }
    notifies :notify, "slack_notify[notify_nginx_installed]", :immediately
  end

  # Install Redis
  package 'redis-server' do
    not_if { ::File.exist?("/etc/init.d/redis-server") }
    only_if { this_resource.environment_vars['REDIS'] }
    notifies :notify, "slack_notify[notify_redis_installed]", :immediately
  end

  # Reload/Start Redis
  bash 'restart Redis' do
    code <<-EOH
        sudo service redis-server stop
        sudo pm2 delete Redis
        sudo pm2 start /usr/bin/redis-server --name Redis
    EOH
    only_if { this_resource.environment_vars['REDIS'] }
    notifies :notify, "slack_notify[notify_redis_reload]", :immediately
  end

  log 'message' do
    message "PATHS: #{::File.exist?(this_resource.app_path)}"
    level :fatal
  end

  # Move the prod directory if exists
  bash 'move prod directory' do
    cwd this_resource.app_path
    code <<-EOH
      sudo mv #{this_resource.app_path} #{stage_path}
      sudo cd #{stage_path}
      sudo yarn prod:stage
    EOH
    only_if { ::File.exist?(this_resource.app_path) }
    notifies :notify, "slack_notify[notify_prod_moved]", :immediately
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
      notifies :notify, "slack_notify[notify_git_deploy]", :immediately
    end

    # Setup the environment variables
    template this_resource.app_path + '/.env' do
      source 'env.erb'
      mode '0660'
      owner 'www-data'
      group 'www-data'
      variables(
        :env => stage_env
      )
    end

    bash 'install project dependencies' do
      cwd this_resource.app_path
      code <<-EOH
        sudo yarn install
      EOH
    end

    bash 'build app' do
      cwd this_resource.app_path
      code <<-EOH
        sudo yarn build
      EOH
    end

    bash 'run app' do
      cwd this_resource.app_path
      code <<-EOH
        sudo yarn prod
      EOH
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
      variables( :app => stage_app )
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

    # Delete old app
    bash 'Delete and cleanup old app' do
      cwd this_resource.app_path
      code <<-EOH
        sudo yarn prod:delete-tmp
        sudo rm -rf #{stage_path}
      EOH
      notifies :notify, "slack_notify[notify_delete_old]", :immediately
    end
  end
end

action_class do
  def port_open?(port)
    !system("sudo lsof -i:#{port}", out: '/dev/null')
  end
end
