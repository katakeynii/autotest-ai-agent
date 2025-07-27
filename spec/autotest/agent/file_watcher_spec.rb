# frozen_string_literal: true

RSpec.describe Autotest::Agent::FileWatcher, type: :unit do
  let(:configuration) { test_configuration }
  let(:watch_path) { @test_work_dir }
  subject(:file_watcher) { described_class.new(watch_path, configuration) }

  let(:mock_listener) { instance_double(Listen::Listener) }
  let(:mock_ai_generator) { instance_double(Autotest::Agent::AIGenerator) }
  let(:mock_test_runner) { instance_double(Autotest::Agent::TestRunner) }

  before do
    create_rails_structure
    
    # Mock Listen
    allow(Listen).to receive(:to).and_return(mock_listener)
    allow(mock_listener).to receive(:ignore)
    allow(mock_listener).to receive(:only)
    allow(mock_listener).to receive(:start)
    allow(mock_listener).to receive(:stop)
    
    # Mock dependencies
    allow(Autotest::Agent::AIGenerator).to receive(:new).and_return(mock_ai_generator)
    allow(Autotest::Agent::TestRunner).to receive(:new).and_return(mock_test_runner)
    allow(mock_ai_generator).to receive(:generate_for_file)
    allow(mock_test_runner).to receive(:run)
  end

  describe "#initialize" do
    it "sets the path and configuration" do
      expect(file_watcher.path).to eq(File.expand_path(watch_path))
      expect(file_watcher.configuration).to eq(configuration)
    end

    it "initializes listener as nil" do
      expect(file_watcher.listener).to be_nil
    end
  end

  describe "#start" do
    before do
      allow($stdout).to receive(:puts) # Silence output
      allow(file_watcher).to receive(:sleep) # Don't actually sleep
    end

    it "sets up the listener" do
      expect(file_watcher).to receive(:setup_listener)
      
      file_watcher.start
    end

    it "starts the listener" do
      expect(mock_listener).to receive(:start)
      
      file_watcher.start
    end

    it "displays watched paths" do
      expect($stdout).to receive(:puts).with(/📋 Chemins surveillés :/)
      
      file_watcher.start
    end
  end

  describe "#stop" do
    before do
      allow($stdout).to receive(:puts)
      file_watcher.instance_variable_set(:@listener, mock_listener)
    end

    it "stops the listener" do
      expect(mock_listener).to receive(:stop)
      
      file_watcher.stop
    end

    it "displays stop message" do
      expect($stdout).to receive(:puts).with(/🛑 Surveillance arrêtée/)
      
      file_watcher.stop
    end
  end

  describe "#setup_listener" do
    let(:watched_dirs) { ["app/models", "app/controllers"] }

    before do
      configuration.watch_paths = watched_dirs
      # Crée les répertoires pour qu'ils existent
      watched_dirs.each { |dir| FileUtils.mkdir_p(File.join(watch_path, dir)) }
    end

    it "creates listener for existing directories only" do
      expected_paths = watched_dirs.map { |p| File.join(watch_path, p) }
      
      expect(Listen).to receive(:to).with(*expected_paths) do |&block|
        # Stocke le block pour les tests
        file_watcher.instance_variable_set(:@change_handler, block)
        mock_listener
      end
      
      file_watcher.send(:setup_listener)
    end

    it "configures ignore patterns" do
      expect(mock_listener).to receive(:ignore)
      
      file_watcher.send(:setup_listener)
    end

    it "configures only patterns for Ruby files" do
      expect(mock_listener).to receive(:only).with([/\.rb$/])
      
      file_watcher.send(:setup_listener)
    end
  end

  describe "#handle_file_changes" do
    let(:user_model_path) { create_test_model("user") }
    let(:test_file_path) { create_test_file("spec/models/user_spec.rb", "# existing test") }
    let(:log_file_path) { create_test_file("log/test.log", "log content") }

    before do
      allow($stdout).to receive(:puts)
      allow(file_watcher).to receive(:process_file_change)
    end

    it "processes relevant Ruby files only" do
      modified_files = [user_model_path, test_file_path, log_file_path]
      
      expect(file_watcher).to receive(:process_file_change).with(user_model_path)
      expect(file_watcher).not_to receive(:process_file_change).with(test_file_path)
      expect(file_watcher).not_to receive(:process_file_change).with(log_file_path)
      
      file_watcher.send(:handle_file_changes, modified_files, [], [])
    end

    it "displays detected changes" do
      modified_files = [user_model_path]
      
      expect($stdout).to receive(:puts).with(/🔄 Changements détectés :/)
      
      file_watcher.send(:handle_file_changes, modified_files, [], [])
    end

    it "does nothing when no relevant changes" do
      modified_files = [test_file_path, log_file_path]
      
      expect(file_watcher).not_to receive(:process_file_change)
      
      file_watcher.send(:handle_file_changes, modified_files, [], [])
    end
  end

  describe "#process_file_change" do
    let(:user_model_path) { create_test_model("user") }
    let(:generated_test_content) { sample_generated_test }

    before do
      allow($stdout).to receive(:puts)
      allow(mock_ai_generator).to receive(:generate_for_file).and_return(generated_test_content)
      allow(file_watcher).to receive(:ai_generator).and_return(mock_ai_generator)
      allow(file_watcher).to receive(:test_runner).and_return(mock_test_runner)
    end

    it "detects file type correctly" do
      expect(file_watcher.send(:detect_file_type, user_model_path)).to eq(:model)
    end

    it "calls AI generator with correct parameters" do
      expect(mock_ai_generator).to receive(:generate_for_file)
        .with(user_model_path, file_type: :model)
        .and_return(generated_test_content)
      
      file_watcher.send(:process_file_change, user_model_path)
    end

    it "writes generated test to correct location" do
      file_watcher.send(:process_file_change, user_model_path)
      
      expected_test_path = File.join(@test_work_dir, "spec/models/user_spec.rb")
      expect(File.exist?(expected_test_path)).to be true
      expect(File.read(expected_test_path)).to eq(generated_test_content)
    end

    it "runs tests when auto_run_tests is enabled" do
      configuration.auto_run_tests = true
      
      expect(mock_test_runner).to receive(:run)
      
      file_watcher.send(:process_file_change, user_model_path)
    end

    it "does not run tests when auto_run_tests is disabled" do
      configuration.auto_run_tests = false
      
      expect(mock_test_runner).not_to receive(:run)
      
      file_watcher.send(:process_file_change, user_model_path)
    end

    context "when AI generation fails" do
      before do
        allow(mock_ai_generator).to receive(:generate_for_file)
          .and_raise(StandardError, "API error")
      end

      it "handles errors gracefully" do
        expect($stdout).to receive(:puts).with(/❌ Erreur lors de la génération/)
        
        expect { file_watcher.send(:process_file_change, user_model_path) }.not_to raise_error
      end
    end

    context "when no test content is generated" do
      before do
        allow(mock_ai_generator).to receive(:generate_for_file).and_return(nil)
      end

      it "displays warning message" do
        expect($stdout).to receive(:puts).with(/⚠️  Aucun test généré/)
        
        file_watcher.send(:process_file_change, user_model_path)
      end
    end
  end

  describe "#relevant_file?" do
    let(:user_model) { create_test_model("user") }
    let(:user_spec) { create_test_file("spec/models/user_spec.rb", "# test") }
    let(:text_file) { create_test_file("readme.txt", "text content") }
    let(:vendor_file) { create_test_file("vendor/gems/gem.rb", "# vendor") }

    it "returns true for Ruby files in watched paths" do
      expect(file_watcher.send(:relevant_file?, user_model)).to be true
    end

    it "returns false for test files" do
      expect(file_watcher.send(:relevant_file?, user_spec)).to be false
    end

    it "returns false for non-Ruby files" do
      expect(file_watcher.send(:relevant_file?, text_file)).to be false
    end

    it "returns false for files in excluded paths" do
      expect(file_watcher.send(:relevant_file?, vendor_file)).to be false
    end
  end

  describe "#detect_file_type" do
    it "detects model files" do
      path = "app/models/user.rb"
      expect(file_watcher.send(:detect_file_type, path)).to eq(:model)
    end

    it "detects controller files" do
      path = "app/controllers/users_controller.rb"
      expect(file_watcher.send(:detect_file_type, path)).to eq(:controller)
    end

    it "detects service files" do
      path = "app/services/user_service.rb"
      expect(file_watcher.send(:detect_file_type, path)).to eq(:service)
    end

    it "detects job files" do
      path = "app/jobs/user_job.rb"
      expect(file_watcher.send(:detect_file_type, path)).to eq(:job)
    end

    it "detects helper files" do
      path = "app/helpers/application_helper.rb"
      expect(file_watcher.send(:detect_file_type, path)).to eq(:helper)
    end

    it "detects mailer files" do
      path = "app/mailers/user_mailer.rb"
      expect(file_watcher.send(:detect_file_type, path)).to eq(:mailer)
    end

    it "detects library files" do
      path = "lib/custom_lib.rb"
      expect(file_watcher.send(:detect_file_type, path)).to eq(:library)
    end

    it "returns unknown for unrecognized patterns" do
      path = "config/application.rb"
      expect(file_watcher.send(:detect_file_type, path)).to eq(:unknown)
    end
  end

  describe "#determine_test_file_path" do
    let(:base_path) { @test_work_dir }

    context "with RSpec" do
      before { configuration.test_framework = :rspec }

      it "maps app/models to spec/models" do
        source_path = File.join(base_path, "app/models/user.rb")
        expected_path = File.join(base_path, "spec/models/user_spec.rb")
        
        result = file_watcher.send(:determine_test_file_path, source_path, :model)
        expect(result).to eq(expected_path)
      end

      it "maps lib files to spec/lib" do
        source_path = File.join(base_path, "lib/custom_lib.rb")
        expected_path = File.join(base_path, "spec/lib/custom_lib_spec.rb")
        
        result = file_watcher.send(:determine_test_file_path, source_path, :library)
        expect(result).to eq(expected_path)
      end
    end

    context "with Minitest" do
      before { configuration.test_framework = :minitest }

      it "maps app/models to test/models" do
        source_path = File.join(base_path, "app/models/user.rb")
        expected_path = File.join(base_path, "test/models/user_test.rb")
        
        result = file_watcher.send(:determine_test_file_path, source_path, :model)
        expect(result).to eq(expected_path)
      end
    end
  end

  describe "#write_test_file" do
    let(:test_path) { File.join(@test_work_dir, "spec/models/user_spec.rb") }
    let(:test_content) { "# Generated test content" }

    before do
      allow($stdout).to receive(:puts)
    end

    it "creates directory if it doesn't exist" do
      expect(File.directory?(File.dirname(test_path))).to be false
      
      file_watcher.send(:write_test_file, test_path, test_content)
      
      expect(File.directory?(File.dirname(test_path))).to be true
    end

    it "writes content to file" do
      file_watcher.send(:write_test_file, test_path, test_content)
      
      expect(File.exist?(test_path)).to be true
      expect(File.read(test_path)).to eq(test_content)
    end

    it "displays success message" do
      expect($stdout).to receive(:puts).with(/✅ Test généré/)
      
      file_watcher.send(:write_test_file, test_path, test_content)
    end
  end

  describe "helper methods" do
    describe "#ruby_file?" do
      it "returns true for .rb files" do
        expect(file_watcher.send(:ruby_file?, "test.rb")).to be true
      end

      it "returns false for non-.rb files" do
        expect(file_watcher.send(:ruby_file?, "test.txt")).to be false
      end
    end

    describe "#test_file?" do
      it "detects spec files" do
        expect(file_watcher.send(:test_file?, "/path/spec/models/user_spec.rb")).to be true
      end

      it "detects test files" do
        expect(file_watcher.send(:test_file?, "/path/test/models/user_test.rb")).to be true
      end

      it "returns false for non-test files" do
        expect(file_watcher.send(:test_file?, "/path/app/models/user.rb")).to be false
      end
    end

    describe "#excluded_path?" do
      it "returns true for excluded paths" do
        expect(file_watcher.send(:excluded_path?, "/path/tmp/file.rb")).to be true
        expect(file_watcher.send(:excluded_path?, "/path/vendor/file.rb")).to be true
      end

      it "returns false for non-excluded paths" do
        expect(file_watcher.send(:excluded_path?, "/path/app/models/user.rb")).to be false
      end
    end

    describe "#in_watched_path?" do
      it "returns true for files in watched paths" do
        path = File.join(@test_work_dir, "app/models/user.rb")
        expect(file_watcher.send(:in_watched_path?, path)).to be true
      end

      it "returns false for files not in watched paths" do
        path = File.join(@test_work_dir, "config/application.rb")
        expect(file_watcher.send(:in_watched_path?, path)).to be false
      end
    end

    describe "#relative_path" do
      it "returns path relative to watch directory" do
        full_path = File.join(@test_work_dir, "app/models/user.rb")
        expected = "app/models/user.rb"
        
        expect(file_watcher.send(:relative_path, full_path)).to eq(expected)
      end
    end
  end

  describe "lazy loading" do
    describe "#ai_generator" do
      it "creates AIGenerator instance" do
        expect(Autotest::Agent::AIGenerator).to receive(:new).with(configuration)
        
        file_watcher.send(:ai_generator)
      end

      it "memoizes the instance" do
        expect(Autotest::Agent::AIGenerator).to receive(:new).once.and_return(mock_ai_generator)
        
        2.times { file_watcher.send(:ai_generator) }
      end
    end

    describe "#test_runner" do
      it "creates TestRunner instance" do
        expect(Autotest::Agent::TestRunner).to receive(:new).with(configuration)
        
        file_watcher.send(:test_runner)
      end

      it "memoizes the instance" do
        expect(Autotest::Agent::TestRunner).to receive(:new).once.and_return(mock_test_runner)
        
        2.times { file_watcher.send(:test_runner) }
      end
    end
  end
end 