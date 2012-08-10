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
      (?<name> \w+ )
      (?:
        (?<equals> \s* = \s* | \s+ )
        (?<value> .+ )?
      )?
    $/ix

  # === Options Format
  #
  # :parameters => {
  #  'name' (string) => {
  #   The name of the parameter.
  #
  #   :alias => 'other_name' (string),
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
    #TODO: rewrite this entire thing because it's a mess.
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
  require 'json'
  print JSON[ArgParser.parse_args(ARGV, :implicit => true)], $/
end
