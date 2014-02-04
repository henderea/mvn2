require 'everyday-plugins'
include EverydayPlugins
class DefaultRunnerPlugin
  extend Plugin
  extend PluginType

  register_variable :output

  def self.def_runners
    register(:runner_enable, key: :default) { |_| true }

    register(:runner, key: :default, priority: 0) { |_, cmd|
      output = `#{cmd}`
      result = $?.success?
      Plugins.set_var :output, output
      result
    }
  end

  def_runners

  def self.def_actions
    register(:after_run, order: 1000) { |_, _|
      runner = Plugins.get_var :runner
      if runner == :default
        output = Plugins.get_var :output
        IO.write(Plugins.get(:log_file_name), output) if Plugins.get(:log_file_enable)
        output.each_line { |l|
          tmp = Plugins.get :line_filter, l
          puts tmp unless tmp.nil?
        }
        found = Plugins.get_var :found
        output.each_line { |line| puts line } unless found
      end
    }
  end

  def_actions
end