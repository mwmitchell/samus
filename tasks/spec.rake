gem 'rspec'

# $stderr.puts `gem list`

require 'spec'
require 'spec/rake/spectask'

task :default => "spec:default"

namespace :spec do
  
  desc 'run specs'
  Spec::Rake::SpecTask.new(:default) do |t|
    t.spec_files = [File.join('spec', 'spec_helper.rb')]
    t.spec_files += FileList[File.join('spec', '**', '*_spec.rb')]
    t.verbose = true
    t.spec_opts = ['--color']
  end
  
end