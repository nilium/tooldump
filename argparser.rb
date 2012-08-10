#!/usr/bin/env ruby -W

module ArgParser

  # used by parse_args
  @@SHORT_OPT = /^
    ^
    - (?<name> [\w] )
      (?<equals> \s* = \s* )?
      (?<value> .+ )?
    $/ix
  @@LONG_OPT = /^
    --
      (?<name> \w+ )
      (?:
        (?<equals> \s* = \s* | \s+ )
        (?<value> .+ )?
      )?
    $/ix

  # === Options Format
  #
  # :parameters => {
  #  :name => {
  #   The name of the parameter.
  #
  #   :alias => :other_name,
  #     Defines this param as an alias for another option. If set, you should
  #     not set any other options for this param, as they will be ignored.
  #
  #   :multiple => bool,
  #     Can have one or more inputs (true) or only one (false).
  #     Defaults to false.
  #
  #   :flag => bool,
  #     Whether the input is a flag (if true, the value will be true if found).
  #     Defaults to true.
  #
  #   :swallow => bool
  #     Whether to swallow all following arguments as values of this argument.
  #     Forces :mulitple => true and :flag => false. Defaults to false.
  #  }
  # }
  #
  # :implicit => bool (false)
  #   Whether all options implicitly exist or not. If false (the default), the
  #   parser will raise an exception for options that do not exist.
  #
  def self.parse_args(args, options={})
    args = args.clone

    implicit = !! options[:implicit]
    parameters = options[:parameters] || {}

    inputs = []
    params = {}

    swallow_key = nil

    index = 0

    until args.empty?
      arg = args.shift

      name = nil

      if ! (match = (arg.match(@@SHORT_OPT) || arg.match(@@LONG_OPT))).nil? && swallow_key.nil?
        name = match[:name].to_sym
        opt = parameters[name]

        is_flag = true
        allow_multiple = implicit
        opt_swallow = false

        if opt.nil?
          if ! implicit
            raise "Invalid argument: #{arg}."
          else
            is_flag = match[:value].nil? && match[:equals].nil?
          end
        else
          alias_opt = opt[:alias]
          unless alias_opt.nil?
            name = alias_opt
            opt = parameters[name]
          end

          if opt
            opt_swallow = ! opt[:swallow].nil? && opt[:swallow]
            is_flag = (! opt[:flag].nil? && opt[:flag]) && ! opt_swallow
            allow_multiple = (! opt[:multiple].nil? && opt[:multiple]) || opt_swallow
          end
        end

        if opt_swallow
          swallow_key = name
          index += 1
          next
        end

        value = is_flag ? true : match[:value]

        if ! is_flag && (value.nil? || value.empty?)
          value = args.shift
        end

        if is_flag && ! match[:value].nil?
          raise "Invalid argument: #{arg}."
        end

        container = nil

        if params.include?(name) && allow_multiple
          container = params[name]
          cur_value = container[:value]
          cur_indices = container[:index]
          indices = nil
          if cur_value.is_a? Array
            value = [*cur_value, value]
            indices = [*cur_indices, index]
          else
            value = [cur_value, value]
            indices = [cur_index, index]
          end
          container[:value] = value
          container[:index] = indices
        elsif allow_multiple
          container = {
            :kind => :param,
            :value => [value],
            :index => [index]
          }
        elsif params.include?(name)
          raise "Invalid argument: #{arg} already set to '#{params[name]}'."
        else
          container = {
            :kind => :param,
            :value => value,
            :index => index
          }
        end

        params.store name, container
      elsif swallow_key
        container = params[swallow_key]
        if container.nil?
          params[swallow_key] = [arg]
        else
          params[swallow_key] = [*container, arg]
        end
      else
        inputs << {
          :kind => :input,
          :value => arg,
          :index => index
        }
      end

      index += 1
    end

    return {
      :inputs => inputs,
      :params => params
    }
  end

end # ArgParser

if __FILE__ == $0
  STDOUT.print ArgParser.parse_args(ARGV, :implicit => true).inspect, $/
end
