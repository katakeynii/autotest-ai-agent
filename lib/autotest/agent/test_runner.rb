# frozen_string_literal: true

require "open3"
require "json"

module Autotest
  module Agent
    # Exécute les tests et gère les résultats
    # Supporte RSpec et Minitest avec reporting détaillé
    # Intègre SimpleCov pour la couverture de code
    class TestRunner
      attr_reader :configuration, :last_results

      # Initialise le runner avec la configuration
      def initialize(configuration)
        @configuration = configuration
        @last_results = nil
      end

      # Exécute les tests spécifiés
      def run(test_files = nil, options = {})
        test_files = normalize_test_files(test_files)
        
        return run_all_tests(options) if test_files.nil? || test_files.empty?
        
        puts "🧪 Exécution des tests...".colorize(:blue)
        display_test_files(test_files)
        
        case configuration.test_framework
        when :rspec
          run_rspec(test_files, options)
        when :minitest
          run_minitest(test_files, options)
        else
          raise TestFrameworkError, "Framework de test non supporté : #{configuration.test_framework}"
        end
      end

      # Exécute tous les tests du projet
      def run_all_tests(options = {})
        puts "🧪 Exécution de tous les tests...".colorize(:blue)
        
        case configuration.test_framework
        when :rspec
          run_rspec([], options.merge(all: true))
        when :minitest
          run_minitest([], options.merge(all: true))
        end
      end

      # Exécute les tests en mode watch (continu)
      def run_in_watch_mode
        puts "🔄 Mode surveillance des tests activé".colorize(:green)
        
        loop do
          run_all_tests(watch_mode: true)
          
          puts "\n⏱️  En attente de changements... (Ctrl+C pour arrêter)".colorize(:yellow)
          sleep 2
        end
      rescue Interrupt
        puts "\n👋 Mode surveillance arrêté.".colorize(:yellow)
      end

      # Analyse les résultats du dernier run
      def analyze_results
        return unless @last_results

        puts "\n📊 Analyse des résultats :".colorize(:cyan)
        
        display_summary
        display_failures if has_failures?
        display_coverage_info
        suggest_improvements
      end

      # Vérifie si les tests passent
      def passing?
        @last_results && @last_results[:exit_code] == 0
      end

      # Vérifie s'il y a des échecs
      def has_failures?
        @last_results && @last_results[:exit_code] != 0
      end

      # Retourne les statistiques de couverture
      def coverage_stats
        coverage_file = File.join(configuration.rails_app_path, "coverage", ".last_run.json")
        return nil unless File.exist?(coverage_file)

        JSON.parse(File.read(coverage_file))
      rescue JSON::ParserError
        nil
      end

      private

      # Normalise la liste des fichiers de test
      def normalize_test_files(test_files)
        return nil if test_files.nil?
        
        Array(test_files).select { |file| File.exist?(file) }
      end

      # Affiche les fichiers de test à exécuter
      def display_test_files(test_files)
        puts "📋 Fichiers de test :".colorize(:light_blue)
        test_files.each do |file|
          relative_path = file.gsub("#{configuration.rails_app_path}/", "")
          puts "  • #{relative_path}".colorize(:light_blue)
        end
        puts ""
      end

      # Exécute RSpec
      def run_rspec(test_files, options = {})
        command_parts = ["bundle", "exec", "rspec"]
        
        # Ajoute les fichiers spécifiques ou utilise le répertoire par défaut
        if options[:all] || test_files.empty?
          command_parts << "spec"
        else
          command_parts.concat(test_files)
        end
        
        # Options de formatage
        unless options[:watch_mode]
          command_parts << "--format" << "documentation"
          command_parts << "--color"
        end
        
        # Active la couverture de code
        env = { "COVERAGE" => "true" }
        
        execute_command(command_parts, env, options)
      end

      # Exécute Minitest
      def run_minitest(test_files, options = {})
        command_parts = ["bundle", "exec", "rails", "test"]
        
        # Ajoute les fichiers spécifiques
        unless options[:all] || test_files.empty?
          command_parts.concat(test_files)
        end
        
        # Options de formatage
        command_parts << "--verbose" unless options[:watch_mode]
        
        # Active la couverture de code
        env = { "COVERAGE" => "true" }
        
        execute_command(command_parts, env, options)
      end

      # Exécute la commande et capture les résultats
      def execute_command(command_parts, env = {}, options = {})
        command = command_parts.join(" ")
        
        puts "🚀 Commande : #{command}".colorize(:light_black) unless options[:quiet]
        
        start_time = Time.now
        stdout, stderr, status = Open3.capture3(env, command, chdir: configuration.rails_app_path)
        end_time = Time.now
        
        # Stocke les résultats
        @last_results = {
          command: command,
          stdout: stdout,
          stderr: stderr,
          exit_code: status.exitstatus,
          duration: end_time - start_time,
          timestamp: end_time
        }
        
        # Affiche les résultats
        display_test_output(stdout, stderr, options)
        display_execution_summary(status.exitstatus, end_time - start_time)
        
        @last_results
      end

      # Affiche la sortie des tests
      def display_test_output(stdout, stderr, options = {})
        unless options[:quiet]
          puts stdout if stdout && !stdout.empty?
          puts stderr.colorize(:red) if stderr && !stderr.empty?
        end
      end

      # Affiche le résumé d'exécution
      def display_execution_summary(exit_code, duration)
        duration_str = "%.2f secondes" % duration
        
        if exit_code == 0
          puts "\n✅ Tests réussis en #{duration_str}".colorize(:green)
        else
          puts "\n❌ Tests échoués en #{duration_str}".colorize(:red)
        end
      end

      # Affiche le résumé des résultats
      def display_summary
        return unless @last_results

        puts "📈 Résumé d'exécution :".colorize(:white)
        puts "  ⏱️  Durée : #{sprintf('%.2f', @last_results[:duration])} secondes"
        puts "  📅 Heure : #{@last_results[:timestamp].strftime('%H:%M:%S')}"
        
        if passing?
          puts "  ✅ Statut : SUCCÈS".colorize(:green)
        else
          puts "  ❌ Statut : ÉCHEC".colorize(:red)
        end
      end

      # Affiche les détails des échecs
      def display_failures
        return unless @last_results && @last_results[:stderr]

        puts "\n🔍 Détails des échecs :".colorize(:red)
        failures = extract_failures_from_output(@last_results[:stdout], @last_results[:stderr])
        
        failures.each_with_index do |failure, index|
          puts "\n#{index + 1}. #{failure}".colorize(:light_red)
        end
      end

      # Extrait les échecs de la sortie
      def extract_failures_from_output(stdout, stderr)
        failures = []
        
        # Pour RSpec
        if configuration.test_framework == :rspec
          # Recherche les sections "Failures:"
          failure_section = stdout.match(/Failures:\n\n(.+?)(?=\n\n|\Z)/m)
          if failure_section
            failures = failure_section[1].split(/\n\n/).map(&:strip)
          end
        end
        
        # Pour Minitest
        if configuration.test_framework == :minitest
          # Recherche les lignes d'erreur
          failures = stdout.scan(/^\s*\d+\)\s*(.+)$/).flatten
        end
        
        # Ajoute les erreurs stderr si pertinentes
        if stderr && !stderr.empty?
          failures << "Erreurs système : #{stderr.strip}"
        end
        
        failures
      end

      # Affiche les informations de couverture
      def display_coverage_info
        stats = coverage_stats
        return unless stats

        puts "\n📊 Couverture de code :".colorize(:cyan)
        
        if stats["result"] && stats["result"]["covered_percent"]
          coverage_percent = stats["result"]["covered_percent"]
          
          if coverage_percent >= configuration.coverage_threshold
            puts "  ✅ #{coverage_percent}% (seuil : #{configuration.coverage_threshold}%)".colorize(:green)
          else
            puts "  ⚠️  #{coverage_percent}% (seuil : #{configuration.coverage_threshold}%)".colorize(:yellow)
          end
        end
        
        coverage_path = File.join(configuration.rails_app_path, "coverage", "index.html")
        if File.exist?(coverage_path)
          puts "  📄 Rapport détaillé : #{coverage_path}"
        end
      end

      # Suggère des améliorations
      def suggest_improvements
        return if passing?

        puts "\n💡 Suggestions d'amélioration :".colorize(:yellow)
        
        suggestions = []
        
        # Suggestions basées sur la couverture
        stats = coverage_stats
        if stats && stats["result"] && stats["result"]["covered_percent"]
          coverage = stats["result"]["covered_percent"]
          if coverage < configuration.coverage_threshold
            suggestions << "Améliorer la couverture de code (actuellement #{coverage}%)"
          end
        end
        
        # Suggestions basées sur les échecs
        if @last_results && @last_results[:stderr]
          if @last_results[:stderr].include?("syntax error")
            suggestions << "Corriger les erreurs de syntaxe"
          end
          
          if @last_results[:stderr].include?("NameError")
            suggestions << "Vérifier les dépendances et les requires"
          end
        end
        
        # Suggestions générales
        suggestions << "Relancer la génération IA avec plus de contexte" if has_failures?
        suggestions << "Vérifier les factory_bot et fixtures" if @last_results[:stdout]&.include?("factory")
        
        suggestions.each_with_index do |suggestion, index|
          puts "  #{index + 1}. #{suggestion}"
        end
        
        if suggestions.empty?
          puts "  Aucune suggestion automatique disponible."
        end
      end
    end
  end
end 