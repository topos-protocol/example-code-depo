require "../../spec_helper"

describe "Run solidity tests for Deploy a Contract on Topos" do
  it "TokenSent appears correct" do
    result = HardhatSpecs.run("test/deploy-a-contract-on-topos.ts")

    result.passing.should eq 5
    result.failing.should eq 0
  end
end
