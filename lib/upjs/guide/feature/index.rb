module Upjs
  module Guide
    class Feature
      class Index

        class Entry

          def initialize(features)
            @features = features
          end

          delegate :guide_id, :guide_path, :name, :search_text, :visibility, :kind, :short_kind, :<=>, :sort_name, :stable, :experimental, :internal?, to: :first_feature

          private

          def first_feature
            @features.first
          end

        end

        def initialize(features)
          @features = features
          @features_by_guide_id = @features.group_by(&:guide_id)
          @entries = @features_by_guide_id.values.collect { |features_with_same_guide_id|
            Entry.new(features_with_same_guide_id)
          }.sort
        end

        def all
          @features
        end

        attr_reader :entries

        def guide_ids
          @features_by_guide_id.keys
        end

        def find_guide_id(guide_id)
          @features_by_guide_id[guide_id] or raise "No features for guide id: #{guide_id.inspect}"
        end

      end
    end
  end
end

