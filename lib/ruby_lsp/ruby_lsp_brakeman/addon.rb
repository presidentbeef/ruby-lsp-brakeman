# frozen_string_literal: true

require "brakeman"
require "ruby_lsp/addon"

module RubyLsp
  module MyGem
    class Addon < ::RubyLsp::Addon
      def initialize
        super
        @brakeman = nil
      end

      # Kick off Brakeman scan in the background
      def activate(global_state, message_queue)
        @message_queue = message_queue

        Thread.new do
          @brakeman = Brakeman.run(app_path: global_state.workspace_path, quiet: false, progress: false)
          $stderr.puts("Ran Brakeman!")
          
          add_warnings(@brakeman.filtered_warnings)
        end

        $stderr.puts("Activated Ruby LSP Brakeman")
      end

      def add_warnings(warnings)
      end

      # Performs any cleanup when shutting down the server, like terminating a subprocess
      def deactivate
      end

      # Returns the name of the addon
      def name
        "Ruby LSP Brakeman"
      end
    end
  end
end
