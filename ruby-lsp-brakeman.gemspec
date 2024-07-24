Gem::Specification.new do |s|
  s.name = 'ruby-lsp-brakeman'
  s.version = '0.0.1'

  s.authors = ["Justin Collins"]
  s.email = "gem@brakeman.org"

  s.summary = "Run Brakeman from VS Code"
  s.description = "Brakeman detects security vulnerabilities in Ruby on Rails applications via static analysis."

  s.files = Dir["lib/**/*"]
  s.license = "MIT"
  s.required_ruby_version = '>= 3.0.0'

  s.metadata = {
    "source_code_uri"   => "https://github.com/presidentbeef/ruby-lsp-brakeman",
  }

  s.add_dependency("ruby-lsp", "~> 0.17.0")
  s.add_dependency("brakeman-lib", "~> 6.1.0")
end
