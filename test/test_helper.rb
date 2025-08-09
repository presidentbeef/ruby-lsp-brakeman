# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "tempfile"
require "ruby_lsp/internal"
require "ruby_lsp/test_helper"
require "ruby_lsp/ruby_lsp_brakeman/addon"

module Minitest
  class Test
    include RubyLsp::TestHelper

    def setup
      @config_path = File.join(File.expand_path("..", __dir__), "config", "brakeman.yml")
      unless File.exist?(@config_path)
        FileUtils.mkdir_p(File.dirname(@config_path))
        File.write(@config_path, <<~YAML)
          ---
          force_scan: true
        YAML
        @config_file_created = true
      else
        require 'yaml'
        options = YAML.safe_load_file @config_path, permitted_classes: [Symbol], symbolize_names: true
        unless options[:force_scan]
          flunk "Brakeman cannot be run in tests without force_scan: true. Please set it in config/brakeman.yml."
        end
      end
    end

    def teardown
      File.delete(@config_path) if @config_file_created && File.exist?(@config_path)
    end

    def pop_diagnostic(server)
      result = server.pop_response
      result = server.pop_response until result.is_a?(RubyLsp::Notification) && result.method == 'textDocument/publishDiagnostics'
      result
    end
  end
end
