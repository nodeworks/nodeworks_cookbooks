#
# Cookbook:: nodeworks_opsworks
# Recipe:: node
#
# Copyright:: 2017, The Authors, All Rights Reserved.

# Setup the variables.
command = search(:aws_opsworks_command).first
deploy_app = command[:args][:app_ids].first
app = search(:aws_opsworks_app, "app_id:#{deploy_app}").first
app_path = "/var/www/" + app[:shortname]

# Deploy the application.
opsworks_deploy_node app_path do
  app_name app[:name]
  app_type app[:environment][:APP_TYPE]
  repository_url app[:app_source][:url]
  repository_key app[:app_source][:ssh_key]
  short_name app[:shortname]
  app app
  permission '0755'
end

# Log the events to Slack.
Chef.event_handler do
  # Called at the very start of a Chef Run
  on :run_start do |version|

  end

  # Called at the end of the Chef run.
  on :run_completed do |node|
    NodeworksNotify.send_notification("#{app[:name]} deploy was successful")
  end

  # Called at the end of a failed run.
  on :run_failed do |exception|
    NodeworksNotify.send_notification("#{app[:name]} deploy failed -- #{exception.message}")
  end

  # Called before action is executed on a resource.
  on :resource_action_start do |resource, action, notification_type, notifier|

  end

  # Called after a resource has been completely converged.
  on :resource_updated do |new_resource, action|
    if new_resource.to_s == 'template[/etc/nginx/nginx.conf]'

    end
  end

  # Called when a resource action has been skipped b/c of a conditional.
  on :resource_skipped do |resource, action, conditional|

  end

  # Called when a resource has no converge actions, e.g., it was already correct.
  on :resource_up_to_date do |resource, action|

  end

  # Called when a resource fails and will not be retried.
  on :resource_failed do |resource, action, exception|

  end

  # The chef-client is attempting to load node data from the Chef server.
  on :node_load_start do |node_name, config|

  end

  # Default and override attrs from roles have been computed, but not yet applied.
  # Normal attrs from JSON have been added to the node.
  on :node_load_completed do |node, expanded_run_list, config|

  end
end
