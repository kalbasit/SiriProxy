#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# This file has been taken from rails
# https://github.com/rails/rails/blob/master/ci/travis.rb
require 'fileutils'
include FileUtils

class Build
  attr_reader :options

  def initialize(options = {})
    @options = options
  end

  def run!(options = {})
    self.options.update(options)
    create_config_file
    announce(heading)
    rake(*tasks)
  end

  def create_config_file
    commands = [
      "rm -rf ~/.siriproxy",
      "mkdir -p ~/.siriproxy",
      "cp config.yml ~/.siriproxy/config.yml",
    ]

    commands.each do |command|
      system("#{command}")
    end
  end

  def announce(heading)
    puts "\n\e[1;33m[Travis CI] #{heading}\e[m\n"
  end

  def heading
    heading = [gem]
    heading.join(' ')
  end

  def tasks
    "spec"
  end

  def gem
    'watch_tower'
  end

  def rake(*tasks)
    tasks.each do |task|
      cmd = "bundle exec rake #{task}"
      puts "Running command: #{cmd}"
      return false unless system(cmd)
    end
    true
  end
end

results = {}

build = Build.new
results[:default] = build.run!

failures = results.select { |key, value| value == false }

if failures.empty?
  puts
  puts "SiriProxy build finished sucessfully"
  exit(true)
else
  puts
  puts "SiriProxy build FAILED"
  puts "Failed: #{failures.keys.join(', ')}"
  exit(false)
end
