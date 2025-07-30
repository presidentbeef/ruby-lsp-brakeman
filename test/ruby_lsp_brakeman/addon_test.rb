# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module BrakemanLsp
    class TestDefinition < Minitest::Test
      def test_publich_diagnostic
        diagnostics = generate_diagnostics_for_source(<<~'RUBY', { line: 2, character: 1 })
          class SomeController < ApplicationController
            def index
              @any = ActiveRecord::Base.where("id = #{params[:id]}")
            end
          end
        RUBY

        assert_equal(1, diagnostics.size)

        diagnostic = diagnostics.first
        assert_equal(2, diagnostic.range.start.line)
        assert_equal(0, diagnostic.range.start.character)
        assert_equal(2, diagnostic.range.end.line)
        assert_equal(1000, diagnostic.range.end.character)
        assert_equal(Constant::DiagnosticSeverity::ERROR, diagnostic.severity)
        assert_equal('https://brakemanscanner.org/docs/warning_types/sql_injection/', diagnostic.code_description.href)
        assert_equal('Brakeman', diagnostic.source)
        assert_equal(<<~'MESSAGE'.chomp, diagnostic.message)
          [SQL Injection] Possible SQL injection.

          Dangerous value: `params[:id]`
        MESSAGE
      end

      def generate_diagnostics_for_source(source, position) # rubocop:disable Metrics/MethodLength
        tf = Tempfile.open(['fake', '.rb']) do |fp|
          fp.puts source
          fp
        end
        with_server do |server, uri|
          server.process_message(
            id: 1,
            method: "workspace/didChangeWatchedFiles",
            params: { changes: [ { uri: URI::File.build(path: tf.path).to_s, type: Constant::FileChangeType::CREATED } ] }
          )

          result = pop_diagnostic(server)
          result.params.diagnostics
        end
      end
    end
  end
end
