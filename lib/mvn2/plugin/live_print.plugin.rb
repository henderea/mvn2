require 'pty'
require 'everyday-plugins'
include EverydayPlugins
class LivePrintPlugin
  extend Plugin

  register :option, sym: :display_all, names: %w(-a --display-all), desc: 'display all output'

  register :option, sym: :live_print, names: %w(-0 --live-print), desc: 'print filtered lines as they are outputted by maven'

  register(:line_filter, priority: 10 ** 6) { |options, line| options[:display_all] ? line : nil }

  register :runner_enable, key: :live_print, option: :live_print
  register :runner_enable, key: :live_print, option: :display_all

  register(:runner, key: :live_print, priority: 1000) { |_, cmd|
    result = false
    begin
      if Plugins.get(:log_file_enable)
        log_file = File.open(Plugins.get(:log_file_name), 'w+')
        log_file.sync = true
      else
        log_file = nil
      end
      PTY.spawn("TERM='xterm-256color' #{cmd}") { |r, w, pid|
        r.each { |l|
          log_file << l.gsub(/\e\[.*?m/, '') unless log_file.nil?
          output = Plugins.get :line_filter, l
          puts "\r\e[2K#{output}" unless output.nil?
          result = true if l.chomp.gsub(/\e\[.*?;/, '').start_with?('[INFO] BUILD SUCCESS')
        }
      }
    ensure
      log_file.close unless log_file.nil?
    end
    result
  }
end