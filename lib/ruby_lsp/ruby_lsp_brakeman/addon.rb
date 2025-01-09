# frozen_string_literal: true

require "brakeman"
require "brakeman/rescanner"
require "ruby_lsp/addon"
require "thread"

module RubyLsp
  module BrakemanLsp
    class Addon < ::RubyLsp::Addon
      FILE_GLOBS = [
        '**/brakeman.yaml',
        '**/brakeman.yml',
        '**/*.html.erb',
        '**/*.js.erb',
        '**/*.html.haml',
        '**/*.html.slim',
        '**/*.rhtml',
        '**/Gemfile',
        '**/Gemfile.lock',
        '**/gems.rb',
        '**/gems.locked',
        '**/*.gemspec',
        '**/.ruby-version',
      ]

      def initialize
        super

        @brakeman = nil
        @changed_queue = Queue.new
      end

      # Kick off Brakeman scan in the background
      def activate(global_state, message_queue)
        @message_queue = message_queue

        unless Brakeman.respond_to?(:run)
          notify('Failed to activate Ruby LSP Brakeman')
          return
        end

        Thread.new do
          @brakeman = Brakeman.run(app_path: global_state.workspace_path, support_rescanning: true)

          notify('Initial Brakeman scan complete.')

          add_warnings(@brakeman.filtered_warnings)

          rescan
        end

        register_additional_file_watchers(global_state, message_queue)

        notify('Activated Ruby LSP Brakeman')
      end

      # Watch additional files, not just *.rb
      def register_additional_file_watchers(global_state, message_queue)
        # Clients are not required to implement this capability
        return unless global_state.supports_watching_files

        watchers = FILE_GLOBS.map do |pattern|
          Interface::FileSystemWatcher.new(
            glob_pattern: pattern,
            kind: Constant::WatchKind::CREATE | Constant::WatchKind::CHANGE | Constant::WatchKind::DELETE
          )
        end

        message_queue << Request.new(
          id: "ruby-lsp-brakeman-file-watcher",
          method: "client/registerCapability",
          params: Interface::RegistrationParams.new(
            registrations: [
              Interface::Registration.new(
                id: "workspace/didChangeWatchedFilesMyGem",
                method: "workspace/didChangeWatchedFiles",
                register_options: Interface::DidChangeWatchedFilesRegistrationOptions.new(
                  watchers: watchers,
                ),
              ),
            ],
          ),
        )
      end

      # Send warnings to the client as diagnostic messages
      def add_warnings(warnings, fixed_warnings = [])

        # Each "publishDiagnostics" message to the client provides
        # a list of diagnostic messages per file.
        # Here we group the warnings by file and convert the warnings
        # to diagnostics.
        diagnostics = warnings.group_by do |warning|
          warning.file.absolute
        end.each_value do |warnings|
          warnings.map! do |warning|
            warning_to_lsp_diagnostic(warning)
          end
        end

        # Send diagnostics to client, grouped by file
        diagnostics.each do |path, diags|
          @message_queue << Notification.new(
            method: 'textDocument/publishDiagnostics',
            params: Interface::PublishDiagnosticsParams.new(uri: URI::Generic.from_path(path: path), diagnostics: diags)
          )
        end

        # If a file used to have warnings, but they are now
        # all fixed, send an empty array to clear old warnings in the
        # client. Otherwise they can hang around.
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

      # Convert a Brakeman warning to a diagnostic
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
          code_description: Interface::CodeDescription.new(href: warning.link) # Does not work in VSCode?
        )
      end

      # Format the warning message
      def warning_message(warning)
        parts = ["[#{warning.warning_type}] #{warning.message}.\n"]

        if warning.user_input
          parts << "Dangerous value: `#{warning.format_user_input}`"
        end

        parts.join("\n")
      end

      def deactivate
      end

      # Returns the name of the addon
      def name
        "Ruby LSP Brakeman"
      end

      # When any files change, add them to the queue for rescanning.
      def workspace_did_change_watched_files(changes)
        changed_files = changes.map { |change| URI(change[:uri]).path }
        changed_files.each { |path| @changed_queue << path }


        notify("Queued #{changed_files.join(', ')}")
      end

      # Wait for changed files, then scan them.
      # Can handle multiple changed files (e.g. if files changed during a scan)
      def rescan
        loop do
          # Grab the first file off the top of the queue.
          # Will block until there's a file in the queue.
          first_path = @changed_queue.pop
          changed_files = [first_path]

          # Get the rest of the files from the queue, if any.
          @changed_queue.length.times do
            changed_files << @changed_queue.pop
          end

          changed_files.uniq!

          notify("Rescanning #{changed_files.join(', ')}")

          # Rescan the changed files
          rescanner = Brakeman::Rescanner.new(@brakeman.options, @brakeman.processor, changed_files)
          rescan = rescanner.recheck
          @brakeman = rescanner.tracker

          notify("Rescanned #{changed_files.join(', ')}")

          # Send new/fixed warning information to the client
          add_warnings(rescan.all_warnings, rescan.fixed_warnings)

          # Log the results
          notify("Warnings: #{rescan.new_warnings.length} new, #{rescan.fixed_warnings.length} fixed, #{rescan.all_warnings.length} total")
        end
      end

      # Send logging information to the client
      def notify(message)
        @message_queue << Notification.window_log_message("[Brakeman] #{message.to_s}")
      end
    end
  end
end
