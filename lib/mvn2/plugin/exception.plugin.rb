require 'everyday-plugins'
include EverydayPlugins
class ExceptionPlugin
  extend Plugin

  register :option, sym: :exception, names: %w(-e --exception), desc: 'add the "-e -X" options to the mvn call'

  register :command_flag, flag: '-e -X', option: :exception
end