module Unpoly
  module Guide
    class Repository
      include Logger

      PROMOTED_KLASS_NAMES = %w[
        up.link
        up.modal
        up.popup
        up.motion
        up.feedback
        up.syntax
        up.fragment
        up.proxy
        up.form
        up.tooltip
        up.history
        up.viewport
        up.bus
        up.radio
        up.browser
        up.protocol
        up.util
        up.params
        up.log
      ]

      def initialize(input_path)
        @path = input_path
        reload
      end

      attr_reader :path

      def reload
        @klasses = []
        @feature_index = nil
        @changelog = nil
        @promoted_klasses = nil
        parse
        self
      end

      def changelog
        @changelog ||= begin
          path = File.join(@path, 'CHANGELOG.md')
          File.read(path)
        end
      end

      def github_url
        'https://github.com/unpoly/unpoly'
      end

      def promoted_klasses
        @promoted_klasses ||= begin
          PROMOTED_KLASS_NAMES.map do |klass_name|
            klass_for_name(klass_name)
          end
        end
      end

      def all_features
        @feature_index.all
      end

      def all_feature_guide_ids
        # We have multiple selectors called [up-close]
        @feature_index.guide_ids
      end

      # Since we (e.g.) have multiple selectors called [up-close],
      # we display all of them on the same guide page.
      def features_for_guide_id(guide_id)
        @feature_index.find_guide_id(guide_id)
      end

      def version
        require File.join(@path, 'lib/unpoly/rails/version')
        Unpoly::Rails::VERSION
      end

      def git_version_tag
        "v#{version}"
      end

      def git_revision
        revision = nil
        Dir.chdir @path do
          revision = `git rev-parse HEAD`
        end
        revision
      end

      attr_reader :klasses

      attr_reader :feature_index

      def klass_for_name(name)
        klasses.detect { |klass| klass.name == name } or raise UnknownClass, "No such Klass: #{name}"
      end

      def source_paths
        File.directory?(@path) or raise "Input path not found: #{@path}"
        pattern = File.join(@path, "lib/**/*{.coffee,.coffee.erb}")
        log("Input pattern", pattern)
        Dir[pattern]
      end

      def parse
        parser = Parser.new(self)
        log("Source paths", source_paths)
        source_paths.each do |source_path|
          parser.parse(source_path)
        end
        @feature_index = Feature::Index.new(klasses.collect(&:features).flatten)
      end

      def inspect
        "#<#{self.class.name} klass_names=#{klasses.collect(&:name)}>"
      end

    end
  end
end
