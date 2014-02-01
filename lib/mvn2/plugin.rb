require 'everyday-cli-utils'
include EverydayCliUtils
import :maputil

module Mvn2
  class Plugins
    def self.instance
      @instance ||= Plugins.new
    end

    def initialize
      @ext   = {}
      @types = {}
      @vars  = {}
    end

    def register(type, options = {}, &block)
      @ext[type] ||= []
      @ext[type] << { options: options, block: block }
    end

    def register_type(type, &block)
      @types[type] = block
    end

    def register_variable(name, value = nil)
      @vars[name] = value
    end

    def [](type)
      @ext[type] || []
    end

    def get(type, *args)
      @types[type].call(self[type], *args)
    end

    def self.get(type, *args)
      instance.get(type, *args)
    end

    def get_var(name)
      @vars[name] || nil
    end

    def set_var(name, value)
      @vars[name] = value
    end

    def self.get_var(name)
      instance.get_var(name)
    end

    def self.set_var(name, value)
      instance.set_var(name, value)
    end
  end
  module Plugin
    def register(type, options = {}, &block)
      Mvn2::Plugins.instance.register(type, options, &block)
    end
  end
  module PluginType
    def register_type(type, &block)
      Mvn2::Plugins.instance.register_type(type, &block)
    end

    def register_variable(name, value = nil)
      Mvn2::Plugins.instance.register_variable(name, value)
    end
  end
  class DefaultTypes
    extend Mvn2::PluginType

    register_variable :options
    register_variable :result
    register_variable :runner
    register_variable :cmd
    register_variable :cmd_clean
    register_variable :message_text

    register_type(:option) { |list, options|
      list.sort_by { |v| v[:options][:sym].to_s }.each { |option|
        id      = option[:options].delete(:sym)
        names   = option[:options].delete(:names)
        default = option[:options].delete(:default) || nil
        options.option id, names, option[:options]
        options.default_options id => default unless default.nil?
      }
    }

    register_type(:option_with_param) { |list, options|
      list.sort_by { |v| v[:options][:sym].to_s }.each { |option|
        id      = option[:options].delete(:sym)
        names   = option[:options].delete(:names)
        default = option[:options].delete(:default) || nil
        options.option_with_param id, names, option[:options]
        options.default_options id => default unless default.nil?
      }
    }

    register_type(:command_flag) { |list|
      options = Mvn2::Plugins.get_var :options
      flags   = []
      list.each { |flag|
        if flag[:block].nil?
          flags << " #{flag[:options][:flag]}" if flag[:options].has_key?(:option) && options[flag[:options][:option]] == (flag[:options].has_key?(:value) ? flag[:options][:value] : true)
        else
          flag[:block].call(options, flags)
        end
      }
      flags.join
    }

    register_type(:before_run) { |list|
      options = Mvn2::Plugins.get_var :options
      list.sort_by { |v| v[:options][:order] }.each { |item| item[:block].call(options) }
    }

    register_type(:after_run) { |list|
      options = Mvn2::Plugins.get_var :options
      result  = Mvn2::Plugins.get_var :result
      list.sort_by { |v| v[:options][:order] }.each { |item| item[:block].call(options, result) }
    }

    register_type(:before_start) { |list|
      options = Mvn2::Plugins.get_var :options
      list.sort_by { |v| v[:options][:order] }.each { |item| item[:block].call(options) }
    }

    register_type(:after_end) { |list|
      options = Mvn2::Plugins.get_var :options
      result  = Mvn2::Plugins.get_var :result
      list.sort_by { |v| v[:options][:order] }.each { |item| item[:block].call(options, result) }
    }

    register_type(:notification) { |list|
      options      = Mvn2::Plugins.get_var :options
      result       = Mvn2::Plugins.get_var :result
      cmd_clean    = Mvn2::Plugins.get_var :cmd_clean
      message_text = Mvn2::Plugins.get_var :message_text
      list.sort_by { |v| v[:options][:order] }.each { |item| item[:block].call(options, result, cmd_clean, message_text) }
    }

    register_type(:log_file_name) { |list|
      options = Mvn2::Plugins.get_var :options
      name    = nil
      list.sort_by { |v| -v[:options][:priority] }.each { |item|
        if item[:block].nil?
          if item[:options].has_key?(:name) && item[:options].has_key?(:option) && options[item[:options][:option]] == (item[:options].has_key?(:value) ? item[:options][:value] : true)
            name = item[:options][:name]
            break
          elsif item[:options].has_key?(:option) && !options[item[:options][:option]].nil?
            name = options[item[:options][:option]]
            break
          end
        else
          rval = item[:block].call(options)
          unless rval.nil?
            name = rval
            break
          end
        end
      }
      name
    }

    register_type(:log_file_disable) { |list|
      options = Mvn2::Plugins.get_var :options
      list.any? { |item|
        if item[:block].nil?
          item[:options].has_key?(:option) && options[item[:options][:option]] == (item[:options].has_key?(:value) ? item[:options][:value] : true)
        else
          item[:block].call(options)
        end
      }
    }

    register_type(:log_file_enable) { |list|
      if Mvn2::Plugins.get(:log_file_name).nil? || Mvn2::Plugins.get(:log_file_disable)
        false
      else
        options = Mvn2::Plugins.get_var :options
        list.any? { |item|
          if item[:block].nil?
            item[:options].has_key?(:option) && options[item[:options][:option]] == (item[:options].has_key?(:value) ? item[:options][:value] : true)
          else
            item[:block].call(options)
          end
        }
      end
    }

    register_type(:line_filter) { |list, line|
      options = Mvn2::Plugins.get_var :options
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

    register_type(:runner_enable) { |list, key|
      options = Mvn2::Plugins.get_var :options
      list.select { |v| v[:options][:key] == key }.any? { |item|
        if item[:block].nil?
          item[:options].has_key?(:option) && options[item[:options][:option]] == (item[:options].has_key?(:value) ? item[:options][:value] : true)
        else
          item[:block].call(options)
        end
      }
    }

    register_type(:runner) { |list|
      options = Mvn2::Plugins.get_var :options
      cmd     = Mvn2::Plugins.get_var :cmd
      Mvn2::Plugins.set_var :result, false
      list.sort_by { |v| -v[:options][:priority] }.each { |item|
        if Mvn2::Plugins.get(:runner_enable, item[:options][:key])
          Mvn2::Plugins.set_var :runner, item[:options][:key]
          Mvn2::Plugins.set_var :result, item[:block].call(options, cmd)
          break
        end
      }
      Mvn2::Plugins.get_var :result
    }

    register_type(:goal_override) { |list|
      options        = Mvn2::Plugins.get_var :options
      full_overrides = list.select { |v| v[:options][:override_all] }.sort_by { |v| -v[:options][:priority] }.filtermap { |item|
        if item[:block].nil?
          if item[:options].has_key?(:goal) && item[:options].has_key?(:option) && options[item[:options][:option]] == (item[:options].has_key?(:value) ? item[:options][:value] : true)
            item[:options][:goal]
          else
            item[:options].has_key?(:option) && !options[item[:options][:option]].nil? ? options[item[:options][:option]] : false
          end
        else
          rval = item[:block].call(options)
          (rval.nil? || !rval) ? false : rval
        end
      }
      if full_overrides.nil? || full_overrides.empty?
        goals = list.select { |v| !v[:options][:override_all] }.sort_by { |v| v[:options][:order] }.filtermap { |item|
          if item[:block].nil?
            if item[:options].has_key?(:goal) && item[:options].has_key?(:option) && options[item[:options][:option]] == (item[:options].has_key?(:value) ? item[:options][:value] : true)
              item[:options][:goal]
            else
              item[:options].has_key?(:option) && !options[item[:options][:option]].nil? ? options[item[:options][:option]] : false
            end
          else
            rval = item[:block].call(options)
            (rval.nil? || !rval) ? false : rval
          end
        }
        goals = ['install'] if (goals - ['clean']).empty?
        goals = ['clean'] + goals unless goals.include?('clean')
        goals.join(' ')
      else
        full_overrides.first
      end
    }

    register_type(:operation_name) { |list|
      options = Mvn2::Plugins.get_var :options
      name    = false
      list.sort_by { |v| -v[:options][:priority] }.each { |item|
        if item[:block].nil?
          if item[:options].has_key?(:name) && item[:options].has_key?(:option) && options[item[:options][:option]] == (item[:options].has_key?(:value) ? item[:options][:value] : true)
            name = item[:options][:name]
            break
          elsif item[:options].has_key?(:option) && !options[item[:options][:option]].nil?
            name = options[item[:options][:option]]
            break
          end
        else
          rval = item[:block].call(options)
          unless rval.nil? || !rval
            name = rval
            break
          end
        end
      }
      name || 'Operation'
    }

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

    register_type(:color_override) { |list|
      options = Mvn2::Plugins.get_var :options
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
end