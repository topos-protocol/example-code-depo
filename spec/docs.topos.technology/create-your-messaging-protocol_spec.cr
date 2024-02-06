require "../spec_helper"

describe "Create Your Messaging Protocol" do
  it "TokenSent is where it is expected" do
    ierc20messagingprotocol = ExampleFile.new("submodules/topos-smart-contracts/contracts/interfaces/IERC20Messaging.sol")
    ierc20messagingprotocol.at(21).should match(/event TokenSent/)
    ierc20messagingprotocol.at(27).should match(/\);/)
    ierc20messagingprotocol.between(21..27).should match(/address receiver/m)
  end
end
