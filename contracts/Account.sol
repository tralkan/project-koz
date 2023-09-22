// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.20 <0.9.0;

/// @title Tyron SSI: A self-sovereign identity account with social recovery
/// @notice This contract is a smart contract wallet fully controlled by its owner.
//         It allows the owner to recover the account using a social recovery process.
//         The owner can add guardians to the account. Guardians can vote to recover the account.
//         The owner can also remove guardians from the account.
//         The threshold of votes required to recover the account is determined by the number of guardians (half plus one).
//         The wallet can receive, hold and send any fungible ERC20 token and non-fungible ERC721 token.
//         The wallet can also receive and send the native cryptocurrency.

/// @dev Import the required contracts
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Account is Ownable2Step {
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
    IERC721 private dns;

    /**
     * @notice Constructor to create a new account contract
     * @param _guardians_addr The addresses of the social-recovery guardians
     * @param _dns The address of the DNS contract
     * @param _guardians_id The NFT IDs of the social-recovery guardians
     */
    constructor(
        address[] memory _guardians_addr,
        address _dns,
        uint256[] memory _guardians_id
    ) {
        //setup the first guardians of the account
        setupGuardiansByAddr(_guardians_addr);
        setupGuardiansById(_guardians_id);
        dns = IERC721(_dns);
    }

    /// @dev Setup function that sets initial guardians by address.
    /// @param _guardians List of social-recovery guardians
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
            require(!guardians[guardian_hash], "a guardian cannot be repeated");
            assembly {
                switch guardian
                // A guardian cannot be null
                case 0 {
                    revert(0, 0)
                }
                default {
                    // A guardian cannot be the owner'
                    if eq(guardian, owner) {
                        revert(0, 0)
                    }

                    // The guardian is approved
                    guardian_count := add(guardian_count, 1)
                }
            }
            // Saves guardian in guardians map
            guardians[guardian_hash] = true;
        }
        guardianCount = guardian_count;
        updateGuardianThreshold(guardian_count);
    }

    /**
     * @dev Setup function that sets initial guardians.
     * @param _guardians List of social-recovery guardians by NFT ID.
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
            address guardian = dns.ownerOf(guardian_id);

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
            require(!guardians[guardian_hash], "a guardian cannot be repeated");
            assembly {
                switch guardian
                // A guardian cannot be null
                case 0 {
                    revert(0, 0)
                }
                default {
                    // A guardian cannot be the owner'
                    if eq(guardian, owner) {
                        revert(0, 0)
                    }

                    // The guardian is approved
                    guardian_count := add(guardian_count, 1)
                }
            }
            // Saves guardian in guardians map
            guardians[guardian_hash] = true;
        }
        guardianCount = guardian_count;
        updateGuardianThreshold(guardian_count);
    }

    /**
     * @dev Updates the guardians' threshold.
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
     * @notice Retrieves the number of guardians and the threshold.
     * @return guardian_count_ The number of guardians.
     * @return guardian_threshold_ The threshold required to recover the account.
     * @dev The threshold is the number of guardians required to recover the account.
     * The threshold is half plus one of the number of guardians.
     * The minimum threshold is 3.
     */
    function getGuardianParams()
        public
        view
        returns (uint256 guardian_count_, uint256 guardian_threshold_)
    {
        return (guardianCount, guardianThreshold);
    }
}
