require 'slack-notifier'

class Chef::Recipe::NodeworksNotify
  def self.send_notification(text)
    notifier = Slack::Notifier.new "https://hooks.slack.com/services/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"
    notifier.ping text
  end
end
