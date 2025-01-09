Gem::Specification.new do |s|
  s.name = 'ruby-lsp-brakeman'
  s.version = '0.0.1'

  s.authors = ['Justin Collins']
  s.email = 'gem@brakeman.org'
  s.homepage = 'https://github.com/presidentbeef/ruby-lsp-brakeman'

  s.summary = 'Run Brakeman via Ruby Language Server'
  s.description = 'Brakeman detects security vulnerabilities in Ruby on Rails applications via static analysis.'

  s.files = Dir['lib/**/*']
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.1.0'

  s.metadata = {
    'source_code_uri' => 'https://github.com/presidentbeef/ruby-lsp-brakeman'
  }

  s.add_dependency('brakeman', '~> 7.0.0')
  s.add_dependency('ruby-lsp', '~>0.19')
end
