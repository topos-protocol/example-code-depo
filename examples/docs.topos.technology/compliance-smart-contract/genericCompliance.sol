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

  struct generateIdVars {
    bytes32 receivingEntityId;
    bytes32 resourceId;
    bytes32 organizationId;
    bytes32 previous;
    bytes32 status;
    uint statusIssueDate;
    uint nonce;
    string ref;
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

    setNonceAndPrevious(lvars);

    lvars.id = generateId(
      generateIdVars(
        receivingEntityId,
        resourceId,
        organizationId,
        lvars.previous,
        status,
        statusIssueDate,
        lvars.nonce,
        ref,
        notes
      )
    );

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

    updateObjectAndIndex(lvars, record);

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

  /**
  * @notice Sets the `nonce` and the `previous` values, and if this is the first record, establishes the `Store` record in the `index`.
  * @param lvars The `lvars` of the current record.
  */
  function setNonceAndPrevious(AddEntryVars memory lvars) internal {
    if (index[lvars.key].exists != true) {
      index[lvars.key] = Store(lvars.previous,1,true);
      lvars.nonce = 0;
    } else {
      lvars.previous = index[lvars.key].head;
      lvars.nonce = index[lvars.key].length;
    }
  }

  /**
  * @notice Generates a unique ID for the object described by the provided data. It checks for an id conflic, and mutates the ID in the (very unlikely) case of a conflict.
  * @dev Takes an instance of `generateIdVars` containing all of the variables which describe a given record, and hashes those into a `bytes32` using `keccak256`.
  * @param gvars The `generateIdVars` instance that describes the record.
  * @return id A `bytes32` encoding of the `keccak256` value that was calculated.
  */
  function generateId(
    generateIdVars memory gvars
  ) internal view returns (
    bytes32
  ) {
      bytes32 id;
      uint offset = 0;

      do {
        id = keccak256(
        abi.encodePacked(
          gvars.receivingEntityId,
          gvars.resourceId,
          gvars.organizationId,
          gvars.ref,
          gvars.status,
          gvars.statusIssueDate,
          offset,
          gvars.nonce,
          gvars.notes,
          gvars.previous
        )
      );
      offset = offset + 1;
      // The odds are infinitesimal, but if there is an ID conflict, just change one of the input values (the offset) and recalualge to get a new ID.
    } while (objects[id].exists);

    return id;
  }

  /**
  * @notice Update the object store and the index head and length for the new record.
  */
  function updateObjectAndIndex(
    AddEntryVars memory lvars,
    Record memory record
  ) internal {
    objects[lvars.id] = record;
    index[lvars.key].head = lvars.id;
    index[lvars.key].length = index[lvars.key].length + 1;
    length = length + 1;
  }

  /**
  * @notice Retrieves the compliance record for a given ID.
  * @dev Returns detailed information about the compliance status of a resource. This includes metadata like the issuing organization, status, and timestamps.
  * @param _id The unique identifier of the compliance record to retrieve.
  * @return id The unique identifier of the retrieved compliance record.
  * @return receivingEntityId The ID of the entity receiving the status update.
  * @return resourceId The ID of the resource being tracked.
  * @return organizationId The ID of the organization issuing the update.
  * @return status The current status of the resource.
  * @return previous The ID of the previous record in the compliance history.
  * @return statusIssueDate The timestamp when the status was issued.
  * @return timestamp The timestamp when this record was created.
  * @return nonce The nonce of the record, indicating its sequence in the compliance history.
  * @return ref A reference link or identifier for additional information about the resource.
  * @return notes Additional notes or comments regarding the status update.
  * @return exists A bool value that is true if this is a record which actually exists on-chain (it has been previously stored).
  */
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
    string memory,
    bool
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
      object.notes,
      object.exists
    );
  }

  /**
  * @notice Retrieves the most recent compliance record for a given key.
  * @dev Returns detailed information about the compliance status of a resource. This includes metadata like the issuing organization, status, and timestamps. All prior records can be traversed by retrieving successive records pointed to by the `previous` ID, until that field contains an empty value.
  * @param _key The unique key of the chain of compliance records to access.
  * @return id The unique identifier of the retrieved compliance record.
  * @return receivingEntityId The ID of the entity receiving the status update.
  * @return resourceId The ID of the resource being tracked.
  * @return organizationId The ID of the organization issuing the update.
  * @return status The current status of the resource.
  * @return previous The ID of the previous record in the compliance history.
  * @return statusIssueDate The timestamp when the status was issued.
  * @return timestamp The timestamp when this record was created.
  * @return nonce The nonce of the record, indicating its sequence in the compliance history.
  * @return ref A reference link or identifier for additional information about the resource.
  * @return notes Additional notes or comments regarding the status update.
  * @return a bool value that is true if this is a record which actually exists on-chain (it has been previously stored).
  */
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
    string memory,
    bool
  ) {
    bytes32 id = index[_key].head;
    return getEntry(id);
  }

}