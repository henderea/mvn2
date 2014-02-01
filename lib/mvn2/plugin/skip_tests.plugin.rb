require 'mvn2/plugin'
class SkipTestsPlugin
  extend Mvn2::Plugin

  register :option, sym: :skip_tests, names: %w(-s --skip-tests), desc: 'skip tests'

  register :command_flag, flag: '-D skipTests', option: :skip_tests

  register(:full_avg_name, order: 10) { |options| options[:skip_tests] ? '-skip' : '-test' }

  register(:operation_name, priority: 10) { |options| options[:skip_tests] ? 'Build' : 'Tests' }
end