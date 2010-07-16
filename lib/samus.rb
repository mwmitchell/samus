module Samus
  
  module DataTypes
    
    module Descriptable
      attr_reader :label, :valid_data_types
      def valid_data_types *values
        @valid_data_types = values
      end
      def simple?
        label == "object" ? false : true
      end
      def label
        self.to_s.split("::")[-1].sub(/Type$/,'').downcase
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
    def self.match input
      SimpleTypes[input] || (
        input.ancestors.include?(Samus::Model) ? 
          input : 
          raise("The #{input} type does not look like a valid field type class.")
      )
    end
  end
  
  module Fields
    
    class Base
      
      attr_reader :model, :name, :type_class, :opts, :mapped_type_class, :description
      
      def initialize model, name, type_class, opts, &block
        @model, @name, @type_class, @opts = model, name, type_class, opts
        @mapped_type_class = DataTypes.match type_class
        instance_eval &block if block_given?
      end
      
      def simple?
        mapped_type_class.simple?
      end
      
      def label
        simple? ? mapped_type_class.label : "object"
      end
      
      def many?
        false
      end
      
      def one?
        false
      end
      
      def desc text
        @description = text
      end
      
      # returns the correct value for a field
      def prepare_value value
        return if value.nil? and opts[:optional] == true
        simple? ? value : mapped_type_class.new(value)
      end
      
    end
    
    class One < Base
      def one?
        true
      end
    end
    
    class Many < Base
      def many?
        true
      end
    end
    
  end
  
  # You model will extend this module when including Samus::Model.
  # The methods will be available at the class-level.
  module DSL
    def field_types
      @field_types ||= []
    end
    def one name, type, opts = {}, &block
      field_types << Fields::One.new(self, name, type, opts, &block)
    end
    def many name, type, opts = {}, &block
      field_types << Fields::Many.new(self, name, type, opts, &block)
    end
    
    def description
      @description ||= @desc_block ? @desc_block.call : ""
    end
    
    def desc &block
      @desc_block = block
    end
    
  end
  
  module HashSchemable
    def to_hash
      self.field_types.inject({}) do |hash,p|
        if p.simple?
          v = p.is_a?(Samus::Fields::Many) ? [p.label] : p.label
        elsif p.is_a? Samus::Fields::One
          v = p.mapped_type_class.to_hash
        else
          v = [p.mapped_type_class.to_hash]
        end
        hash.merge p.name.to_s => v
      end
    end
  end
  
  # used to describe a model class (not instance)
  module JsonSchemable
    
    # TODO: need to find a way to use rdoc, but not use the
    # desc/description field -- the description might want
    # to use the to_json_schema method, which results in
    # infinite recursion... 
    def to_json_schema
      {
        "type" => "object",
        "properties" => self.field_types.inject({}) do |hash,field|
          if field.is_a? Fields::Many
            val = field.simple? ? field.label : field.mapped_type_class.to_json_schema
            subhash = {
              "type" => "array"
            }
            unless field.simple?
              subhash["items"] = field.mapped_type_class.to_json_schema
            else
              subhash["items"] = {}
              subhash["items"]['type'] = val
            end
            hash.merge!(field.name.to_s => subhash)
            hash
          else
            if field.simple?
              hash.merge! field.name.to_s => {"type" => field.label}
            else
              hash.merge! field.name.to_s => field.mapped_type_class.to_json_schema
            end
          end
          hash
        end
      }
    end

    def scalar_type(the_type)
      case the_type
      when "StringType"
        'string'
      when "IntegerType"
        'integer'
      when "BooleanType"
        'boolean'
      when "NumericType"
        'number'
      when "ArrayType"
        'array'
      else
        nil
      end
    end
    
  end
  
  # used on instances of Model objects
  module Serializable
    def to_hash
      field_types.inject({}) do |hash,(name,field)|
        if field.mapped_type_class.ancestors.include? Samus::Model
          value = values[field.name]
          if value.is_a? Array
            hash.merge! field.name => values[field.name].map(&:to_hash)
          else
            hash.merge! field.name => values[field.name].to_hash
          end
        else
          hash.merge! field.name => values[field.name]
        end
        hash
      end
    end
  end
  
  module Model
    
    # This is just like the DataTypes::Descriptable module....
    # How to make this smell pretty?
    module Descriptable
      def simple?
        false
      end
      def label
        "object"
      end
      def valid_data_types
        [self]
      end
    end
    
    def self.included base
      base.send :include, Serializable
      base.extend DSL
      base.extend Descriptable
      base.extend JsonSchemable
      base.extend HashSchemable
    end
    
    attr_reader :values
    
    # TODO: clean this up... there's gotta be a way to push some of this
    # into the Fields classes?
    def initialize values = {}
      @values = {}
      m = Module.new
      field_types.each_pair do |name, p|
        m.module_eval <<-R
          def #{name}
            values[:#{name}]
          end
        R
        if p.is_a? Fields::One
          m.module_eval <<-R
            def #{name}= value
              values[:#{name}] = field_types[:#{name}].prepare_value(value)
            end
          R
        elsif p.is_a? Fields::Many
          m.module_eval <<-R
            def append_to_#{name} value
              values[:#{name}] ||= []
              values[:#{name}] << field_types[:#{name}].prepare_value(value)
            end
          R
        end
      end
      extend m
      populate values
    end
    
    # returns a hash of property types assigned to this objects class.
    def field_types
      @field_types ||= self.class.field_types.inject({}){ |hash,p|
        hash.merge p.name.to_sym => p
      }
    end
    
    # TODO: move this logic to the module method above...
    # if you set a many proxy to an array:
    #  hotel.polygon.coords = [...]
    # then it must be possible outside of #populate etc..
    def populate values
      field_types.each_pair do |name, p|
        if p.is_a? Fields::One
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
