// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

contract Memory {
  string engram;

  function store(string calldata fact) public {
    require(bytes(fact).length < 256);
    engram = fact;
  }
}

// A string can be any length, which means that storing a string can
// has an unbounded gas cost. A large string could potentially be very
// expensive to store. So this adds a check which requires that the
// string be less than 256 bytes in length.
