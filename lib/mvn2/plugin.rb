require 'everyday-cli-utils'
include EverydayCliUtils
import :maputil
require 'everyday-plugins'
include EverydayPlugins

module Mvn2

  module TypeHelper
    def basic_type(list, *args)
      options = Plugins.get_var :options
      list.any? { |item|
        if item[:block].nil?
          flag_boolean(item, options)
        else
          item[:block].call(options, *args)
        end
      }
    end

    def flag_boolean(item, options)
      item[:options].has_key?(:option) && options[item[:options][:option]] == (item[:options].has_key?(:value) ? item[:options][:value] : true)
    end

    def complex_filter(list, options, symbol)
      list.filtermap { |item|
        if item[:block].nil?
          if item[:options].has_key?(symbol) && flag_boolean(item, options)
            item[:options][symbol]
          else
            item[:options].has_key?(:option) && !options[item[:options][:option]].nil? ? options[item[:options][:option]] : false
          end
        else
          rval = item[:block].call(options)
          (rval.nil? || !rval) ? false : rval
        end
      }
    end

    def simple_type(list, *args)
      options = Plugins.get_var :options
      list.sort_by { |v| v[:options][:order] }.each { |item| item[:block].call(options, *args) }
    end

    def simple_type_with_result(list)
      result = Plugins.get_var :result
      simple_type(list, result)
    end

    def get_name(list)
      options = Plugins.get_var :options
      rval    = complex_filter(list.sort_by { |v| -v[:options][:priority] }, options, :name)
      (rval.nil? || rval.empty?) ? false : rval.first
    end
  end
  class OptionTypes
    extend PluginType
    extend TypeHelper

    def self.register_option(list, options)
      list.sort_by { |v| v[:options][:sym].to_s }.each { |option|
        id      = option[:options].delete(:sym)
        names   = option[:options].delete(:names)
        default = option[:options].delete(:default) || nil
        yield(id, names, option)
        options.default_options id => default unless default.nil?
      }
    end

    def self.def_options
      register_type(:option) { |list, options| register_option(list, options) { |id, names, option| options.option id, names, option[:options] } }
      register_type(:option_with_param) { |list, options| register_option(list, options) { |id, names, option| options.option_with_param id, names, option[:options] } }
    end

    def_options
  end
  class ActionTypes
    extend PluginType
    extend TypeHelper

    def self.def_actions
      register_type(:before_run) { |list| simple_type(list) }
      register_type(:after_run) { |list| simple_type_with_result(list) }
      register_type(:before_start) { |list| simple_type(list) }
      register_type(:after_end) { |list| simple_type_with_result(list) }
      register_type(:notification) { |list|
        options, result, cmd_clean, message_text = Plugins.get_vars :options, :result, :cmd_clean, :message_text
        list.sort_by { |v| v[:options][:order] }.each { |item| item[:block].call(options, result, cmd_clean, message_text) }
      }
    end

    def_actions
  end
  class LogTypes
    extend PluginType
    extend TypeHelper

    def self.def_logs
      register_type(:log_file_name) { |list| get_name(list) }
      register_type(:log_file_disable) { |list| basic_type(list) }
      register_type(:log_file_enable) { |list| (Plugins.get(:log_file_name).nil? || Plugins.get(:log_file_disable)) ? false : basic_type(list) }
    end

    def_logs
  end
  class FilterTypes
    extend PluginType
    extend TypeHelper

    def self.def_filter
      register_type(:line_filter) { |list, line|
        options = Plugins.get_var :options
        line    = line.chomp
        result  = nil
        begin
          list.sort_by { |v| -v[:options][:priority] }.each { |item|
            tmp = item[:block].call(options, line)
            unless tmp.nil?
              result = tmp || nil
              break
            end
          }
        rescue
          result = line
        end
        result
      }
    end

    def_filter
  end
  class RunnerTypes
    extend PluginType
    extend TypeHelper

    def self.def_runner
      register_type(:runner_enable) { |list, key| basic_type(list.select { |v| v[:options][:key] == key }) }

      register_type(:runner) { |list|
        options, cmd = Plugins.get_vars :options, :cmd
        Plugins.set_var :result, false
        list.sort_by { |v| -v[:options][:priority] }.each { |item|
          if Plugins.get(:runner_enable, item[:options][:key])
            Plugins.set_var :runner, item[:options][:key]
            Plugins.set_var :result, item[:block].call(options, cmd)
            break
          end
        }
        Plugins.get_var :result
      }
    end

    def_runner
  end
  class CommandTypes
    extend PluginType
    extend TypeHelper

    def self.def_command
      def_command_flag
      def_command_goal
      register_type(:operation_name) { |list| get_name(list) || 'Operation' }
      register_type(:clean_block) { |list| basic_type(list) }
    end

    def self.def_command_flag
      register_type(:command_flag) { |list|
        options = Plugins.get_var :options
        flags   = []
        list.each { |flag|
          if flag[:block].nil?
            flags << " #{flag[:options][:flag]}" if flag_boolean(flag, options)
          else
            flag[:block].call(options, flags)
          end
        }
        flags.join
      }
    end

    def self.def_command_goal
      register_type(:goal_override) { |list|
        options        = Plugins.get_var :options
        full_overrides = complex_filter(list.select { |v| v[:options][:override_all] }.sort_by { |v| -v[:options][:priority] }, options, :goal)
        if full_overrides.nil? || full_overrides.empty?
          goals = complex_filter(list.select { |v| !v[:options][:override_all] }.sort_by { |v| v[:options][:order] }, options, :goal)
          goals = ['install'] if (goals - ['clean']).empty?
          goals = ['clean'] + goals unless goals.include?('clean')
          goals = goals - ['clean'] if Plugins.get(:clean_block)
          goals.join(' ')
        else
          full_overrides.first
        end
      }
    end

    def_command
  end
  class ColorTypes
    extend PluginType

    DEFAULT_COLOR_OPTS = {
        time:    {
            fg: :green,
            bg: :none,
        },
        percent: {
            fg: :purple,
            bg: :none,
        },
        average: {
            fg: :cyan,
            bg: :none,
        },
    }

    def self.def_color
      register_type(:color_override) { |list|
        options = Plugins.get_var :options
        opts    = DEFAULT_COLOR_OPTS
        list.sort_by { |v| -v[:options][:priority] }.each { |item|
          rval = item[:block].call(options)
          unless rval.nil? || !rval
            opts = rval
            break
          end
        }
        opts.each { |opt| Format.color_profile opt[0], fgcolor: opt[1][:fg], bgcolor: opt[1][:bg] }
      }
    end

    def_color
  end
  class DefaultTypes
    extend PluginType
    extend TypeHelper

    def self.def_vars
      register_variable :options
      register_variable :result
      register_variable :runner
      register_variable :cmd
      register_variable :cmd_clean
      register_variable :message_text
    end

    def_vars
  end
end