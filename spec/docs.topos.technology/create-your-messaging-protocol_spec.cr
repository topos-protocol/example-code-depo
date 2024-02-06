require "../spec_helper"

describe "Create Your Messaging Protocol" do
  it "TokenSent appears correct" do
    # https://github.com/topos-protocol/topos-smart-contracts/blob/v3.1.0/contracts.interfaces/IERC20Messaging.sol
    # lines 21..27
    ierc20messagingprotocol = ExampleFile.from_github(
      org: "topos-protocol",
      repo: "topos-smart-contracts",
      path: "contracts/interfaces/IERC20Messaging.sol",
      ref: "v3.1.0")
    ierc20messagingprotocol.at(21).should match(/event TokenSent/)
    ierc20messagingprotocol.at(27).should match(/\);/)
    ierc20messagingprotocol.between(21..27).should match(/address receiver/m)
  end
end
