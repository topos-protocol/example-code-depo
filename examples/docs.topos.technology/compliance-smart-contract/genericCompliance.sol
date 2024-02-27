// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import "@openzeppelin/contracts/access/AccessControl.sol";

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
contract GenericCompliance is AccessControl {
    /// @notice Emitted when a new entry is added to the compliance record.
    /// @param key The unique key associated with the entry.
    /// @param id The unique identifier of the newly added record.
    /// @param receivingEntityId The ID of the entity receiving the status update.
    /// @param resourceId The ID of the resource for which the status is updated.
    /// @param organizationId The ID of the organization issuing the status update.
    /// @param status The new status of the resource.
    event AddEntry(
        string indexed key,
        bytes32 id,
        bytes32 indexed receivingEntityId,
        bytes32 indexed resourceId,
        bytes32 organizationId,
        bytes32 status
    );

    /// @notice Indicates an operation was attempted by an address with insufficient authorization for a specific role and access level.
    /// @param addr The address attempting the operation.
    /// @param id The identifier of the role being accessed.
    /// @param variant The variant of the role (e.g., ENTITY, RESOURCE, ORGANIZATION).
    /// @param access The access level required for the operation (e.g., READ, WRITE).
    error InsufficientRoleAuthorized(
        address addr,
        bytes32 id,
        RoleVariant variant,
        RoleAccess access
    );

    /// @notice Indicates an address does not have enough roles available to perform an operation requiring a specific access level.
    /// @param addr The address attempting the operation.
    /// @param access The access level required for the operation.
    error InsufficientRolesAvailable(address addr, RoleAccess access);

    /// @notice Indicates an address is not authorized to create a new role.
    /// @param addr The address attempting to create a new role.
    error NoCreateRole(address addr);

    bytes32 public constant CREATE_ROLE = keccak256("CREATE_ROLE");

    mapping(bytes32 => bytes32[3]) public entityRoles;
    mapping(bytes32 => bytes32[3]) public resourceRoles;
    mapping(bytes32 => bytes32[3]) public organizationRoles;

    /// @dev Represents a record in the compliance tracking system.
    /// @param id System generated unique identifier for each record.
    /// @param receivingEntityId Client-determined unique ID for the recipient.
    /// @param resourceId Client-determined unique ID for the resource.
    /// @param organizationId Client-determined unique ID for the issuing organization for the resource.
    /// @param status Encoded status of the resource.
    /// @param previous The previous record in the linked list.
    /// @param owner The address of the owner of the record.
    /// @param statusIssueDate A timestamp field available to record when the status update became active.
    /// @param timestamp A timestamp for this transaction.
    /// @param nonce Record issue nonce; this increases by one for each new record.
    /// @param ref URL or other unique data reference that the client can use to retrieve the resource.
    /// @param exists Boolean indicating if the record exists (used for validation).
    struct Record {
        bytes32 id;
        bytes32 receivingEntityId;
        bytes32 resourceId;
        bytes32 organizationId;
        bytes32 status;
        bytes32 previous;
        address owner;
        uint statusIssueDate;
        uint timestamp;
        uint nonce;
        string ref;
        bool exists;
    }

    mapping(bytes32 => Record) private objects; // The contract's database of resource records

    /// @title Store
    /// @dev A `Store` represents the starting point (head) of a linked list of records for a specific resource.
    /// @notice A struct that points to the first record in the linked list of records for a given resource.
    /// @param head The identifier of the first record in the linked list.
    /// @param length The total number of records in the linked list.
    /// @param exists A boolean indicating if the store exists (used for validation).
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
    }

    struct generateIdVars {
        bytes32 receivingEntityId;
        bytes32 resourceId;
        bytes32 organizationId;
        bytes32 previous;
        bytes32 status;
        address owner;
        uint statusIssueDate;
        uint nonce;
        string ref;
    }

    /// @title RoleVariant
    /// @notice Defines the types of roles that can be assigned within the contract.
    /// @dev Used to categorize roles as either ENTITY, RESOURCE, or ORGANIZATION for permissioning and access control purposes.
    enum RoleVariant {
        ENTITY,
        RESOURCE,
        ORGANIZATION
    }

    /// @title RoleAccess
    /// @notice Defines the levels of access that can be granted to a role within the contract.
    /// @dev Used to specify the granularity of access control, allowing for READ, WRITE, or ADMIN permissions.
    enum RoleAccess {
        READ,
        WRITE,
        ADMIN
    }

    /// @notice Sets up initial roles for the deploying address, granting it admin and create role capabilities
    /// @dev Grants DEFAULT_ADMIN_ROLE and CREATE_ROLE to the message sender, which is typically the deployer of the contract.
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATE_ROLE, msg.sender);
    }

    /// @notice Generates unique hash values for role permissions based on role ID and variant.
    /// @dev This function creates a fixed-size array of bytes32 hashes, each representing a unique permission level (READ, WRITE, ADMIN) associated with a given role ID and variant.
    /// @param id The unique identifier for the role.
    /// @param variant The variant of the role (ENTITY, RESOURCE, ORGANIZATION).
    /// @return A bytes32[3] array containing unique hashes for READ, WRITE, and ADMIN access levels for the specified role.
    function generateRoleValues(
        bytes32 id,
        RoleVariant variant
    ) internal pure returns (bytes32[3] memory) {
        return [
            keccak256(abi.encodePacked(id, variant, RoleAccess.READ)),
            keccak256(abi.encodePacked(id, variant, RoleAccess.WRITE)),
            keccak256(abi.encodePacked(id, variant, RoleAccess.ADMIN))
        ];
    }

    /// @notice Retrieves the role values (READ, WRITE, ADMIN) for a given ID and its variant (ENTITY, RESOURCE, ORGANIZATION).
    /// @dev Based on the role variant, this function returns the corresponding role values from the appropriate mapping.
    /// @param id The unique identifier for the role.
    /// @param variant The variant of the role (ENTITY, RESOURCE, ORGANIZATION).
    /// @return A bytes32[3] array containing the role values for READ, WRITE, and ADMIN access levels.
    function rolesFor(
        bytes32 id,
        RoleVariant variant
    ) public view returns (bytes32[3] memory) {
        if (variant == RoleVariant.ENTITY) {
            return entityRoles[id];
        } else if (variant == RoleVariant.RESOURCE) {
            return resourceRoles[id];
        } else {
            return organizationRoles[id];
        }
    }

    /// @notice Retrieves the role value for a given ID, variant, and access level (READ, WRITE, ADMIN).
    /// @dev This function first calls `rolesFor` to get all role values for the ID and variant, then returns the specific role value based on the access level.
    /// @param id The unique identifier for the role.
    /// @param variant The variant of the role (ENTITY, RESOURCE, ORGANIZATION).
    /// @param access The specific access level (READ, WRITE, ADMIN) for which the role value is requested.
    /// @return A bytes32 value representing the role for the specified access level.
    function roleFor(
        bytes32 id,
        RoleVariant variant,
        RoleAccess access
    ) public view returns (bytes32) {
        bytes32[3] memory roles = rolesFor(id, variant);

        if (access == RoleAccess.READ) {
            return roles[0];
        } else if (access == RoleAccess.WRITE) {
            return roles[1];
        } else {
            return roles[2];
        }
    }

    /// @notice Grants the CREATE_ROLE to a specified address, allowing it to create new roles.
    /// @dev Checks if the `msg.sender` has the CREATE_ROLE before granting the same role to `addr`.
    ///     Uses the `grantRole` function to assign the role.
    /// @param addr The address to be granted the CREATE_ROLE.
    /// @custom:revert NoCreateRole if `msg.sender` does not have the CREATE_ROLE.
    function grantRole(
        address addr,
        bytes32 id,
        RoleVariant variant,
        RoleAccess access
    ) public {
        if (!hasRole(roleFor(id, variant, access), msg.sender)) {
            revert InsufficientRoleAuthorized(
                msg.sender,
                id,
                variant,
                RoleAccess.ADMIN
            );
        }

        bytes32[3] memory roles = rolesFor(id, variant);

        if (access == RoleAccess.WRITE) {
            grantRole(roles[1], addr);
        } else if (access == RoleAccess.ADMIN) {
            grantRole(roles[2], addr);
        } else {
            grantRole(roles[0], addr);
        }
    }

    /// @notice Grants the CREATE_ROLE to a specified address, allowing it to create new roles.
    /// @dev Checks if the `msg.sender` has the CREATE_ROLE before granting the same role to `addr`.
    ///     Uses the `grantRole` function to assign the role.
    /// @param addr The address to be granted the CREATE_ROLE.
    /// @custom:revert NoCreateRole if `msg.sender` does not have the CREATE_ROLE.
    function grantCreateRole(address addr) public {
        if (!hasRole(CREATE_ROLE, msg.sender)) {
            revert NoCreateRole(msg.sender);
        }

        grantRole(CREATE_ROLE, addr);
    }

    /// @notice Creates a new role with specified ID and variant, assigning role values and setting role admins.
    /// @dev Generates role values using `generateRoleValues` and stores them based on the `variant`.
    ///      Sets the admin role for READ and WRITE roles to the ADMIN role of the same ID and variant.
    ///      Requires the caller to have the CREATE_ROLE.
    /// @param id The unique identifier for the new role.
    /// @param variant The variant of the role (ENTITY, RESOURCE, ORGANIZATION) to be created.
    /// @custom:revert NoCreateRole if the caller does not have the CREATE_ROLE.
    function createRole(bytes32 id, RoleVariant variant) public {
        if (!hasRole(CREATE_ROLE, msg.sender)) {
            revert NoCreateRole(msg.sender);
        }

        bytes32[3] memory roleValues = generateRoleValues(id, variant);
        if (variant == RoleVariant.ENTITY) {
            entityRoles[id] = roleValues;
        } else if (variant == RoleVariant.RESOURCE) {
            resourceRoles[id] = roleValues;
        } else if (variant == RoleVariant.ORGANIZATION) {
            organizationRoles[id] = roleValues;
        }

        _setRoleAdmin(roleValues[0], roleValues[2]);
        _setRoleAdmin(roleValues[1], roleValues[2]);
    }

    /// @notice Determines if an address has any of the specified roles for entity, resource, or organization IDs.
    /// @dev Checks if the address `addr` has the role for either the entity, resource, or organization ID specified,
    ///      with the specified `access` level. Utilizes `roleFor` to get the specific role for each variant and checks
    ///      if the address has that role.
    /// @param addr The address to check roles for.
    /// @param entityId The entity ID to check the role against.
    /// @param resourceId The resource ID to check the role against.
    /// @param organizationId The organization ID to check the role against.
    /// @param access The level of access (READ, WRITE, ADMIN) to check for each role.
    /// @return bool Returns true if the address has any of the roles for the given IDs and access level; otherwise, false.
    function hasAnyRoleFor(
        address addr,
        bytes32 entityId,
        bytes32 resourceId,
        bytes32 organizationId,
        RoleAccess access
    ) internal view returns (bool) {
        return
            hasRole(roleFor(entityId, RoleVariant.ENTITY, access), addr) ||
            hasRole(roleFor(resourceId, RoleVariant.RESOURCE, access), addr) ||
            hasRole(
                roleFor(organizationId, RoleVariant.ORGANIZATION, access),
                addr
            );
    }

    /// @notice Adds a new compliance entry for a given resource.
    /// @dev Creates a new record in the contract, linking it to previous entries of the same resource. Emits an `AddEntry` event upon success.
    /// @param key A unique key identifying the resource.
    /// @param receivingEntityId The ID of the entity receiving the status update.
    /// @param resourceId The ID of the resource being tracked.
    /// @param organizationId The ID of the organization issuing the update.
    /// @param ref A reference link or identifier for additional information about the resource.
    /// @param status The new status of the resource.
    /// @param statusIssueDate The timestamp when the status is issued.
    /// @return success A boolean indicating whether the entry was successfully added.
    function addEntry(
        string calldata key,
        bytes32 receivingEntityId,
        bytes32 resourceId,
        bytes32 organizationId,
        string calldata ref,
        bytes32 status,
        uint statusIssueDate,
        address owner
    ) external returns (bool success) {
        if (
            !hasAnyRoleFor(
                msg.sender,
                receivingEntityId,
                resourceId,
                organizationId,
                RoleAccess.WRITE
            )
        ) {
            revert InsufficientRolesAvailable(msg.sender, RoleAccess.WRITE);
        }

        AddEntryVars memory lvars;
        lvars.key = key;
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
                owner,
                statusIssueDate,
                lvars.nonce,
                ref
            )
        );

        updateObjectAndIndex(
            lvars,
            Record(
                lvars.id,
                receivingEntityId,
                resourceId,
                organizationId,
                status,
                lvars.previous,
                owner,
                statusIssueDate,
                lvars.timestamp,
                lvars.nonce,
                ref,
                true
            )
        );

        emit AddEntry(
            lvars.key,
            lvars.id,
            receivingEntityId,
            resourceId,
            organizationId,
            status
        );
        return true;
    }

    /// @notice Sets the `nonce` and the `previous` values, and if this is the first record, establishes the `Store` record in the `index`.
    /// @param lvars The `lvars` of the current record.
    function setNonceAndPrevious(AddEntryVars memory lvars) internal {
        if (index[lvars.key].exists != true) {
            index[lvars.key] = Store(lvars.previous, 1, true);
            lvars.nonce = 0;
        } else {
            lvars.previous = index[lvars.key].head;
            lvars.nonce = index[lvars.key].length;
        }
    }

    /// @notice Generates a unique ID for the object described by the provided data. It checks for an id conflic, and mutates the ID in the (very unlikely) case of a conflict.
    /// @dev Takes an instance of `generateIdVars` containing all of the variables which describe a given record, and hashes those into a `bytes32` using `keccak256`.
    /// @param gvars The `generateIdVars` instance that describes the record.
    /// @return id A `bytes32` encoding of the `keccak256` value that was calculated.
    function generateId(
        generateIdVars memory gvars
    ) internal view returns (bytes32) {
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
                    gvars.previous,
                    gvars.owner
                )
            );
            offset = offset + 1;
            // The odds are infinitesimal, but if there is an ID conflict, just change one of the input values (the offset) and recalualge to get a new ID.
        } while (objects[id].exists);

        return id;
    }

    /// @notice Update the object store and the index head and length for the new record.
    function updateObjectAndIndex(
        AddEntryVars memory lvars,
        Record memory record
    ) internal {
        objects[lvars.id] = record;
        index[lvars.key].head = lvars.id;
        index[lvars.key].length = index[lvars.key].length + 1;
        length = length + 1;
    }

    /// @notice Retrieves the compliance record for a given ID.
    /// @dev Returns detailed information about the compliance status of a resource. This includes metadata like the issuing organization, status, and timestamps.
    /// @param _id The unique identifier of the compliance record to retrieve.
    /// @return id The unique identifier of the retrieved compliance record.
    /// @return receivingEntityId The ID of the entity receiving the status update.
    /// @return resourceId The ID of the resource being tracked.
    /// @return organizationId The ID of the organization issuing the update.
    /// @return status The current status of the resource.
    /// @return previous The ID of the previous record in the compliance history.
    /// @return owner The owner of the record.
    /// @return statusIssueDate The timestamp when the status was issued.
    /// @return timestamp The timestamp when this record was created.
    /// @return nonce The nonce of the record, indicating its sequence in the compliance history.
    /// @return ref A reference link or identifier for additional information about the resource.
    /// @return exists A bool value that is true if this is a record which actually exists on-chain (it has been previously stored).
    function getEntry(
        bytes32 _id
    )
        public
        view
        returns (
            bytes32,
            bytes32,
            bytes32,
            bytes32,
            bytes32,
            bytes32,
            address,
            uint,
            uint,
            uint,
            string memory,
            bool
        )
    {
        Record memory object = objects[_id];
        return (
            object.id,
            object.receivingEntityId,
            object.resourceId,
            object.organizationId,
            object.status,
            object.previous,
            object.owner,
            object.statusIssueDate,
            object.timestamp,
            object.nonce,
            object.ref,
            object.exists
        );
    }

    /// @notice Retrieves the most recent compliance record for a given key.
    /// @dev Returns detailed information about the compliance status of a resource. This includes metadata like the issuing organization, status, and timestamps. All prior records can be traversed by retrieving successive records pointed to by the `previous` ID, until that field contains an empty value.
    /// @param _key The unique key of the chain of compliance records to access.
    /// @return id The unique identifier of the retrieved compliance record.
    /// @return receivingEntityId The ID of the entity receiving the status update.
    /// @return resourceId The ID of the resource being tracked.
    /// @return organizationId The ID of the organization issuing the update.
    /// @return status The current status of the resource.
    /// @return previous The ID of the previous record in the compliance history.
    /// @return owner The owner of the record.
    /// @return statusIssueDate The timestamp when the status was issued.
    /// @return timestamp The timestamp when this record was created.
    /// @return nonce The nonce of the record, indicating its sequence in the compliance history.
    /// @return ref A reference link or identifier for additional information about the resource.
    /// @return a bool value that is true if this is a record which actually exists on-chain (it has been previously stored).
    function getLatest(
        string calldata _key
    )
        external
        view
        returns (
            bytes32,
            bytes32,
            bytes32,
            bytes32,
            bytes32,
            bytes32,
            address,
            uint,
            uint,
            uint,
            string memory,
            bool
        )
    {
        bytes32 id = index[_key].head;
        return getEntry(id);
    }
}
