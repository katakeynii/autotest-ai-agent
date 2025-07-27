# frozen_string_literal: true

require "autotest/ia"
require "fileutils"
require "tmpdir"
require "webmock/rspec"
require "vcr"

# Configuration des mocks HTTP
WebMock.disable_net_connect!(allow_localhost: true)

# Configuration VCR pour les tests d'API
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = { 
    record: :once,
    match_requests_on: [:method, :uri, :body]
  }
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.configure_rspec_metadata!
end

RSpec.configure do |config|
  # Configuration générale
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

  # Formatage
  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  # Setup et teardown globaux
  config.before(:suite) do
    # Création d'un répertoire temporaire pour les tests
    @test_tmp_dir = Dir.mktmpdir("autotest-ia-test")
    ENV['AUTOTEST_IA_TEST_DIR'] = @test_tmp_dir
  end

  config.after(:suite) do
    # Nettoyage du répertoire temporaire
    FileUtils.rm_rf(@test_tmp_dir) if @test_tmp_dir
  end

  config.before(:each) do
    # Reset de la configuration entre les tests
    Autotest::Agent.instance_variable_set(:@configuration, nil)
    
    # Setup d'un répertoire de travail temporaire pour chaque test
    @test_work_dir = File.join(ENV['AUTOTEST_IA_TEST_DIR'], "test_#{rand(10000)}")
    FileUtils.mkdir_p(@test_work_dir)
    @original_dir = Dir.pwd
    Dir.chdir(@test_work_dir)
  end

  config.after(:each) do
    # Retour au répertoire original
    Dir.chdir(@original_dir) if @original_dir
    
    # Nettoyage du répertoire de test
    FileUtils.rm_rf(@test_work_dir) if @test_work_dir
  end
end

# Contexte partagé pour les helpers de test
RSpec.shared_context "test helpers", type: :unit do
  # Helper pour créer une configuration de test
  def test_configuration
    Autotest::Agent::Configuration.new.tap do |config|
      config.ai_provider = :openai
      config.ai_model = "gpt-3.5-turbo"
      config.ai_api_key = "test-api-key"
      config.test_framework = :rspec
      config.auto_run_tests = false
      config.interactive_mode = false
      config.rails_app_path = @test_work_dir
    end
  end

  # Helper pour créer une structure Rails de test
  def create_rails_structure
    %w[app/models app/controllers app/services app/jobs app/helpers app/mailers lib spec].each do |dir|
      FileUtils.mkdir_p(File.join(@test_work_dir, dir))
    end
    
    # Crée un Gemfile basique
    File.write("Gemfile", <<~GEMFILE)
      source 'https://rubygems.org'
      gem 'rails'
      gem 'rspec-rails'
    GEMFILE
  end

  # Helper pour créer un fichier Ruby de test
  def create_test_file(path, content)
    full_path = File.join(@test_work_dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  # Helper pour créer un modèle Rails de test
  def create_test_model(name, content = nil)
    content ||= <<~RUBY
      class #{name.capitalize} < ApplicationRecord
        validates :name, presence: true
      end
    RUBY
    create_test_file("app/models/#{name}.rb", content)
  end

  # Helper pour créer un contrôleur Rails de test
  def create_test_controller(name, content = nil)
    content ||= <<~RUBY
      class #{name.capitalize}Controller < ApplicationController
        def index
          render json: { message: 'Hello' }
        end
      end
    RUBY
    create_test_file("app/controllers/#{name}_controller.rb", content)
  end

  # Mock pour les appels IA
  def mock_ai_response(response_content)
    allow_any_instance_of(Autotest::Agent::AIGenerator).to receive(:generate_test)
      .and_return(response_content)
  end

  # Stub pour empêcher les vrais appels d'API
  def stub_ai_api
    allow_any_instance_of(Langchain::LLM::OpenAI).to receive(:chat)
      .and_return({
        "choices" => [{
          "message" => {
            "content" => sample_generated_test
          }
        }]
      })
  end

  # Exemple de test généré par l'IA
  def sample_generated_test
    <<~RUBY
      # frozen_string_literal: true

      require 'rails_helper'

      RSpec.describe User, type: :model do
        describe 'validations' do
          it { should validate_presence_of(:name) }
        end
      end
    RUBY
  end
end

# Include the shared context in unit tests
RSpec.configure do |config|
  config.include_context "test helpers", type: :unit
end
