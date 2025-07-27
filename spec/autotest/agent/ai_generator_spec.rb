# frozen_string_literal: true

RSpec.describe Autotest::Agent::AIGenerator, type: :unit do
  let(:configuration) { test_configuration }
  subject(:ai_generator) { described_class.new(configuration) }

  let(:mock_llm) { instance_double(Langchain::LLM::OpenAI) }
  let(:user_model_path) { create_test_model("user") }
  let(:sample_response) do
    {
      "choices" => [{
        "message" => {
          "content" => sample_generated_test
        }
      }]
    }
  end

  before do
    allow(Langchain::LLM::OpenAI).to receive(:new).and_return(mock_llm)
    allow(mock_llm).to receive(:chat).and_return(sample_response)
  end

  describe "#initialize" do
    it "stores the configuration" do
      expect(ai_generator.configuration).to eq(configuration)
    end

    it "sets up the LLM" do
      expect(ai_generator.llm).to eq(mock_llm)
    end

    it "initializes context cache" do
      expect(ai_generator.instance_variable_get(:@context_cache)).to eq({})
    end
  end

  describe "#generate_for_file" do
    let(:file_content) do
      <<~RUBY
        class User < ApplicationRecord
          validates :email, presence: true
        end
      RUBY
    end

    before do
      File.write(user_model_path, file_content)
      allow($stdout).to receive(:puts) # Silence output
    end

    it "raises error for non-existent file" do
      expect {
        ai_generator.generate_for_file("non_existent.rb")
      }.to raise_error(Autotest::Agent::AIGenerationError, /Fichier non trouvé/)
    end

    it "returns nil for unknown file type" do
      unknown_file = create_test_file("config/application.rb", "# config")
      result = ai_generator.generate_for_file(unknown_file)
      expect(result).to be_nil
    end

    it "reads file content" do
      expect(File).to receive(:read).with(user_model_path).and_call_original
      
      ai_generator.generate_for_file(user_model_path, file_type: :model)
    end

    it "calls generate_test with correct parameters" do
      expect(ai_generator).to receive(:generate_test)
        .with(file_content, :model, kind_of(String))
        .and_return(sample_generated_test)
      
      ai_generator.generate_for_file(user_model_path, file_type: :model)
    end

    it "cleans and validates the generated test" do
      expect(ai_generator).to receive(:clean_and_validate_test)
        .with(sample_generated_test, :model)
        .and_call_original
      
      ai_generator.generate_for_file(user_model_path, file_type: :model)
    end

    it "returns cleaned test content" do
      result = ai_generator.generate_for_file(user_model_path, file_type: :model)
      
      expect(result).to include("# frozen_string_literal: true")
      expect(result).to include("require 'rails_helper'")
      expect(result).to include("RSpec.describe User")
    end

    context "when AI generation fails" do
      before do
        allow(mock_llm).to receive(:chat).and_raise(StandardError, "API error")
      end

      it "raises AIGenerationError" do
        expect {
          ai_generator.generate_for_file(user_model_path, file_type: :model)
        }.to raise_error(Autotest::Agent::AIGenerationError, /Erreur lors de la génération IA/)
      end
    end
  end

  describe "#generate_interactive" do
    let(:mock_prompt) { instance_double(TTY::Prompt) }

    before do
      allow(TTY::Prompt).to receive(:new).and_return(mock_prompt)
      allow(mock_prompt).to receive(:ask).and_return("User authentication model")
      allow($stdout).to receive(:puts)
    end

    context "when interactive mode is enabled" do
      before { configuration.interactive_mode = true }

      it "collects user context" do
        expect(ai_generator).to receive(:collect_user_context)
          .with(user_model_path, :model)
          .and_return("Custom context")
        
        ai_generator.generate_interactive(user_model_path)
      end
    end

    context "when interactive mode is disabled" do
      before { configuration.interactive_mode = false }

      it "generates without collecting context" do
        expect(ai_generator).not_to receive(:collect_user_context)
        
        ai_generator.generate_interactive(user_model_path)
      end
    end
  end

  describe "#improve_existing_test" do
    let(:test_file_path) { create_test_file("spec/models/user_spec.rb", "# Basic test") }
    let(:source_file_path) { user_model_path }
    let(:improvement_notes) { "Add validation tests" }

    it "returns nil if files don't exist" do
      result = ai_generator.improve_existing_test("missing.rb", "missing.rb")
      expect(result).to be_nil
    end

    it "builds improvement prompt" do
      expect(ai_generator).to receive(:build_improvement_prompt)
        .with("# Basic test", kind_of(String), :model, improvement_notes)
        .and_return("Improve this test")
      
      ai_generator.improve_existing_test(test_file_path, source_file_path, improvement_notes)
    end

    it "calls LLM with improvement prompt" do
      expect(mock_llm).to receive(:chat)
        .with(hash_including(messages: array_including(
          hash_including(role: "system"),
          hash_including(role: "user")
        )))
        .and_return(sample_response)
      
      ai_generator.improve_existing_test(test_file_path, source_file_path, improvement_notes)
    end
  end

  describe "#setup_llm" do
    context "with OpenAI provider" do
      before { configuration.ai_provider = :openai }

      it "creates OpenAI LLM instance" do
        expect(Langchain::LLM::OpenAI).to receive(:new)
          .with(hash_including(
            api_key: configuration.ai_api_key,
            default_options: hash_including(
              model: configuration.ai_model,
              temperature: 0.3,
              max_tokens: 2000
            )
          ))
        
        ai_generator.send(:setup_llm)
      end

      it "raises error for missing API key" do
        configuration.ai_api_key = nil
        
        expect {
          ai_generator.send(:setup_llm)
        }.to raise_error(Autotest::Agent::ConfigurationError, /Clé API OpenAI manquante/)
      end
    end

    context "with Ollama provider" do
      before { configuration.ai_provider = :ollama }

      it "creates Ollama LLM instance" do
        expect(Langchain::LLM::Ollama).to receive(:new)
          .with(hash_including(
            url: "http://localhost:11434",
            default_options: hash_including(
              model: configuration.ai_model,
              temperature: 0.3
            )
          ))
        
        ai_generator.send(:setup_llm)
      end
    end

    context "with unsupported provider" do
      before { configuration.ai_provider = :unsupported }

      it "raises configuration error" do
        expect {
          ai_generator.send(:setup_llm)
        }.to raise_error(Autotest::Agent::ConfigurationError, /Provider IA non supporté/)
      end
    end
  end

  describe "#detect_file_type" do
    it "detects model files" do
      expect(ai_generator.send(:detect_file_type, "app/models/user.rb")).to eq(:model)
    end

    it "detects controller files" do
      expect(ai_generator.send(:detect_file_type, "app/controllers/users_controller.rb")).to eq(:controller)
    end

    it "detects service files" do
      expect(ai_generator.send(:detect_file_type, "app/services/user_service.rb")).to eq(:service)
    end

    it "detects job files" do
      expect(ai_generator.send(:detect_file_type, "app/jobs/user_job.rb")).to eq(:job)
    end

    it "detects helper files" do
      expect(ai_generator.send(:detect_file_type, "app/helpers/users_helper.rb")).to eq(:helper)
    end

    it "detects mailer files" do
      expect(ai_generator.send(:detect_file_type, "app/mailers/user_mailer.rb")).to eq(:mailer)
    end

    it "detects library files" do
      expect(ai_generator.send(:detect_file_type, "lib/utilities.rb")).to eq(:library)
    end

    it "returns unknown for unrecognized files" do
      expect(ai_generator.send(:detect_file_type, "config/application.rb")).to eq(:unknown)
    end
  end

  describe "#build_context" do
    let(:file_path) { user_model_path }
    let(:user_context) { "Authentication model" }

    it "includes user context when provided" do
      result = ai_generator.send(:build_context, file_path, user_context)
      expect(result).to include(user_context)
    end

    it "analyzes project context" do
      expect(ai_generator).to receive(:analyze_project_context)
        .with(file_path)
        .and_return("Project context")
      
      result = ai_generator.send(:build_context, file_path, user_context)
      expect(result).to include("Project context")
    end

    it "analyzes related files" do
      expect(ai_generator).to receive(:analyze_related_files)
        .with(file_path)
        .and_return("Related files")
      
      result = ai_generator.send(:build_context, file_path, user_context)
      expect(result).to include("Related files")
    end
  end

  describe "#generate_test" do
    let(:file_content) { "class User; end" }
    let(:file_type) { :model }
    let(:context) { "Test context" }

    it "formats prompt with template" do
      template = configuration.prompt_templates[file_type]
      expected_prompt = template[:user] % { code: file_content, context: context }
      
      expect(mock_llm).to receive(:chat)
        .with(hash_including(
          messages: [
            { role: "system", content: template[:system] },
            { role: "user", content: expected_prompt }
          ]
        ))
        .and_return(sample_response)
      
      ai_generator.send(:generate_test, file_content, file_type, context)
    end

    it "returns content from AI response" do
      result = ai_generator.send(:generate_test, file_content, file_type, context)
      expect(result).to eq(sample_generated_test)
    end

    it "returns nil for missing template" do
      result = ai_generator.send(:generate_test, file_content, :unknown, context)
      expect(result).to be_nil
    end
  end

  describe "#collect_user_context" do
    let(:mock_prompt) { instance_double(TTY::Prompt) }

    before do
      allow(TTY::Prompt).to receive(:new).and_return(mock_prompt)
      allow($stdout).to receive(:puts)
    end

    context "for model files" do
      it "asks model-specific questions" do
        expect(mock_prompt).to receive(:ask).with(/rôle métier/, default: "").and_return("User model")
        expect(mock_prompt).to receive(:yes?).with(/règles métier/).and_return(false)
        expect(mock_prompt).to receive(:yes?).with(/cas limites/).and_return(false)
        
        result = ai_generator.send(:collect_user_context, user_model_path, :model)
        expect(result).to include("User model")
      end
    end

    context "for controller files" do
      let(:controller_path) { create_test_controller("users") }

      it "asks controller-specific questions" do
        expect(mock_prompt).to receive(:ask).with(/rôle de ce contrôleur/, default: "").and_return("API controller")
        expect(mock_prompt).to receive(:yes?).with(/permissions/).and_return(false)
        
        result = ai_generator.send(:collect_user_context, controller_path, :controller)
        expect(result).to include("API controller")
      end
    end

    context "for service files" do
      let(:service_path) { create_test_file("app/services/user_service.rb", "class UserService; end") }

      it "asks service-specific questions" do
        expect(mock_prompt).to receive(:ask).with(/Que fait ce service/, default: "").and_return("User operations")
        expect(mock_prompt).to receive(:ask).with(/cas d'erreur/, default: "").and_return("API failures")
        
        result = ai_generator.send(:collect_user_context, service_path, :service)
        expect(result).to include("User operations")
        expect(result).to include("API failures")
      end
    end

    context "for unknown file types" do
      let(:unknown_path) { create_test_file("lib/utility.rb", "module Utility; end") }

      it "asks general questions" do
        expect(mock_prompt).to receive(:ask).with(/Contexte métier/, default: "").and_return("Utility module")
        
        result = ai_generator.send(:collect_user_context, unknown_path, :unknown)
        expect(result).to include("Utility module")
      end
    end
  end

  describe "#clean_and_validate_test" do
    context "with markdown wrapped content" do
      let(:wrapped_content) do
        <<~CONTENT
          ```ruby
          # frozen_string_literal: true
          
          require 'rails_helper'
          
          RSpec.describe User do
            it 'works' do
              expect(true).to be true
            end
          end
          ```
        CONTENT
      end

      it "removes markdown wrapping" do
        result = ai_generator.send(:clean_and_validate_test, wrapped_content, :model)
        expect(result).not_to include("```ruby")
        expect(result).not_to include("```")
        expect(result).to include("RSpec.describe User")
      end
    end

    context "with missing headers" do
      let(:content_without_headers) do
        <<~RUBY
          RSpec.describe User do
            it 'works' do
              expect(true).to be true
            end
          end
        RUBY
      end

      it "adds frozen_string_literal header" do
        result = ai_generator.send(:clean_and_validate_test, content_without_headers, :model)
        expect(result).to start_with("# frozen_string_literal: true")
      end

      it "adds appropriate require statement" do
        result = ai_generator.send(:clean_and_validate_test, content_without_headers, :model)
        expect(result).to include("require 'rails_helper'")
      end
    end

    context "with Rails content" do
      let(:rails_content) do
        <<~RUBY
          RSpec.describe User do
            it { should validate_presence_of(:email) }
          end
        RUBY
      end

      it "adds rails_helper for Rails tests" do
        result = ai_generator.send(:clean_and_validate_test, rails_content, :model)
        expect(result).to include("require 'rails_helper'")
      end
    end

    context "with non-Rails content" do
      let(:plain_content) do
        <<~RUBY
          RSpec.describe Calculator do
            it 'adds numbers' do
              expect(Calculator.add(1, 2)).to eq(3)
            end
          end
        RUBY
      end

      it "adds spec_helper for non-Rails tests" do
        result = ai_generator.send(:clean_and_validate_test, plain_content, :library)
        expect(result).to include("require 'spec_helper'")
      end
    end

    it "validates Ruby syntax" do
      expect(ai_generator).to receive(:validate_ruby_syntax).and_return(true)
      
      ai_generator.send(:clean_and_validate_test, sample_generated_test, :model)
    end

    it "returns nil for empty content" do
      expect(ai_generator.send(:clean_and_validate_test, nil, :model)).to be_nil
      expect(ai_generator.send(:clean_and_validate_test, "", :model)).to be_nil
    end
  end

  describe "#validate_ruby_syntax" do
    context "with valid Ruby code" do
      let(:valid_code) { "class Test; end" }

      it "returns true" do
        result = ai_generator.send(:validate_ruby_syntax, valid_code)
        expect(result).to be true
      end
    end

    context "with invalid Ruby code" do
      let(:invalid_code) { "class Test end" }

      it "handles syntax errors gracefully" do
        expect($stdout).to receive(:puts).with(/Attention : Possible erreur de syntaxe/)
        
        result = ai_generator.send(:validate_ruby_syntax, invalid_code)
        expect(result).to be true
      end
    end
  end

  describe "context analysis methods" do
    describe "#analyze_project_context" do
      context "for model files" do
        let(:model_path) { "app/models/user.rb" }

        it "analyzes recent migrations" do
          expect(ai_generator).to receive(:analyze_recent_migrations)
            .and_return("Recent migrations info")
          
          result = ai_generator.send(:analyze_project_context, model_path)
          expect(result).to include("Recent migrations info")
        end
      end

      context "for controller files" do
        let(:controller_path) { "app/controllers/users_controller.rb" }

        it "analyzes routes" do
          expect(ai_generator).to receive(:analyze_routes)
            .and_return("Routes info")
          
          result = ai_generator.send(:analyze_project_context, controller_path)
          expect(result).to include("Routes info")
        end
      end
    end

    describe "#analyze_related_files" do
      let(:model_content) do
        <<~RUBY
          class User < ApplicationRecord
            belongs_to :organization
            has_many :posts
            include Authenticatable
          end
        RUBY
      end

      before do
        File.write(user_model_path, model_content)
      end

      it "detects associations and includes" do
        result = ai_generator.send(:analyze_related_files, user_model_path)
        expect(result).to include("belongs_to")
        expect(result).to include("has_many")
        expect(result).to include("include")
      end
    end

    describe "#analyze_recent_migrations" do
      before do
        create_rails_structure
        migration_dir = File.join(@test_work_dir, "db", "migrate")
        FileUtils.mkdir_p(migration_dir)
        
        # Crée quelques migrations de test
        %w[001_create_users.rb 002_add_email_to_users.rb 003_create_posts.rb].each do |migration|
          File.write(File.join(migration_dir, migration), "# Migration content")
        end
      end

      it "finds recent migrations" do
        result = ai_generator.send(:analyze_recent_migrations)
        expect(result).to include("Migrations récentes")
        expect(result).to include("003_create_posts.rb")
      end
    end

    describe "#analyze_routes" do
      before do
        create_test_file("config/routes.rb", "Rails.application.routes.draw do; end")
      end

      it "detects routes file" do
        result = ai_generator.send(:analyze_routes)
        expect(result).to include("routes.rb disponible")
      end
    end
  end
end 