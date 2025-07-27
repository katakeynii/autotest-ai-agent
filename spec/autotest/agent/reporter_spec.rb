# frozen_string_literal: true

RSpec.describe Autotest::Agent::Reporter, type: :unit do
  let(:configuration) { test_configuration }
  let(:mock_test_runner) { instance_double(Autotest::Agent::TestRunner) }
  subject(:reporter) { described_class.new(configuration, mock_test_runner) }

  let(:sample_coverage_stats) do
    {
      "result" => {
        "covered_percent" => 85.5,
        "covered_lines" => 120,
        "total_lines" => 140,
        "groups" => {
          "Controllers" => {
            "files" => {
              "app/controllers/users_controller.rb" => {
                "covered_percent" => 90.0,
                "covered_lines" => 18,
                "missed_lines" => 2,
                "lines_of_code" => 20
              }
            }
          }
        }
      }
    }
  end

  before do
    create_rails_structure
    allow(mock_test_runner).to receive(:coverage_stats).and_return(sample_coverage_stats)
    allow(mock_test_runner).to receive(:last_results).and_return({
      exit_code: 0,
      duration: 1.23,
      passing: true,
      command: "bundle exec rspec",
      timestamp: Time.now
    })
    allow($stdout).to receive(:puts)
  end

  describe "#initialize" do
    it "stores configuration and test runner" do
      expect(reporter.configuration).to eq(configuration)
      expect(reporter.test_runner).to eq(mock_test_runner)
    end
  end

  describe "#generate_full_report" do
    let(:output_file) { File.join(@test_work_dir, "report.html") }

    it "collects report data" do
      expect(reporter).to receive(:collect_report_data).and_call_original
      
      reporter.generate_full_report(output_file)
    end

    it "generates HTML report" do
      expect(reporter).to receive(:generate_html_report).and_call_original
      
      reporter.generate_full_report(output_file)
    end

    it "writes report to file" do
      reporter.generate_full_report(output_file)
      
      expect(File.exist?(output_file)).to be true
      content = File.read(output_file)
      expect(content).to include("<html>")
      expect(content).to include("Autotest IA")
    end

    it "displays success message" do
      expect($stdout).to receive(:puts).with(/✅ Rapport généré :/)
      
      reporter.generate_full_report(output_file)
    end

    it "returns output file path" do
      result = reporter.generate_full_report(output_file)
      expect(result).to eq(output_file)
    end

    context "when no output file specified" do
      it "uses default path" do
        expect(reporter).to receive(:default_report_path).and_call_original
        
        reporter.generate_full_report
      end
    end
  end

  describe "#generate_coverage_report" do
    context "when coverage data is available" do
      it "displays coverage summary" do
        expect(reporter).to receive(:display_coverage_summary)
        
        reporter.generate_coverage_report
      end

      it "displays uncovered files" do
        expect(reporter).to receive(:display_uncovered_files)
        
        reporter.generate_coverage_report
      end

      it "suggests improvements" do
        expect(reporter).to receive(:suggest_coverage_improvements)
        
        reporter.generate_coverage_report
      end

      it "returns coverage data" do
        result = reporter.generate_coverage_report
        expect(result).to be_a(Hash)
        expect(result[:covered_percent]).to eq(85.5)
      end
    end

    context "when no coverage data" do
      before do
        allow(reporter).to receive(:analyze_coverage_data).and_return(nil)
      end

      it "returns nil" do
        result = reporter.generate_coverage_report
        expect(result).to be_nil
      end
    end
  end

  describe "#generate_trend_report" do
    it "collects trend data for specified days" do
      expect(reporter).to receive(:collect_trend_data).with(7).and_call_original
      
      reporter.generate_trend_report(7)
    end

    it "displays trend analysis" do
      expect(reporter).to receive(:display_trend_analysis)
      
      reporter.generate_trend_report
    end

    it "returns trend data" do
      result = reporter.generate_trend_report(5)
      expect(result).to be_an(Array)
      expect(result.size).to eq(5)
    end
  end

  describe "#generate_quality_report" do
    it "analyzes code quality" do
      expect(reporter).to receive(:analyze_code_quality).and_call_original
      
      reporter.generate_quality_report
    end

    it "displays quality metrics" do
      expect(reporter).to receive(:display_quality_metrics)
      
      reporter.generate_quality_report
    end

    it "suggests quality improvements" do
      expect(reporter).to receive(:suggest_quality_improvements)
      
      reporter.generate_quality_report
    end

    it "returns quality data" do
      result = reporter.generate_quality_report
      expect(result).to be_a(Hash)
      expect(result).to have_key(:test_files_count)
      expect(result).to have_key(:source_files_count)
    end
  end

  describe "#export_json" do
    let(:output_file) { File.join(@test_work_dir, "report.json") }

    it "collects report data" do
      expect(reporter).to receive(:collect_report_data).and_call_original
      
      reporter.export_json(output_file)
    end

    it "writes JSON to file" do
      reporter.export_json(output_file)
      
      expect(File.exist?(output_file)).to be true
      content = JSON.parse(File.read(output_file))
      expect(content).to have_key("timestamp")
      expect(content).to have_key("project_info")
    end

    it "displays success message" do
      expect($stdout).to receive(:puts).with(/📄 Données exportées :/)
      
      reporter.export_json(output_file)
    end
  end

  describe "#collect_report_data" do
    it "includes all required sections" do
      result = reporter.send(:collect_report_data)
      
      expect(result).to have_key(:timestamp)
      expect(result).to have_key(:project_info)
      expect(result).to have_key(:test_framework)
      expect(result).to have_key(:test_results)
      expect(result).to have_key(:coverage)
      expect(result).to have_key(:quality)
      expect(result).to have_key(:files_analyzed)
      expect(result).to have_key(:ai_stats)
    end

    it "includes project information" do
      result = reporter.send(:collect_report_data)
      project_info = result[:project_info]
      
      expect(project_info).to have_key(:name)
      expect(project_info).to have_key(:ruby_version)
      expect(project_info).to have_key(:gem_version)
      expect(project_info[:gem_version]).to eq(Autotest::Agent::VERSION)
    end
  end

  describe "#analyze_coverage_data" do
    context "when test runner has coverage stats" do
      it "returns formatted coverage data" do
        result = reporter.send(:analyze_coverage_data)
        
        expect(result).to have_key(:covered_percent)
        expect(result).to have_key(:covered_lines)
        expect(result).to have_key(:total_lines)
        expect(result).to have_key(:files)
        expect(result[:covered_percent]).to eq(85.5)
      end

      it "analyzes file coverage" do
        result = reporter.send(:analyze_coverage_data)
        files = result[:files]
        
        expect(files).to be_an(Array)
        expect(files.first).to have_key(:path)
        expect(files.first).to have_key(:covered_percent)
      end
    end

    context "when no coverage stats available" do
      before do
        allow(mock_test_runner).to receive(:coverage_stats).and_return(nil)
      end

      it "returns nil" do
        result = reporter.send(:analyze_coverage_data)
        expect(result).to be_nil
      end
    end
  end

  describe "#analyze_code_quality" do
    before do
      # Create some test files
      create_test_file("spec/models/user_spec.rb", sample_generated_test)
      create_test_file("spec/controllers/users_controller_spec.rb", sample_generated_test)
      create_test_model("user")
      create_test_controller("users")
    end

    it "counts test files correctly" do
      result = reporter.send(:analyze_code_quality)
      expect(result[:test_files_count]).to eq(2)
    end

    it "counts source files correctly" do
      result = reporter.send(:analyze_code_quality)
      expect(result[:source_files_count]).to eq(2)
    end

    it "calculates test to source ratio" do
      result = reporter.send(:analyze_code_quality)
      expect(result[:test_to_source_ratio]).to eq(100.0)
    end

    it "calculates average file size" do
      result = reporter.send(:analyze_code_quality)
      expect(result[:average_file_size]).to be > 0
    end

    it "finds large files" do
      # Create a large file
      large_content = "# " + "line\n" * 250
      create_test_file("app/models/large_model.rb", large_content)
      
      result = reporter.send(:analyze_code_quality)
      expect(result[:large_files]).not_to be_empty
      expect(result[:large_files].first[:lines]).to be > 200
    end
  end

  describe "#display_coverage_summary" do
    let(:coverage_data) do
      {
        covered_percent: 85.5,
        covered_lines: 120,
        total_lines: 140
      }
    end

    before { configuration.coverage_threshold = 80 }

    it "displays coverage percentage" do
      expect($stdout).to receive(:puts).with(/📈 Couverture globale : 85.5%/)
      
      reporter.send(:display_coverage_summary, coverage_data)
    end

    it "displays line counts" do
      expect($stdout).to receive(:puts).with(/📝 Lignes couvertes : 120\/140/)
      
      reporter.send(:display_coverage_summary, coverage_data)
    end

    context "when coverage meets threshold" do
      it "displays success message" do
        expect($stdout).to receive(:puts).with(/✅ Objectif atteint/)
        
        reporter.send(:display_coverage_summary, coverage_data)
      end
    end

    context "when coverage below threshold" do
      before { configuration.coverage_threshold = 90 }

      it "displays warning with gap" do
        expect($stdout).to receive(:puts).with(/⚠️  Objectif manqué de 4.5%/)
        
        reporter.send(:display_coverage_summary, coverage_data)
      end
    end
  end

  describe "#display_uncovered_files" do
    let(:coverage_data) do
      {
        files: [
          { path: "app/models/user.rb", covered_percent: 95.0 },
          { path: "app/models/post.rb", covered_percent: 75.0 },
          { path: "app/models/comment.rb", covered_percent: 60.0 }
        ]
      }
    end

    it "displays files below 80% coverage" do
      expect($stdout).to receive(:puts).with(/🔍 Fichiers à améliorer/)
      expect($stdout).to receive(:puts).with(/post.rb : 75.0%/)
      expect($stdout).to receive(:puts).with(/comment.rb : 60.0%/)
      
      reporter.send(:display_uncovered_files, coverage_data)
    end

    context "when all files have good coverage" do
      let(:coverage_data) do
        { files: [{ path: "app/models/user.rb", covered_percent: 95.0 }] }
      end

      it "does not display anything" do
        expect($stdout).not_to receive(:puts).with(/🔍 Fichiers à améliorer/)
        
        reporter.send(:display_uncovered_files, coverage_data)
      end
    end
  end

  describe "#suggest_coverage_improvements" do
    context "with low coverage" do
      let(:coverage_data) { { covered_percent: 65.0 } }

      it "suggests basic test additions" do
        expect($stdout).to receive(:puts).with(/Prioriser l'ajout de tests de base/)
        
        reporter.send(:suggest_coverage_improvements, coverage_data)
      end
    end

    context "with medium coverage" do
      let(:coverage_data) { { covered_percent: 80.0 } }

      it "suggests edge case testing" do
        expect($stdout).to receive(:puts).with(/Ajouter des tests pour les cas limites/)
        
        reporter.send(:suggest_coverage_improvements, coverage_data)
      end
    end

    context "with high coverage" do
      let(:coverage_data) { { covered_percent: 90.0 } }

      it "suggests optimization" do
        expect($stdout).to receive(:puts).with(/Optimiser les tests existants/)
        
        reporter.send(:suggest_coverage_improvements, coverage_data)
      end
    end
  end

  describe "#display_quality_metrics" do
    let(:quality_data) do
      {
        test_to_source_ratio: 85.5,
        average_file_size: 45,
        source_files_count: 12,
        test_files_count: 10
      }
    end

    it "displays all quality metrics" do
      expect($stdout).to receive(:puts).with(/🔍 Métriques de qualité :/)
      expect($stdout).to receive(:puts).with(/📊 Ratio tests\/source : 85.5%/)
      expect($stdout).to receive(:puts).with(/📏 Taille moyenne des fichiers : 45 lignes/)
      expect($stdout).to receive(:puts).with(/📁 Fichiers source : 12/)
      expect($stdout).to receive(:puts).with(/🧪 Fichiers de test : 10/)
      
      reporter.send(:display_quality_metrics, quality_data)
    end
  end

  describe "#suggest_quality_improvements" do
    context "with low test ratio" do
      let(:quality_data) { { test_to_source_ratio: 30.0, large_files: [] } }

      it "suggests increasing test count" do
        expect($stdout).to receive(:puts).with(/Augmenter le nombre de tests/)
        
        reporter.send(:suggest_quality_improvements, quality_data)
      end
    end

    context "with large files" do
      let(:quality_data) do
        { 
          test_to_source_ratio: 80.0,
          large_files: [
            { path: "app/models/huge.rb", lines: 350 }
          ]
        }
      end

      it "suggests refactoring large files" do
        expect($stdout).to receive(:puts).with(/Refactoriser les gros fichiers/)
        
        reporter.send(:suggest_quality_improvements, quality_data)
      end
    end
  end

  describe "#display_trend_analysis" do
    context "with improving trend" do
      let(:trend_data) do
        [
          { date: Date.today - 7, coverage: 75 },
          { date: Date.today, coverage: 85 }
        ]
      end

      it "displays improvement message" do
        expect($stdout).to receive(:puts).with(/↗️  Couverture en amélioration \(\+10%\)/)
        
        reporter.send(:display_trend_analysis, trend_data)
      end
    end

    context "with declining trend" do
      let(:trend_data) do
        [
          { date: Date.today - 7, coverage: 90 },
          { date: Date.today, coverage: 80 }
        ]
      end

      it "displays decline message" do
        expect($stdout).to receive(:puts).with(/↘️  Couverture en baisse \(-10%\)/)
        
        reporter.send(:display_trend_analysis, trend_data)
      end
    end

    context "with stable trend" do
      let(:trend_data) do
        [
          { date: Date.today - 7, coverage: 80 },
          { date: Date.today, coverage: 80 }
        ]
      end

      it "displays stable message" do
        expect($stdout).to receive(:puts).with(/➡️  Couverture stable/)
        
        reporter.send(:display_trend_analysis, trend_data)
      end
    end
  end

  describe "#generate_html_report" do
    let(:report_data) do
      {
        timestamp: Time.now,
        project_info: { name: "Test Project" },
        coverage: { covered_percent: 85.5 },
        quality: { source_files_count: 10 },
        test_results: { passing: true }
      }
    end

    it "generates valid HTML" do
      result = reporter.send(:generate_html_report, report_data)
      
      expect(result).to include("<!DOCTYPE html>")
      expect(result).to include("<html>")
      expect(result).to include("Test Project")
      expect(result).to include("85.5%")
    end

    it "includes all sections" do
      result = reporter.send(:generate_html_report, report_data)
      
      expect(result).to include("Couverture de Code")
      expect(result).to include("Qualité du Code")
      expect(result).to include("Résultats des Tests")
    end
  end

  describe "#default_report_path" do
    it "returns path in tmp directory" do
      result = reporter.send(:default_report_path)
      expect(result).to include("tmp/autotest_ia_report.html")
    end
  end

  describe "helper methods" do
    describe "#extract_project_name" do
      context "with Rails application" do
        before do
          create_test_file("config/application.rb", "module TestApp\n  class Application\nend")
        end

        it "extracts name from application.rb" do
          result = reporter.send(:extract_project_name)
          expect(result).to eq("TestApp")
        end
      end

      context "without Rails application" do
        it "uses directory name" do
          result = reporter.send(:extract_project_name)
          expect(result).to be_a(String)
        end
      end
    end

    describe "#rails_application?" do
      context "with Rails files" do
        before do
          create_test_file("config/application.rb", "# Rails app")
        end

        it "returns true" do
          expect(reporter.send(:rails_application?)).to be true
        end
      end

      context "without Rails files" do
        it "returns false" do
          expect(reporter.send(:rails_application?)).to be false
        end
      end
    end
  end
end 