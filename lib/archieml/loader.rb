module Archieml
  class Loader

    NEXT_LINE     = /.*((\r|\n)+)/
    START_KEY     = /^\s*([A-Za-z0-9\-_\.]+)[ \t\r]*:[ \t\r]*(.*(?:\n|\r|$))/
    COMMAND_KEY   = /^\s*:[ \t\r]*(endskip|ignore|skip|end)/i
    ARRAY_ELEMENT = /^\s*\*[ \t\r]*(.*(?:\n|\r|$))/
    SCOPE_PATTERN = /^\s*(\[|\{)[ \t\r]*([A-Za-z0-9\-_\.]*)[ \t\r]*(?:\]|\})[ \t\r]*.*?(\n|\r|$)/

    def initialize
      @data = @scope = {}

      @buffer_scope  = @buffer_key = nil
      @buffer_string = ''

      @is_skipping  = false
      @done_parsing = false

      self.flush_scope!
    end

    def load(stream)
      stream.each_line do |line|
        return @data if @done_parsing

        if match = line.match(COMMAND_KEY)
          self.parse_command_key(match[1].downcase)

        elsif !@is_skipping && (match = line.match(START_KEY)) && (!@array || @array_type != 'simple')
          self.parse_start_key(match[1], match[2] || '')

        elsif !@is_skipping && (match = line.match(ARRAY_ELEMENT)) && @array && @array_type != 'complex'
          self.parse_array_element(match[1])

        elsif !@is_skipping && match = line.match(SCOPE_PATTERN)
          self.parse_scope(match[1], match[2])

        else
          @buffer_string += line
        end
      end

      self.flush_buffer!
      return @data
    end

    def parse_start_key(key, rest_of_line)
      self.flush_buffer!

      if @array
        @array_type ||= 'complex'

        # Ignore complex keys inside simple arrays
        return if @array_type == 'simple'

        if [nil, key].include?(@array_first_key)
          @array << (@scope = {})
        end

        @array_first_key ||= key
      end

      @buffer_key = key
      @buffer_string = rest_of_line

      self.flush_buffer_into(key, replace: true)
    end

    def parse_array_element(value)
      self.flush_buffer!

      @array_type ||= 'simple'

      # Ignore simple array elements inside complex arrays
      return if @array_type == 'complex'

      @array << ''
      @buffer_key = @array
      @buffer_string = value
      self.flush_buffer_into(@array, replace: true)
    end

    def parse_command_key(command)
      if @is_skipping && !%w(endskip ignore).include?(command)
        return self.flush_buffer!
      end

      case command
      when "end"
        self.flush_buffer_into(@buffer_key, replace: false) if @buffer_key
        return

      when "ignore"
        return @done_parsing = true

      when "skip"
        @is_skipping = true

      when "endskip"
        @is_skipping = false
      end

      self.flush_buffer!
    end

    def parse_scope(scope_type, scope_key)
      self.flush_buffer!
      self.flush_scope!

      if scope_key == ''
        @scope = @data

      elsif %w([ {).include?(scope_type)
        key_scope = @data
        key_bits  = scope_key.split('.')
        key_bits[0...-1].each do |bit|
          key_scope = key_scope[bit] ||= {}
        end

        if scope_type == '['
          @array = key_scope[key_bits.last] ||= []

          if @array.length > 0
            @array_type = @array.first.class == String ? 'simple' : 'complex'
          end

        elsif scope_type == '{'
          @scope = key_scope[key_bits.last] ||= {}
        end
      end
    end

    def flush_buffer!
      result = @buffer_string.dup
      @buffer_string = ''
      return result
    end

    def flush_buffer_into(key, options = {})
      value = self.flush_buffer!

      if options[:replace]
        value = self.format_value(value, :replace).sub(/^\s*/, '')
        @buffer_string = value.match(/\s*\Z/)[0]
      else
        value = self.format_value(value, :append)
      end

      if key.class == Array
        key[key.length - 1] = '' if options[:replace]
        key[key.length - 1] += value.sub(/\s*\Z/, '')

      else
        key_bits = key.split('.')
        @buffer_scope = @scope

        key_bits[0...-1].each do |bit|
          @buffer_scope[bit] = {} if @buffer_scope[bit].class == String # reset
          @buffer_scope = @buffer_scope[bit] ||= {}
        end

        @buffer_scope[key_bits.last] = '' if options[:replace]
        @buffer_scope[key_bits.last] += value.sub(/\s*\Z/, '')
      end
    end

    def flush_scope!
      @array = @array_type = @array_first_key = nil
    end

    # type can be either :replace or :append.
    # If it's :replace, then the string is assumed to be the first line of a
    # value, and no escaping takes place.
    # If we're appending to a multi-line string, escape special punctuation
    # by prepending the line with a backslash.
    # (:, [, {, *, \) surrounding the first token of any line.
    def format_value(value, type)
      value.gsub!(/(?:^\\)?\[[^\[\]\n\r]*\](?!\])/, '') # remove comments
      value.gsub!(/\[\[([^\[\]\n\r]*)\]\]/, '[\1]') # [[]] => []

      if type == :append
        value.gsub!(/^(\s*)\\/, '\1')
      end

      value
    end

  end
end
