require 'mvn2/plugin'
class AvgPlugin
  extend Mvn2::Plugin
  extend Mvn2::PluginType
  extend Mvn2::TypeHelper

  register_variable :average
  register_variable :averages2
  register_variable :counts

  register_type(:full_avg_name) { |list|
    options = Mvn2::Plugins.get_var :options
    pieces  = []
    list.sort_by { |v| v[:options][:order] }.each { |name| pieces << name[:block].call(options) }
    pieces.join
  }

  register_type(:block_average) { |list| basic_type(list) }

  register_type(:block_update) { |list|
    result, average, diff = Mvn2::Plugins.get_vars :result, :average, :diff
    basic_type(list, result, average, diff)
  }

  register_type(:block_full_average) { |list| Mvn2::Plugins.get(:block_average) || basic_type(list) }

  register :option, sym: :track_average, names: %w(-k --track-average), desc: 'update the average and also display a progress bar while the build is in progress'

  register :option, sym: :track_full_average, names: %w(-u --track-full-average), desc: 'update the average list and also display a progress bar while the build is in progress'

  register :option, sym: :advanced_average, names: %w(-d --advanced-average), desc: 'use k-means (with minimum optimal k) to find a list of averages and use the closest one for the progress bar and displayed average'

  register :option, sym: :show_average, names: %w(-w --show-average), desc: 'show the average(s) before and after the build (average tracking must be enabled)'

  register :option, sym: :block_update, names: %w(-b --block-update), desc: 'block the average feature from updating the file(s)'

  register :block_update, option: :block_update

  register(:block_update) { |options, result, average, diff| !(result || (!options[:skip_tests] && diff >= average / 2.0)) }

  register :block_full_average, option: :track_full_average, value: false

  register :block_average, option: :track_average, value: false

  register(:before_run, order: 1) { |options|
    read_avg
    read_full_avg
    read_advanced_avg
    show_averages if options[:show_average]
  }

  register(:after_run, order: 2) { |_, _|
    update_avg
    update_full_avg
  }

  register(:after_run, order: 4) { |options, _|
    if options[:show_average]
      read_avg
      read_full_avg
      read_advanced_avg
      show_averages
    end
  }

  def self.full_avg_file
    pieces = Mvn2::Plugins.get :full_avg_name
    "avg#{pieces}.txt"
  end

  def self.float_filter(line)
    begin
      f = line.chomp
      f.length == 0 || (f =~ /^\d+(\.\d+)?$/).nil? ? false : f.to_f
    rescue
      false
    end
  end

  def self.read_full_avg
    average   = Mvn2::Plugins.get_var :average
    file_name = full_avg_file
    if !Mvn2::Plugins.get(:block_full_average) && File.exist?(file_name)
      lines   = IO.readlines(file_name)
      data    = lines.filtermap { |line| float_filter(line) }
      average = data.average
    end
    Mvn2::Plugins.set_var :average, average
  end

  def self.read_advanced_avg
    options, average = Mvn2::Plugins.get_vars :options, :average
    averages         = [average]
    file_name        = full_avg_file
    if !Mvn2::Plugins.get(:block_full_average) && options[:advanced_average] && File.exist?(file_name)
      lines    = IO.readlines(file_name)
      data     = lines.filtermap { |line| float_filter(line) }
      averages = data.nmeans
    end
    Mvn2::Plugins.set_var :averages, averages
  end

  def self.update_full_avg
    diff = Mvn2::Plugins.get_var :diff
    if !Mvn2::Plugins.get(:block_full_average) && !Mvn2::Plugins.get(:block_update)
      file = File.new(full_avg_file, 'a+')
      file.puts(diff)
      file.close
    end
  end

  def self.get_data(averages, counts, lines, ind)
    if lines.count > ind
      parts         = lines[ind].chomp.split(';')
      averages[ind] = parts[0].to_f
      counts[ind]   = parts[1].to_i
      averages[ind] = 0 if counts[ind] == 0
    end
  end

  def self.read_avg
    options  = Mvn2::Plugins.get_var :options
    average  = 0
    averages = [0, 0, 0, 0]
    counts   = [0, 0, 0, 0]
    if !Mvn2::Plugins.get(:block_average) && File.exist?('avg.txt')
      lines = IO.readlines('avg.txt')
      get_data(averages, counts, lines, 0)
      get_data(averages, counts, lines, 1)
      get_data(averages, counts, lines, 2)
      get_data(averages, counts, lines, 3)
      pkg     = options[:package] ? 2 : 0
      average = averages[(options[:skip_tests] ? 0 : 1) + pkg]
    end
    Mvn2::Plugins.set_vars average: average, averages2: averages, counts: counts
  end

  def self.calc_new_avg(ind)
    averages2, counts, diff = Mvn2::Plugins.get_vars :averages2, :counts, :diff
    sum                     = averages2[ind] * counts[ind] + diff
    counts[ind]             += 1
    averages2[ind]          = sum / counts[ind]
  end

  def self.update_avg
    options, averages2, counts = Mvn2::Plugins.get_vars :options, :averages2, :counts
    if !Mvn2::Plugins.get(:block_average) && !Mvn2::Plugins.get(:block_update)
      options[:skip_tests] ? calc_new_avg(0) : calc_new_avg(1)
      IO.write('avg.txt', "#{averages2[0]};#{counts[0]}\n#{averages2[1]};#{counts[1]}\n#{averages2[2]};#{counts[2]}\n#{averages2[3]};#{counts[3]}")
    end
  end

  def self.show_averages
    averages = Mvn2::Plugins.get_var :averages
    unless averages.empty? || (averages.length == 1 && averages[0] == 0)
      strs = averages.map { |a|
        m, s = get_time_parts(a)
        "#{m}:#{s}"
      }
      puts "\r\e[2KAverage(s): #{strs.join(', ')}"
    end
  end

  def self.get_time_parts(time)
    return (time / 60.0).floor, '%06.3f' % (time % 60)
  end
end