// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

contract Memory {
  string engram;

  function store(string calldata fact) public {
    engram = fact;
  }
}

// The Memory contract has evolved to allow the storage of data.
