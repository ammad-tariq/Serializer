require 'pry'
class Serializer


  attr_accessor :object, :root, :scope

  def initialize(object, options = {})
    self.object = object
    self.instance_options = options
    self.root = instance_options[:root]
    self.scope = instance_options[:scope]

    return if !(scope_name = instance_options[:scope_name]) || respond_to?(scope_name)

    define_singleton_method scope_name, -> { scope }
  end

  Field = Struct.new(:name, :options, :block) do
    def initialize(*)
      super

      validate_condition!
    end

    # Compute the actual value of a field for a given serializer instance.
    # @param [Serializer] The serializer instance for which the value is computed.
    # @return [Object] value
    #
    # @api private
    #
    def value(serializer)
      if block
        serializer.instance_eval(&block)
      else
        serializer.read_attribute_for_serialization(name)
      end
    end

    # Decide whether the field should be serialized by the given serializer instance.
    # @param [Serializer] The serializer instance
    # @return [Bool]
    #
    # @api private
    #
    def excluded?(serializer)
      case condition_type
      when :if
        !evaluate_condition(serializer)
      when :unless
        evaluate_condition(serializer)
      else
        false
      end
    end

    private

    def validate_condition!
      return if condition_type == :none

      case condition
      when Symbol, String, Proc
        # noop
      else
        fail TypeError, "#{condition_type.inspect} should be a Symbol, String or Proc"
      end
    end

    def evaluate_condition(serializer)
      case condition
      when Symbol
        serializer.public_send(condition)
      when String
        serializer.instance_eval(condition)
      when Proc
        if condition.arity.zero?
          serializer.instance_exec(&condition)
        else
          serializer.instance_exec(serializer, &condition)
        end
      else
        nil
      end
    end

    def condition_type
      @condition_type ||=
        if options.key?(:if)
          :if
        elsif options.key?(:unless)
          :unless
        else
          :none
        end
    end

    def condition
      options[condition_type]
    end
  end

  def serialize(options={})
    serializable_object(options)
  end

  def serializable_object(options={})
    return @wrap_in_array ? [] : nil if @object.nil?

    hash = (@object.is_a? Struct) ? @object.to_h.compact : hash
    formatized_hash = hash.map{|k,v| [k,(v.is_a? Date) ? v.strftime("%d-%m-%Y") : v]}.to_h
    @wrap_in_array ? [hash] : formatized_hash
  end

  def self.attribute(attr, options = {}, &block)
    attributes_data= {}
    key = options.fetch(:key, attr)
    attributes_data[key] = Field.new(attr, options, block)
  end
  protected

  attr_accessor :instance_options
end
