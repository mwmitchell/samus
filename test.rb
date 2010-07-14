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

puts Location.to_hash.inspect
puts Location.to_protocol_buffers.inspect