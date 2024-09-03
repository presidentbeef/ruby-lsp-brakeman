# frozen_string_literal: true

require "brakeman"
require "brakeman/rescanner"
require "ruby_lsp/addon"
require "thread"

module RubyLsp
  module MyGem
    class Addon < ::RubyLsp::Addon
      def initialize
        super

        @brakeman = nil
        @changed_queue = Queue.new
      end

      # Kick off Brakeman scan in the background
      def activate(global_state, message_queue)
        @message_queue = message_queue

        Thread.new do
          @brakeman = Brakeman.run(app_path: global_state.workspace_path, support_rescanning: true)

          $stderr.puts("Ran Brakeman!")
          
          add_warnings(@brakeman.filtered_warnings)

          rescan
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

      def workspace_did_change_watched_files(changes)
        changed_files = changes.map { |change| URI(change[:uri]).path }
        changed_files.each { |path| @changed_queue << path }


        $stderr.puts("Queued #{changed_files.join(', ')}")
      end

      def rescan
        loop do
          first_path = @changed_queue.pop
          changed_files = [first_path]

          @changed_queue.length.times do
            changed_files << @changed_queue.pop
          end

          changed_files.uniq!

          $stderr.puts("Rescanning #{changed_files.join(', ')}")

          rescanner = Brakeman::Rescanner.new(@brakeman.options, @brakeman.processor, changed_files)
          rescan = rescanner.recheck
          @brakeman = rescanner.tracker

          $stderr.puts("Rescanned #{changed_files.join(', ')}")
          $stderr.puts rescan
        end
      end
    end
  end
end
