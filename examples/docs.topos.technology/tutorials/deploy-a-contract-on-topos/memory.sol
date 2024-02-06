// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

contract Memory {
  string engram;

  function store(string calldata fact) public {
    require(bytes(fact).length < 256);
    engram = fact;
  }

  function recall() public view returns (string memory) {
    return engram;
  }
}
