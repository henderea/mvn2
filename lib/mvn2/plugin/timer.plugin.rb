require 'mvn2/plugin'
class TimerPlugin
  extend Mvn2::Plugin
  extend Mvn2::PluginType

  register_variable :time1
  register_variable :diff
  register_variable :thread

  register :option, sym: :timer, names: %w(-t --timer), desc: 'display a timer while the build is in progress'

  register :option, sym: :colored, names: %w(-c --colored), desc: 'display some colors in the timer/progress message'

  register(:before_run, order: 2) { |options|
    Mvn2::Plugins.set_var :time1, Time.now
    Mvn2::Plugins.set_var :thread, options[:timer] ? Thread.new {
      start_time = Mvn2::Plugins.get_var :time1
      while true
        print "\r#{get_timer_message(start_time, Time.now)}"
        sleep(0.05)
      end
    } : nil
  }

  register(:after_run, order: 1) { |_, _|
    time2 = Time.now
    time1 = Mvn2::Plugins.get_var :time1
    Mvn2::Plugins.set_var :diff, time2 - time1
  }

  register(:after_run, order: 3) { |_, _|
    thread = Mvn2::Plugins.get_var :thread
    unless thread.nil?
      thread.kill
      print "\n"
    end
  }

  def self.colorize_if_should(text)
    options = Mvn2::Plugins.get_var :options
    options[:colored] ? text.format_all : text.remove_format
  end

  def self.get_avg_message(amin, asec, avg, diff, m, s)
    progress = ((diff.to_f / avg.to_f) * 100.0)
    bars     = [progress.floor, 100].min
    "[#{'=' * bars}>#{' ' * (100 - bars)}] {#{m}:#{s}}(:time) ({~#{'%.3f' % progress}%}(:percent)) (average: {#{amin}:#{asec}}(:average))"
  end

  def self.get_closest(time)
    averages = Mvn2::Plugins.get_var :averages
    averages.min { |a, b| (a - time).abs <=> (b - time).abs }
  end

  def self.get_timer_message(start_time, time)
    diff       = time - start_time
    avg        = get_closest(diff)
    amin, asec = get_time_parts(avg)
    m, s       = get_time_parts(diff)
    colorize_if_should((avg == 0) ? "{#{m}:#{s}}(:time)" : get_avg_message(amin, asec, avg, diff, m, s))
  end

  def self.get_time_parts(time)
    return (time / 60.0).floor, '%06.3f' % (time % 60)
  end
end