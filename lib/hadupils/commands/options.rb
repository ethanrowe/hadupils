module Hadupils::Commands
  module Options
    # NOTE: Only a single option per command (known limitation for now)
    module Directory
      def perform_directory?
        %w(-d --directory).include? params[0]
      end
    end
    module DryRun
      def perform_dry_run?
        %w(-n --dry-run).include? params[0]
      end
    end
    module Recursive
      def perform_recursive?
        %w(-r -R --recursive).include? params[0]
      end
    end
  end
end
