// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MultiSigGuardianship
 * @notice Implements multisig functionality for transaction execution and owner replacement.
 * @dev Used as a base contract for multisig account system. Includes reentrancy protection.
 */
contract MultiSigGuardianship is ReentrancyGuard {
    error MultiSigGuardianship__OwnerToReplaceNotFound();
    error MultiSigGuardianship__OwnerAlreadyVoted();
    error MultiSigGuardianship__CallerIsNotOwner();
    error MultiSigGuardianship__ReplacementAlreadyExecuted();
    error MultiSigGuardianship__MinConfirmationsNotValid();
    error MultiSigGuardianship__TransactionAlreadyExecuted();
    error MultiSigGuardianship__ExecutionFailed(bytes reason);
    error MultiSigGuardianship__SameOwnerAddresses();

    struct ReplaceRequest {
        address oldOwner;
        address newOwner;
        address initiator;
        uint256 confirmations;
        bool executed;
    }

    struct TransactionRequest {
        address dest;
        uint256 value;
        bytes functionData;
        address initiator;
        uint256 confirmations;
        bool executed;
    }

    uint256 public minConfirmations;
    uint256 public nonce;

    mapping(address owner => bool isOwner) public s_owners;

    mapping(bytes32 txId => TransactionRequest) public s_pendingTransactions;
    mapping(bytes32 txId => mapping(address owner => bool isVoted)) public s_transactionVotes;

    mapping(bytes32 opId => ReplaceRequest) public s_pendingReplacements;
    mapping(bytes32 opId => mapping(address owner => bool isVoted)) public s_replacementVotes;

    event TransactionProposed(
        bytes32 indexed txId, 
        address indexed dest, 
        uint256 value, 
        bytes functionData
    );
    event ReplaceProposed(
        bytes32 indexed opId, 
        address indexed oldOwner, 
        address indexed newOwner
    );
    event OwnerReplaces(address indexed oldOwner, address indexed newOwner);

    /**
     * @dev Restricts access to functions to contract owners only.
     */
    modifier onlyOwners() {
        if (!s_owners[msg.sender] ) {
            revert MultiSigGuardianship__CallerIsNotOwner();
        }
        _;
    }

    /**
     * @notice Proposes a transaction to be executed upon enough confirmations.
     * @param dest The target address for the transaction.
     * @param value The amount of ETH to send.
     * @param functionData The calldata to pass to the destination.
     * @return txId The unique identifier of the proposed transaction.
     */
    function proposeTransaction(address dest, uint256 value, bytes calldata functionData) 
        external 
        onlyOwners 
        returns(bytes32 txId) 
    {
        txId = keccak256(abi.encode(dest, value, functionData, nonce));

        s_transactionVotes[txId][msg.sender] = true;

        s_pendingTransactions[txId] = TransactionRequest({
            dest: dest,
            value: value,
            functionData: functionData,
            initiator: msg.sender,
            confirmations: 1,
            executed: false
        });

        nonce += 1;

        emit TransactionProposed(txId, dest, value, functionData);
    }

    /**
     * @notice Proposes the replacement of an owner with a new address.
     * @param oldOwner The current owner to be replaced.
     * @param newOwner The new address proposed to replace the old owner.
     * @return opId The unique identifier of the replacement proposal.
     */
    function proposeOwnerReplacement(address oldOwner, address newOwner) 
        public 
        onlyOwners 
        returns(bytes32 opId)
    {
        if (!s_owners[oldOwner]) {
            revert MultiSigGuardianship__OwnerToReplaceNotFound();
        }
        if (oldOwner == newOwner) {
            revert MultiSigGuardianship__SameOwnerAddresses();
        }

        opId = keccak256(abi.encode(oldOwner, newOwner, nonce));

        s_replacementVotes[opId][msg.sender] = true;

        s_pendingReplacements[opId] = ReplaceRequest({
            oldOwner: oldOwner,
            newOwner: newOwner,
            initiator: msg.sender,
            confirmations: 1,
            executed: false
        });

        emit ReplaceProposed(opId, oldOwner, newOwner);
    }

    /**
     * @notice Confirms and, if threshold met, executes a proposed transaction.
     * @param txId The identifier of the transaction proposal.
     */
    function confirmTransaction(bytes32 txId) public onlyOwners nonReentrant {
        TransactionRequest storage proposal = s_pendingTransactions[txId];

        if (proposal.executed) {
            revert MultiSigGuardianship__TransactionAlreadyExecuted();
        }
        if (s_transactionVotes[txId][msg.sender]) {
            revert MultiSigGuardianship__OwnerAlreadyVoted();
        }

        s_transactionVotes[txId][msg.sender] = true;
        proposal.confirmations += 1;

        if (proposal.confirmations >= minConfirmations) {
            proposal.executed = true;

            (bool success, bytes memory result) = proposal.dest.call{value: proposal.value}(proposal.functionData);
            if (!success) {
                revert MultiSigGuardianship__ExecutionFailed(result);
            }
        }
    }

    /**
     * @notice Confirms and, if threshold met, executes an owner replacement.
     * @param opId The identifier of the replacement proposal.
     */
    function confirmOwnerReplacement(bytes32 opId) public onlyOwners {
        ReplaceRequest storage proposal = s_pendingReplacements[opId];
        
        if (proposal.executed) {
            revert MultiSigGuardianship__ReplacementAlreadyExecuted();
        }
        if (s_replacementVotes[opId][msg.sender]) {
            revert MultiSigGuardianship__OwnerAlreadyVoted();
        }

        s_replacementVotes[opId][msg.sender] = true;
        proposal.confirmations += 1;

        if (proposal.confirmations == minConfirmations) {
            proposal.executed = true;
            nonce += 1;

            address oldOwner = proposal.oldOwner;
            address newOwner = proposal.newOwner;

            s_owners[oldOwner] = false;
            s_owners[newOwner] = true;

            emit OwnerReplaces(oldOwner, newOwner);
        }
    }

    /**
     * @notice Checks whether a given address is an owner.
     * @param user The address to check.
     * @return True if the address is an owner, false otherwise.
     */
    function isOwner(address user) public view returns(bool) {
        return s_owners[user];
    }

    /**
     * @notice Checks if a transaction proposal has reached the required confirmations.
     * @param txId The transaction identifier.
     * @return True if confirmed, false otherwise.
     */
    function isApprovedTransaction(bytes32 txId) public view returns(bool){
        TransactionRequest storage proposal = s_pendingTransactions[txId];
        return proposal.confirmations >= minConfirmations;
    }

    /**
     * @notice Returns full data for a pending transaction proposal.
     * @param txId The identifier of the transaction proposal.
     * @return The TransactionRequest object.
     */
    function getPendingTransaction(bytes32 txId) external view returns (TransactionRequest memory) {
        return s_pendingTransactions[txId];
    }
}