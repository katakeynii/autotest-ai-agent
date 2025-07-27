# frozen_string_literal: true

RSpec.describe Autotest::Agent::CLI, type: :unit do
  subject(:cli) { described_class.new }

  let(:mock_configuration) { test_configuration }

  before do
    allow(Autotest::Agent).to receive(:configure).and_return(mock_configuration)
    allow(Autotest::Agent).to receive(:configuration).and_return(mock_configuration)
    allow($stdout).to receive(:puts)
    allow($stderr).to receive(:puts)
  end

  describe "#version" do
    it "displays the current version" do
      expect { cli.version }.to output(/Autotest IA version #{Autotest::Agent::VERSION}/).to_stdout
    end
  end

  describe "#init" do
    let(:options) do
      {
        "provider" => "openai",
        "model" => "gpt-3.5-turbo",
        "interactive" => true
      }
    end

    before do
      create_rails_structure
      allow(cli).to receive(:options).and_return(options)
      allow(cli).to receive(:yes?).and_return(true)
    end

    it "verifies ruby project" do
      expect(cli).to receive(:verify_ruby_project!)
      
      cli.init
    end

    it "configures the gem" do
      expect(cli).to receive(:configure_gem).with(options)
      
      cli.init
    end

    it "sets up test framework" do
      expect(cli).to receive(:setup_test_framework)
      
      cli.init
    end

    it "creates config file" do
      expect(cli).to receive(:create_config_file).with(options)
      
      cli.init
    end

    it "displays success message" do
      expect($stdout).to receive(:puts).with(/✅ Autotest-ia initialisé avec succès !/)
      
      cli.init
    end
  end

  describe "#watch" do
    let(:options) { { "interactive" => true, "auto_run" => true } }
    let(:mock_file_watcher) { instance_double(Autotest::Agent::FileWatcher) }

    before do
      allow(cli).to receive(:options).and_return(options)
      allow(Autotest::Agent).to receive(:start_watching)
      mock_configuration.ai_api_key = "test-key"
    end

    it "loads configuration" do
      expect(cli).to receive(:load_configuration).with(options)
      
      cli.watch
    end

    it "verifies AI configuration" do
      expect(cli).to receive(:verify_ai_configuration!)
      
      cli.watch
    end

    it "starts watching" do
      expect(Autotest::Agent).to receive(:start_watching).with(".")
      
      cli.watch
    end

    it "accepts custom path" do
      expect(Autotest::Agent).to receive(:start_watching).with("/custom/path")
      
      cli.watch("/custom/path")
    end
  end

  describe "#generate" do
    let(:file_path) { create_test_model("user") }
    let(:options) { { "context" => "User model", "interactive" => false } }
    let(:generated_content) { sample_generated_test }

    before do
      allow(cli).to receive(:options).and_return(options)
      allow(Autotest::Agent).to receive(:generate_test_for).and_return(generated_content)
      mock_configuration.ai_api_key = "test-key"
    end

    context "when file exists" do
      it "loads configuration" do
        expect(cli).to receive(:load_configuration).with(options)
        
        cli.generate(file_path)
      end

      it "verifies AI configuration" do
        expect(cli).to receive(:verify_ai_configuration!)
        
        cli.generate(file_path)
      end

      it "generates test for file" do
        expect(Autotest::Agent).to receive(:generate_test_for)
          .with(file_path, context: "User model")
          .and_return(generated_content)
        
        cli.generate(file_path)
      end

      it "saves generated test" do
        expect(cli).to receive(:save_generated_test)
        
        cli.generate(file_path)
      end

      it "displays success message" do
        expect($stdout).to receive(:puts).with(/✅ Test généré :/)
        
        cli.generate(file_path)
      end
    end

    context "when file does not exist" do
      it "displays error and exits" do
        expect($stdout).to receive(:puts).with(/❌ Fichier non trouvé :/)
        expect { cli.generate("non_existent.rb") }.to raise_error(SystemExit)
      end
    end

    context "when generation fails" do
      before do
        allow(Autotest::Agent).to receive(:generate_test_for).and_return(nil)
      end

      it "displays error and exits" do
        expect($stdout).to receive(:puts).with(/❌ Impossible de générer le test/)
        expect { cli.generate(file_path) }.to raise_error(SystemExit)
      end
    end

    context "in interactive mode" do
      let(:options) { { "interactive" => true } }

      it "generates interactive test" do
        expect(cli).to receive(:generate_interactive_test).with(file_path)
          .and_return(generated_content)
        
        cli.generate(file_path)
      end
    end
  end

  describe "#test" do
    let(:test_files) { ["spec/models/user_spec.rb"] }
    let(:options) { { "coverage" => true, "watch" => false } }
    let(:mock_test_runner) { instance_double(Autotest::Agent::TestRunner) }

    before do
      allow(cli).to receive(:options).and_return(options)
      allow(Autotest::Agent).to receive(:run_tests)
      allow(Autotest::Agent::TestRunner).to receive(:new).and_return(mock_test_runner)
      allow(mock_test_runner).to receive(:run_in_watch_mode)
      allow(mock_test_runner).to receive(:analyze_results)
    end

    it "loads configuration" do
      expect(cli).to receive(:load_configuration).with(options)
      
      cli.test(*test_files)
    end

    context "in normal mode" do
      it "runs tests" do
        expect(Autotest::Agent).to receive(:run_tests).with(test_files)
        
        cli.test(*test_files)
      end

      it "analyzes results when coverage enabled" do
        expect(mock_test_runner).to receive(:analyze_results)
        
        cli.test(*test_files)
      end
    end

    context "in watch mode" do
      let(:options) { { "watch" => true } }

      it "runs in watch mode" do
        expect(mock_test_runner).to receive(:run_in_watch_mode)
        
        cli.test(*test_files)
      end
    end

    context "with no files specified" do
      it "runs tests with nil" do
        expect(Autotest::Agent).to receive(:run_tests).with(nil)
        
        cli.test
      end
    end
  end

  describe "#report" do
    let(:options) { { "output" => "/tmp/report.html", "days" => 7 } }
    let(:mock_test_runner) { instance_double(Autotest::Agent::TestRunner) }
    let(:mock_reporter) { instance_double(Autotest::Agent::Reporter) }

    before do
      allow(cli).to receive(:options).and_return(options)
      allow(Autotest::Agent::TestRunner).to receive(:new).and_return(mock_test_runner)
      allow(Autotest::Agent::Reporter).to receive(:new).and_return(mock_reporter)
    end

    it "loads configuration" do
      expect(cli).to receive(:load_configuration).with(options)
      
      cli.report("full")
    end

    context "with coverage report" do
      it "generates coverage report" do
        expect(mock_reporter).to receive(:generate_coverage_report)
        
        cli.report("coverage")
      end
    end

    context "with quality report" do
      it "generates quality report" do
        expect(mock_reporter).to receive(:generate_quality_report)
        
        cli.report("quality")
      end
    end

    context "with trend report" do
      it "generates trend report with specified days" do
        expect(mock_reporter).to receive(:generate_trend_report).with(7)
        
        cli.report("trend")
      end
    end

    context "with full report" do
      it "generates full report and displays browser message" do
        expect(mock_reporter).to receive(:generate_full_report)
          .with("/tmp/report.html")
          .and_return("/tmp/report.html")
        expect($stdout).to receive(:puts).with(/🌐 Ouvrez .* dans votre navigateur/)
        
        cli.report("full")
      end
    end

    context "with unknown report type" do
      it "displays error and exits" do
        expect($stdout).to receive(:puts).with(/❌ Type de rapport non reconnu/)
        expect { cli.report("unknown") }.to raise_error(SystemExit)
      end
    end
  end

  describe "#config" do
    before do
      mock_configuration.ai_api_key = "test-key"
    end

    it "loads configuration" do
      expect(cli).to receive(:load_configuration)
      
      cli.config
    end

    it "displays configuration details" do
      expect($stdout).to receive(:puts).with(/⚙️  Configuration actuelle :/)
      expect($stdout).to receive(:puts).with(/Provider IA : openai/)
      expect($stdout).to receive(:puts).with(/Modèle : gpt-3.5-turbo/)
      
      cli.config
    end

    context "when configuration is valid" do
      it "displays valid status" do
        expect($stdout).to receive(:puts).with(/✅ Configuration valide/)
        
        cli.config
      end
    end

    context "when configuration is invalid" do
      before { mock_configuration.ai_api_key = nil }

      it "displays errors" do
        expect($stdout).to receive(:puts).with(/❌ Erreurs de configuration :/)
        
        cli.config
      end
    end
  end

  describe "#improve" do
    let(:test_file) { create_test_file("spec/models/user_spec.rb", "# existing test") }
    let(:source_file) { create_test_model("user") }
    let(:options) { { "notes" => "Add validation tests" } }
    let(:mock_generator) { instance_double(Autotest::Agent::AIGenerator) }
    let(:improved_content) { "# improved test content" }

    before do
      allow(cli).to receive(:options).and_return(options)
      allow(Autotest::Agent::AIGenerator).to receive(:new).and_return(mock_generator)
      allow(mock_generator).to receive(:improve_existing_test).and_return(improved_content)
      allow(FileUtils).to receive(:cp)
      allow(Time).to receive(:now).and_return(double(to_i: 123456))
      mock_configuration.ai_api_key = "test-key"
    end

    context "when files exist" do
      it "loads configuration and verifies AI config" do
        expect(cli).to receive(:load_configuration).with(options)
        expect(cli).to receive(:verify_ai_configuration!)
        
        cli.improve(test_file, source_file)
      end

      it "improves existing test" do
        expect(mock_generator).to receive(:improve_existing_test)
          .with(test_file, source_file, "Add validation tests")
          .and_return(improved_content)
        
        cli.improve(test_file, source_file)
      end

      it "creates backup of original test" do
        expect(FileUtils).to receive(:cp).with(test_file, "#{test_file}.backup.123456")
        
        cli.improve(test_file, source_file)
      end

      it "writes improved content" do
        cli.improve(test_file, source_file)
        
        expect(File.read(test_file)).to eq(improved_content)
      end

      it "displays success message" do
        expect($stdout).to receive(:puts).with(/✅ Test amélioré :/)
        
        cli.improve(test_file, source_file)
      end
    end

    context "when files don't exist" do
      it "displays error and exits" do
        expect($stdout).to receive(:puts).with(/❌ Fichier\(s\) non trouvé\(s\)/)
        expect { cli.improve("missing.rb", "missing.rb") }.to raise_error(SystemExit)
      end
    end

    context "when improvement fails" do
      before do
        allow(mock_generator).to receive(:improve_existing_test).and_return(nil)
      end

      it "displays error and exits" do
        expect($stdout).to receive(:puts).with(/❌ Impossible d'améliorer le test/)
        expect { cli.improve(test_file, source_file) }.to raise_error(SystemExit)
      end
    end
  end

  describe "#interactive" do
    let(:mock_prompt) { instance_double(TTY::Prompt) }

    before do
      allow(TTY::Prompt).to receive(:new).and_return(mock_prompt)
      allow(mock_prompt).to receive(:select).and_return(:exit)
    end

    it "loads configuration" do
      expect(cli).to receive(:load_configuration)
      
      cli.interactive
    end

    it "creates TTY::Prompt interface" do
      expect(TTY::Prompt).to receive(:new).and_return(mock_prompt)
      
      cli.interactive
    end

    it "displays goodbye message on exit" do
      expect($stdout).to receive(:puts).with(/👋 Au revoir !/)
      
      cli.interactive
    end

    context "when selecting watch option" do
      before do
        allow(mock_prompt).to receive(:select).and_return(:watch, :exit)
        allow(cli).to receive(:handle_interactive_watch)
      end

      it "handles interactive watch" do
        expect(cli).to receive(:handle_interactive_watch).with(mock_prompt)
        
        cli.interactive
      end
    end
  end

  describe "private methods" do
    describe "#verify_ruby_project!" do
      context "in a Ruby project" do
        before { create_test_file("Gemfile", "source 'https://rubygems.org'") }

        it "does not raise error" do
          expect { cli.send(:verify_ruby_project!) }.not_to raise_error
        end
      end

      context "not in a Ruby project" do
        it "displays error and exits" do
          expect($stdout).to receive(:puts).with(/❌ Ce ne semble pas être un projet Ruby/)
          expect { cli.send(:verify_ruby_project!) }.to raise_error(SystemExit)
        end
      end
    end

    describe "#configure_gem" do
      let(:options) do
        {
          "provider" => "ollama",
          "model" => "codellama",
          "interactive" => false
        }
      end

      it "configures the gem with provided options" do
        expect(Autotest::Agent).to receive(:configure) do |&block|
          config = double("config")
          expect(config).to receive(:ai_provider=).with(:ollama)
          expect(config).to receive(:ai_model=).with("codellama")
          expect(config).to receive(:interactive_mode=).with(false)
          block.call(config)
        end
        
        cli.send(:configure_gem, options)
      end
    end

    describe "#setup_test_framework" do
      context "when RSpec is not configured" do
        before do
          allow(mock_configuration).to receive(:test_framework).and_return(:rspec)
          allow(cli).to receive(:yes?).and_return(true)
        end

        it "prompts to install RSpec" do
          expect(cli).to receive(:yes?).with(/RSpec n'est pas configuré/)
          
          cli.send(:setup_test_framework)
        end

        it "sets up RSpec if user agrees" do
          expect(mock_configuration).to receive(:setup_rspec!)
          
          cli.send(:setup_test_framework)
        end
      end
    end

    describe "#create_config_file" do
      let(:options) { { "provider" => "openai", "model" => "gpt-4" } }

      context "when config file doesn't exist" do
        it "creates config file" do
          cli.send(:create_config_file, options)
          
          expect(File.exist?(".autotest_ia.yml")).to be true
          content = File.read(".autotest_ia.yml")
          expect(content).to include("ai_provider: openai")
          expect(content).to include("ai_model: gpt-4")
        end
      end

      context "when config file exists" do
        before do
          File.write(".autotest_ia.yml", "existing config")
          allow(cli).to receive(:yes?).and_return(false)
        end

        it "prompts to overwrite" do
          expect(cli).to receive(:yes?).with(/Fichier de config existant/)
          
          cli.send(:create_config_file, options)
        end

        it "does not overwrite if user declines" do
          original_content = File.read(".autotest_ia.yml")
          cli.send(:create_config_file, options)
          
          expect(File.read(".autotest_ia.yml")).to eq(original_content)
        end
      end
    end

    describe "#verify_ai_configuration!" do
      context "when configuration is valid" do
        before { mock_configuration.ai_api_key = "valid-key" }

        it "does not raise error" do
          expect { cli.send(:verify_ai_configuration!) }.not_to raise_error
        end
      end

      context "when configuration is invalid" do
        before { mock_configuration.ai_api_key = nil }

        it "displays errors and exits" do
          expect($stdout).to receive(:puts).with(/❌ Configuration IA invalide/)
          expect { cli.send(:verify_ai_configuration!) }.to raise_error(SystemExit)
        end

        it "provides OpenAI setup hint" do
          expect($stdout).to receive(:puts).with(/💡 Pour utiliser OpenAI/)
          expect { cli.send(:verify_ai_configuration!) }.to raise_error(SystemExit)
        end
      end
    end

    describe "#load_configuration" do
      context "when config file exists" do
        before do
          File.write(".autotest_ia.yml", <<~YAML)
            ai_provider: ollama
            ai_model: codellama
            interactive_mode: false
          YAML
        end

        it "loads configuration from file" do
          expect(cli).to receive(:load_config_file)
          
          cli.send(:load_configuration, {})
        end
      end

      it "overrides with CLI options" do
        cli_options = { "interactive" => false, "auto_run" => false }
        
        expect(Autotest::Agent).to receive(:configure) do |&block|
          config = double("config")
          expect(config).to receive(:interactive_mode=).with(false)
          expect(config).to receive(:auto_run_tests=).with(false)
          block.call(config)
        end
        
        cli.send(:load_configuration, cli_options)
      end
    end

    describe "#determine_output_file" do
      let(:source_file) { "app/models/user.rb" }
      let(:mock_file_watcher) { instance_double(Autotest::Agent::FileWatcher) }

      it "determines output file path" do
        expect(Autotest::Agent::FileWatcher).to receive(:new)
          .with(".", mock_configuration)
          .and_return(mock_file_watcher)
        expect(mock_file_watcher).to receive(:send)
          .with(:determine_test_file_path, File.expand_path(source_file), :unknown)
          .and_return("spec/models/user_spec.rb")
        
        result = cli.send(:determine_output_file, source_file)
        expect(result).to eq("spec/models/user_spec.rb")
      end
    end
  end
end 