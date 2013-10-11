require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'

PuppetLint.configuration.ignore_paths = ["spec/**/*.pp", "vendor/**/*.pp"]
PuppetLint.configuration.log_format = '%{path}:%{linenumber}:%{KIND}:%{message}'
PuppetLint.configuration.send("disable_80chars")
PuppetLint.configuration.send("disable_class_inherits_from_params_class")
PuppetLint.configuration.send("disable_class_parameter_defaults")

task :default => [:spec, :syntax, :lint]

desc 'Validate syntax for all manifests.'
task :syntax do
  successes = []
  failures = []
  Dir.glob('manifests/**/*.pp').each do |puppet_file|
    puts "Checking syntax for #{puppet_file}"

    # Run syntax checker in subprocess.
    system("puppet parser validate #{puppet_file}")

    # Keep track of the results.
    if $?.success?
      successes << puppet_file
    else
      failures << puppet_file
    end
  end

  # Print the results.
  total_manifests = successes.count + failures.count
  puts "#{total_manifests} files total."
  puts "#{successes.count} files succeeded."
  puts "#{failures.count} files failed:"
  puts
  failures.each do |filename|
    puts filename
  end

  # Fail the task if any files failed syntax check.
  if failures.count > 0
    fail("#{failures.count} filed failed syntax check.")
  end
end
