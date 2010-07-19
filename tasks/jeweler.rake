begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "samus"
    gemspec.summary = "Ruby-centric IDL"
    gemspec.description = "Ruby-centric IDL"
    gemspec.email = "goodieboy@gmail.com"
    gemspec.homepage = "http://github.com/mwmitchell/samus"
    gemspec.authors = ["Matt Mitchell"]
    
    gemspec.files = FileList['lib/**/*.rb', 'LICENSE', 'README.rdoc', 'VERSION']
    
    gemspec.test_files = ['spec/**/*.rb', 'Rakefile', 'tasks/spec.rake', 'tasks/rdoc.rake']
    
    now = Time.now
    gemspec.date = "#{now.year}-#{now.month}-#{now.day}"
    
    gemspec.has_rdoc = true
  end
  
  # Jeweler::GemcutterTasks.new
  
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end