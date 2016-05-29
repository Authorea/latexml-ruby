# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = "latexml-ruby"
  spec.version       = "0.0.1"

  spec.authors       = ["Deyan Ginev"]
  spec.email         = ["deyan@authorea.com"]

  spec.summary       = %q{Ruby wrapper for LaTeXML}
  spec.description   = %q{The wrapper automates LaTeX to HTML5 conversions with LaTeXML, addressing common production needs such as error-handling, timeouts, managing option sets and automatic recognition of available binaries.}
  spec.homepage      = "https://github.com/Authorea/latexml-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'escape_utils'
  spec.add_dependency 'json'

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-reporters"

end
