name 'nodeworks_opsworks'
maintainer 'Rob Lee'
maintainer_email 'rob@nodeworks.com'
license 'All Rights Reserved'
description 'Installs/Configures nodeworks_opsworks'
long_description 'Installs/Configures nodeworks_opsworks'
version '0.1.0'

depends "application_git"
depends "certbot"
depends "php-fpm"

recipe "php", "Deploy a PHP application"
recipe "node", "Deploy a Node application"

gem "slack-notifier"