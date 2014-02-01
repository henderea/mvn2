require 'mvn2/plugin'
class DefaultRunnerPlugin
  extend Mvn2::Plugin
  extend Mvn2::PluginType

  register_variable :output

  register(:runner_enable, key: :default) { |_| true }

  register(:runner, key: :default, priority: 0) { |_, cmd|
    output = `#{cmd}`
    result = $?.success?
    Mvn2::Plugins.set_var :output, output
    result
  }

  register(:after_run, order: 1000) { |_, _|
    runner = Mvn2::Plugins.get_var :runner
    if runner == :default
      output = Mvn2::Plugins.get_var :output
      IO.write(Mvn2::Plugins.get(:log_file_name), output) if Mvn2::Plugins.get(:log_file_enable)
      output.each_line { |l|
        tmp = Mvn2::Plugins.get :line_filter, l
        puts tmp unless tmp.nil?
      }
      found = Mvn2::Plugins.get_var :found
      output.each_line { |line| puts line } unless found
    end
  }
end