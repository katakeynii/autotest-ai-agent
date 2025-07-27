# frozen_string_literal: true

require_relative "agent/version"
require_relative "agent/configuration"
require_relative "agent/file_watcher"
require_relative "agent/ai_generator"
require_relative "agent/test_runner"
require_relative "agent/reporter"
require_relative "agent/cli"

# Dépendances externes
require "langchain"
require "listen"
require "thor"
require "tty-prompt"
require "tty-spinner"
require "colorize"

module Autotest
  module Agent
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class AIGenerationError < Error; end
    class TestFrameworkError < Error; end

    # Point d'entrée principal du gem
    class << self
      # Configuration globale du gem
      attr_accessor :configuration

      # Initialise la configuration par défaut
      def configure
        self.configuration ||= Configuration.new
        yield(configuration) if block_given?
        configuration
      end

      # Démarre le watcher de fichiers
      def start_watching(path = ".")
        configure unless configuration
        FileWatcher.new(path, configuration).start
      end

      # Interface CLI principale
      def cli
        CLI.start(ARGV)
      end

      # Génère un test pour un fichier spécifique
      def generate_test_for(file_path, context: nil)
        configure unless configuration
        AIGenerator.new(configuration).generate_for_file(file_path, context)
      end

      # Exécute les tests
      def run_tests(test_files = nil)
        configure unless configuration
        TestRunner.new(configuration).run(test_files)
      end
    end
  end
end
