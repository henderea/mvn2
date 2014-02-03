# mvn2

A Ruby script that runs a maven build, including (or not including) tests, and only outputs the lines that come after a compile failure, build success, test result, or reactor summary start line

## Installation

Install it yourself as:

    $ gem install mvn2

## Usage

Version 2.0.0 introduces a plugin system.  Other gems can add plugins to mvn2.  The files have to match the pattern `mvn2/plugin/*.plugin.rb` in your gem's `lib/` folder.  If you do that, when the gem is installed, `mvn2` will automatically pick up on it and load it.

Please see the plugin folder in this gem for examples of how to use the plugin system.  My `colorconfig` and `mvn2-say` gems also have plugins for `mvn2`

###optional parameters:
* `-t` or `--timer` to display a timer while the build is in progress (default is display nothing)
* `-s` or `--skip-tests` to skip tests (default is running tests)
* `-n` or `--no-sticky` to make the growl notification non-sticky (default is sticky)
* `-a` or `--display-all` to display all output (default is to only display the output after a compile failure, build success, test result, or reactor summary start line)
* `-k` or `--track-average` to update the average (stored in `avg.txt`) and also display a progress bar while the build is in progress (default is not to do track average or display progress bar)
* `-u` or `--track-full-average` to update the average list (stored in `avg-skip.txt` or `avg-test.txt`) and also display a progress bar while the build is in progress (default is to not do track average or display progress bar) (including this option will cause the progress bar to use the average calculated from the average list if available, but if `-k` or `--track-average` is specified, `avg.txt` will still be updated)
* `-c` or `--colored` to display some colors in the timer/progress message
* `--write-log` to write all of the output to a log file (default is to not write to a log file)
* `--log-file NAME` to set the log file name to `NAME` (default is `build.log`)
* `-d` or `--advanced-average` to use k-means (with minimum optimal k) to find a list of averages and use the closest one for the progress bar and displayed average (default is to use overall average)
* `--command-override CMD` to override the maven command (disables average tracking options and skip test option) (default is `clean install` (with optional `-D skipTests`) and not disabling any options)
* `-p` or `--package` to run `mvn clean package` (with optional `-D skipTests`) (default is `mvn clean install` (with optional `-D skipTests`) (supports average tracking)
* `-h` or `--hide-between` to hide the output between the end of test results (the line starting with "Tests run:") and the next trigger line
* `-w` or `--show-average` to show the average(s) before and after the build (average tracking must be enabled) (default is to not show averages)
* `-b` or `--block-update` to block the average feature from updating the file(s)
* `-v` or `--override-colors` to override the colors with the ones configured by the [colorconfig][colorconfig] script
* `-j` or `--show-projects` to show the `Building <project>` lines when outputting
* `--run-before CMD` to run `CMD` before calling the maven build
* `--run-after CMD` to run `CMD` after finishing the maven build
* `--run-success CMD` to run `CMD` after finishing a successful maven build
* `--run-failure CMD` to run `CMD` after finishing an unsuccessful maven build
* `-e` or `--exception` to add the `-e -X` options to the `mvn` call
* `-0` or `--live-print` to print filtered lines as they are outputted by maven
* `-1` or `--set-defaults` to set the defaults so you can just run `mvn2` without any parameters

###displays:
a Growl notification indicating success or failure

##Plugin System

The following is my initial documentation of the plugin system.  It may be improved as I have time.

-----

Version 2.0.0 introduces a plugin system.  Other gems can add plugins to mvn2.  The files have to match the pattern `mvn2/plugin/*.plugin.rb` in your gem's `lib/` folder.  If you do that, when the gem is installed, `mvn2` will automatically pick up on it and load it.

Two examples of this are my gems `colorconfig` and `mvn2-say`.

The `Mvn2::Plugin` module is used for registering a plugin of a defined type.  It defines the `register` method.  You should use `extend` so that you can define things statically.  There is no need for a `build` method because it automatically adds the plugins at the time you call the method.

Here is an example:

```ruby
register :option, sym: :timer, names: %w(-t --timer), desc: 'display a timer while the build is in progress'
```

And another:

```ruby
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
```

The `register` method takes a first parameter of the plugin type identifier, followed by an optional (but probably necessary) hash of options, and an optional block (usable with most built-in plugin types, required by some).

-----

If you want to define a new plugin type, you can extend the `Mvn2::PluginType`.  This defines the `register_type` and `register_variable` methods.  Technically, you don't really need to register a variable, but if you want to give it a certain starting value, you will need to register it and pass over the value.  `register_type` takes a first parameter of the plugin type identifier, followed by a block.  The block will always take a first parameter of the list of instances, followed by any additional parameters passed to the plugin when it is called.  The block has the task of taking the list of plugin instances and turning it into whatever result the plugin is supposed to have.

Here is an example:

```ruby
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
```

-----

You might notice in the second plugin example, as well as the plugin type example, methods are called on `Mvn2::Plugins`.  This is the class that stores all of the plugins and types.  It has various methods, but the ones involved in making a plugin are:

* `Mvn2::Plugins.get(type, *args)`
    * Gets the result of a plugin type.  The first parameter is the plugin type identifier, followed by any additional arguments the plugin type takes.
* `Mvn2::Plugins.get_var(name)`
    * Gets a single variable by name
* `Mvn2::Plugins.get_vars(*names)`
    * Gets a list of variables by name.  Useful for getting a lot of variables in one line.
* `Mvn2::Plugins.set_var(name, value)`
    * Sets a single variable of the given name to the given value.
* `Mvn2::Plugins.set_vars(vars = {})`
    * Sets a list of variables to the values specified.  It use a hash format, so you can do something like `Mvn2::Plugins.set_vars found: true, info_line_last: false`

If you come up with a plugin, feel free to publish it on your own (that's what the plugin system is designed to support).  If you think it should be part of the built-in plugin set, you can always file a pull request.

## Contributing

1. Fork it ( http://github.com/henderea/mvn2/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request