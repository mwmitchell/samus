module Samus
  
  module DataTypes
    
    TypeError = Class.new RuntimeError
    
    module Base
      
      def self.included base
        base.extend Validatable
      end
      
      module Validatable
        
        def validate_type! value, targets
          raise TypeError.new("#{value.inspect} is not a #{targets.join(', or ')}") unless 
            targets.include?(value.class)
        end
        
        def validate! value, opts
          validate_type! value, [Hash, self]
        end
        
      end
    end
    
    class IntegerType
      include Base
      def self.validate! value, opts
        validate_type! value, [Integer, Fixnum]
      end
    end
    
    class NumericType
      include Base
      def self.validate! value, opts
        validate_type! value, [Integer, Float, Fixnum, Numeric]
      end
    end
    
    class StringType
      include Base
      def self.validate! value, opts
        validate_type! value, [String]
      end
    end
    
    class BooleanType
      include Base
      def self.validate! value, opts
        validate_type! value, [TrueClass, FalseClass]
      end
    end
    
    class ArrayType
      include Base
      def self.validate! value, opts
        validate_type! value, [Array]
        value.each do |v|
          validate_type! v, [opts[:contains]]
        end if opts[:contains]
      end
    end
    
    # alias these here so the model definitions
    # can just use Boolean instead of BooleanType (for example)...
    Boolean = BooleanType
    Number = NumericType
    
    # The mapping of dsl/external classes to internal "type" classes
    Map = {
      Number => NumericType,
      String => StringType,
      Boolean => BooleanType,
      Integer => IntegerType,
      Array => ArrayType
    }
    
    # pass in the Ruby type and #match
    # will return the internal Samus type
    def self.match input
      Map[input] || (
        input.ancestors.include?(Samus::Model) ? 
          input : 
          raise("The #{input} type does not look like a valid property type class.")
      )
    end
  end
  
  module PropertyTypes
    
    FieldMissingError = Class.new RuntimeError
    
    class Base
      
      attr_reader :model, :name, :type, :opts, :mapped_type, :description
      
      def initialize model, name, type, opts, &block
        @model, @name, @type, @opts = model, name, type, opts
        @mapped_type = DataTypes.match type
        instance_eval &block if block_given?
      end
      
      def desc text
        @description = text
      end
      
      # returns the correct value if validation passes
      def prepare_value! value
        return if value.nil? and opts[:optional] == true
        raise FieldMissingError.new("#{model} :#{name} is required") if value.nil?
        begin
          mapped_type.validate! value, opts
        rescue DataTypes::TypeError
          raise DataTypes::TypeError.new("#{$!} for #{model} :#{name}")
        end
        if DataTypes::Map[type]
          # working with core type (String, Float etc..)
          value
        else
          # working with custom object
          type.new value
        end
      end
      
    end
    
    class One < Base
      
    end
    
    class Many < Base
    
    end
    
  end
  
  module DSL
    def property_types
      @property_types ||= []
    end
    def one name, type, opts = {}, &block
      property_types << PropertyTypes::One.new(self, name, type, opts, &block)
    end
    def many name, type, opts = {}, &block
      property_types << PropertyTypes::Many.new(self, name, type, opts, &block)
    end
    
    def description
      @description ||= @desc_block ? @desc_block.call : ""
    end
    
    def desc &block
      @desc_block = block
    end
    
  end
  
  # used to describe a model class (not instance)
  module Descriptable
    
    def to_rdoc level=0
      rdoc = ["#{'=' * (level+1)}#{self.to_s.split("::")[-2..-1].join('/')}"]
      rdoc << self.description.to_s.gsub(/ +/, ' ')
      rdoc << "====Properties"
      rdoc << property_types.map{|p|
        sub = "* #{p.name.to_s}"
        sub << " (#{p.opts[:optional] ? "optional" : "required"})"
        sub << "  - #{p.description}\n" if p.description
        unless DataTypes::Map.values.include? p.mapped_type
          sub << p.mapped_type.to_rdoc(level+1)
        end
        sub
      }.join("\n")
      rdoc.join("\n")
    end
    
    # TODO: refactor this
    def to_hash
      self.property_types.inject({}) do |hash,p|
        case p.mapped_type.to_s.split("::")[-1]
        when "StringType"
          v = p.is_a?(Samus::PropertyTypes::Many) ? ["<string>"] : "string"
          hash.merge! p.name.to_s => v
        when "IntegerType"
          v = p.is_a?(Samus::PropertyTypes::Many) ? ["<integer>"] : "integer"
          hash.merge! p.name.to_s => v
        when "BooleanType"
          v = p.is_a?(Samus::PropertyTypes::Many) ? ["<boolean>"] : "boolean"
          hash.merge! p.name.to_s => v
        when "NumericType"
          v = p.is_a?(Samus::PropertyTypes::Many) ? ["<number>"] : "number"
          hash.merge! p.name.to_s => v
        when "ArrayType"
          v = p.is_a?(Samus::PropertyTypes::Many) ? ["<array>"] : "array"
          hash.merge! p.name.to_s => v
        else
          if p.class == Samus::PropertyTypes::One
            hash.merge! p.name => p.mapped_type.to_hash
          else
            hash.merge! p.name => [p.mapped_type.to_hash]
          end
        end
        hash
      end
    end
    
    # TODO: need to find a way to use rdoc, but not use the
    # desc/description field -- the description might want
    # to use the to_json_schema method, which results in
    # infinite recursion... 
    def to_json_schema
      {
        "type" => "object",
        #"description" => self.description,
        "properties" => self.property_types.inject({}) do |hash,p|
          case p.mapped_type.to_s.split("::")[-1]
          when "StringType"
            hash.merge! p.name.to_s => {"type" => "string"}
          when "IntegerType"
            hash.merge! p.name.to_s => {"type" => "integer"}
          when "BooleanType"
            hash.merge! p.name.to_s => {"type" => "boolean"}
          when "NumericType"
            hash.merge! p.name.to_s => {"type" => "number"}
          when "ArrayType"
            hash.merge! p.name.to_s => {"type" => "array"}
          else
            hash.merge! p.name.to_s => p.mapped_type.to_json_schema
          end
          hash
        end
      }
    end
    
    # TODO: actually implement
    def to_protocol_buffers
      
    end
    
  end
  
  # used on instance of Model objects
  module Serializable
    def to_hash
      property_types.inject({}) do |hash,(name,p)|
        if p.mapped_type.ancestors.include? Samus::Model
          value = values[p.name]
          if value.is_a? Array
            hash.merge! p.name => values[p.name].map(&:to_hash)
          else
            hash.merge! p.name => values[p.name].to_hash
          end
        else
          hash.merge! p.name => values[p.name]
        end
        hash
      end
    end
  end
  
  module Model
    
    def self.included base
      base.extend DSL
      base.send :include, DataTypes
      base.send :include, Serializable
      base.extend DataTypes::Base::Validatable
      base.extend Descriptable
    end
    
    attr_reader :values
    
    # TODO: clean this up... there's gotta be a way to push some of this
    # into the PropertyTypes classes?
    def initialize values = {}
      @values = {}
      m = Module.new
      property_types.each_pair do |name, p|
        m.module_eval <<-R
          def #{name}
            values[:#{name}]
          end
        R
        if p.is_a? PropertyTypes::One
          m.module_eval <<-R
            def #{name}= value
              values[:#{name}] = property_types[:#{name}].prepare_value!(value)
            end
          R
        elsif p.is_a? PropertyTypes::Many
          m.module_eval <<-R
            def append_to_#{name} value
              values[:#{name}] ||= []
              values[:#{name}] << property_types[:#{name}].prepare_value!(value)
            end
          R
        end
      end
      extend m
      populate values
    end
    
    # returns a hash of property types assigned to this objects class.
    def property_types
      @property_types ||= self.class.property_types.inject({}){ |hash,p|
        hash.merge p.name.to_sym => p
      }
    end
    
    # TODO: move this logic to the module method above...
    # if you set a many proxy to an array:
    #  hotel.polygon.coords = [...]
    # then it must be possible outside of #populate etc..
    def populate values
      property_types.each_pair do |name, p|
        if p.is_a? PropertyTypes::One
          send "#{name}=".to_sym, values[name]
        else
          raise "#{self.class} ##{name} is required, and must be an array when using #populate" unless
            p.opts[:optional] || values[name].is_a?(Array)
          values[name].each do |v|
            raise "#{name} should be populated with a hash, not a #{v.class}" unless v.is_a?(Hash)
            send "append_to_#{name}", v
          end
        end
      end
    end
    
  end
  
end