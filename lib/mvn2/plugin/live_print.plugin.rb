require 'mvn2/plugin'
class LivePrintPlugin
  extend Mvn2::Plugin

  register :option, sym: :display_all, names: %w(-a --display-all), desc: 'display all output'

  register :option, sym: :live_print, names: %w(-0 --live-print), desc: 'print filtered lines as they are outputted by maven'

  register(:line_filter, priority: 10 ** 6) { |options, line| options[:display_all] ? line : nil }

  register :runner_enable, key: :live_print, option: :live_print
  register :runner_enable, key: :live_print, option: :display_all

  register(:runner, key: :live_print, priority: 1000) { |_, cmd|
    result = false
    begin
      log_file = Mvn2::Plugins.get(:log_file_enable) ? File.open(Mvn2::Plugins.get(:log_file_name), 'w+') : nil
      IO.popen(cmd).each do |l|
        log_file << l unless log_file.nil?
        output = Mvn2::Plugins.get :line_filter, l
        puts "\r\e[2K#{output}" unless output.nil?
        result = true if l.chomp.start_with?('[INFO] BUILD SUCCESS')
      end
    ensure
      log_file.close unless log_file.nil?
    end
    result
  }
end