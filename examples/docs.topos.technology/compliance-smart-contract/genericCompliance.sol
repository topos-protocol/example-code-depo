// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

// This is a generic implementation of a contract for providing a compliance certification
// system built upon a blockchain.
//
// The intention of the contract is to define a data structure that can flexibly accommodate
// a wide variety of compliance applications. The basic concept is that the contract wraps a
// data structure which will store an immutable sequence of records about each item that
// requires compliance certification.
//
// The data structure itself is represented by a mapping which is indexed by a unique key, and
// which points to the most recent record for that key. That record is the head of a linked
// list of all previous records for that key. In this way, a very fast query will return the
// current status of any given item, while the complete history is avbailable at any time by
// performing additional queries.
contract GenericCompliance {

  string public constant version = "0.1.0";

  // event AddEntry(
  //   bytes32 id,
  //   bytes32 indexed receivingEntityId,
  //   bytes32 indexed resourceId,
  //   bytes32 indexed organizationId,
  //   string ref,
  //   bytes32 status,
  //   bytes32 hash,
  //   uint documentIssueDate,
  //   uint timestamp,
  //   uint nonce,
  //   string notes,
  //   bytes32 previous
  // );

  struct Record {
    bytes32 id;
    bytes32 receivingEntityId; // client-determined unique ID for the recipient
    bytes32 resourceId; // client-determined unique ID for the resource
    bytes32 organizationId; // client-determined unique ID for the issuing organization for the resource
    string ref; // URL or other unique data reference that the client can use to retrieve the resource
    bytes32 status; // encoded status of the resource
    bytes32 hash; // storage for a unique hash code for the resource
    uint documentIssueDate;
    uint timestamp;
    uint nonce; // record issue nonce.
    string notes; // Any data can go here, but the presumption is that it will be rarely used because of the potential for high gas costs.
    bytes32 previous; // the previous record in the linked list
    bool isValue;
  }
  mapping(bytes32 => Record) private objects; // The contract's database of resource records

  struct Store {
    bytes32 head;
    uint length;
    bool isValue;
  }
  mapping(string => Store) private index; // This mapping allows one to query the current most-recent record for a given resource key.
  uint public length = 0; // Maintain a count of the total number of records in the store.
  string[] private keys;

  // Use a structure for local variables, to work around the stack limit of 16 local variables. 
  struct AddEntryVars {
    string key;
    uint timestamp;
    bytes32 id;
    bytes32 previous;
    uint offset;
    uint nonce;
    string notes;
  }

  function addEntry(
    string calldata key,
    bytes32 receivingEntityId,
    bytes32 resourceId,
    bytes32 organizationId,
    string calldata ref,
    bytes32 status,
    bytes32 hash,
    uint documentIssueDate,
    string calldata notes
  ) public returns (bool){
    AddEntryVars memory lvars;
    lvars.key = key;
    lvars.notes = notes;
    lvars.timestamp = block.timestamp;
    lvars.offset = lvars.timestamp;

    if (index[lvars.key].isValue != true) {
      keys.push(lvars.key);
      index[lvars.key] = Store(lvars.previous,1,true);
      lvars.nonce = 0;
    } else {
      lvars.previous = index[key].head;
      lvars.nonce = index[key].length;
    }

    do {
      lvars.id = keccak256(
        abi.encodePacked(
          receivingEntityId,
          resourceId,
          organizationId,
          ref,
          status,
          hash,
          documentIssueDate,
          lvars.offset,
          lvars.nonce,
          notes,
          lvars.previous
        )
      );
      lvars.offset = lvars.offset + 1;
    } while (objects[lvars.id].isValue);

    Record memory record = Record(
      lvars.id,
      receivingEntityId,
      resourceId,
      organizationId,
      ref,
      status,
      hash,
      documentIssueDate,
      lvars.timestamp,
      lvars.nonce,
      notes,
      lvars.previous,
      true
    );

    objects[lvars.id] = record;
    index[lvars.key].head = lvars.id;
    index[lvars.key].length = index[lvars.key].length + 1;
    length = length + 1;

    // emit AddEntry(
    //   lvars.id,
    //   receivingEntityId,
    //   resourceId,
    //   organizationId,
    //   ref,
    //   status,
    //   hash,
    //   documentIssueDate,
    //   lvars.timestamp,
    //   lvars.nonce,
    //   lvars.notes,
    //   lvars.previous
    // );    
    return true;
  }

  function getEntry(bytes32 _id) public view returns (
    bytes32,
    bytes32,
    bytes32,
    bytes32,
    string memory,
    bytes32,
    bytes32,
    uint,
    uint,
    uint,
    string memory,
    bytes32
  ) {
    AddEntryVars memory lvars;
    lvars.id = _id;
    Record memory object = objects[lvars.id];
    return (
      object.id,
      object.receivingEntityId,
      object.resourceId,
      object.organizationId,
      object.ref,
      object.status,
      object.hash,
      object.documentIssueDate,
      object.timestamp,
      object.nonce,
      object.notes,
      object.previous
    );
  }

  function getLatest(string calldata _key) public view returns (
    bytes32,
    bytes32,
    bytes32,
    bytes32,
    string memory,
    bytes32,
    bytes32,
    uint,
    uint,
    uint,
    string memory,
    bytes32
  ) {
    AddEntryVars memory lvars;
    lvars.key = _key;
    bytes32 id = index[lvars.key].head;
    Record memory object = objects[id];
    return (
      object.id,
      object.receivingEntityId,
      object.resourceId,
      object.organizationId,
      object.ref,
      object.status,
      object.hash,
      object.documentIssueDate,
      object.timestamp,
      object.nonce,
      object.notes,
      object.previous
    );
  }

}
