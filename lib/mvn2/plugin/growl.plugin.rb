require 'everyday-plugins'
include EverydayPlugins
class GrowlPlugin
  extend Plugin
  extend PluginType

  register :option, sym: :no_sticky, names: %w(-n --no-sticky), desc: 'make the growl notification non-sticky'

  register(:notification, order: 100) { |options, _, cmd_clean, message_text|
    path = Dir.getwd
    path = path[(path.rindex('/')+1)..-1]
    begin
      `growlnotify -n Terminal -a Terminal#{(options[:no_sticky] ? '' : ' -s')} -m "#{message_text}" -t "#{path}" 2>&1`
    end until $?.success?
  }
end