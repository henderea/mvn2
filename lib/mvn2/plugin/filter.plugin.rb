require 'everyday-plugins'
include EverydayPlugins

class String
  def start_with_any?(*strs)
    strs.empty? ? false : strs.any? { |str| start_with?(str) }
  end
end

class FilterPlugin
  extend Plugin
  extend PluginType

  INFO_LINE   = '[INFO] ------------------------------------------------------------------------'
  BUILD_REGEX = /\[INFO\] Building (?!(jar|war|zip))/

  def self.def_vars
    register_variable :info_line_last, false
    register_variable :found, false
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
      if line.start_with_any?('[INFO] BUILD SUCCESS', '[INFO] Reactor Summary:', '[INFO] BUILD FAILURE')
        str = ''
        str << INFO_LINE << "\n" unless info_line_last
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
        Plugins.set_vars found: true, info_line_last: line.start_with?(INFO_LINE)
        str
      else
        nil
      end
    }
  end

  def self.def_filter4
    register(:line_filter, priority: 40) { |options, line|
      found = Plugins.get_var :found
      if options[:hide_between] && found && line.start_with?('Tests run:')
        str = line << "\n\n"
        Plugins.set_vars found: false, info_line_last: false
        str
      else
        nil
      end
    }
  end

  def self.def_filter5
    register(:line_filter, priority: 50) { |options, line|
      info_line_last = Plugins.get_var :info_line_last
      if options[:show_projects] && line =~ BUILD_REGEX
        str = ''
        str << INFO_LINE << "\n" unless info_line_last
        str << line << "\n"
        str << INFO_LINE << "\n"
        Plugins.set_var :info_line_last, true
        str
      else
        nil
      end
    }
  end

  def_filters
end