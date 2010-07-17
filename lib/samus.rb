module Samus
  
  module DataTypes
    
    # provides the ability for a property value class to describe itself,
    # whether it be a +simple+ type (string,integer etc.) or a custom/compound class.
    module Descriptable
      attr_reader :label, :valid_data_types
      def valid_data_types *values
        @valid_data_types = values
      end
      def simple?
        label == "object" ? false : true
      end
      def label
        @label ||= (
          if DataTypes::SimpleTypes.values.include? self
            self.to_s.split("::")[-1].sub(/Type$/,'').downcase
          else
            "object"
          end
        )
      end
    end
    
    class IntegerType
      extend Descriptable
      valid_data_types Integer, Fixnum
    end
    
    class NumericType
      extend Descriptable
      valid_data_types Integer, Float, Fixnum, Numeric
    end
    
    class StringType
      extend Descriptable
      valid_data_types String
    end
    
    class BooleanType
      extend Descriptable
      valid_data_types TrueClass, FalseClass
    end
    
    class ArrayType
      extend Descriptable
      valid_data_types Array
    end
    
    # alias these here so the model definitions
    # can just use Boolean instead of BooleanType (for example)...
    Boolean = BooleanType
    Number = NumericType
    
    # The mapping of dsl/external classes to internal scalar type classes
    SimpleTypes = {
      Number => NumericType,
      String => StringType,
      Boolean => BooleanType,
      Integer => IntegerType,
      Array => ArrayType
    }
    
    # Returns the internal Samus type if found in the Map
    # hash above, or returns the custom model class,
    # which should be including the Samus::Model module.
    def self.resolve input
      SimpleTypes[input] || (
        input.ancestors.include?(Samus::Model) ? 
          input : 
          raise("The #{input} type does not look like a valid property type class.")
      )
    end
  end
  
  module Properties
    
    # The Properties::Base class is used to defined a property on a model.
    # This class holds a reference to the model class name, the type class name (String, Integer)
    # and the smapped type class name (StringType)
    # If a custom object was used for the field type class,
    # the type class and mapped class will be the same.
    class Base
      
      attr_reader :model, :name, :type_class, :opts, :description
      
      def initialize model, name, type_class, opts, &block
        @model, @name, @type_class, @opts = model, name, type_class, opts
        instance_eval &block if block_given?
      end
      
      # returns the value of type_class.simple?
      def simple?; type_class.simple? end
      
      # returns the value of type_class.label
      def label; type_class.label end
      
      # true/false if this is a +many+ property
      def many?; end
      
      # true/false if this is a +one+ property
      def one?; end
      
      # returns the desc value of this class
      def desc text
        @description = text
      end
      
      # returns the correct value for a property...
      # which means... if it's a non-simple type
      # the correct class instance is returned,
      # otherwise the value passed-in is returned.
      def prepare_value value
        return if value.nil? and opts[:optional] == true
        if simple?
          value
        else
          value.is_a?(type_class) ? value : type_class.new(value)
        end
      end
      
    end
    
    class One < Base
      def one?; true end
    end
    
    class Many < Base
      def many?; true end
    end
    
  end
  
  # You model will extend this module when including Samus::Model.
  # The methods will be available at the class-level.
  module DSL
    
    def property_types
      @property_types ||= []
    end
    
    def one name, type, opts = {}, &block
      property_types << Properties::One.new(self, name, DataTypes.resolve(type), opts, &block)
    end
    
    def many name, type, opts = {}, &block
      property_types << Properties::Many.new(self, name, DataTypes.resolve(type), opts, &block)
    end
    
    def description
      @description ||= @desc_block ? @desc_block.call : ""
    end
    
    def desc &block
      @desc_block = block
    end
    
  end
  
  # used to describe a model class (not instance)
  module Schemable
    
    def to_json_schema
      {
        "type" => "object",
        "properties" => self.property_types.inject({}) do |hash,property|
          type_class = property.type_class
          if property.many?
            val = property.simple? ? property.label : type_class.to_json_schema
            subhash = {
              "type" => "array"
            }
            unless property.simple?
              subhash["items"] = type_class.to_json_schema
            else
              subhash["items"] = {}
              subhash["items"]['type'] = val
            end
            hash.merge!(property.name.to_s => subhash)
            hash
          else
            if property.simple?
              hash.merge! property.name.to_s => {"type" => property.label}
            else
              hash.merge! property.name.to_s => type_class.to_json_schema
            end
          end
          hash
        end
      }
    end
    
    def to_hash
      self.property_types.inject({}) do |hash,p|
        if p.simple?
          v = p.many? ? [p.label] : p.label
        elsif p.one?
          v = p.type_class.to_hash
        else
          v = [p.type_class.to_hash]
        end
        hash.merge p.name.to_s => v
      end
    end
    
  end
  
  # used on instances of Model objects
  module Serializable
    def to_hash
      property_types.inject({}) do |hash,(name,property)|
        if property.type_class.ancestors.include? Samus::Model
          value = attributes[property.name]
          if value.is_a? Array
            hash.merge! property.name => attributes[property.name].map(&:to_hash)
          else
            hash.merge! property.name => attributes[property.name].to_hash
          end
        else
          hash.merge! property.name => attributes[property.name]
        end
        hash
      end
    end
  end
  
  module Model
    
    def self.included base
      
      # Serializable provides alternate output format for +instances+ of Model
      base.send :include, Serializable
      
      # provides the #one and #many methods
      base.extend DSL
      
      # bring the various types (String, Integer, Numeric etc.) into scope:
      base.send :include, DataTypes
      
      # allow the model defs to access the DataTypes::Descriptable methods...
      base.extend DataTypes::Descriptable
      base.valid_data_types self
      
      # provides class-level output serialization
      base.extend Schemable
    end
    
    # the property attributes for a Model instance
    attr_reader :attributes
    
    def initialize values = {}
      @attributes = {}
      m = Module.new
      property_types.each_pair do |name, p|
        m.module_eval <<-R
          def #{name}
            attributes[:#{name}]
          end
        R
        if p.one?
          m.module_eval <<-R
            def #{name}= value
              attributes[:#{name}] = property_types[:#{name}].prepare_value(value)
            end
          R
        # it's a many property...
        else
          @attributes[name] ||= []
        end
      end
      extend m
      self.attributes = values
    end
    
    # returns a hash of property types assigned to this objects class.
    def property_types
      @property_types ||= self.class.property_types.inject({}){ |hash,p|
        hash.merge p.name.to_sym => p
      }
    end
    
    PropertyNameError = Class.new(RuntimeError)
    ManyPropertyAssignmentError = Class.new(RuntimeError)
    NestedAssignmentError = Class.new(RuntimeError)
    
    # accepts a hash where the keys must match the
    # property_type keys of the model.
    def attributes= values
      values.each_pair do |name,value|
        property_type = property_types[name]
        raise PropertyNameError.new("#{self.class} does not have a ##{name} property.") unless property_type
        if property_type.one?
          send "#{name}=".to_sym, property_type.prepare_value(value)
        else
          unless value.is_a?(Array)
            raise ManyPropertyAssignmentError.new("#{self.class} ##{name} must be an array when set via #attributes=")
          end
          value.each do |v|
            unless [Hash, property_type.type_class].include?(v.class)
              raise NestedAssignmentError.new("#{name} should be populated with a Hash or #{property_type.type_class}, not a #{v.class}")
            end
            send("#{name}") << property_type.prepare_value(v)
          end
        end
      end
    end
    
  end
  
end