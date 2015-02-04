module Upjs
  module Guide
    class Parser
      include Logger

      class CannotParse < StandardError; end

      BLOCK_PATTERN = %r{
        ^[\ \t]*\#\#\#\*[\ \t]*\n  # YUIDoc begin symbol
        ((?:.|\n)*?)               # block content ($1)
        ^[\ \t]*\#\#\#[\ \t]*\n    # YUIDoc end symbol
      }x

      KLASS_PATTERN = %r{
        \@class  # @class
        \        # space
        (.+)     # class name ($1)
      }x

      FUNCTION_PATTERN = %r{
        \@method  # @function
        \         # space
        (.+)      # function name ($1)
      }x

      VISIBILITY_PATTERN = %r{
        \@(public|protected|private)
      }x

      TYPES_PATTERN = %r{
      \{        # opening brace
        ([^\}]+)  # pipe-separated list of types ($1)
        \}        # closing brace
      }x

      TYPES_SEPARATOR = %r{
        [\ \t]*  # whitespace
        \|       # pipe symbol
        [\ \t]*  # whitespace
      }x

      PARAM_PATTERN = %r{
        (^[ \t]*)      # first line indent ($1)
        \@param        # @param
        (              # param spec ($2)
          .+\n         # .. remainder of first line
          (?:          # .. subsequent lines that are indented further than the first line
            \1[\ \t]+
            .*$
          )*
        )
      }x

      PARAM_NAME_PATTERN = %r{
        ([^\ \t]+)      # required param name ($1)
        |
        (?:
          \[
            ([^\ \t]+)  # optional param name ($2)
            (?:
              [\ \t]*   # .. whitespace around equals symbol
              \=        # .. equals symbol
              [\ \t]*   # .. whitespace around equals symbol
              (.*?)     # .. default value ($3)
            )?
          \]
        )
      }x

      UJS_PATTERN = %r{
        \@ujs
      }x

      # EXAMPLE_PATTERN = %r{
      #   (^[ \t]*)     # first line indent ($1)
      #   \@example     # @example
      #   (             # example body ($1)
      #     .+\n        # .. remainder of first line
      #     \1[\ \t]+   # .. subsequent lines that are indented further than the first line
      #   )
      # }x

      def initialize(repository)
        @repository = repository
        @last_klass = nil
      end

      def parse(path)
        log("Block pattern", BLOCK_PATTERN)
        log("try", "###*\nfoo\n###\n".match(BLOCK_PATTERN))
        code = File.read(path)
        blocks = find_blocks(code)
        log("Found blocks", blocks)
        blocks.each do |block|
          puts block
          parse_klass!(block) || parse_function!(block)
        end
      end

      def parse_klass!(block)
        log("Trying to parse klass", block)
        if block.sub!(KLASS_PATTERN, '')
          klass_name = $1
          log("Parsed klass name", klass_name)
          klass = Klass.new(klass_name)
          if visibility = parse_visibility!(block)
            klass.visibility = visibility
          end
          # All the remaining text is guide prose
          klass.guide_markdown = block
          @repository.klasses << klass
          @last_klass = klass
          klass
        end
      end

      def parse_function!(block)
        if block.sub!(FUNCTION_PATTERN, '')
          function_name = $1
          log("Parsed function name", function_name)
          function = Function.new(function_name)
          if visibility = parse_visibility!(block)
            function.visibility = visibility
          end
          while param = parse_param!(block)
            function.params << param
          end
          # while example = parse_example(block)
          #   function.examples << example
          # end
          # if response = parse_response!(block)
          #   function.response = response
          # end
          if parse_ujs!(block)
            function.ujs = true
          end
          # All the remaining text is guide prose
          function.guide_markdown = block
          @last_klass.functions << function
          function
        end
      end

      def parse_visibility!(block)
        if block.sub!(VISIBILITY_PATTERN, '')
          visibility = $1
          visibility
        end
      end

      def parse_param!(block)
        if block.sub!(PARAM_PATTERN, '')
          param_spec = unindent($2)
          param = Param.new
          param.types = parse_types!(param_spec)
          if name_props = parse_param_name_and_optionality!(param_spec)
            param.name = name_props[:name].strip
            param.optional = name_props[:optional] if name_props.has_key?(:optional)
            param.default = name_props[:default] if name_props.has_key?(:default)
          end
          param.guide_markdown = unindent_hanging(param_spec)
          param
        end
      end

      # A param's name, optional/required property and
      # eventual default value are so interwoven syntax-wise
      # that we parse all three with a single function.
      def parse_param_name_and_optionality!(param_spec)
        if param_spec.sub!(PARAM_NAME_PATTERN, '')
          required_param_name = $1
          optional_param_name = $2
          default_value = $2
          if required_param_name
            { name: required_param_name,
              optional: false }
          else
            { name: optional_param_name,
              optional: true,
              default: default_value }
          end
        end
      end

      def parse_ujs!(block)
        if block.sub!(UJS_PATTERN, '')
          true
        end
      end

      def parse_types!(block)
        if block.sub!(TYPES_PATTERN, '')
          types = $1.split(TYPES_SEPARATOR)
          types
        end
      end

      private

      def find_blocks(code)
        code.scan(BLOCK_PATTERN).collect do |match|
          log("match", match[0])
          unindent(match[0])
        end
      end

      # Takes a multi-line string (or an Array of single lines)
      # and unindents all lines by the first line's indent.
      def unindent(text_or_lines)
        lines = text_or_lines.is_a?(String) ? split_lines(text_or_lines) : text_or_lines.dup
        remove_preceding_blank_lines!(lines)
        if lines.size > 0
          first_indent = lines.first.match(/^[ \t]*/)[0]
          lines.collect { |line|
            line.gsub(/^[ \t]{0, #{first_indent.size}}/, '')
          }.join("\n")
        else
          ''
        end
      end

      # Removes all leading whitespace from the first line
      # and unindents all subsequent lines by the second line's indent.
      def unindent_hanging(block)
        first_line, other_lines = first_and_other_lines(block)
        first_line.sub!(/^[\ \t]+/, '')
        unindented_other_lines = unindent(other_lines)
        log("first_line", first_line)
        log("other_lines", other_lines)
        [first_line, unindented_other_lines].join("\n")
      end

      def split_lines(text)
        text.split(/\n/)
      end

      def first_and_other_lines(text)
        lines = split_lines(text)
        if lines.length == 0
          ['', []]
        else
          first_line, *other_lines = lines
          [first_line, other_lines]
        end
      end

      def remove_preceding_blank_lines!(lines)
        while lines.first =~ /^([ \t]*)$/
          lines.shift
        end
        lines
      end

    end

  end
end
