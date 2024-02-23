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
    bytes32 id; // System generated unique identifier for each record
    bytes32 receivingEntityId; // client-determined unique ID for the recipient
    bytes32 resourceId; // client-determined unique ID for the resource
    bytes32 organizationId; // client-determined unique ID for the issuing organization for the resource
    bytes32 status; // encoded status of the resource
    bytes32 previous; // the previous record in the linked list
    uint statusIssueDate; // a timestamp field available to record when the status update became active
    uint timestamp; // a timestamp for this transaction
    uint nonce; // record issue nonce; this increases by one for each new record
    string ref; // URL or other unique data reference that the client can use to retrieve the resource
    string notes; // any data can go here; data as-needed for the use case
    bool exists;
  }
  mapping(bytes32 => Record) private objects; // The contract's database of resource records

  // A `Store` is a pointer to the first record in the linked list of records for a given resource.
  struct Store {
    bytes32 head;
    uint length;
    bool exists;
  }

  mapping(string => Store) private index; // The `index` maps keys (used when adding an entry, or retrieving one) to a Store record.
  uint public length = 0; // Maintain a count of the total number of records in the store.

  struct AddEntryVars {
    string key;
    uint timestamp;
    bytes32 id;
    bytes32 previous;
    uint offset;
    uint nonce;
    string notes;
  }

  /**
   * @notice Adds a new compliance entry for a given resource.
   * @dev Creates a new record in the contract, linking it to previous entries of the same resource. Emits an `AddEntry` event upon success.
   * @param key A unique key identifying the resource.
   * @param receivingEntityId The ID of the entity receiving the status update.
   * @param resourceId The ID of the resource being tracked.
   * @param organizationId The ID of the organization issuing the update.
   * @param ref A reference link or identifier for additional information about the resource.
   * @param status The new status of the resource.
   * @param statusIssueDate The timestamp when the status is issued.
   * @param notes Additional notes or comments regarding the status update.
   * @return success A boolean indicating whether the entry was successfully added.
   */
  function addEntry(
    string calldata key,
    bytes32 receivingEntityId,
    bytes32 resourceId,
    bytes32 organizationId,
    string calldata ref,
    bytes32 status,
    uint statusIssueDate,
    string calldata notes
  ) external returns (bool success) {
    AddEntryVars memory lvars;
    lvars.key = key;
    lvars.notes = notes;
    lvars.timestamp = block.timestamp;
    lvars.offset = lvars.timestamp;

    if (index[lvars.key].exists != true) {
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
          statusIssueDate,
          lvars.offset,
          lvars.nonce,
          notes,
          lvars.previous
        )
      );
      lvars.offset = lvars.offset + 1;
      // The odds are infinitesimal, but if there is an ID conflict, just change one of the input values (the offset) and recalualge to get a new ID.
    } while (objects[lvars.id].exists);

    Record memory record = Record(
      lvars.id,
      receivingEntityId,
      resourceId,
      organizationId,
      status,
      lvars.previous,
      statusIssueDate,
      lvars.timestamp,
      lvars.nonce,
      ref,
      notes,
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
    bytes32,
    bytes32,
    uint,
    uint,
    uint,
    string memory,
    string memory
  ) {
    Record memory object = objects[_id];
    return (
      object.id,
      object.receivingEntityId,
      object.resourceId,
      object.organizationId,
      object.status,
      object.previous,
      object.statusIssueDate,
      object.timestamp,
      object.nonce,
      object.ref,
      object.notes
    );
  }

  function getLatest(string calldata _key) external view returns (
    bytes32,
    bytes32,
    bytes32,
    bytes32,
    bytes32,
    bytes32,
    uint,
    uint,
    uint,
    string memory,
    string memory
  ) {
    bytes32 id = index[_key].head;
    return getEntry(id);
  }

}