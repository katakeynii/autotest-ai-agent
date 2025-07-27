# frozen_string_literal: true

RSpec.describe Autotest::Agent, type: :unit do
  it "has a version number" do
    expect(Autotest::Agent::VERSION).not_to be nil
    expect(Autotest::Agent::VERSION).to match(/\d+\.\d+\.\d+/)
  end

  it "defines required constants and modules" do
    expect(defined?(Autotest::Agent::Configuration)).to be_truthy
    expect(defined?(Autotest::Agent::FileWatcher)).to be_truthy
    expect(defined?(Autotest::Agent::AIGenerator)).to be_truthy
    expect(defined?(Autotest::Agent::TestRunner)).to be_truthy
    expect(defined?(Autotest::Agent::Reporter)).to be_truthy
    expect(defined?(Autotest::Agent::CLI)).to be_truthy
  end

  it "defines error classes hierarchy" do
    expect(Autotest::Agent::Error).to be < StandardError
    expect(Autotest::Agent::ConfigurationError).to be < Autotest::Agent::Error
    expect(Autotest::Agent::AIGenerationError).to be < Autotest::Agent::Error
    expect(Autotest::Agent::TestFrameworkError).to be < Autotest::Agent::Error
  end
end
