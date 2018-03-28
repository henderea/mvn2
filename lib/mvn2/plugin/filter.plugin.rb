require 'everyday-plugins'
include EverydayPlugins

class FilterPlugin
  extend Plugin
  extend PluginType

  INFO_LINE_FULL   = '[INFO] ------------------------------------------------------------------------'
  INFO_LINE_COLORED   = "[\e[1;34mINFO\e[m] \e[1m------------------------------------------------------------------------\e[m"
  BUILD_REGEX = /(\[(?:\e\S+)?INFO(?:\e\S+)?\] (?:\e\S+)?)Building (?!(jar|war|zip)).*(?:\e\S+)?$/

  def self.def_vars
    register_variable :info_line_last, false
    register_variable :found, false
    register_variable :failures, 0
    register_variable :info_line, INFO_LINE_COLORED
  end

  def_vars

  def self.def_options
    register :option, sym: :hide_between, names: %w(-h --hide-between), desc: 'hide the output between the end of test results (the line starting with "Tests run:") and the next trigger line'
    register :option, sym: :show_projects, names: %w(-j --show-projects), desc: 'show the "Building <project>" lines when outputting'
  end

  def_options

  def self.def_filters
    def_filter1
    def_filter2
    def_filter3
    def_filter4
    def_filter5
  end

  def self.def_filter1
    register(:line_filter, priority: 10) { |_, line|
      info_line_last = Plugins.get_var :info_line_last
      info_line = Plugins.get_var :info_line
      if line.start_with_any?('[INFO] BUILD SUCCESS', '[INFO] Reactor Summary:', '[INFO] BUILD FAILURE')
        str = ''
        str << "#{info_line}\n" unless info_line_last
        str << line << "\n"
        Plugins.set_vars found: true, info_line_last: false
        str
      else
        nil
      end
    }
  end

  def self.def_filter2
    register(:line_filter, priority: 20) { |_, line|
      if line.start_with_any?('[ERROR] COMPILATION ERROR :', 'Results :')
        str = line << "\n"
        Plugins.set_vars found: true, info_line_last: false
        str
      else
        nil
      end
    }
  end

  def self.def_filter3
    register(:line_filter, priority: 30) { |_, line|
      found = Plugins.get_var :found
      if found
        str = line << "\n"
        Plugins.set_vars found: true, info_line_last: line.start_with_any?(INFO_LINE_FULL)
        str
      else
        nil
      end
    }
  end

  def self.def_filter4
    register(:line_filter, priority: 40) { |options, line|
      found = Plugins.get_var :found
      if options[:hide_between] && found && line.start_with_any?('Tests run:')
        str = line << "\n\n"
        Plugins.set_vars found: false, info_line_last: false
        if line =~ /^.*Failures:\s+(\d+),.*$/
          Plugins.set_var :failures, $1.to_i
        else
          Plugins.set_var :failures, nil
        end
        str
      else
        nil
      end
    }
  end

  def self.def_filter5
    register(:line_filter, priority: 50) { |options, line|
      info_line_last = Plugins.get_var :info_line_last
      info_line = Plugins.get_var :info_line
      if line.gsub(/\e\[.*?m/, '').chomp == INFO_LINE_FULL
        Plugins.set_var :info_line, line.chomp
        nil
      elsif options[:show_projects] && line =~ BUILD_REGEX
        str = ''
        str << "#{info_line}\n" unless info_line_last
        str << line << "\n"
        str << "#{info_line}\n"
        Plugins.set_var :info_line_last, true
        str
      else
        nil
      end
    }
  end

  def_filters
end