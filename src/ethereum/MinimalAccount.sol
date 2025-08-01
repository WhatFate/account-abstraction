// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MultiSigGuardianship} from "./MultiSigGuardianship.sol";

/**
 * @title MinimalAccount
 * @notice A simple multisig account contract compatible with ERC-4337 (Account Abstraction).
 * @dev Inherits from MultiSigGuardianship and implements the IAccount interface for EntryPoint integration.
 */
contract MinimalAccount is MultiSigGuardianship, IAccount {
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__TransactionNotApproved(bytes32 txId);

    IEntryPoint private immutable i_entryPoint;

    /**
     * @dev Ensures that a function is only callable by the EntryPoint.
     */
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    /**
     * @notice Initializes the MinimalAccount with a set of owners and minimym confirmations.
     * @param _entryPoint Address of the EntryPoint contract for Account Abstraction.
     * @param _owners List of addresses that are designated as account owners.
     * @param _minConfirmations Minimum number of confirmations required to approve operations.
     */
    constructor(
        address _entryPoint, 
        address[] memory _owners, 
        uint256 _minConfirmations) 
    {
        uint256 amountOwners = _owners.length;

        if (_minConfirmations == 0 || _minConfirmations >= amountOwners) {
            revert MultiSigGuardianship__MinConfirmationsNotValid();
        }

        for (uint256 i = 0; i < amountOwners; ) {
            s_owners[_owners[i]] = true;
            unchecked {
                ++i;
            }
        }

        minConfirmations = _minConfirmations;
        i_entryPoint = IEntryPoint(_entryPoint);
    }

    receive() external payable {}

    /**
     * @inheritdoc IAccount
     * @notice Called by EntryPoint to validate a user operation's signature and fund the prefund if necessary.
     * @param userOp The packed user operation submitted by the bundler.
     * @param userOpHash The hash of the user operation.
     * @param missingAccountFunds The amount of ETH to transfer to EntryPoint to prefund the operation.
     * @return validationData A status code (0 for success) as required by ERC-4337.
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) 
        external 
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    /**
     * @notice Validates that the signature belongs to one of the registered owners.
     * @param userOp The user operation to validate.
     * @param userOpHash The hashed user operation message.
     * @return validationData A status code (0 for success) as required by ERC-4337.
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) 
        internal 
        view 
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (!isOwner(signer)) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @notice Sends any required ETH prefund to the EntryPoint if needed.
     * @param missingAccountFunds Amount of ETH the account must fund to EntryPoint.
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    /**
     * @notice Returns the address of the configured EntryPoint.
     * @return The EntryPoint address.
     */
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}