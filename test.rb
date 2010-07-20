require 'lib/samus'

# TODO: make this a useful example?

class Location
    
    class Coord
      
      include Samus::Model
      
      desc "The lat/lng values of a polygon point, which describe the area of a location"
      
      require 'bigdecimal'
      
      one :lat, Number, :desc => "The lattitude of the property"
      one :lng, Number, :desc => "The longitude of the property"
      
    end
    
    class Polygon
      include Samus::Model
      many :coords, Coord, :desc => "\"coords\" is an object which contains many +Coord+ objects"
    end
    
    include Samus::Model
    
    desc "The Location description..."
    
    one :name, String, :desc => "The name of the location"
    one :polygon, Polygon, :desc => "An object which contains many coordinates"
    many :sub_location_ids, String
    
  end

require 'rubygems'

# pretty_generate required >= JSON 1.4.3
require 'json'

puts Location.to_hash.inspect

puts JSON.pretty_generate(Location.to_json_schema)
puts

location = Location.new(:name => "Nowhere", :polygon => {:coords => [{:lat => 1.0, :lng => 2.0}, {:lat => 10.0, :lng => 21.0}]})
location.to_hash
location.polygon.coords.each do |coord|
  puts "#{coord.lat}, #{coord.lng}"
end

puts

location.sub_location_ids << "one"

location.traverse do |name,o|
  puts "#{name}:"
  puts "#{o.inspect}"
  puts
end