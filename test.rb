require 'lib/samus'

class Location
  
  class Origin
    include Samus::Model
    one :name, String
  end
  
  class Source
    include Samus::Model
    one :identifier, String
  end
  
  include Samus::Model
  one :name, String
  many :colors, String
  
  many :origins, Origin
  one :source, Source
  
end

require 'rubygems'

# pretty_generate required >= JSON 1.4.3
require 'json'

puts Location.to_hash.inspect
puts
puts JSON.pretty_generate(Location.to_json_schema)
puts

[Location, Location::Origin, Location::Source].each do |klass|
  puts klass.to_protocol_buffers
end