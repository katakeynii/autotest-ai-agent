# frozen_string_literal: true

require_relative "lib/autotest/agent/version"

Gem::Specification.new do |spec|
  spec.name = "autotest-ia"
  spec.version = Autotest::Agent::VERSION
  spec.authors = ["Mohamed Camara GUEYE"]
  spec.email = ["mohamed-camara.gueye@free-partenaires.sn"]

  spec.summary = "Automate test generation and execution in Rails apps using AI"
  spec.description = "An intelligent gem that uses AI to automatically generate, update, and execute tests in Rails applications. Supports RSpec and Minitest with real-time file watching and AI-powered test generation."
  spec.homepage = "https://github.com/username/autotest-ia"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/username/autotest-ia"
  spec.metadata["changelog_uri"] = "https://github.com/username/autotest-ia/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = ["autotest-ia"]
  spec.require_paths = ["lib"]

  # Dépendances principales pour le fonctionnement du gem
  spec.add_dependency "langchainrb", "~> 0.6"
  spec.add_dependency "listen", "~> 3.8"
  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "tty-spinner", "~> 0.9"
  spec.add_dependency "colorize", "~> 0.8"

  # Dépendances de développement pour les tests et l'automatisation
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "guard", "~> 2.18"
  spec.add_development_dependency "guard-rspec", "~> 4.7"
  spec.add_development_dependency "factory_bot", "~> 6.2"
  spec.add_development_dependency "faker", "~> 3.0"
  spec.add_development_dependency "shoulda-matchers", "~> 5.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "vcr", "~> 6.1"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "email_spec", "~> 2.2"
  spec.add_development_dependency "database_cleaner-active_record", "~> 2.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
