# frozen_string_literal: true

require "fileutils"
require "thor"

module Autotest
  module Agent
    # Interface en ligne de commande pour autotest-ia
    # Utilise Thor pour une CLI moderne et intuitive
    # Fournit toutes les fonctionnalités du gem via des commandes simples
    class CLI < Thor
      include Thor::Actions

      # Description du gem
      desc "version", "Affiche la version d'autotest-ia"
      def version
        puts "Autotest IA version #{Autotest::Agent::VERSION}".colorize(:green)
      end

      # Initialisation et configuration
      desc "init", "Initialise autotest-ia dans le projet Rails"
      option :provider, aliases: "-p", default: "openai", desc: "Provider IA (openai, ollama)"
      option :model, aliases: "-m", default: "gpt-3.5-turbo", desc: "Modèle IA à utiliser"
      option :interactive, type: :boolean, default: true, desc: "Mode interactif"
      def init
        puts "🚀 Initialisation d'autotest-ia...".colorize(:blue)
        
        # Vérifie que c'est un projet Rails/Ruby valide
        verify_ruby_project!
        
        # Configure autotest-ia
        configure_gem(options)
        
        # Configure RSpec si nécessaire
        setup_test_framework
        
        # Crée le fichier de configuration
        create_config_file(options)
        
        puts "✅ Autotest-ia initialisé avec succès !".colorize(:green)
        puts "📚 Lancez 'autotest-ia help' pour voir toutes les commandes disponibles."
      end

      # Surveillance des fichiers
      desc "watch [PATH]", "Démarre la surveillance des fichiers (défaut: répertoire courant)"
      option :interactive, type: :boolean, default: true, desc: "Mode interactif pour le contexte métier"
      option :auto_run, type: :boolean, default: true, desc: "Exécute automatiquement les tests générés"
      def watch(path = ".")
        puts "🔍 Démarrage de la surveillance avec autotest-ia...".colorize(:blue)
        
        # Charge la configuration
        load_configuration(options)
        
        # Vérifie la configuration IA
        verify_ai_configuration!
        
        # Démarre le watcher
        Autotest::Agent.start_watching(path)
      end

      # Génération de tests manuelle
      desc "generate FILE", "Génère un test pour un fichier spécifique"
      option :context, aliases: "-c", desc: "Contexte métier pour la génération"
      option :interactive, type: :boolean, default: false, desc: "Mode interactif pour collecter le contexte"
      option :output, aliases: "-o", desc: "Fichier de sortie pour le test généré"
      def generate(file_path)
        puts "🤖 Génération de test pour #{file_path}...".colorize(:cyan)
        
        # Vérifie que le fichier existe
        unless File.exist?(file_path)
          puts "❌ Fichier non trouvé : #{file_path}".colorize(:red)
          exit 1
        end
        
        # Charge la configuration
        load_configuration(options)
        verify_ai_configuration!
        
        # Génère le test
        if options[:interactive]
          test_content = generate_interactive_test(file_path)
        else
          test_content = Autotest::Agent.generate_test_for(file_path, context: options[:context])
        end
        
        if test_content
          output_file = options[:output] || determine_output_file(file_path)
          save_generated_test(output_file, test_content)
          puts "✅ Test généré : #{output_file}".colorize(:green)
        else
          puts "❌ Impossible de générer le test".colorize(:red)
          exit 1
        end
      end

      # Exécution des tests
      desc "test [FILES]", "Exécute les tests (tous si aucun fichier spécifié)"
      option :coverage, type: :boolean, default: true, desc: "Active le rapport de couverture"
      option :watch, type: :boolean, default: false, desc: "Mode surveillance continue"
      def test(*files)
        puts "🧪 Exécution des tests...".colorize(:blue)
        
        load_configuration(options)
        
        if options[:watch]
          runner = TestRunner.new(Autotest::Agent.configuration)
          runner.run_in_watch_mode
        else
          results = Autotest::Agent.run_tests(files.empty? ? nil : files)
          
          if results && options[:coverage]
            runner = TestRunner.new(Autotest::Agent.configuration)
            runner.analyze_results
          end
        end
      end

      # Rapports et analyses
      desc "report [TYPE]", "Génère un rapport (coverage, quality, trend, full)"
      option :output, aliases: "-o", desc: "Fichier de sortie pour le rapport"
      option :days, type: :numeric, default: 7, desc: "Nombre de jours pour l'analyse de tendance"
      def report(type = "full")
        puts "📊 Génération du rapport #{type}...".colorize(:blue)
        
        load_configuration(options)
        
        test_runner = TestRunner.new(Autotest::Agent.configuration)
        reporter = Reporter.new(Autotest::Agent.configuration, test_runner)
        
        case type.downcase
        when "coverage"
          reporter.generate_coverage_report
        when "quality"
          reporter.generate_quality_report
        when "trend"
          reporter.generate_trend_report(options[:days])
        when "full"
          output_file = reporter.generate_full_report(options[:output])
          puts "🌐 Ouvrez #{output_file} dans votre navigateur".colorize(:cyan)
        else
          puts "❌ Type de rapport non reconnu : #{type}".colorize(:red)
          puts "Types disponibles : coverage, quality, trend, full"
          exit 1
        end
      end

      # Configuration
      desc "config", "Affiche la configuration actuelle"
      def config
        load_configuration
        
        puts "⚙️  Configuration actuelle :".colorize(:cyan)
        config = Autotest::Agent.configuration
        
        puts "  🤖 Provider IA : #{config.ai_provider}"
        puts "  🧠 Modèle : #{config.ai_model}"
        puts "  🧪 Framework de test : #{config.test_framework}"
        puts "  📁 Chemins surveillés : #{config.watch_paths.join(', ')}"
        puts "  🎯 Seuil de couverture : #{config.coverage_threshold}%"
        puts "  ⚡ Exécution auto : #{config.auto_run_tests ? 'Activée' : 'Désactivée'}"
        puts "  💬 Mode interactif : #{config.interactive_mode ? 'Activé' : 'Désactivé'}"
        
        if config.valid?
          puts "  ✅ Configuration valide".colorize(:green)
        else
          puts "  ❌ Erreurs de configuration :".colorize(:red)
          config.validation_errors.each { |error| puts "    • #{error}" }
        end
      end

      # Amélioration de tests existants
      desc "improve TEST_FILE SOURCE_FILE", "Améliore un test existant"
      option :notes, aliases: "-n", desc: "Notes d'amélioration spécifiques"
      def improve(test_file, source_file)
        puts "🔧 Amélioration du test #{test_file}...".colorize(:yellow)
        
        unless File.exist?(test_file) && File.exist?(source_file)
          puts "❌ Fichier(s) non trouvé(s)".colorize(:red)
          exit 1
        end
        
        load_configuration(options)
        verify_ai_configuration!
        
        generator = AIGenerator.new(Autotest::Agent.configuration)
        improved_content = generator.improve_existing_test(test_file, source_file, options[:notes])
        
        if improved_content
          # Sauvegarde le test original
          backup_file = "#{test_file}.backup.#{Time.now.to_i}"
          FileUtils.cp(test_file, backup_file)
          puts "💾 Sauvegarde créée : #{backup_file}".colorize(:light_black)
          
          # Écrit le test amélioré
          File.write(test_file, improved_content)
          puts "✅ Test amélioré : #{test_file}".colorize(:green)
        else
          puts "❌ Impossible d'améliorer le test".colorize(:red)
          exit 1
        end
      end

      # Mode interactif complet
      desc "interactive", "Lance le mode interactif complet"
      def interactive
        puts "🎮 Mode interactif autotest-ia".colorize(:green)
        
        load_configuration
        
        prompt = TTY::Prompt.new
        
        loop do
          choice = prompt.select("Que souhaitez-vous faire ?", {
            "🔍 Surveiller les fichiers" => :watch,
            "🤖 Générer un test" => :generate,
            "🧪 Exécuter les tests" => :test,
            "📊 Voir un rapport" => :report,
            "⚙️  Configuration" => :config,
            "🚪 Quitter" => :exit
          })
          
          case choice
          when :watch
            handle_interactive_watch(prompt)
          when :generate
            handle_interactive_generate(prompt)
          when :test
            handle_interactive_test(prompt)
          when :report
            handle_interactive_report(prompt)
          when :config
            config
          when :exit
            puts "👋 Au revoir !".colorize(:yellow)
            break
          end
          
          puts "\n" + "="*50 + "\n"
        end
      end

      private

      # Vérifie que c'est un projet Ruby/Rails valide
      def verify_ruby_project!
        unless File.exist?("Gemfile") || Dir.glob("**/*.rb").any?
          puts "❌ Ce ne semble pas être un projet Ruby/Rails valide".colorize(:red)
          exit 1
        end
      end

      # Configure le gem avec les options
      def configure_gem(options)
        Autotest::Agent.configure do |config|
          config.ai_provider = options[:provider].to_sym
          config.ai_model = options[:model]
          config.interactive_mode = options[:interactive]
        end
      end

      # Configure le framework de test
      def setup_test_framework
        config = Autotest::Agent.configuration
        
        if config.test_framework == :rspec && !File.exist?("spec/spec_helper.rb")
          if yes?("RSpec n'est pas configuré. Voulez-vous l'installer ? (y/n)".colorize(:yellow))
            config.setup_rspec!
          end
        end
      end

      # Crée le fichier de configuration
      def create_config_file(options)
        config_content = generate_config_content(options)
        config_file = ".autotest_ia.yml"
        
        if File.exist?(config_file)
          return unless yes?("Fichier de config existant. Écraser ? (y/n)".colorize(:yellow))
        end
        
        File.write(config_file, config_content)
        puts "📝 Configuration sauvée : #{config_file}".colorize(:green)
      end

      # Génère le contenu du fichier de configuration
      def generate_config_content(options)
        <<~YAML
          # Configuration autotest-ia
          ai_provider: #{options[:provider]}
          ai_model: #{options[:model]}
          interactive_mode: #{options[:interactive]}
          auto_run_tests: true
          coverage_threshold: 80
          
          # Chemins à surveiller (relatifs au projet)
          watch_paths:
            - app/models
            - app/controllers
            - app/jobs
            - app/services
            - app/helpers
            - app/mailers
            - lib
          
          # Chemins à exclure
          exclude_paths:
            - tmp
            - log
            - vendor
            - node_modules
            - .git
        YAML
      end

      # Charge la configuration
      def load_configuration(cli_options = {})
        Autotest::Agent.configure do |config|
          # Charge depuis le fichier de config si présent
          load_config_file(config) if File.exist?(".autotest_ia.yml")
          
          # Override avec les options CLI
          config.interactive_mode = cli_options[:interactive] if cli_options.key?(:interactive)
          config.auto_run_tests = cli_options[:auto_run] if cli_options.key?(:auto_run)
        end
      end

      # Charge le fichier de configuration YAML
      def load_config_file(config)
        require "yaml"
        file_config = YAML.load_file(".autotest_ia.yml")
        
        config.ai_provider = file_config["ai_provider"].to_sym if file_config["ai_provider"]
        config.ai_model = file_config["ai_model"] if file_config["ai_model"]
        config.interactive_mode = file_config["interactive_mode"] if file_config.key?("interactive_mode")
        config.auto_run_tests = file_config["auto_run_tests"] if file_config.key?("auto_run_tests")
        config.coverage_threshold = file_config["coverage_threshold"] if file_config["coverage_threshold"]
        config.watch_paths = file_config["watch_paths"] if file_config["watch_paths"]
        config.exclude_paths = file_config["exclude_paths"] if file_config["exclude_paths"]
      end

      # Vérifie la configuration IA
      def verify_ai_configuration!
        config = Autotest::Agent.configuration
        
        unless config.valid?
          puts "❌ Configuration IA invalide :".colorize(:red)
          config.validation_errors.each { |error| puts "  • #{error}" }
          
          if config.ai_provider == :openai && (!config.ai_api_key || config.ai_api_key.empty?)
            puts "\n💡 Pour utiliser OpenAI, définissez votre clé API :".colorize(:yellow)
            puts "   export OPENAI_API_KEY='votre-clé-api'"
          end
          
          exit 1
        end
      end

      # Génère un test en mode interactif
      def generate_interactive_test(file_path)
        generator = AIGenerator.new(Autotest::Agent.configuration)
        generator.generate_interactive(file_path)
      end

      # Détermine le fichier de sortie pour un test
      def determine_output_file(source_file)
        config = Autotest::Agent.configuration
        file_watcher = FileWatcher.new(".", config)
        file_watcher.send(:determine_test_file_path, File.expand_path(source_file), :unknown)
      end

      # Sauvegarde un test généré
      def save_generated_test(output_file, content)
        FileUtils.mkdir_p(File.dirname(output_file))
        File.write(output_file, content)
      end

      # Gestion interactive - surveillance
      def handle_interactive_watch(prompt)
        path = prompt.ask("Chemin à surveiller :", default: ".")
        invoke(:watch, [path])
      end

      # Gestion interactive - génération
      def handle_interactive_generate(prompt)
        file_path = prompt.ask("Chemin du fichier à analyser :")
        return unless file_path && File.exist?(file_path)
        
        invoke(:generate, [file_path], { interactive: true })
      end

      # Gestion interactive - tests
      def handle_interactive_test(prompt)
        choice = prompt.select("Type d'exécution :", {
          "Tous les tests" => :all,
          "Tests spécifiques" => :specific,
          "Mode surveillance" => :watch
        })
        
        case choice
        when :all
          invoke(:test, [])
        when :specific
          files = prompt.ask("Fichiers de test (séparés par des espaces) :").split
          invoke(:test, files)
        when :watch
          invoke(:test, [], { watch: true })
        end
      end

      # Gestion interactive - rapports
      def handle_interactive_report(prompt)
        type = prompt.select("Type de rapport :", {
          "Rapport complet" => "full",
          "Couverture de code" => "coverage",
          "Qualité du code" => "quality",
          "Tendances" => "trend"
        })
        
        invoke(:report, [type])
      end
    end
  end
end 