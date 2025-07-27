# frozen_string_literal: true

module Autotest
  module Agent
    # Générateur de tests utilisant l'IA via langchain.rb
    # Analyse le code source et génère des tests pertinents
    # selon le contexte métier et les meilleures pratiques
    class AIGenerator
      attr_reader :configuration, :llm

      # Initialise le générateur avec la configuration
      def initialize(configuration)
        @configuration = configuration
        @llm = setup_llm
        @context_cache = {}
      end

      # Génère un test pour un fichier donné
      def generate_for_file(file_path, file_type: nil, context: nil)
        raise AIGenerationError, "Fichier non trouvé : #{file_path}" unless File.exist?(file_path)
        
        file_type ||= detect_file_type(file_path)
        return nil if file_type == :unknown

        puts "🧠 Analyse du fichier avec l'IA...".colorize(:magenta)
        
        begin
          # Lit le contenu du fichier
          file_content = File.read(file_path)
          
          # Prépare le contexte
          full_context = build_context(file_path, context)
          
          # Génère le test
          test_content = generate_test(file_content, file_type, full_context)
          
          # Post-traite le contenu généré
          clean_and_validate_test(test_content, file_type)
          
        rescue => e
          raise AIGenerationError, "Erreur lors de la génération IA : #{e.message}"
        end
      end

      # Génère un test interactif avec contexte utilisateur
      def generate_interactive(file_path, user_context = nil)
        file_type = detect_file_type(file_path)
        
        if configuration.interactive_mode
          user_context = collect_user_context(file_path, file_type) unless user_context
        end
        
        generate_for_file(file_path, file_type: file_type, context: user_context)
      end

      # Améliore un test existant
      def improve_existing_test(test_file_path, source_file_path, improvement_notes = nil)
        return nil unless File.exist?(test_file_path) && File.exist?(source_file_path)

        existing_test = File.read(test_file_path)
        source_code = File.read(source_file_path)
        file_type = detect_file_type(source_file_path)
        
        prompt = build_improvement_prompt(existing_test, source_code, file_type, improvement_notes)
        
        improved_content = llm.chat(messages: [
          { role: "system", content: configuration.prompt_templates[file_type][:system] },
          { role: "user", content: prompt }
        ]).dig("choices", 0, "message", "content")

        clean_and_validate_test(improved_content, file_type)
      end

      private

      # Configure le LLM selon le provider choisi
      def setup_llm
        case configuration.ai_provider
        when :openai
          setup_openai_llm
        when :ollama
          setup_ollama_llm
        else
          raise ConfigurationError, "Provider IA non supporté : #{configuration.ai_provider}"
        end
      end

      # Configure OpenAI via langchain
      def setup_openai_llm
        raise ConfigurationError, "Clé API OpenAI manquante" unless configuration.ai_api_key

        Langchain::LLM::OpenAI.new(
          api_key: configuration.ai_api_key,
          default_options: {
            model: configuration.ai_model,
            temperature: 0.3, # Plus bas pour plus de cohérence
            max_tokens: 2000
          }
        )
      end

      # Configure Ollama local via langchain
      def setup_ollama_llm
        Langchain::LLM::Ollama.new(
          url: "http://localhost:11434",
          default_options: {
            model: configuration.ai_model || "codellama",
            temperature: 0.3
          }
        )
      end

      # Détecte le type de fichier pour les prompts appropriés
      def detect_file_type(file_path)
        case file_path
        when %r{app/models/.*\.rb$}
          :model
        when %r{app/controllers/.*\.rb$}
          :controller
        when %r{app/jobs/.*\.rb$}
          :job
        when %r{app/services/.*\.rb$}
          :service
        when %r{app/helpers/.*\.rb$}
          :helper
        when %r{app/mailers/.*\.rb$}
          :mailer
        when %r{lib/.*\.rb$}
          :library
        else
          :unknown
        end
      end

      # Construit le contexte complet pour la génération
      def build_context(file_path, user_context)
        context_parts = []
        
        # Contexte utilisateur
        context_parts << user_context if user_context && !user_context.empty?
        
        # Contexte du projet (migrations, autres modèles, etc.)
        project_context = analyze_project_context(file_path)
        context_parts << project_context if project_context
        
        # Contexte des fichiers liés
        related_context = analyze_related_files(file_path)
        context_parts << related_context if related_context
        
        context_parts.join("\n\n")
      end

      # Analyse le contexte du projet Rails
      def analyze_project_context(file_path)
        return @context_cache[:project] if @context_cache[:project]

        context_parts = []
        
        # Analyse les migrations récentes si c'est un modèle
        if file_path.include?("/app/models/")
          context_parts << analyze_recent_migrations
        end
        
        # Analyse les routes si c'est un contrôleur
        if file_path.include?("/app/controllers/")
          context_parts << analyze_routes
        end
        
        @context_cache[:project] = context_parts.compact.join("\n")
      end

      # Analyse les fichiers liés (associations, héritages, etc.)
      def analyze_related_files(file_path)
        return nil unless File.exist?(file_path)
        
        content = File.read(file_path)
        related_files = []
        
        # Trouve les associations/héritages dans le code
        content.scan(/(?:belongs_to|has_many|has_one|inherits_from|include|extend)\s+[:\w]+/) do |match|
          # Logique pour trouver les fichiers liés (simplifié pour l'exemple)
          related_files << match
        end
        
        related_files.empty? ? nil : "Éléments liés détectés : #{related_files.join(', ')}"
      end

      # Analyse les migrations récentes
      def analyze_recent_migrations
        migration_dir = File.join(configuration.rails_app_path, "db", "migrate")
        return nil unless File.directory?(migration_dir)
        
        recent_migrations = Dir.glob("#{migration_dir}/*.rb")
                              .sort
                              .last(3)
                              .map { |f| File.basename(f) }
        
        recent_migrations.empty? ? nil : "Migrations récentes : #{recent_migrations.join(', ')}"
      end

      # Analyse le fichier routes.rb
      def analyze_routes
        routes_file = File.join(configuration.rails_app_path, "config", "routes.rb")
        return nil unless File.exist?(routes_file)
        
        "Fichier routes.rb disponible pour analyse des endpoints"
      end

      # Génère le test avec l'IA
      def generate_test(file_content, file_type, context)
        template = configuration.prompt_templates[file_type]
        return nil unless template

        # Formate le prompt utilisateur
        user_prompt = template[:user] % {
          code: file_content,
          context: context.empty? ? "Aucun contexte spécifique fourni" : context
        }

        # Appel à l'IA
        response = llm.chat(messages: [
          { role: "system", content: template[:system] },
          { role: "user", content: user_prompt }
        ])

        response.dig("choices", 0, "message", "content")
      end

      # Collecte le contexte utilisateur de manière interactive
      def collect_user_context(file_path, file_type)
        prompt = TTY::Prompt.new
        
        puts "\n📝 Configuration du contexte métier pour #{File.basename(file_path)}".colorize(:cyan)
        
        context_parts = []
        
        # Questions spécifiques au type de fichier
        case file_type
        when :model
          context_parts << ask_model_context(prompt)
        when :controller
          context_parts << ask_controller_context(prompt)
        when :service
          context_parts << ask_service_context(prompt)
        else
          context_parts << ask_general_context(prompt)
        end
        
        context_parts.compact.join("\n")
      end

      # Questions pour les modèles
      def ask_model_context(prompt)
        context = []
        
        context << prompt.ask("Quel est le rôle métier de ce modèle ?", default: "")
        
        if prompt.yes?("Y a-t-il des règles métier spécifiques à tester ?")
          context << prompt.ask("Décrivez les règles métier importantes :")
        end
        
        if prompt.yes?("Y a-t-il des cas limites particuliers ?")
          context << prompt.ask("Décrivez les cas limites :")
        end
        
        context.compact.join("\n")
      end

      # Questions pour les contrôleurs
      def ask_controller_context(prompt)
        context = []
        
        context << prompt.ask("Quel est le rôle de ce contrôleur ?", default: "")
        
        if prompt.yes?("Y a-t-il des permissions/autorisations spécifiques ?")
          context << prompt.ask("Décrivez les règles d'autorisation :")
        end
        
        context.compact.join("\n")
      end

      # Questions pour les services
      def ask_service_context(prompt)
        context = []
        
        context << prompt.ask("Que fait ce service métier ?", default: "")
        context << prompt.ask("Quels sont les cas d'erreur à prévoir ?", default: "")
        
        context.compact.join("\n")
      end

      # Questions générales
      def ask_general_context(prompt)
        prompt.ask("Contexte métier ou notes particulières pour les tests :", default: "")
      end

      # Construit le prompt d'amélioration de test
      def build_improvement_prompt(existing_test, source_code, file_type, notes)
        base_prompt = <<~PROMPT
          Améliore ce test existant en tenant compte du code source mis à jour :

          CODE SOURCE :
          #{source_code}

          TEST EXISTANT :
          #{existing_test}
        PROMPT

        if notes && !notes.empty?
          base_prompt += "\n\nNOTES D'AMÉLIORATION :\n#{notes}"
        end

        base_prompt += "\n\nGénère une version améliorée du test qui :"
        base_prompt += "\n- Couvre mieux le code"
        base_prompt += "\n- Suit les meilleures pratiques #{configuration.test_framework}"
        base_prompt += "\n- Inclut des cas limites pertinents"
        base_prompt += "\n- Maintient ou améliore la lisibilité"

        base_prompt
      end

      # Nettoie et valide le contenu généré
      def clean_and_validate_test(content, file_type)
        return nil if content.nil? || content.empty?

        # Supprime les balises markdown si présentes
        cleaned_content = content.gsub(/```ruby\n?/, '').gsub(/```\n?/, '').strip
        
        # Ajoute les requires nécessaires si manquants
        cleaned_content = add_required_headers(cleaned_content, file_type)
        
        # Valide la syntaxe Ruby de base
        validate_ruby_syntax(cleaned_content)
        
        cleaned_content
      end

      # Ajoute les headers nécessaires au fichier de test
      def add_required_headers(content, file_type)
        headers = []
        
        # Header frozen_string_literal
        headers << "# frozen_string_literal: true" unless content.include?("frozen_string_literal")
        
        # Require du helper approprié
        case configuration.test_framework
        when :rspec
          # Détection de contenu Rails
          rails_indicators = [
            "Rails", "ApplicationRecord", "ActionController", "ActionMailer",
            "should validate_", "shoulda-matchers", "ActiveRecord", 
            "have_db_column", "have_many", "belong_to", "validates_"
          ]
          is_rails_test = rails_indicators.any? { |indicator| content.include?(indicator) }
          
          # Les types de fichiers Rails utilisent rails_helper par défaut
          rails_file_types = [:model, :controller, :job, :service, :helper, :mailer]
          is_rails_file = rails_file_types.include?(file_type)
          
          if (is_rails_test || is_rails_file) && !content.include?("rails_helper")
            headers << "\nrequire 'rails_helper'"
          elsif !is_rails_test && !is_rails_file && !content.include?("spec_helper") && !content.include?("rails_helper")
            headers << "\nrequire 'spec_helper'"
          end
        when :minitest
          headers << "\nrequire 'test_helper'" unless content.include?("test_helper")
        end
        
        if headers.any?
          "#{headers.join("\n")}\n\n#{content}"
        else
          content
        end
      end

      # Validation basique de la syntaxe Ruby
      def validate_ruby_syntax(content)
        # Tentative de parsing pour détecter les erreurs de syntaxe évidentes
        begin
          RubyVM::InstructionSequence.compile(content)
        rescue SyntaxError => e
          puts "⚠️  Attention : Possible erreur de syntaxe détectée : #{e.message}".colorize(:yellow)
        end
        
        true
      end
    end
  end
end 