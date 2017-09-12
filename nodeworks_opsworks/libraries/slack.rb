require 'slack-notifier'

class Chef::Recipe::NodeworksNotify
  def self.send_notification(text)
    notifier = Slack::Notifier.new "https://hooks.slack.com/services/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"
    notifier.ping text
  end
end
