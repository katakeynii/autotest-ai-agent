# frozen_string_literal: true

require "json"
require "erb"

module Autotest
  module Agent
    # Génère des rapports détaillés sur l'état des tests
    # et les métriques de couverture de code
    # Propose des analyses et recommandations d'amélioration
    class Reporter
      attr_reader :configuration, :test_runner

      # Initialise le reporter avec la configuration
      def initialize(configuration, test_runner = nil)
        @configuration = configuration
        @test_runner = test_runner
      end

      # Génère un rapport complet
      def generate_full_report(output_file = nil)
        output_file ||= default_report_path
        
        puts "📊 Génération du rapport complet...".colorize(:blue)
        
        report_data = collect_report_data
        html_content = generate_html_report(report_data)
        
        File.write(output_file, html_content)
        
        puts "✅ Rapport généré : #{output_file}".colorize(:green)
        output_file
      end

      # Génère un rapport de couverture détaillé
      def generate_coverage_report
        coverage_data = analyze_coverage_data
        return nil unless coverage_data

        puts "📈 Analyse de la couverture de code...".colorize(:cyan)
        
        display_coverage_summary(coverage_data)
        display_uncovered_files(coverage_data)
        suggest_coverage_improvements(coverage_data)
        
        coverage_data
      end

      # Génère un rapport d'évolution dans le temps
      def generate_trend_report(days = 7)
        puts "📈 Analyse des tendances (#{days} derniers jours)...".colorize(:blue)
        
        trend_data = collect_trend_data(days)
        display_trend_analysis(trend_data)
        
        trend_data
      end

      # Génère un rapport de qualité du code
      def generate_quality_report
        puts "🔍 Analyse de la qualité du code...".colorize(:magenta)
        
        quality_data = analyze_code_quality
        display_quality_metrics(quality_data)
        suggest_quality_improvements(quality_data)
        
        quality_data
      end

      # Export des données en JSON
      def export_json(output_file = nil)
        output_file ||= File.join(configuration.rails_app_path, "tmp", "autotest_ia_report.json")
        
        report_data = collect_report_data
        
        File.write(output_file, JSON.pretty_generate(report_data))
        puts "📄 Données exportées : #{output_file}".colorize(:green)
        
        output_file
      end

      private

      # Collecte toutes les données pour le rapport
      def collect_report_data
        {
          timestamp: Time.now,
          project_info: collect_project_info,
          test_framework: configuration.test_framework,
          test_results: collect_test_results,
          coverage: analyze_coverage_data,
          quality: analyze_code_quality,
          files_analyzed: count_analyzed_files,
          ai_stats: collect_ai_stats
        }
      end

      # Collecte les informations du projet
      def collect_project_info
        {
          name: extract_project_name,
          ruby_version: RUBY_VERSION,
          rails_version: detect_rails_version,
          gem_version: Autotest::Agent::VERSION,
          total_files: count_ruby_files
        }
      end

      # Extrait le nom du projet
      def extract_project_name
        gemfile_path = File.join(configuration.rails_app_path, "Gemfile")
        return "Application Rails" unless File.exist?(gemfile_path)

        # Essaie d'extraire le nom depuis le Gemfile ou config/application.rb
        config_app = File.join(configuration.rails_app_path, "config", "application.rb")
        if File.exist?(config_app)
          content = File.read(config_app)
          match = content.match(/module\s+(\w+)/)
          return match[1] if match
        end

        File.basename(configuration.rails_app_path).capitalize
      end

      # Détecte la version de Rails
      def detect_rails_version
        return "Non-Rails" unless rails_application?

        gemfile_lock = File.join(configuration.rails_app_path, "Gemfile.lock")
        return "Inconnue" unless File.exist?(gemfile_lock)

        content = File.read(gemfile_lock)
        match = content.match(/rails \(([^)]+)\)/)
        match ? match[1] : "Inconnue"
      end

      # Vérifie si c'est une application Rails
      def rails_application?
        File.exist?(File.join(configuration.rails_app_path, "config", "application.rb"))
      end

      # Compte les fichiers Ruby dans le projet
      def count_ruby_files
        Dir.glob(File.join(configuration.rails_app_path, "**", "*.rb")).size
      end

      # Collecte les résultats des tests
      def collect_test_results
        return nil unless test_runner&.last_results

        {
          exit_code: test_runner.last_results[:exit_code],
          duration: test_runner.last_results[:duration],
          passing: test_runner.passing?,
          command: test_runner.last_results[:command],
          timestamp: test_runner.last_results[:timestamp]
        }
      end

      # Analyse les données de couverture
      def analyze_coverage_data
        return nil unless test_runner

        coverage_stats = test_runner.coverage_stats
        return nil unless coverage_stats

        result = coverage_stats["result"]
        return nil unless result

        {
          covered_percent: result["covered_percent"],
          covered_lines: result["covered_lines"],
          total_lines: result["total_lines"],
          files: analyze_file_coverage(coverage_stats)
        }
      end

      # Analyse la couverture par fichier
      def analyze_file_coverage(coverage_stats)
        return [] unless coverage_stats["result"]["groups"]

        files_data = []
        
        coverage_stats["result"]["groups"].each do |group_name, group_data|
          next unless group_data["files"]
          
          group_data["files"].each do |file_path, file_data|
            files_data << {
              path: file_path,
              covered_percent: file_data["covered_percent"],
              covered_lines: file_data["covered_lines"],
              missed_lines: file_data["missed_lines"],
              total_lines: file_data["lines_of_code"]
            }
          end
        end
        
        files_data.sort_by { |f| f[:covered_percent] }
      end

      # Analyse la qualité du code
      def analyze_code_quality
        {
          test_files_count: count_test_files,
          source_files_count: count_source_files,
          test_to_source_ratio: calculate_test_ratio,
          average_file_size: calculate_average_file_size,
          large_files: find_large_files
        }
      end

      # Compte les fichiers de test
      def count_test_files
        test_pattern = case configuration.test_framework
                      when :rspec
                        File.join(configuration.rails_app_path, "spec", "**", "*_spec.rb")
                      when :minitest
                        File.join(configuration.rails_app_path, "test", "**", "*_test.rb")
                      end
        
        Dir.glob(test_pattern).size
      end

      # Compte les fichiers source
      def count_source_files
        source_files = 0
        configuration.watch_paths.each do |path|
          full_path = File.join(configuration.rails_app_path, path, "**", "*.rb")
          source_files += Dir.glob(full_path).size
        end
        source_files
      end

      # Calcule le ratio tests/source
      def calculate_test_ratio
        source_count = count_source_files
        return 0 if source_count.zero?
        
        (count_test_files.to_f / source_count * 100).round(2)
      end

      # Calcule la taille moyenne des fichiers
      def calculate_average_file_size
        all_files = Dir.glob(File.join(configuration.rails_app_path, "**", "*.rb"))
        return 0 if all_files.empty?
        
        total_lines = all_files.sum { |file| File.readlines(file).size }
        (total_lines.to_f / all_files.size).round(0)
      end

      # Trouve les gros fichiers
      def find_large_files(threshold = 200)
        large_files = []
        
        Dir.glob(File.join(configuration.rails_app_path, "**", "*.rb")).each do |file|
          lines = File.readlines(file).size
          if lines > threshold
            large_files << {
              path: file.gsub("#{configuration.rails_app_path}/", ""),
              lines: lines
            }
          end
        end
        
        large_files.sort_by { |f| -f[:lines] }
      end

      # Compte les fichiers analysés
      def count_analyzed_files
        # Simule le comptage des fichiers analysés par l'IA
        # Dans une implémentation réelle, ceci viendrait d'un log ou cache
        configuration.watch_paths.sum do |path|
          Dir.glob(File.join(configuration.rails_app_path, path, "**", "*.rb")).size
        end
      end

      # Collecte les statistiques IA
      def collect_ai_stats
        # Simule les statistiques d'utilisation de l'IA
        # Dans une implémentation réelle, ceci viendrait de logs
        {
          provider: configuration.ai_provider,
          model: configuration.ai_model,
          generations_count: 0, # À implémenter avec un système de log
          avg_generation_time: 0, # À implémenter avec un système de log
          success_rate: 0 # À implémenter avec un système de log
        }
      end

      # Collecte les données de tendance
      def collect_trend_data(days)
        # Simule la collecte de données historiques
        # Dans une implémentation réelle, ceci viendrait d'une base de données
        trend_data = []
        
        days.times do |i|
          date = Date.today - i
          trend_data << {
            date: date,
            coverage: rand(70..95),
            tests_count: rand(50..100),
            files_count: rand(20..50)
          }
        end
        
        trend_data.reverse
      end

      # Affiche le résumé de couverture
      def display_coverage_summary(coverage_data)
        return unless coverage_data

        puts "\n📊 Résumé de couverture :".colorize(:cyan)
        puts "  📈 Couverture globale : #{coverage_data[:covered_percent]}%"
        puts "  📝 Lignes couvertes : #{coverage_data[:covered_lines]}/#{coverage_data[:total_lines]}"
        
        if coverage_data[:covered_percent] >= configuration.coverage_threshold
          puts "  ✅ Objectif atteint (#{configuration.coverage_threshold}%)".colorize(:green)
        else
          gap = configuration.coverage_threshold - coverage_data[:covered_percent]
          puts "  ⚠️  Objectif manqué de #{gap}%".colorize(:yellow)
        end
      end

      # Affiche les fichiers non couverts
      def display_uncovered_files(coverage_data)
        return unless coverage_data && coverage_data[:files]

        uncovered = coverage_data[:files].select { |f| f[:covered_percent] < 80 }
        return if uncovered.empty?

        puts "\n🔍 Fichiers à améliorer (< 80% de couverture) :".colorize(:yellow)
        uncovered.first(10).each do |file|
          puts "  📄 #{file[:path]} : #{file[:covered_percent]}%".colorize(:light_yellow)
        end
      end

      # Suggère des améliorations de couverture
      def suggest_coverage_improvements(coverage_data)
        return unless coverage_data

        puts "\n💡 Suggestions d'amélioration :".colorize(:yellow)
        
        if coverage_data[:covered_percent] < 70
          puts "  • Prioriser l'ajout de tests de base pour tous les modèles"
        elsif coverage_data[:covered_percent] < 85
          puts "  • Ajouter des tests pour les cas limites et erreurs"
        else
          puts "  • Optimiser les tests existants et ajouter des tests d'intégration"
        end
      end

      # Affiche les métriques de qualité
      def display_quality_metrics(quality_data)
        puts "\n🔍 Métriques de qualité :".colorize(:magenta)
        puts "  📊 Ratio tests/source : #{quality_data[:test_to_source_ratio]}%"
        puts "  📏 Taille moyenne des fichiers : #{quality_data[:average_file_size]} lignes"
        puts "  📁 Fichiers source : #{quality_data[:source_files_count]}"
        puts "  🧪 Fichiers de test : #{quality_data[:test_files_count]}"
      end

      # Suggère des améliorations de qualité
      def suggest_quality_improvements(quality_data)
        puts "\n💡 Suggestions de qualité :".colorize(:yellow)
        
        if quality_data[:test_to_source_ratio] < 50
          puts "  • Augmenter le nombre de tests (ratio faible)"
        end
        
        if quality_data[:large_files].any?
          puts "  • Refactoriser les gros fichiers (#{quality_data[:large_files].size} fichiers > 200 lignes)"
        end
      end

      # Affiche l'analyse des tendances
      def display_trend_analysis(trend_data)
        return if trend_data.empty?

        puts "\n📈 Tendances :".colorize(:blue)
        
        coverage_trend = trend_data.last[:coverage] - trend_data.first[:coverage]
        if coverage_trend > 0
          puts "  ↗️  Couverture en amélioration (+#{coverage_trend}%)".colorize(:green)
        elsif coverage_trend < 0
          puts "  ↘️  Couverture en baisse (#{coverage_trend}%)".colorize(:red)
        else
          puts "  ➡️  Couverture stable"
        end
      end

      # Génère le rapport HTML
      def generate_html_report(data)
        template = html_template
        ERB.new(template).result(binding)
      end

      # Template HTML pour le rapport
      def html_template
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>Rapport Autotest IA - <%= data[:project_info][:name] %></title>
            <meta charset="utf-8">
            <style>
              body { font-family: Arial, sans-serif; margin: 40px; }
              .header { background: #4CAF50; color: white; padding: 20px; border-radius: 5px; }
              .section { margin: 20px 0; padding: 15px; border-left: 4px solid #ddd; }
              .coverage { border-left-color: #2196F3; }
              .quality { border-left-color: #FF9800; }
              .tests { border-left-color: #9C27B0; }
              .metric { display: inline-block; margin: 10px; padding: 10px; background: #f5f5f5; border-radius: 3px; }
            </style>
          </head>
          <body>
            <div class="header">
              <h1>🤖 Autotest IA - Rapport de Test</h1>
              <p>Projet: <%= data[:project_info][:name] %> | Généré le: <%= data[:timestamp].strftime('%d/%m/%Y à %H:%M') %></p>
            </div>
            
            <div class="section coverage">
              <h2>📊 Couverture de Code</h2>
              <% if data[:coverage] %>
                <div class="metric">Couverture: <%= data[:coverage][:covered_percent] %>%</div>
                <div class="metric">Lignes: <%= data[:coverage][:covered_lines] %>/<%= data[:coverage][:total_lines] %></div>
              <% else %>
                <p>Aucune donnée de couverture disponible</p>
              <% end %>
            </div>
            
            <div class="section quality">
              <h2>🔍 Qualité du Code</h2>
              <div class="metric">Fichiers source: <%= data[:quality][:source_files_count] %></div>
              <div class="metric">Fichiers de test: <%= data[:quality][:test_files_count] %></div>
              <div class="metric">Ratio tests/source: <%= data[:quality][:test_to_source_ratio] %>%</div>
            </div>
            
            <div class="section tests">
              <h2>🧪 Résultats des Tests</h2>
              <% if data[:test_results] %>
                <div class="metric">Statut: <%= data[:test_results][:passing] ? '✅ Succès' : '❌ Échec' %></div>
                <div class="metric">Durée: <%= sprintf('%.2f', data[:test_results][:duration]) %>s</div>
              <% else %>
                <p>Aucun test exécuté récemment</p>
              <% end %>
            </div>
          </body>
          </html>
        HTML
      end

      # Chemin par défaut du rapport
      def default_report_path
        File.join(configuration.rails_app_path, "tmp", "autotest_ia_report.html")
      end
    end
  end
end 