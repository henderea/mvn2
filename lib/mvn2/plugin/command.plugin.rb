require 'everyday-plugins'
include EverydayPlugins
class CommandPlugin
  extend Plugin
  extend PluginType

  def self.def_options
    register :option_with_param, sym: :command_override, names: ['--command-override'], desc: 'override the maven command (disables average tracking options and skip test option)'
    register :option, sym: :package, names: %w(-p --package), desc: 'run "mvn clean package" (with optional "-D skipTests")'
    register :option_with_param, sym: :run_before, names: ['--run-before'], desc: 'run a command before calling the maven build'
    register :option_with_param, sym: :run_after, names: ['--run-after'], desc: 'run a command after finishing the maven build'
    register :option_with_param, sym: :run_success, names: ['--run-success'], desc: 'run a command after finishing a successful maven build'
    register :option_with_param, sym: :run_failure, names: ['--run-failure'], desc: 'run a command after finishing an unsuccessful maven build'
    register :option_with_param, sym: :run_test, names: ['--run-test'], desc: 'run a specific test class or method(s) (support dependent on maven surefire plugin version)'
  end

  def_options

  def self.def_others
    register :goal_override, order: 10, option: :package, goal: 'package'

    register(:goal_override, order: 20) { |options| options[:run_test].nil? ? nil : 'test' }

    register(:command_flag) { |options, flags| flags << ' -Dtest=' << options[:run_test] << ' -DfailIfNoTests=false' unless options[:run_test].nil? }

    register :goal_override, override_all: true, priority: 100, option: :command_override

    register(:full_avg_name, order: 20) { |options| options[:package] ? '-package' : '' }

    register(:operation_name, priority: 100) { |options| options[:command_override].nil? ? nil : 'Operation' }

    register(:block_average) { |options| !options[:command_override].nil? || !options[:run_test].nil? }
  end

  def_others

  def self.def_actions
    register(:before_start, order: 10) { |options| run_cmd(options[:run_before]) }

    register(:after_end, order: 10) { |options, result|
      run_cmd(options[:run_after])
      result ? run_cmd(options[:run_success]) : run_cmd(options[:run_failure])
    }
  end

  def_actions

  def self.run_cmd(cmd)
    unless cmd.nil?
      puts "$ #{cmd}"
      system(cmd)
      print "\n"
    end
  end
end