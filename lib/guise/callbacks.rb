module Guise
  # @api private
  class Callback
    def initialize(guise, attribute)
      @guise = guise
      @attribute = attribute
    end
  end

  # @api private
  class SourceCallback < Callback
    def after_initialize(record)
      if record.new_record?
        record.guises.build(@attribute => @guise)
      end
    end
  end

  # @api private
  class AssociationCallback < Callback
    def after_initialize(record)
      record.assign_attributes(@attribute => @guise)
    end
  end
end
