# frozen_string_literal: true

RSpec.describe Autotest::Agent::Configuration, type: :unit do
  subject(:configuration) { described_class.new }

  describe "initialization" do
    it "sets default values" do
      expect(configuration.ai_provider).to eq(:openai)
      expect(configuration.ai_model).to eq("gpt-3.5-turbo")
      expect(configuration.auto_run_tests).to be true
      expect(configuration.coverage_threshold).to eq(80)
      expect(configuration.interactive_mode).to be true
      expect(configuration.rails_app_path).to eq(Dir.pwd)
    end

    it "detects test framework automatically" do
      expect([:rspec, :minitest]).to include(configuration.test_framework)
    end

    it "sets default watch paths" do
      expected_paths = %w[
        app/models app/controllers app/jobs app/services
        app/helpers app/mailers lib
      ]
      expect(configuration.watch_paths).to eq(expected_paths)
    end

    it "sets default exclude paths" do
      expected_excludes = %w[tmp log vendor node_modules .git]
      expect(configuration.exclude_paths).to eq(expected_excludes)
    end

    it "initializes prompt templates" do
      expect(configuration.prompt_templates).to be_a(Hash)
      expect(configuration.prompt_templates).to have_key(:model)
      expect(configuration.prompt_templates).to have_key(:controller)
      expect(configuration.prompt_templates).to have_key(:service)
    end
  end

  describe "#detect_test_framework" do
    context "when RSpec is present" do
      before do
        create_test_file("spec/spec_helper.rb", "# RSpec config")
      end

      it "detects RSpec" do
        expect(configuration.detect_test_framework).to eq(:rspec)
      end
    end

    context "when rails_helper is present" do
      before do
        create_test_file("spec/rails_helper.rb", "# Rails RSpec config")
      end

      it "detects RSpec" do
        expect(configuration.detect_test_framework).to eq(:rspec)
      end
    end

    context "when Minitest is present" do
      before do
        create_test_file("test/test_helper.rb", "# Minitest config")
      end

      it "detects Minitest" do
        expect(configuration.detect_test_framework).to eq(:minitest)
      end
    end

    context "when no test framework is present" do
      it "defaults to RSpec" do
        expect(configuration.detect_test_framework).to eq(:rspec)
      end
    end
  end

  describe "#detect_test_output_path" do
    context "when test framework is RSpec" do
      before { configuration.test_framework = :rspec }

      it "returns spec directory" do
        expect(configuration.detect_test_output_path).to eq("spec")
      end
    end

    context "when test framework is Minitest" do
      before { configuration.test_framework = :minitest }

      it "returns test directory" do
        expect(configuration.detect_test_output_path).to eq("test")
      end
    end

    context "when test framework is unknown" do
      before { configuration.test_framework = :unknown }

      it "defaults to spec directory" do
        expect(configuration.detect_test_output_path).to eq("spec")
      end
    end
  end

  describe "#valid?" do
    context "when configuration is valid" do
      before do
        configuration.ai_api_key = "valid-api-key"
      end

      it "returns true" do
        expect(configuration).to be_valid
      end
    end

    context "when API key is missing" do
      before do
        configuration.ai_api_key = nil
      end

      it "returns false" do
        expect(configuration).not_to be_valid
      end
    end

    context "when API key is empty" do
      before do
        configuration.ai_api_key = ""
      end

      it "returns false" do
        expect(configuration).not_to be_valid
      end
    end
  end

  describe "#validation_errors" do
    context "when configuration is valid" do
      before do
        configuration.ai_api_key = "valid-api-key"
      end

      it "returns empty array" do
        expect(configuration.validation_errors).to be_empty
      end
    end

    context "when API key is missing" do
      before do
        configuration.ai_api_key = nil
      end

      it "returns error about missing API key" do
        errors = configuration.validation_errors
        expect(errors).to include("Clé API IA manquante")
      end
    end

    context "when Rails app path is invalid" do
      before do
        configuration.ai_api_key = "valid-key"
        configuration.rails_app_path = "/non/existent/path"
      end

      it "returns error about invalid path" do
        errors = configuration.validation_errors
        expect(errors).to include("Chemin Rails invalide")
      end
    end
  end

  describe "#setup_rspec!" do
    context "when RSpec is not configured" do
      it "creates spec directory" do
        configuration.setup_rspec!
        expect(File.directory?("spec")).to be true
      end

      it "creates spec_helper.rb" do
        allow($stdout).to receive(:puts) # Silence output
        configuration.setup_rspec!
        expect(File.exist?("spec/spec_helper.rb")).to be true
      end

      it "sets test framework to RSpec" do
        allow($stdout).to receive(:puts)
        configuration.setup_rspec!
        expect(configuration.test_framework).to eq(:rspec)
      end

      it "sets test output path to spec" do
        allow($stdout).to receive(:puts)
        configuration.setup_rspec!
        expect(configuration.test_output_path).to eq("spec")
      end

      context "in a Rails application" do
        before do
          create_rails_structure
          create_test_file("config/application.rb", "# Rails app")
        end

        it "creates rails_helper.rb" do
          allow($stdout).to receive(:puts)
          configuration.setup_rspec!
          expect(File.exist?("spec/rails_helper.rb")).to be true
        end
      end
    end

    context "when RSpec is already configured" do
      before do
        create_test_file("spec/spec_helper.rb", "# Existing RSpec config")
      end

      it "does not overwrite existing configuration" do
        original_content = File.read("spec/spec_helper.rb")
        configuration.setup_rspec!
        expect(File.read("spec/spec_helper.rb")).to eq(original_content)
      end
    end
  end

  describe "prompt templates" do
    let(:templates) { configuration.prompt_templates }

    it "includes templates for all file types" do
      expect(templates).to have_key(:model)
      expect(templates).to have_key(:controller)
      expect(templates).to have_key(:job)
      expect(templates).to have_key(:service)
    end

    it "each template has system and user prompts" do
      templates.each do |_type, template|
        expect(template).to have_key(:system)
        expect(template).to have_key(:user)
        expect(template[:system]).to be_a(String)
        expect(template[:user]).to be_a(String)
      end
    end

    it "user prompts contain placeholders" do
      templates.each do |_type, template|
        user_prompt = template[:user]
        expect(user_prompt).to include("%{code}")
        expect(user_prompt).to include("%{context}")
      end
    end
  end

  describe "attribute accessors" do
    it "allows reading and writing all configuration attributes" do
      configuration.ai_provider = :ollama
      configuration.ai_model = "codellama"
      configuration.auto_run_tests = false
      configuration.coverage_threshold = 90
      configuration.interactive_mode = false

      expect(configuration.ai_provider).to eq(:ollama)
      expect(configuration.ai_model).to eq("codellama")
      expect(configuration.auto_run_tests).to be false
      expect(configuration.coverage_threshold).to eq(90)
      expect(configuration.interactive_mode).to be false
    end

    it "allows modifying watch paths" do
      new_paths = ["custom/path"]
      configuration.watch_paths = new_paths
      expect(configuration.watch_paths).to eq(new_paths)
    end

    it "allows modifying exclude paths" do
      new_excludes = ["custom_exclude"]
      configuration.exclude_paths = new_excludes
      expect(configuration.exclude_paths).to eq(new_excludes)
    end
  end

  describe "private methods" do
    describe "#rails_application?" do
      context "in a Rails application" do
        before do
          create_test_file("config/application.rb", "# Rails app")
          create_test_file("Gemfile", "gem 'rails'")
        end

        it "returns true" do
          expect(configuration.send(:rails_application?)).to be true
        end
      end

      context "not in a Rails application" do
        it "returns false" do
          expect(configuration.send(:rails_application?)).to be false
        end
      end
    end

    describe "#create_spec_helper" do
      it "creates spec_helper with SimpleCov configuration" do
        allow($stdout).to receive(:puts)
        configuration.send(:create_spec_helper)
        
        content = File.read("spec/spec_helper.rb")
        expect(content).to include("SimpleCov.start 'rails'")
        expect(content).to include("minimum_coverage #{configuration.coverage_threshold}")
      end

      it "includes standard RSpec configuration" do
        allow($stdout).to receive(:puts)
        configuration.send(:create_spec_helper)
        
        content = File.read("spec/spec_helper.rb")
        expect(content).to include("config.disable_monkey_patching!")
        expect(content).to include("config.order = :random")
      end
    end

    describe "#create_rails_helper" do
      before do
        create_test_file("config/environment.rb", "# Rails environment")
      end

      it "creates rails_helper with Rails-specific configuration" do
        allow($stdout).to receive(:puts)
        configuration.send(:create_rails_helper)
        
        content = File.read("spec/rails_helper.rb")
        expect(content).to include("require 'spec_helper'")
        expect(content).to include("require 'rspec/rails'")
        expect(content).to include("use_transactional_fixtures")
      end
    end
  end
end 