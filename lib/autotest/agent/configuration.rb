# frozen_string_literal: true

require "fileutils"

module Autotest
  module Agent
    # Gère la configuration globale du gem autotest-ia
    # Permet de personnaliser le comportement de génération de tests,
    # les paramètres IA, les frameworks de test, etc.
    class Configuration
      attr_accessor :test_framework, :ai_provider, :ai_model, :ai_api_key,
                    :watch_paths, :exclude_paths, :auto_run_tests,
                    :coverage_threshold, :interactive_mode, :prompt_templates,
                    :rails_app_path, :test_output_path

      # Initialise la configuration avec des valeurs par défaut
      def initialize
        @test_framework = detect_test_framework
        @ai_provider = :openai
        @ai_model = "gpt-3.5-turbo"
        @ai_api_key = ENV["OPENAI_API_KEY"]
        
        # Chemins à surveiller par défaut dans une app Rails
        @watch_paths = %w[
          app/models
          app/controllers
          app/jobs
          app/services
          app/helpers
          app/mailers
          lib
        ]
        
        # Chemins à exclure de la surveillance
        @exclude_paths = %w[
          tmp
          log
          vendor
          node_modules
          .git
        ]
        
        @auto_run_tests = true
        @coverage_threshold = 80
        @interactive_mode = true
        @rails_app_path = Dir.pwd
        @test_output_path = detect_test_output_path
        
        # Templates de prompts pour différents types de fichiers
        @prompt_templates = default_prompt_templates
      end

      # Détecte automatiquement le framework de test utilisé
      def detect_test_framework
        if File.exist?("spec/spec_helper.rb") || File.exist?("spec/rails_helper.rb")
          :rspec
        elsif File.exist?("test/test_helper.rb")
          :minitest
        else
          :rspec # Par défaut, on installe RSpec
        end
      end

      # Détecte le chemin de sortie des tests
      def detect_test_output_path
        case test_framework
        when :rspec
          "spec"
        when :minitest
          "test"
        else
          "spec"
        end
      end

      # Vérifie que la configuration est valide
      def valid?
        ai_api_key && !ai_api_key.empty?
      end

      # Retourne les erreurs de configuration
      def validation_errors
        errors = []
        errors << "Clé API IA manquante" if !ai_api_key || ai_api_key.empty?
        errors << "Chemin Rails invalide" unless File.directory?(rails_app_path)
        errors
      end

      # Configure automatiquement RSpec si pas de framework détecté
      def setup_rspec!
        return if File.exist?("spec/spec_helper.rb")

        puts "🔧 Configuration de RSpec...".colorize(:yellow)
        
        # Crée le répertoire spec
        FileUtils.mkdir_p("spec")
        
        # Crée spec_helper.rb
        create_spec_helper
        
        # Crée rails_helper.rb si c'est une app Rails
        create_rails_helper if rails_application?
        
        @test_framework = :rspec
        @test_output_path = "spec"
        
        puts "✅ RSpec configuré avec succès !".colorize(:green)
      end

      private

      # Vérifie si c'est une application Rails
      def rails_application?
        File.exist?("config/application.rb") && File.exist?("Gemfile")
      end

      # Crée le fichier spec_helper.rb
      def create_spec_helper
        spec_helper_content = <<~RUBY
          # frozen_string_literal: true

          require 'simplecov'
          SimpleCov.start 'rails' do
            add_filter '/vendor/'
            add_filter '/spec/'
            minimum_coverage #{coverage_threshold}
          end

          RSpec.configure do |config|
            config.expect_with :rspec do |expectations|
              expectations.include_chain_clauses_in_custom_matcher_descriptions = true
            end

            config.mock_with :rspec do |mocks|
              mocks.verify_partial_doubles = true
            end

            config.shared_context_metadata_behavior = :apply_to_host_groups
            config.filter_run_when_matching :focus
            config.example_status_persistence_file_path = "spec/examples.txt"
            config.disable_monkey_patching!
            config.warnings = true

            if config.files_to_run.one?
              config.default_formatter = "doc"
            end

            config.profile_examples = 10
            config.order = :random
            Kernel.srand config.seed
          end
        RUBY

        FileUtils.mkdir_p("spec")
        File.write("spec/spec_helper.rb", spec_helper_content)
      end

      # Crée le fichier rails_helper.rb pour les apps Rails
      def create_rails_helper
        rails_helper_content = <<~RUBY
          # frozen_string_literal: true

          require 'spec_helper'
          ENV['RAILS_ENV'] ||= 'test'
          require_relative '../config/environment'

          abort("The Rails environment is running in production mode!") if Rails.env.production?
          require 'rspec/rails'

          begin
            ActiveRecord::Migration.maintain_test_schema!
          rescue ActiveRecord::PendingMigrationError => e
            abort e.to_s.strip
          end

          RSpec.configure do |config|
            config.fixture_path = "\#{::Rails.root}/spec/fixtures"
            config.use_transactional_fixtures = true
            config.infer_spec_type_from_file_location!
            config.filter_rails_from_backtrace!
          end
        RUBY

        FileUtils.mkdir_p("spec")
        File.write("spec/rails_helper.rb", rails_helper_content)
      end

      # Templates de prompts par défaut pour différents types de fichiers
      def default_prompt_templates
        {
          model: {
            system: "Tu es un expert en tests Ruby on Rails. Génère des tests RSpec complets et pertinents.",
            user: "Génère des tests pour ce modèle Rails :\n\n%{code}\n\nContexte métier : %{context}\n\nInclus des tests pour :\n- Validations\n- Associations\n- Méthodes métier\n- Scopes\n- Callbacks"
          },
          controller: {
            system: "Tu es un expert en tests de contrôleurs Rails. Génère des tests RSpec complets.",
            user: "Génère des tests pour ce contrôleur Rails :\n\n%{code}\n\nContexte métier : %{context}\n\nInclus des tests pour :\n- Actions CRUD\n- Authentification/autorisation\n- Paramètres\n- Redirections\n- Format JSON/HTML"
          },
          job: {
            system: "Tu es un expert en tests de jobs Rails. Génère des tests RSpec complets.",
            user: "Génère des tests pour ce job Rails :\n\n%{code}\n\nContexte métier : %{context}\n\nInclus des tests pour :\n- Exécution du job\n- Gestion des erreurs\n- Files d'attente\n- Arguments"
          },
          service: {
            system: "Tu es un expert en tests de services Ruby. Génère des tests RSpec complets.",
            user: "Génère des tests pour ce service :\n\n%{code}\n\nContexte métier : %{context}\n\nInclus des tests pour :\n- Méthodes publiques\n- Gestion des erreurs\n- Cas limites\n- Valeurs de retour"
          }
        }
      end
    end
  end
end 