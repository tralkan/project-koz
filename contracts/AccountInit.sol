// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.20 <0.9.0;

/// @title Tyron SSI: A self-sovereign identity account with social recovery
/// @notice This contract is a smart contract wallet fully controlled by its owner.
//         It allows the owner to recover the account using a social recovery process.
//         The owner can add guardians to the account. Guardians can vote to recover the account.
//         The owner can also remove guardians from the account.
//         The threshold of votes required to recover the account is determined by the number of guardians (absolute majority, i.e. half plus one).
//         The wallet can receive, hold and send any fungible ERC20 token and non-fungible ERC721 token.
//         The wallet can also receive and send the native cryptocurrency.

/// @dev Import the required contracts
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "hardhat/console.sol";

contract AccountInit is Ownable2Step {
    /**
     * @dev Using SafeMath for uint256
     */
    using SafeMath for uint256;
    /**
     * @dev Mapping of guardians by the hash of their addresses (social-recovery key)
     */
    mapping(bytes32 => bool) internal guardians;
    uint256 guardianCount;
    uint256 internal guardianThreshold;
    IERC721 private _dns;

    /**
     * @dev Emitted when guardians are added or removed.
     * @param account The address of this account.
     * @param threshold The threshold required to recover the account.
     */
    event guardians_updated(address indexed account, uint256 indexed threshold);

    /**
     * @notice Constructor to create a new account contract
     * @param guardiansAddr The addresses of the social-recovery guardians
     * @param dns The address of the DNS contract
     * @param guardiansId The NFT IDs of the social-recovery guardians
     */
    constructor(
        address[] memory guardiansAddr,
        address dns,
        uint256[] memory guardiansId
    ) {
        //setup the first guardians of the account
        setupGuardiansByAddr(guardiansAddr);
        setupGuardiansById(guardiansId);
        _dns = IERC721(dns);
    }

    /**
     * @notice Receives native cryptocurrency.
     * @dev The function reverts if the value is zero.
     */
    receive() external payable {
        require(msg.value > 0, "Account: The value must be greater than zero.");
    }

    /**
     * @notice Retrieves a guardian of the account per address hash.
     * @param _guardian The address has of the guardian.
     * @return is_guardian_ True if the guardian is registered.
     */
    function isGuardian(
        bytes32 _guardian
    ) public view returns (bool is_guardian_) {
        return guardians[_guardian];
    }

    /**
     * @notice Retrieves the number of guardians and the threshold.
     * @return guardian_count_ The number of guardians.
     * @return guardian_threshold_ The threshold required to recover the account.
     * @dev The threshold is the number of guardians required to recover the account.
     * The threshold is half plus one of the number of guardians.
     * The minimum threshold is 3.
     */
    function getGuardianParams()
        external
        view
        returns (uint256 guardian_count_, uint256 guardian_threshold_)
    {
        return (guardianCount, guardianThreshold);
    }

    /**
     * @notice Updates the guardians' threshold.
     * Sets the theshold to half plus one of the number of guardians.
     * @param _guardian_count The number of registered guardians.
     */
    function updateGuardianThreshold(uint256 _guardian_count) internal {
        uint256 threshold;
        assembly {
            threshold := add(div(_guardian_count, 2), 1)
            // Requires the threeshold to be at least 3.
            if lt(threshold, 3) {
                threshold := 3
            }
        }
        guardianThreshold = threshold;
        emit guardians_updated(address(this), threshold);
    }

    /**
     * @notice Setup function that sets initial guardians by address.
     * @param _guardians List of social-recovery guardians per address.
     * @dev The guardians must be unique, not null and not the owner.
     */
    function setupGuardiansByAddr(address[] memory _guardians) internal {
        /**
         * @dev Counts the number of incoming guardians
         */
        uint256 incoming = _guardians.length;

        /**
         * @dev Accounts the registered guardians
         */
        uint256 guardian_count = guardianCount;

        /**
         * @dev Fetches the owner of the account
         */
        address owner = owner();

        /**
         * @dev Accounts the new guardians that pass the checks
         */
        for (uint256 i = 0; i < incoming; i++) {
            address guardian = _guardians[i];
            console.log("The given address is: %o", guardian);

            /**
             * @dev Calculates the hash of the guardian address.
             */
            bytes32 guardian_hash = keccak256(abi.encodePacked(guardian));

            /**
             * @dev Verifies that the guardian is valid.
             * A guardian cannot be repeated.
             * A guardian cannot be null.
             * A guardian cannot be the owner.
             */
            require(
                !isGuardian(guardian_hash),
                "Account: A guardian cannot be repeated."
            );

            /**
             * @dev Verifies that the given address is not null.
             * A guardian cannot be null.
             */
            require(
                guardian != address(0),
                "Account: A guardian cannot be null."
            );

            /**
             * @dev Verifies that the guardian is not the account owner.
             * A guardian cannot be the owner.
             */
            require(
                guardian != owner,
                "Account: A guardian cannot be the account owner."
            );

            /**
             * @notice The guardian is approved.
             * @dev Adds one to the number of guardians.
             * @dev Saves the guardian in the guardians map.
             */
            guardian_count = guardian_count.add(1);
            guardians[guardian_hash] = true;
        }
        guardianCount = guardian_count;
        updateGuardianThreshold(guardian_count);
    }

    /**
     * @notice Setup function that sets initial guardians.
     * @param _guardians List of social-recovery guardians by NFT ID.
     * @dev The guardians must be unique, not null and not the owner.
     */
    function setupGuardiansById(uint256[] memory _guardians) internal {
        /**
         * @dev Counts the number of incoming guardians.
         */
        uint256 incoming = _guardians.length;

        /**
         * @dev Accounts the registered guardians
         */
        uint256 guardian_count = guardianCount;

        /**
         * @dev Fetches the owner of the account
         */
        address owner = owner();

        /**
         * @dev Accounts the new guardians that pass the checks
         */
        for (uint256 i = 0; i < incoming; i++) {
            uint256 guardian_id = _guardians[i];
            /**
             * @dev Fetches the owner address with ownerOf
             */
            address guardian = _dns.ownerOf(guardian_id);

            /**
             * @dev Calculates the hash of the guardian address
             */
            bytes32 guardian_hash = keccak256(abi.encodePacked(guardian));

            /**
             * @dev Verifies that the guardian is valid
             * A guardian cannot be repeated
             * A guardian cannot be null
             * A guardian cannot be the owner
             */
            require(
                !isGuardian(guardian_hash),
                "Account: A guardian cannot be repeated."
            );

            /**
             * @dev Verifies that the given address is not null.
             * A guardian cannot be null.
             */
            require(
                guardian != address(0),
                "Account: A guardian cannot be null."
            );

            /**
             * @dev Verifies that the guardian is not the account owner.
             * A guardian cannot be the owner.
             */
            require(
                guardian != owner,
                "Account: A guardian cannot be the account owner."
            );

            /**
             * @notice The guardian is approved.
             * @dev Adds one to the number of guardians.
             * @dev Saves the guardian in the guardians map.
             */
            guardian_count = guardian_count.add(1);
            guardians[guardian_hash] = true;
        }
        guardianCount = guardian_count;
        updateGuardianThreshold(guardian_count);
    }

    /**
     * @inheritdoc Ownable2Step
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner()
        public
        view
        override(Ownable2Step)
        returns (address)
    {
        return Ownable2Step.pendingOwner();
    }

    /**
     * @inheritdoc Ownable2Step
     *  @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(
        address _new_owner
    ) public override(Ownable2Step) onlyOwner {
        Ownable2Step.transferOwnership(_new_owner);
    }

    /**
     * @inheritdoc Ownable2Step
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(
        address _new_owner
    ) internal override(Ownable2Step) {
        Ownable2Step._transferOwnership(_new_owner);
    }

    /**
     * @inheritdoc Ownable2Step
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public override(Ownable2Step) {
        Ownable2Step.acceptOwnership();
    }

    /**
     * @notice Adds new guardians to the account.
     * @param _guardians_addr The addresses of the social-recovery guardians.
     * @param _guardians_id The NFT IDs of the social-recovery guardians.
     * @dev The guardians must be unique, not null and not the owner.
     * The guardians must be approved by the owner.
     */
    function addGuardians(
        address[] memory _guardians_addr,
        uint256[] memory _guardians_id
    ) public onlyOwner {
        setupGuardiansByAddr(_guardians_addr);
        setupGuardiansById(_guardians_id);
    }

    /**
     * @notice Removes guardians from the account.
     * @param _guardians List of social-recovery guardians per address hash.
     * @dev The guardians must be valid.
     * The removal must be approved by the owner.
     */
    function removeGuardians(bytes32[] memory _guardians) public onlyOwner {
        /**
         * @dev Counts the number of guardians to remove.
         */
        uint256 outcoming = _guardians.length;

        /**
         * @dev Accounts the registered guardians
         */
        uint256 guardian_count = guardianCount;

        /**
         * @dev Accounts the guardians that pass the checks
         */
        for (uint256 i = 0; i < outcoming; i++) {
            bytes32 guardian = _guardians[i];

            /**
             * @dev Verifies that the guardian is valid.
             * A guardian must be registered.
             */
            require(!isGuardian(guardian), "Account: Unregistered guardian.");

            // Removes guardian from guardians map
            delete guardians[guardian];
            // Decreases the number of guardians by one
            guardian_count = guardian_count.sub(1);
        }
        guardianCount = guardian_count;
        updateGuardianThreshold(guardian_count);
    }
}
