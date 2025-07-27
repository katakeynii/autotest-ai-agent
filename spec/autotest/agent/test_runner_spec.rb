# frozen_string_literal: true

RSpec.describe Autotest::Agent::TestRunner, type: :unit do
  let(:configuration) { test_configuration }
  subject(:test_runner) { described_class.new(configuration) }

  let(:test_files) { ["spec/models/user_spec.rb", "spec/controllers/users_controller_spec.rb"] }
  let(:sample_stdout) do
    <<~OUTPUT
      User
        validations
          should validate presence of name

      Finished in 0.12 seconds (files took 1.23 seconds to load)
      1 example, 0 failures
    OUTPUT
  end
  let(:sample_stderr) { "" }
  let(:exit_status) { double("exit_status", exitstatus: 0) }

  before do
    create_rails_structure
    test_files.each { |file| create_test_file(file, sample_generated_test) }
    
    allow(Open3).to receive(:capture3).and_return([sample_stdout, sample_stderr, exit_status])
    allow($stdout).to receive(:puts) # Silence output
  end

  describe "#initialize" do
    it "stores the configuration" do
      expect(test_runner.configuration).to eq(configuration)
    end

    it "initializes last_results as nil" do
      expect(test_runner.last_results).to be_nil
    end
  end

  describe "#run" do
    context "with specific test files" do
      it "normalizes test files" do
        expect(test_runner).to receive(:normalize_test_files).with(test_files).and_call_original
        
        test_runner.run(test_files)
      end

      it "displays test files to be run" do
        expect(test_runner).to receive(:display_test_files)
        
        test_runner.run(test_files)
      end

      it "executes tests based on framework" do
        configuration.test_framework = :rspec
        expect(test_runner).to receive(:run_rspec).with(test_files, {})
        
        test_runner.run(test_files)
      end
    end

    context "without test files" do
      it "runs all tests" do
        expect(test_runner).to receive(:run_all_tests).with({})
        
        test_runner.run(nil)
      end
    end

    context "with empty test files array" do
      it "runs all tests" do
        expect(test_runner).to receive(:run_all_tests).with({})
        
        test_runner.run([])
      end
    end

    context "with unsupported test framework" do
      before { configuration.test_framework = :unsupported }

      it "raises TestFrameworkError" do
        expect {
          test_runner.run(test_files)
        }.to raise_error(Autotest::Agent::TestFrameworkError, /Framework de test non supporté/)
      end
    end
  end

  describe "#run_all_tests" do
    context "with RSpec framework" do
      before { configuration.test_framework = :rspec }

      it "calls run_rspec with all flag" do
        expect(test_runner).to receive(:run_rspec).with([], { all: true })
        
        test_runner.run_all_tests
      end
    end

    context "with Minitest framework" do
      before { configuration.test_framework = :minitest }

      it "calls run_minitest with all flag" do
        expect(test_runner).to receive(:run_minitest).with([], { all: true })
        
        test_runner.run_all_tests
      end
    end
  end

  describe "#run_in_watch_mode" do
    before do
      allow(test_runner).to receive(:run_all_tests)
      allow(test_runner).to receive(:sleep).and_raise(Interrupt) # Simulate Ctrl+C
    end

    it "runs tests in a loop" do
      expect(test_runner).to receive(:run_all_tests).with(watch_mode: true)
      
      test_runner.run_in_watch_mode
    end

    it "handles interruption gracefully" do
      expect($stdout).to receive(:puts).with(/Mode surveillance arrêté/)
      
      test_runner.run_in_watch_mode
    end
  end

  describe "#analyze_results" do
    context "when last_results is present" do
      before do
        test_runner.instance_variable_set(:@last_results, {
          exit_code: 0,
          duration: 1.23,
          timestamp: Time.now
        })
      end

      it "displays summary" do
        expect(test_runner).to receive(:display_summary)
        test_runner.analyze_results
      end

      it "displays coverage info" do
        expect(test_runner).to receive(:display_coverage_info)
        test_runner.analyze_results
      end

      it "suggests improvements" do
        expect(test_runner).to receive(:suggest_improvements)
        test_runner.analyze_results
      end

      context "when tests have failures" do
        before do
          test_runner.instance_variable_set(:@last_results, { exit_code: 1 })
        end

        it "displays failures" do
          expect(test_runner).to receive(:display_failures)
          test_runner.analyze_results
        end
      end
    end

    context "when last_results is nil" do
      it "does nothing" do
        expect(test_runner).not_to receive(:display_summary)
        test_runner.analyze_results
      end
    end
  end

  describe "#passing?" do
    context "when tests passed" do
      before do
        test_runner.instance_variable_set(:@last_results, { exit_code: 0 })
      end

      it "returns true" do
        expect(test_runner).to be_passing
      end
    end

    context "when tests failed" do
      before do
        test_runner.instance_variable_set(:@last_results, { exit_code: 1 })
      end

      it "returns false" do
        expect(test_runner).not_to be_passing
      end
    end

    context "when no results" do
      it "returns false" do
        expect(test_runner).not_to be_passing
      end
    end
  end

  describe "#has_failures?" do
    context "when tests failed" do
      before do
        test_runner.instance_variable_set(:@last_results, { exit_code: 1 })
      end

      it "returns true" do
        expect(test_runner).to have_failures
      end
    end

    context "when tests passed" do
      before do
        test_runner.instance_variable_set(:@last_results, { exit_code: 0 })
      end

      it "returns false" do
        expect(test_runner).not_to have_failures
      end
    end
  end

  describe "#coverage_stats" do
    let(:coverage_file) { File.join(@test_work_dir, "coverage", ".last_run.json") }
    let(:coverage_data) do
      {
        "result" => {
          "covered_percent" => 85.5,
          "covered_lines" => 120,
          "total_lines" => 140
        }
      }
    end

    context "when coverage file exists" do
      before do
        FileUtils.mkdir_p(File.dirname(coverage_file))
        File.write(coverage_file, JSON.generate(coverage_data))
      end

      it "returns parsed JSON data" do
        result = test_runner.coverage_stats
        expect(result).to eq(coverage_data)
      end
    end

    context "when coverage file doesn't exist" do
      it "returns nil" do
        expect(test_runner.coverage_stats).to be_nil
      end
    end

    context "when coverage file has invalid JSON" do
      before do
        FileUtils.mkdir_p(File.dirname(coverage_file))
        File.write(coverage_file, "invalid json")
      end

      it "returns nil" do
        expect(test_runner.coverage_stats).to be_nil
      end
    end
  end

  describe "#normalize_test_files" do
    it "returns nil for nil input" do
      expect(test_runner.send(:normalize_test_files, nil)).to be_nil
    end

    it "returns existing files only" do
      valid_file = test_files.first
      invalid_file = "spec/non_existent_spec.rb"
      
      result = test_runner.send(:normalize_test_files, [valid_file, invalid_file])
      expect(result).to eq([valid_file])
    end

    it "converts single file to array" do
      valid_file = test_files.first
      
      result = test_runner.send(:normalize_test_files, valid_file)
      expect(result).to eq([valid_file])
    end
  end

  describe "#run_rspec" do
    before { configuration.test_framework = :rspec }

    it "builds correct command for specific files" do
      expected_command = ["bundle", "exec", "rspec"] + test_files + ["--format", "documentation", "--color"]
      
      expect(Open3).to receive(:capture3)
        .with({ "COVERAGE" => "true" }, expected_command.join(" "), hash_including(chdir: @test_work_dir))
        .and_return([sample_stdout, sample_stderr, exit_status])
      
      test_runner.send(:run_rspec, test_files, {})
    end

    it "builds correct command for all tests" do
      expected_command = ["bundle", "exec", "rspec", "spec", "--format", "documentation", "--color"]
      
      expect(Open3).to receive(:capture3)
        .with({ "COVERAGE" => "true" }, expected_command.join(" "), hash_including(chdir: @test_work_dir))
        .and_return([sample_stdout, sample_stderr, exit_status])
      
      test_runner.send(:run_rspec, [], { all: true })
    end

    it "omits formatting options in watch mode" do
      expected_command = ["bundle", "exec", "rspec", "spec"]
      
      expect(Open3).to receive(:capture3)
        .with({ "COVERAGE" => "true" }, expected_command.join(" "), hash_including(chdir: @test_work_dir))
        .and_return([sample_stdout, sample_stderr, exit_status])
      
      test_runner.send(:run_rspec, [], { all: true, watch_mode: true })
    end
  end

  describe "#run_minitest" do
    before { configuration.test_framework = :minitest }

    it "builds correct command for specific files" do
      expected_command = ["bundle", "exec", "rails", "test"] + test_files + ["--verbose"]
      
      expect(Open3).to receive(:capture3)
        .with({ "COVERAGE" => "true" }, expected_command.join(" "), hash_including(chdir: @test_work_dir))
        .and_return([sample_stdout, sample_stderr, exit_status])
      
      test_runner.send(:run_minitest, test_files, {})
    end

    it "builds correct command for all tests" do
      expected_command = ["bundle", "exec", "rails", "test", "--verbose"]
      
      expect(Open3).to receive(:capture3)
        .with({ "COVERAGE" => "true" }, expected_command.join(" "), hash_including(chdir: @test_work_dir))
        .and_return([sample_stdout, sample_stderr, exit_status])
      
      test_runner.send(:run_minitest, [], { all: true })
    end
  end

  describe "#execute_command" do
    let(:command_parts) { ["bundle", "exec", "rspec", "spec"] }
    let(:env) { { "COVERAGE" => "true" } }

    it "captures command execution" do
      expect(Open3).to receive(:capture3)
        .with(env, command_parts.join(" "), hash_including(chdir: @test_work_dir))
        .and_return([sample_stdout, sample_stderr, exit_status])
      
      test_runner.send(:execute_command, command_parts, env, {})
    end

    it "stores results" do
      start_time = Time.now
      allow(Time).to receive(:now).and_return(start_time, start_time + 1.5)
      
      test_runner.send(:execute_command, command_parts, env, {})
      
      results = test_runner.last_results
      expect(results[:command]).to eq(command_parts.join(" "))
      expect(results[:stdout]).to eq(sample_stdout)
      expect(results[:stderr]).to eq(sample_stderr)
      expect(results[:exit_code]).to eq(0)
      expect(results[:duration]).to eq(1.5)
    end

    it "displays execution summary" do
      expect(test_runner).to receive(:display_execution_summary).with(0, kind_of(Float))
      
      test_runner.send(:execute_command, command_parts, env, {})
    end

    context "when not quiet" do
      it "displays test output" do
        expect(test_runner).to receive(:display_test_output)
          .with(sample_stdout, sample_stderr, {})
        
        test_runner.send(:execute_command, command_parts, env, {})
      end
    end

    context "when quiet" do
      it "does not display test output" do
        expect(test_runner).to receive(:display_test_output)
          .with(sample_stdout, sample_stderr, { quiet: true })
        
        test_runner.send(:execute_command, command_parts, env, { quiet: true })
      end
    end
  end

  describe "#display_execution_summary" do
    context "when tests pass" do
      it "displays success message" do
        expect($stdout).to receive(:puts).with(/✅ Tests réussis en/)
        
        test_runner.send(:display_execution_summary, 0, 1.23)
      end
    end

    context "when tests fail" do
      it "displays failure message" do
        expect($stdout).to receive(:puts).with(/❌ Tests échoués en/)
        
        test_runner.send(:display_execution_summary, 1, 1.23)
      end
    end
  end

  describe "#display_summary" do
    let(:timestamp) { Time.now }
    
    before do
      test_runner.instance_variable_set(:@last_results, {
        duration: 1.23,
        timestamp: timestamp,
        exit_code: 0
      })
    end

    it "displays execution summary" do
      expect($stdout).to receive(:puts).with(/📈 Résumé d'exécution :/)
      expect($stdout).to receive(:puts).with(/⏱️  Durée : 1.23 secondes/)
      expect($stdout).to receive(:puts).with(/✅ Statut : SUCCÈS/)
      
      test_runner.send(:display_summary)
    end
  end

  describe "#display_coverage_info" do
    let(:coverage_data) do
      {
        "result" => {
          "covered_percent" => 85.5
        }
      }
    end

    before do
      allow(test_runner).to receive(:coverage_stats).and_return(coverage_data)
    end

    context "when coverage meets threshold" do
      before { configuration.coverage_threshold = 80 }

      it "displays success message" do
        expect($stdout).to receive(:puts).with(/✅ 85.5% \(seuil : 80%\)/)
        
        test_runner.send(:display_coverage_info)
      end
    end

    context "when coverage below threshold" do
      before { configuration.coverage_threshold = 90 }

      it "displays warning message" do
        expect($stdout).to receive(:puts).with(/⚠️  85.5% \(seuil : 90%\)/)
        
        test_runner.send(:display_coverage_info)
      end
    end

    context "when coverage report exists" do
      before do
        coverage_path = File.join(@test_work_dir, "coverage", "index.html")
        FileUtils.mkdir_p(File.dirname(coverage_path))
        File.write(coverage_path, "<html></html>")
      end

      it "displays report path" do
        expect($stdout).to receive(:puts).with(/📄 Rapport détaillé :/)
        
        test_runner.send(:display_coverage_info)
      end
    end
  end

  describe "#suggest_improvements" do
    context "when tests are passing" do
      before do
        test_runner.instance_variable_set(:@last_results, { exit_code: 0 })
      end

      it "does not suggest improvements" do
        expect($stdout).not_to receive(:puts).with(/💡 Suggestions d'amélioration :/)
        
        test_runner.send(:suggest_improvements)
      end
    end

    context "when tests are failing" do
      before do
        test_runner.instance_variable_set(:@last_results, { 
          exit_code: 1,
          stderr: "syntax error",
          stdout: "factory not found"
        })
        allow(test_runner).to receive(:coverage_stats).and_return({
          "result" => { "covered_percent" => 60 }
        })
        configuration.coverage_threshold = 80
      end

      it "suggests various improvements" do
        expect($stdout).to receive(:puts).with(/💡 Suggestions d'amélioration :/)
        expect($stdout).to receive(:puts).with(/Améliorer la couverture de code/)
        expect($stdout).to receive(:puts).with(/Corriger les erreurs de syntaxe/)
        expect($stdout).to receive(:puts).with(/Vérifier les factory_bot/)
        
        test_runner.send(:suggest_improvements)
      end
    end
  end

  describe "#extract_failures_from_output" do
    context "with RSpec output" do
      let(:rspec_output) do
        <<~OUTPUT
          Some test output

          Failures:

          1) User validations should validate presence of name
             Failure/Error: expect(user.name).to be_present
               expected "" to be present
             # ./spec/models/user_spec.rb:10

          2) User validations should validate uniqueness of email
             Failure/Error: expect(user).to be_valid
               expected User to be valid
             # ./spec/models/user_spec.rb:15

          Finished in 0.12 seconds
        OUTPUT
      end

      before { configuration.test_framework = :rspec }

      it "extracts failure details" do
        failures = test_runner.send(:extract_failures_from_output, rspec_output, "")
        
        expect(failures.size).to eq(2)
        expect(failures.first).to include("User validations should validate presence of name")
        expect(failures.second).to include("User validations should validate uniqueness of email")
      end
    end

    context "with Minitest output" do
      let(:minitest_output) do
        <<~OUTPUT
          1) Failure:
          UserTest#test_validation [test/models/user_test.rb:10]:
          Expected true to be false

          2) Error:
          UserTest#test_creation [test/models/user_test.rb:15]:
          NoMethodError: undefined method `create' for User:Class
        OUTPUT
      end

      before { configuration.test_framework = :minitest }

      it "extracts failure details" do
        failures = test_runner.send(:extract_failures_from_output, minitest_output, "")
        
        expect(failures.size).to eq(2)
        expect(failures).to include("Failure:")
        expect(failures).to include("Error:")
      end
    end

    context "with stderr content" do
      it "includes stderr errors" do
        failures = test_runner.send(:extract_failures_from_output, "", "LoadError: cannot load such file")
        
        expect(failures.size).to eq(1)
        expect(failures.first).to include("Erreurs système")
        expect(failures.first).to include("LoadError")
      end
    end
  end
end 