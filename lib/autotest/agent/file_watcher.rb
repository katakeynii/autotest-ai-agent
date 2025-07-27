# frozen_string_literal: true

require "fileutils"

module Autotest
  module Agent
    # Surveille les changements de fichiers dans l'application Rails
    # et déclenche la génération de tests automatiquement
    # Utilise la gem Listen pour une surveillance efficace des fichiers
    class FileWatcher
      attr_reader :path, :configuration, :listener

      # Initialise le watcher avec le chemin à surveiller et la configuration
      def initialize(path, configuration)
        @path = File.expand_path(path)
        @configuration = configuration
        @listener = nil
        @ai_generator = nil
        @test_runner = nil
      end

      # Démarre la surveillance des fichiers
      def start
        puts "🔍 Démarrage de la surveillance des fichiers...".colorize(:blue)
        puts "📂 Chemin surveillé : #{path}".colorize(:light_blue)
        
        setup_listener
        display_watched_paths
        
        listener.start
        
        puts "✅ Surveillance active ! Appuyez sur Ctrl+C pour arrêter.".colorize(:green)
        
        # Garde le processus en vie
        sleep
      rescue Interrupt
        stop
        puts "\n👋 Surveillance arrêtée.".colorize(:yellow)
      end

      # Arrête la surveillance
      def stop
        listener&.stop
        puts "🛑 Surveillance arrêtée.".colorize(:red)
      end

      private

      # Configure le listener Listen avec les chemins et filtres appropriés
      def setup_listener
        watched_paths = configuration.watch_paths.map { |p| File.join(path, p) }
                                                 .select { |p| File.directory?(p) }

        @listener = Listen.to(*watched_paths) do |modified, added, removed|
          handle_file_changes(modified, added, removed)
        end

        # Configure les filtres
        listener.ignore(build_ignore_patterns)
        listener.only(build_only_patterns)
      end

      # Affiche les chemins surveillés
      def display_watched_paths
        puts "\n📋 Chemins surveillés :".colorize(:cyan)
        configuration.watch_paths.each do |watch_path|
          full_path = File.join(path, watch_path)
          status = File.directory?(full_path) ? "✅" : "❌"
          puts "  #{status} #{watch_path}".colorize(:light_cyan)
        end
        puts ""
      end

      # Gère les changements de fichiers détectés
      def handle_file_changes(modified, added, removed)
        all_changes = (modified + added).uniq
        
        relevant_changes = all_changes.select { |file| relevant_file?(file) }
        
        return if relevant_changes.empty?

        puts "\n🔄 Changements détectés :".colorize(:yellow)
        relevant_changes.each do |file|
          puts "  📝 #{relative_path(file)}".colorize(:light_yellow)
        end

        relevant_changes.each do |file|
          process_file_change(file)
        end
      end

      # Traite le changement d'un fichier spécifique
      def process_file_change(file_path)
        file_type = detect_file_type(file_path)
        return unless file_type

        puts "\n🤖 Génération de tests pour #{relative_path(file_path)} (#{file_type})...".colorize(:cyan)

        begin
          test_content = ai_generator.generate_for_file(file_path, file_type: file_type)
          
          if test_content && !test_content.empty?
            test_file_path = determine_test_file_path(file_path, file_type)
            write_test_file(test_file_path, test_content)
            
            # Exécute les tests si configuré
            run_tests_if_enabled(test_file_path) if configuration.auto_run_tests
          else
            puts "⚠️  Aucun test généré pour #{relative_path(file_path)}".colorize(:yellow)
          end
        rescue => e
          puts "❌ Erreur lors de la génération : #{e.message}".colorize(:red)
        end
      end

      # Détermine si un fichier est pertinent pour la génération de tests
      def relevant_file?(file_path)
        # Vérifie l'extension
        return false unless ruby_file?(file_path)
        
        # Exclut les fichiers de test existants
        return false if test_file?(file_path)
        
        # Exclut les chemins ignorés
        return false if excluded_path?(file_path)
        
        # Vérifie que c'est dans un chemin surveillé
        in_watched_path?(file_path)
      end

      # Vérifie si c'est un fichier Ruby
      def ruby_file?(file_path)
        File.extname(file_path) == ".rb"
      end

      # Vérifie si c'est déjà un fichier de test
      def test_file?(file_path)
        file_path.include?("/spec/") || 
        file_path.include?("/test/") ||
        file_path.end_with?("_spec.rb") ||
        file_path.end_with?("_test.rb")
      end

      # Vérifie si le chemin est exclu
      def excluded_path?(file_path)
        configuration.exclude_paths.any? { |exclude| file_path.include?(exclude) }
      end

      # Vérifie si le fichier est dans un chemin surveillé
      def in_watched_path?(file_path)
        configuration.watch_paths.any? do |watch_path|
          file_path.include?(File.join(path, watch_path))
        end
      end

      # Détecte le type de fichier Rails
      def detect_file_type(file_path)
        case file_path
        when %r{app/models/}
          :model
        when %r{app/controllers/}
          :controller
        when %r{app/jobs/}
          :job
        when %r{app/services/}
          :service
        when %r{app/helpers/}
          :helper
        when %r{app/mailers/}
          :mailer
        when %r{lib/}
          :library
        else
          :unknown
        end
      end

      # Détermine le chemin du fichier de test
      def determine_test_file_path(source_file_path, file_type)
        relative_source = source_file_path.gsub("#{path}/", "")
        
        case configuration.test_framework
        when :rspec
          # app/models/user.rb -> spec/models/user_spec.rb
          test_path = relative_source.gsub(%r{^app/}, "spec/")
                                   .gsub(%r{^lib/}, "spec/lib/")
                                   .gsub(/\.rb$/, "_spec.rb")
        when :minitest
          # app/models/user.rb -> test/models/user_test.rb
          test_path = relative_source.gsub(%r{^app/}, "test/")
                                   .gsub(%r{^lib/}, "test/lib/")
                                   .gsub(/\.rb$/, "_test.rb")
        end

        File.join(path, test_path)
      end

      # Écrit le fichier de test généré
      def write_test_file(test_file_path, content)
        # Crée le répertoire si nécessaire
        FileUtils.mkdir_p(File.dirname(test_file_path))
        
        # Écrit le contenu
        File.write(test_file_path, content)
        
        puts "✅ Test généré : #{relative_path(test_file_path)}".colorize(:green)
      end

      # Exécute les tests si activé
      def run_tests_if_enabled(test_file_path)
        puts "🧪 Exécution des tests...".colorize(:blue)
        test_runner.run([test_file_path])
      end

      # Construit les patterns à ignorer pour Listen
      def build_ignore_patterns
        configuration.exclude_paths.map do |exclude_path|
          %r{#{Regexp.escape(exclude_path)}}
        end
      end

      # Construit les patterns à surveiller uniquement
      def build_only_patterns
        [/\.rb$/] # Seulement les fichiers Ruby
      end

      # Retourne le chemin relatif pour l'affichage
      def relative_path(file_path)
        file_path.gsub("#{path}/", "")
      end

      # Lazy loading du générateur IA
      def ai_generator
        @ai_generator ||= AIGenerator.new(configuration)
      end

      # Lazy loading du runner de tests
      def test_runner
        @test_runner ||= TestRunner.new(configuration)
      end
    end
  end
end 