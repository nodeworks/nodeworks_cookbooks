name 'nodeworks_opsworks'
maintainer 'Rob Lee'
maintainer_email 'rob@nodeworks.com'
license 'All Rights Reserved'
description 'Installs/Configures nodeworks_opsworks'
long_description 'Installs/Configures nodeworks_opsworks'
version '0.1.0'
chef_version '>= 12.1' if respond_to?(:chef_version)

# The `issues_url` points to the location where issues for this cookbook are
# tracked.  A `View Issues` link will be displayed on this cookbook's page when
# uploaded to a Supermarket.
#
# issues_url 'https://github.com/<insert_org_here>/nodeworks_opsworks/issues'

# The `source_url` points to the development repository for this cookbook.  A
# `View Source` link will be displayed on this cookbook's page when uploaded to
# a Supermarket.
#
# source_url 'https://github.com/<insert_org_here>/nodeworks_opsworks'

depends "chef_slack"
depends "application_git"
depends "certbot"
depends "php-fpm"

recipe "php", "Deploy a PHP application"
recipe "node", "Deploy a Node application"

gem "slack-notifier"