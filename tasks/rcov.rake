require 'rake'
require 'spec/rake/spectask'
 
desc 'run specs with rcov'
Spec::Rake::SpecTask.new('rcov') do |t|
  t.spec_files = FileList['spec/*_spec.rb']
  t.rcov = true
  t.rcov_dir = File.join('coverage', 'all')
  # --only-uncovered
  t.rcov_opts.concat(['--exclude', 'spec', '--sort', 'coverage'])
end

namespace :rcov do
  desc 'run api specs with rcov'
  Spec::Rake::SpecTask.new('all') do |t|
    rm_f "coverage"
    rm_f "coverage.data"
    t.spec_files = FileList['spec/spec_helper.rb', 'spec/*_spec.rb']
    t.rcov = true
    t.rcov_dir = File.join('coverage')
    # --only-uncovered
    t.rcov_opts.concat(['--exclude', 'spec', '--sort', 'coverage'])
  end
  
end