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

    def pop_diagnostic(server)
      result = server.pop_response
      result = server.pop_response until result.is_a?(RubyLsp::Notification) && result.method == 'textDocument/publishDiagnostics'
      result
    end
  end
end
