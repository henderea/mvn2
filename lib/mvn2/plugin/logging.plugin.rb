require 'everyday-plugins'
include EverydayPlugins
class LoggingPlugin
  extend Plugin
  extend PluginType

  register :option, sym: :write_log, names: %w(-l --write-log), desc: 'write all of the output to a log file'
  register :option_with_param, sym: :log_file, names: ['--log-file'], desc: 'set the log file name', default: 'build.log'

  register :log_file_name, priority: 1000, option: :log_file

  register :log_file_enable, option: :write_log
end