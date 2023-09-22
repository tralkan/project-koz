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

contract Account is Ownable2Step {
    using SafeMath for uint256;
    mapping(address => bool) internal guardians;
    uint256 guardianCount;
    uint256 internal threshold;

    /// @notice Constructor to create a new account contract
    /// @param _guardians The addresses of the social-recovery guardians
    constructor(address[] memory _guardians) {
        //setup the first guardians of the account
        setupGuardians(_guardians);
    }

    /// @dev Setup function sets initial guardians.
    /// @param _guardians List of social-recovery guardians
    function setupGuardians(address[] memory _guardians) internal {
        //count the number of guardians
        uint256 count = _guardians.length;
        uint256 guardian_threshold;
        //fetch owner
        address owner = owner();
        /// @dev account the guardians that pass the checks
        uint256 guardian_count = 0;
        for (uint256 i = 0; i < count; i++) {
            address guardian = _guardians[i];

            /// @dev verify that the guardian is valid
            //a guardian cannot be repeated
            require(guardians[guardian], "a guardian cannot be repeated");
            assembly {
                switch guardian
                //a guardian cannot be null
                case 0 {
                    revert(0, 0)
                }
                default {
                    //a guardian cannot be the owner'
                    if eq(guardian, owner) {
                        revert(0, 0)
                    }

                    //the guardian is approved
                    guardian_count := add(guardian_count, 1)
                }
            }
            //save guardian in guardians map
            guardians[guardian] = true;

            //set the threshold to half plus one of the number of guardians
            assembly {
                guardian_threshold := add(div(guardian_count, 2), 1)
                //require the threeshold to be at least 3
                if lt(guardian_threshold, 3) {
                    guardian_threshold := 3
                }
            }
        }
        threshold = guardian_threshold;
    }

    //@inheritdoc
    /**
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
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(
        address newOwner
    ) public override(Ownable2Step) onlyOwner {
        Ownable2Step.transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(
        address newOwner
    ) internal override(Ownable2Step) {
        Ownable2Step._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public override(Ownable2Step) {
        Ownable2Step.acceptOwnership();
    }
}
