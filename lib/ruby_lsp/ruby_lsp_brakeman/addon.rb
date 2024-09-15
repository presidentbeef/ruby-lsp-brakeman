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

          @message_queue << Notification.window_log_message("Brakeman ran!")
          $stderr.puts("Ran Brakeman!")
          
          add_warnings(@brakeman.filtered_warnings)

          rescan
        end

        $stderr.puts("Activated Ruby LSP Brakeman")
      end

      # Send warnings to the client as diagnostic messages
      def add_warnings(warnings, fixed_warnings = [])
        diagnostics = warnings.group_by do |warning|
          warning.file.absolute
        end.each_value do |warnings|
          warnings.map! do |warning|
            warning_to_lsp_diagnostic(warning)
          end
        end

        diagnostics.each do |path, diags|
          @message_queue << Notification.new(
            method: 'textDocument/publishDiagnostics',
            params: Interface::PublishDiagnosticsParams.new(uri: URI::Generic.from_path(path: path), diagnostics: diags)
          )
        end

        fixed_warnings.group_by do |warning|
          warning.file.absolute
        end.each do |path, warnings|
          next if diagnostics[path] # Only clear diagnostics if no warnings for file

          # Otherwise, send empty message for file to clear
          @message_queue << Notification.new(
            method: 'textDocument/publishDiagnostics',
            params: Interface::PublishDiagnosticsParams.new(uri: URI::Generic.from_path(path: path), diagnostics: [])
          )
        end
      end

      def warning_to_lsp_diagnostic(warning)
        severity = case warning.confidence
                   when 0 # High
                     Constant::DiagnosticSeverity::ERROR
                   when 1 # Medium
                     Constant::DiagnosticSeverity::WARNING
                   when 2 # Low
                     Constant::DiagnosticSeverity::INFORMATION
                   else # Theoretical other levels
                     Constant::DiagnosticSeverity::INFORMATION
                   end

        Interface::Diagnostic.new(
          source: "Brakeman",
          message: warning_message(warning),
          severity: severity,
          range: Interface::Range.new(
            start: Interface::Position.new(
              line: warning.line - 1, # Zero indexed lines
              character: 0, # "Start of line"
            ),
            end: Interface::Position.new(
              line: warning.line - 1,
              character: 1000, # "End of line"
            ),
          ),
          code: warning.code,
          code_description: Interface::CodeDescription.new(href: warning.link)
        )
      end

      def warning_message(warning)
        parts = ["[#{warning.warning_type}] #{warning.message}\n"]

        if warning.user_input
          parts << "Dangerous value: `#{warning.format_user_input}`"
        end

        parts.join("\n")
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
          add_warnings(rescan.all_warnings, rescan.fixed_warnings)

          $stderr.puts rescan
        end
      end
    end
  end
end
