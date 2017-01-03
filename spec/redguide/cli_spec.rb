require "spec_helper"

describe Redguide::Cli do
  it "has a version number" do
    expect(Redguide::Cli::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
