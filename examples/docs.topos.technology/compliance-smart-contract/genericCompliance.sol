// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

// This is a contract that implements a generic data compliance contract.
// It allows for the storage of linked lists of elements, where each element
// represents a status and optional notes for some resource, owned by some
// entity, issued by some organization, on a given date.
// The linked list lets one traverse a complete history of status changes
// for a given resource.
//
// The implementation builds the linked list backwards, updating the head with
// every new element, which each new element pointing to the previous head element.
// In this way, the most common use case, which is to query what the current state
// is for a given resource, will be a single element query, and it will never have
// to traverse the linked list.
contract GenericCompliance {
  event AddEntry(
    string indexed key,
    bytes32 id,
    bytes32 indexed receivingEntityId,
    bytes32 indexed resourceId,
    bytes32 organizationId,
    bytes32 status
  );

  struct Record {
    bytes32 id;
    bytes32 receivingEntityId; // client-determined unique ID for the recipient
    bytes32 resourceId; // client-determined unique ID for the resource
    bytes32 organizationId; // client-determined unique ID for the issuing organization for the resource
    string ref; // URL or other unique data reference that the client can use to retrieve the resource
    bytes32 status; // encoded status of the resource
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
          documentIssueDate,
          lvars.offset,
          lvars.nonce,
          notes,
          lvars.previous
        )
      );
      lvars.offset = lvars.offset + 1;
      // The odds are infinitesimal, but if there is an ID conflict, just change one of the input values (the offset) and recalualge to get a new ID.
    } while (objects[lvars.id].isValue);

    Record memory record = Record(
      lvars.id,
      receivingEntityId,
      resourceId,
      organizationId,
      ref,
      status,
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

    emit AddEntry(
      key,
      lvars.id,
      receivingEntityId,
      resourceId,
      organizationId,
      status
    );    
     return true;
  }

  function getEntry(bytes32 _id) public view returns (
    bytes32,
    bytes32,
    bytes32,
    bytes32,
    string memory,
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
      object.documentIssueDate,
      object.timestamp,
      object.nonce,
      object.notes,
      object.previous
    );
  }

}