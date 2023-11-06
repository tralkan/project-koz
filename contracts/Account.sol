// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

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
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {CustomSlotInitializable} from "./CustomSlotInitializable.sol";
import {BaseAccount} from "@account-abstraction/contracts/core/BaseAccount.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {TokenCallbackHandler} from "@account-abstraction/contracts/samples/callback/TokenCallbackHandler.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @notice Extending Alchemy's `LightAccount`, a simple ERC-4337 compatible smart contract account with a designated owner account
 * @dev Like eth-infinitism's `SimpleAccount`, but with the following changes:
 *
 * 1. Instead of the default storage slots, uses namespaced storage to avoid
 * clashes when switching implementations.
 *
 * 2. Ownership can be transferred via `transferOwnership`, similar to the
 * behavior of an `Ownable` contract. This is a simple single-step operation,
 * so care must be taken to ensure that the ownership is being transferred to
 * the correct address.
 *
 * 3. Supports [ERC-1271](https://eips.ethereum.org/EIPS/eip-1271) signature
 * validation for both validating the signature on user operations and in
 * exposing its own `isValidSignature` method. This only works when the owner of
 * `LightAccount` also support ERC-1271.
 *
 * ERC-4337's bundler validation rules limit the types of contracts that can be
 * used as owners to validate user operation signatures. For example, the
 * contract's `isValidSignature` function may not use any forbidden opcodes
 * such as `TIMESTAMP` or `NUMBER`, and the contract may not be an ERC-1967
 * proxy as it accesses a constant implementation slot not associated with
 * the account, violating storage access rules. This also means that the
 * owner of a `LightAccount` may not be another `LightAccount` if you want to
 * send user operations through a bundler.
 *
 * 4. Event `SimpleAccountInitialized` renamed to `LightAccountInitialized`.
 *
 * 5. Uses custom errors.
 */

contract TyronSSIAccount is
    Ownable2Step,
    CustomSlotInitializable,
    BaseAccount,
    IERC1271,
    TokenCallbackHandler,
    UUPSUpgradeable
{
    /**
     * @dev Using libraries
     */
    using SafeMath for uint256;
    using ECDSA for bytes32;
    /**
     * @dev Mapping of guardians by the hash of their addresses (social-recovery feature)
     */
    mapping(bytes32 => bool) internal _guardians;
    uint256 internal _guardianCount;
    uint256 internal _guardianThreshold;
    IERC721 private immutable _dns;

    // keccak256(abi.encode(uint256(keccak256("light_account_v1.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal immutable _STORAGE_POSITION =
        0x691ec1a18226d004c07c9f8e5c4a6ff15a7b38db267cf7e3c945aef8be512200;
    // keccak256(abi.encode(uint256(keccak256("light_account_v1.initializable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal immutable _INITIALIZABLE_STORAGE_POSITION =
        0x33e4b41198cc5b8053630ed667ea7c0c4c873f7fc8d9a478b5d7259cec0a4a00;
    // bytes4(keccak256("isValidSignature(bytes32,bytes)"))
    bytes4 internal immutable _1271_MAGIC_VALUE = 0x1626ba7e;
    IEntryPoint private immutable _entryPoint;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // keccak256("LightAccountMessage(bytes message)");
    bytes32 private constant LA_MSG_TYPEHASH =
        0x5e3baca2936049843f06038876a12f03627b5edc98025751ecf2ac7562640199;

    /**
     * @dev Alchemy's Light Account Storage
     * @param address The address of the account signer.
     * @param threshold The threshold required to recover the account.
     */
    struct LightAccountStorage {
        address owner;
    }

    /**
     * @dev Emitted when a guardians are added or removed.
     * @param account The address of this account.
     * @param threshold The threshold required to recover the account.
     */
    event GuardiansUpdated(address indexed account, uint256 indexed threshold);

    /**
     * @notice Emitted when this account is first initialized
     * @param entryPoint The entry point
     * @param owner The initial owner
     */
    event LightAccountInitialized(
        IEntryPoint indexed entryPoint,
        address indexed owner
    );

    /**
     * @dev The length of the array does not match the expected length.
     */
    error ArrayLengthMismatch();

    /**
     * @dev The new owner is not a valid owner (e.g., `address(0)`, the
     * account itself, or the current owner).
     */
    error InvalidOwner(address owner);

    /**
     * @dev The caller is not authorized.
     */
    error NotAuthorized(address caller);

    /**
     * @notice Constructor to create a new account contract
     * @param guardiansAddr The addresses of the social-recovery guardians
     * @param dns The address of the DNS contract
     * @param guardiansId The NFT IDs of the social-recovery guardians
     * param anEntryPoint The AA Entry Point interface
     */
    constructor(
        address[] memory guardiansAddr,
        address dns,
        uint256[] memory guardiansId,
        address anEntryPoint
    ) CustomSlotInitializable(_INITIALIZABLE_STORAGE_POSITION) {
        _initialize(msg.sender);
        /**
         * @dev Setup the first guardians of the account.
         */
        _setupGuardiansByAddr(guardiansAddr);
        _setupGuardiansById(guardiansId);
        _dns = IERC721(dns);
        _entryPoint = IEntryPoint(anEntryPoint);
        _disableInitializers();
    }

    /**
     * @notice Called once as part of initialization, either during initial deployment or when first upgrading to
     * this contract.
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of LightAccount must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     * @param anOwner The initial owner of the account
     */
    function _initialize(address anOwner) internal initializer {
        if (anOwner == address(0)) {
            revert InvalidOwner(address(0));
        }
        _getStorage().owner = anOwner;
        emit LightAccountInitialized(_entryPoint, anOwner);
        emit OwnershipTransferred(address(0), anOwner);
    }

    /**
     * @notice Receives native cryptocurrency.
     * @dev The function reverts if the value is zero.
     */
    receive() external payable {
        require(msg.value > 0, "Account: The value must be greater than zero.");
    }

    /**
     * @notice Returns the address of the current owner.
     * @return The current owner.
     */
    function owner() public view override returns (address) {
        return _getStorage().owner;
    }

    /**
     * @notice Returns the domain separator for this contract, as defined in the EIP-712 standard.
     * @return bytes32 The domain separator hash.
     */
    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_SEPARATOR_TYPEHASH,
                    abi.encode("TyronSSIAccount"), // name
                    abi.encode("1"), // version
                    block.chainid, // chainId
                    address(this) // verifying contract
                )
            );
    }

    /**
     * @notice Returns the pre-image of the message hash
     * @param message Message that should be encoded.
     * @return Encoded message.
     */
    function encodeMessageData(
        bytes memory message
    ) public view returns (bytes memory) {
        bytes32 message_hash = keccak256(
            abi.encode(LA_MSG_TYPEHASH, keccak256(message))
        );
        return abi.encodePacked("\x19\x01", domainSeparator(), message_hash);
    }

    /**
     * @notice Returns hash of a message that can be signed by owners.
     * @param message Message that should be hashed.
     * @return Message hash.
     */
    function getMessageHash(
        bytes memory message
    ) public view returns (bytes32) {
        return keccak256(encodeMessageData(message));
    }

    /*
     * @notice Implements template method of BaseAccount.
     * @dev A modified version of `SignatureChecker.isValidSignatureNow` in
     * which the digest is wrapped with an "Ethereum Signed Message" envelope
     * for the EOA-owner case but not in the ERC-1271 contract-owner case.
     */
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view override returns (uint256 validationData) {
        address signer = owner();
        bytes32 signedHash = userOpHash.toEthSignedMessageHash();
        bytes memory signature = userOp.signature;
        (address recovered, ECDSA.RecoverError error) = signedHash.tryRecover(
            signature
        );
        if (
            (error == ECDSA.RecoverError.NoError && recovered == signer) ||
            SignatureChecker.isValidERC1271SignatureNow(
                signer,
                userOpHash,
                signature
            )
        ) {
            return 0;
        }
        return SIG_VALIDATION_FAILED;
    }

    /**
     * @inheritdoc IERC1271
     * @notice Signature authentication.
     * @dev The signature is valid if it is signed by the owner's private key
     * (if the owner is an EOA) or if it is a valid ERC-1271 signature from the
     * owner (if the owner is a contract). Note that unlike the signature
     * validation used in `validateUserOp`, this does **not** wrap the digest in
     * an "Ethereum Signed Message" envelope before checking the signature in
     * the EOA-owner case.
     *
     */
    function isValidSignature(
        bytes32 digest,
        bytes memory signature
    ) external view override returns (bytes4) {
        bytes32 message_hash = getMessageHash(abi.encode(digest));
        if (
            SignatureChecker.isValidSignatureNow(
                owner(),
                message_hash,
                signature
            )
        ) {
            return _1271_MAGIC_VALUE;
        }
        return 0xffffffff;
    }

    function _getStorage()
        internal
        pure
        returns (LightAccountStorage storage storageStruct)
    {
        bytes32 position = _STORAGE_POSITION;
        assembly {
            storageStruct.slot := position
        }
    }

    /**
     * @inheritdoc BaseAccount
     */
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * @inheritdoc Ownable
     */
    function _checkOwner() internal view override {
        // @dev Directly from EOA owner, or through the account itself (which gets redirected through execute())
        if (msg.sender != address(this) && msg.sender != owner()) {
            revert NotAuthorized(msg.sender);
        }
    }

    /**
     * @notice Requires the function call to go through EntryPoint or owner
     */
    function _requireFromEntryPointOrOwner() internal view {
        if (msg.sender != address(entryPoint()) && msg.sender != owner()) {
            revert NotAuthorized(msg.sender);
        }
    }

    /**
     * @notice Deposits more funds for this account in the entryPoint.
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * @notice Checks current account deposit in the entryPoint.
     * @return The current account deposit.
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * @notice Withdraws value from the account's deposit.
     * @param withdrawAddress Target to send to.
     * @param amount Amount to withdraw.
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @notice Executes a transaction. This may only be called directly by the
     * owner or by the entry point via a user operation signed by the owner.
     * @param dest The target of the transaction
     * @param value The amount of wei sent in the transaction
     * @param func The transaction's calldata
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        _call(dest, value, func);
    }

    /**
     * @notice Executes a sequence of transactions.
     * @param dest An array of the targets for each transaction in the sequence.
     * @param func An array of calldata for each transaction in the sequence.
     * Must be the same length as dest, with corresponding elements representing
     * the parameters for each transaction.
     */
    function executeBatch(
        address[] calldata dest,
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        if (dest.length != func.length) {
            revert ArrayLengthMismatch();
        }
        uint256 length = dest.length;
        for (uint256 i = 0; i < length; ) {
            _call(dest[i], 0, func[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Executes a sequence of transactions.
     * @param dest An array of the targets for each transaction in the sequence.
     * @param value An array of values for each transaction in the sequence.
     * @param func An array of calldata for each transaction in the sequence.
     * Must be the same length as dest, with corresponding elements representing
     * the parameters for each transaction.
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        if (dest.length != func.length || dest.length != value.length) {
            revert ArrayLengthMismatch();
        }
        uint256 length = dest.length;
        for (uint256 i = 0; i < length; ) {
            _call(dest[i], value[i], func[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Retrieves a guardian of the account per address hash.
     * @param guardian The address has of the guardian.
     * @return is_guardian_ True if the guardian is registered.
     */
    function isGuardian(
        bytes32 guardian
    ) public view returns (bool is_guardian_) {
        return _guardians[guardian];
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
        return (_guardianCount, _guardianThreshold);
    }

    /**
     * @notice Updates the guardians' threshold.
     * Sets the theshold to half plus one of the number of guardians.
     * @param guardianCount The number of registered guardians.
     */
    function _updateGuardianThreshold(uint256 guardianCount) internal {
        uint256 threshold;
        assembly {
            threshold := add(div(guardianCount, 2), 1)
            // Requires the threeshold to be at least 3.
            if lt(threshold, 3) {
                threshold := 3
            }
        }
        _guardianThreshold = threshold;
        emit GuardiansUpdated(address(this), threshold);
    }

    /**
     * @notice Setup function that sets initial guardians by address.
     * @param guardiansAddr List of social-recovery guardians per address.
     * @dev The guardians must be unique, not null and not the owner.
     */
    function _setupGuardiansByAddr(address[] memory guardiansAddr) internal {
        /**
         * @dev Count the number of incoming guardians
         */
        uint256 incoming = guardiansAddr.length;

        /**
         * @dev Account the registered guardians
         */
        uint256 guardian_count = _guardianCount;

        /**
         * @dev Fetch the owner of the account
         */
        address signer = owner();

        /**
         * @dev Account the new guardians that pass the checks
         */
        for (uint256 i = 0; i < incoming; i++) {
            address guardian = guardiansAddr[i];

            /**
             * @dev Calculate the hash of the guardian address.
             */
            bytes32 guardian_hash = keccak256(abi.encodePacked(guardian));

            /**
             * @dev Verify that the guardian is valid.
             * A guardian cannot be repeated.
             * A guardian cannot be null.
             * A guardian cannot be the owner.
             */
            require(
                !isGuardian(guardian_hash),
                "Account: A guardian cannot be repeated."
            );

            /**
             * @dev Verify that the given address is not null.
             * A guardian cannot be null.
             */
            require(
                guardian != address(0),
                "Account: A guardian cannot be null."
            );

            /**
             * @dev Verify that the guardian is not the account owner.
             * A guardian cannot be the owner.
             */
            require(
                guardian != signer,
                "Account: A guardian cannot be the account owner."
            );

            /**
             * @dev The guardian is approved.
             * Add one to the number of guardians.
             * Save the guardian in the guardians map.
             */
            guardian_count = guardian_count.add(1);
            _guardians[guardian_hash] = true;
            console.log("New guardian address: %o", guardian);
        }
        _guardianCount = guardian_count;
        _updateGuardianThreshold(guardian_count);
    }

    /**
     * @notice Setup function that sets initial guardians.
     * @param guardiansId List of social-recovery guardians by NFT ID.
     * @dev The guardians must be unique, not null and not the owner.
     */
    function _setupGuardiansById(uint256[] memory guardiansId) internal {
        /**
         * @dev Counts the number of incoming guardians.
         */
        uint256 incoming = guardiansId.length;

        /**
         * @dev Accounts for the registered guardians.
         */
        uint256 guardian_count = _guardianCount;

        /**
         * @dev Fetches the owner of the account
         */
        address signer = owner();

        /**
         * @dev Accounts for the new guardians that pass the checks.
         */
        for (uint256 i = 0; i < incoming; i++) {
            uint256 guardian_id = guardiansId[i];
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
                guardian != signer,
                "Account: A guardian cannot be the account owner."
            );

            /**
             * @notice The guardian is approved.
             * @dev Adds one to the number of guardians.
             * @dev Saves the guardian in the guardians map.
             */
            guardian_count = guardian_count.add(1);
            _guardians[guardian_hash] = true;
        }
        _guardianCount = guardian_count;
        _updateGuardianThreshold(guardian_count);
    }

    /**
     * @notice Adds new guardians to the account.
     * @param guardiansAddr The addresses of the social-recovery guardians.
     * @param guardiansId The NFT IDs of the social-recovery guardians.
     * @dev The guardians must be unique, not null and not the owner.
     * The guardians must be approved by the owner.
     */
    function addGuardians(
        address[] memory guardiansAddr,
        uint256[] memory guardiansId
    ) external onlyOwner {
        _setupGuardiansByAddr(guardiansAddr);
        _setupGuardiansById(guardiansId);
    }

    /**
     * @notice Removes guardians from the account.
     * @param guardiansHash List of social-recovery guardians per address hash.
     * @dev The guardians must be valid.
     * The removal must be approved by the owner.
     */
    function removeGuardians(
        bytes32[] memory guardiansHash
    ) external onlyOwner {
        /**
         * @dev Count the number of guardians to remove.
         */
        uint256 outcoming = guardiansHash.length;

        /**
         * @dev Account the registered guardians
         */
        uint256 guardian_count = _guardianCount;

        /**
         * @dev Account the guardians that pass the checks
         */
        for (uint256 i = 0; i < outcoming; i++) {
            bytes32 guardian = guardiansHash[i];

            /**
             * @dev Verify that the guardian is valid.
             * A guardian must be registered.
             */
            require(isGuardian(guardian), "Account: Unregistered guardian.");

            /**
             * @dev Remove guardian from guardians map.
             */
            delete _guardians[guardian];
            /**
             * @dev Decrease the number of guardians by one.
             */
            guardian_count = guardian_count.sub(1);
        }
        _guardianCount = guardian_count;
        _updateGuardianThreshold(guardian_count);
    }

    /**
     * @inheritdoc Ownable2Step
     * @notice Starts the ownership transfer of the contract to a new signer. Replaces the pending owner if there is one.
     * @dev Can only be called by the current owner or from the entry point via a
     * user operation signed by the current owner.
     * @param newOwner The new account owner.
     */
    function transferOwnership(address newOwner) public override(Ownable2Step) {
        LightAccountStorage storage _storage = _getStorage();
        address old_owner = _storage.owner;

        if (
            newOwner == old_owner ||
            newOwner == address(0) ||
            newOwner == address(this)
        ) {
            revert InvalidOwner(newOwner);
        }
        Ownable2Step.transferOwnership(newOwner);
    }

    /**
     * @inheritdoc Ownable2Step
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public override(Ownable2Step) {
        address sender = _msgSender();
        require(
            pendingOwner() == sender,
            "Ownable2Step: caller is not the new owner"
        );

        /**
         * @dev Transfer ownership of the account to the sender.
         * But the new owner remains as the _pendingOwner.
         */
        LightAccountStorage storage _storage = _getStorage();
        address old_owner = _storage.owner;
        _storage.owner = sender;
        emit OwnershipTransferred(old_owner, sender);
    }

    /**
     * @notice Updates the owner of the account with the help of its guardians.
     * @param newOwner Address of the new account owner.
     * @param guardians Guardians' addresses.
     * @param signatures Guardians' signatures.
     * @dev The guardians must be valid.
     * The removal must be approved by the owner.
     */
    function socialRecovery(
        address newOwner,
        address[] memory guardians,
        bytes[] memory signatures
    ) external {
        LightAccountStorage memory new_signer = LightAccountStorage({
            owner: newOwner
        });
        /**
         * @dev Get the new owner message hash.
         */
        bytes32 message_hash = getMessageHash(abi.encode(new_signer));

        /**
         * @dev Count the number of guardians.
         */
        uint256 guardian_amount = guardians.length;

        /**
         * @dev Accounts for the verified guardians.
         */
        uint256 guardian_count = 0;

        for (uint256 i = 0; i < guardian_amount; i++) {
            address guardian = guardians[i];
            /**
             * @dev Calculate the hash of the guardian address.
             */
            bytes32 guardian_hash = keccak256(abi.encodePacked(guardian));

            /**
             * @dev Verify that the guardian is valid.
             * A guardian must be registered.
             */
            console.log("Address: %o", guardian);

            console.log("isGuardian: %o", isGuardian(guardian_hash));
            require(
                isGuardian(guardian_hash),
                "Account: Unregistered guardian."
            );

            /**
             * @dev Verify the guardian's signature.
             */
            bytes memory signature = signatures[i];
            if (
                SignatureChecker.isValidSignatureNow(
                    guardian,
                    message_hash,
                    signature
                )
            ) {
                /**
                 * @notice The guardian is authenticated.
                 * @dev Adds one to the number of verified guardians.
                 */
                guardian_count = guardian_count.add(1);
                console.log("count: %o", guardian_count);
            }
        }
        console.log("verified count: %o", guardian_count);
        require(guardian_count >= _guardianThreshold, "Failed Recovery");
        transferOwnership(newOwner);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _checkOwner();
    }
}
