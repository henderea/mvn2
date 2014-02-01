require 'mvn2/plugin'

class String
  def start_with_any?(*strs)
    strs.empty? ? false : strs.any? { |str| start_with?(str) }
  end
end

class FilterPlugin
  extend Mvn2::Plugin
  extend Mvn2::PluginType

  INFO_LINE   = '[INFO] ------------------------------------------------------------------------'
  BUILD_REGEX = /\[INFO\] Building (?!(jar|war|zip))/

  register_variable :info_line_last, false
  register_variable :found, false

  register :option, sym: :hide_between, names: %w(-h --hide-between), desc: 'hide the output between the end of test results (the line starting with "Tests run:") and the next trigger line'

  register :option, sym: :show_projects, names: %w(-j --show-projects), desc: 'show the "Building <project>" lines when outputting'

  register(:line_filter, priority: 10) { |_, line|
    info_line_last = Mvn2::Plugins.get_var :info_line_last
    if line.start_with_any?('[INFO] BUILD SUCCESS', '[INFO] Reactor Summary:', '[INFO] BUILD FAILURE')
      str = ''
      str << INFO_LINE << "\n" unless info_line_last
      str << line << "\n"
      Mvn2::Plugins.set_var :found, true
      Mvn2::Plugins.set_var :info_line_last, false
      str
    else
      nil
    end
  }

  register(:line_filter, priority: 20) { |_, line|
    if line.start_with_any?('[ERROR] COMPILATION ERROR :', 'Results :')
      str = line << "\n"
      Mvn2::Plugins.set_var :found, true
      Mvn2::Plugins.set_var :info_line_last, false
      str
    else
      nil
    end
  }

  register(:line_filter, priority: 30) { |_, line|
    found = Mvn2::Plugins.get_var :found
    if found
      str = line << "\n"
      Mvn2::Plugins.set_var :found, true
      Mvn2::Plugins.set_var :info_line_last, line.start_with?(INFO_LINE)
      str
    else
      nil
    end
  }

  register(:line_filter, priority: 40) { |options, line|
    found = Mvn2::Plugins.get_var :found
    if options[:hide_between] && found && line.start_with?('Tests run:')
      str = line << "\n\n"
      Mvn2::Plugins.set_var :found, false
      Mvn2::Plugins.set_var :info_line_last, false
      str
    else
      nil
    end
  }

  register(:line_filter, priority: 50) { |options, line|
    info_line_last = Mvn2::Plugins.get_var :info_line_last
    if options[:show_projects] && line =~ BUILD_REGEX
      str = ''
      str << INFO_LINE << "\n" unless info_line_last
      str << line << "\n"
      str << INFO_LINE << "\n"
      Mvn2::Plugins.set_var :info_line_last, true
      str
    else
      nil
    end
  }
end