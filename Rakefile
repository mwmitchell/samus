require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

ENV['RUBYOPT'] = '-W1'
 
task :environment do
  require File.dirname(__FILE__) + '/lib/samus'
end
 
Dir['tasks/**/*.rake'].each { |t| load t }

