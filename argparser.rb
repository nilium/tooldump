#!/usr/bin/env ruby -W
=begin
Copyright (c) 2012, Noel R. Cower
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=end

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
      (?<name> [^\s=]+ )
      (?:
        (?<equals> \s* = \s* | \s+ )
        (?<value> .+ )?
      )?
    $/ix

  @@ARG_RESULT = Struct.new(:params, :inputs)
  @@ARG_INFO = Struct.new(:value, :index)

  # Parses an array of arguments of three forms:
  #  1. Short form: -p[value]  where p is a letter, number, or underscore and
  #     value is any string.
  #  2. Long form:  --param[ value|=value]  where param is any string of
  #     characters other than whitespace or an equals sign underscores and value
  #     is any string. The param and value must be separated by either
  #     whitespace or an = symbol (the = symbol may optionally be surrounded by
  #     as much or as little whitespace as you want), otherwise the parameter is
  #     treated as a flag (true/false) instead of a value.
  #  3. Input form: anything that doesn't conform to (1) or (2) is considered an
  #     input (such as a filename) and may be any string whatsoever.
  #
  # === Options
  #
  # :parameters => {
  #  'name' (string) => {
  #   The name of the parameter.
  #
  #   :alias => 'other_name' (nil)
  #     Defines this param as an alias for another option. If set, you should
  #     not set any other options for this param, as they will be ignored.
  #
  #   :multiple => bool (false)
  #     Can have one or more inputs (true) or only one (false).
  #
  #   :flag => bool
  #     Whether the input is a flag (if true, the value will be true if found).
  #
  #   :swallow => bool (false)
  #     Whether to swallow all following arguments as values of this argument.
  #     Forces :mulitple => true and :flag => false. Defaults to false.
  #
  #   :default => object (nil)
  #     The default value for this parameter. If none specified, this param will
  #     not be included in params if never specified.
  #
  #   :parser => proc or lambda (nil)
  #     If provided, param values will be passed to this proc/lambda for
  #     parsing. Whatever value the parser returns is the value of the param.
  #  }
  # }
  #
  # :implicit => bool (false)
  #   Whether all options implicitly exist or not. If false (the default), the
  #   parser will raise an exception for options that do not exist.
  #
  # :allow_inputs => bool (true)
  #   Whether to allow inputs (e.g., filenames and such). If false, will raise
  #   an exception for any unrecognized arguments.
  #
  def self.parse_args(args, options={})
    #TODO: rewrite this entire thing because it's a mess.
    args = args.clone

    implicit = !! options[:implicit]
    allow_inputs = !! options[:allow_inputs]
    parameters = options[:parameters] || {}

    inputs = []
    params = {}

    swallow_key = nil

    index = 0

    until args.empty?
      arg = args.shift

      name = nil

      if ! (match = (arg.match(@@SHORT_OPT) || arg.match(@@LONG_OPT))).nil? && swallow_key.nil?
        name = match[:name]
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

        parser = opt[:parser]

        value = is_flag ? true : match[:value]

        if ! is_flag && (value.nil? || value.empty?)
          value = args.shift
        end

        if is_flag && ! match[:value].nil?
          raise "Invalid argument: #{arg}."
        end

        value = parser[value] unless parser.nil?

        container = nil

        if params.include?(name) && allow_multiple
          container = params[name]
          cur_value = container.value
          cur_indices = container.index
          indices = nil
          if cur_value.is_a? Array
            value = [*cur_value, value]
            indices = [*cur_indices, index]
          else
            value = [cur_value, value]
            indices = [cur_index, index]
          end
          container.value = value
          container.index = indices
        elsif allow_multiple
          container = @@ARG_INFO.new([value], [index])
        elsif params.include?(name)
          raise "Invalid argument: #{arg} already set to '#{params[name]}'."
        else
          container = @@ARG_INFO.new(value, index)
        end

        params.store name, container
      elsif swallow_key
        container = params[swallow_key]
        if container.nil?
          params[swallow_key] = [arg]
        else
          params[swallow_key] = [*container, arg]
        end
      elsif allow_inputs
        inputs << @@ARG_INFO.new(arg, index)
      else
        raise "Unrecognized argument: #{arg}"
      end

      index += 1
    end

    parameters.each {|k, v|
      if v[:default] && (! params.include?(k))
        params[k] = @@ARG_INFO.new(v[:default], -1)
      end
    }

    return @@ARG_RESULT.new(params, inputs)
  end

end # ArgParser

if __FILE__ == $0
  require 'json'
  print JSON[ArgParser.parse_args(ARGV, :implicit => true)], $/
end
