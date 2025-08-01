// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";
import {MultiSigGuardianship} from "src/ethereum/MultiSigGuardianship.sol";

contract MinimalAccountTest is Test {
    HelperConfig config;
    MinimalAccount account;

    uint256 public constant SEND_AMOUNT = 1 ether;
    uint256 public constant MIN_CONFIRMATIONS = 2;

    address owner1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address owner2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address owner3 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address randomUser = makeAddr("randomUser");

    address[] public owners = [owner1, owner2, owner3];

    bytes public emptyBytes = "0x";

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (config, account) = deployMinimal.deployMinimalAccount(owners, MIN_CONFIRMATIONS);
        vm.deal(address(account), 20 ether);
    }


    // --- Initialization and Setup Tests ---

    function testInitializationWithValidOwnersAndMinConfirmations() public view {
        assertTrue(account.isOwner(owners[0]));
        assertTrue(account.isOwner(owners[1]));
        assertTrue(account.isOwner(owners[2]));

        assertTrue(account.minConfirmations() == MIN_CONFIRMATIONS);
    }

    function testInitializationFailsWithInvalidMinConfirmations() public {
        DeployMinimal deployer = new DeployMinimal();
        vm.expectRevert(MultiSigGuardianship.MultiSigGuardianship__MinConfirmationsNotValid.selector);
        deployer.deployMinimalAccount(owners, 3);
    }


    // --- Transaction Proposal Tests ---

    function testProposeTransactionSuccessfullyCreatesNewProposal() public {
        vm.prank(owner1);
        bytes32 txId = account.proposeTransaction(randomUser, SEND_AMOUNT, emptyBytes);
        MultiSigGuardianship.TransactionRequest memory proposal = account.getPendingTransaction(txId);
        
        assertEq(proposal.initiator, owner1);
        assertEq(proposal.dest, randomUser);
        assertEq(proposal.value, SEND_AMOUNT);
        assertEq(proposal.functionData, emptyBytes);
    }

    function testNonceIncrementsAfterProposeTransaction() public {
        assertEq(account.nonce(), 0);

        vm.prank(owner1);
        account.proposeTransaction(randomUser, SEND_AMOUNT, emptyBytes);

        assertEq(account.nonce(), 1);
    }


    // --- Transaction Confirmation Tests ---

    function testOwnerCanConfirmTransaction() public {
        vm.prank(owner1);
        bytes32 txId = account.proposeTransaction(randomUser, SEND_AMOUNT, emptyBytes);

        assertEq(address(account).balance, 20 ether);
        assertEq(address(randomUser).balance, 0 ether);

        vm.prank(owner2);
        account.confirmTransaction(txId);

        assertEq(address(account).balance, 19 ether);
        assertEq(address(randomUser).balance, 1 ether);
    }

    function testOwnerCannotConfirmTransactionTwice() public {
        vm.startPrank(owner1);
        bytes32 txId = account.proposeTransaction(randomUser, SEND_AMOUNT, emptyBytes);
        
        vm.expectRevert(MultiSigGuardianship.MultiSigGuardianship__OwnerAlreadyVoted.selector);
        account.confirmTransaction(txId);
    }
    
    function testExecutedFlagSetAfterTransactionExecution() public {
        vm.prank(owner1);
        bytes32 txId = account.proposeTransaction(randomUser, SEND_AMOUNT, emptyBytes);
        MultiSigGuardianship.TransactionRequest memory proposal = account.getPendingTransaction(txId);

        assertFalse(proposal.executed);
        assertEq(proposal.confirmations, 1);

        vm.prank(owner2);
        account.confirmTransaction(txId);

        proposal = account.getPendingTransaction(txId);

        assertEq(proposal.confirmations, MIN_CONFIRMATIONS);
        assertTrue(proposal.executed);
    }
    
    function testConfirmTransactionRevertsOnFailedCall() public {
        vm.prank(owner1);
        bytes32 txId = account.proposeTransaction(randomUser, 21 ether, emptyBytes);

        vm.prank(owner2);
        vm.expectRevert();
        account.confirmTransaction(txId);

        MultiSigGuardianship.TransactionRequest memory proposal = account.getPendingTransaction(txId);

        assertFalse(proposal.executed);
        assertEq(proposal.confirmations, 1);
    }


    // --- Owner Replacement Confirmation Tests ---

    function testProposeOwnerReplacementSucceeds() public {
        vm.prank(owner1);
        bytes32 opId = account.proposeOwnerReplacement(owner3, randomUser);
        
        assertTrue(account.isOwner(owner3));
        assertFalse(account.isOwner(randomUser));
        
        vm.prank(owner2);
        account.confirmOwnerReplacement(opId);

        assertFalse(account.isOwner(owner3));
        assertTrue(account.isOwner(randomUser));
    }
    
    function testProposeOwnerReplacementRevertsIfOldOwnerNotFound() public {
        vm.prank(owner1);
        vm.expectRevert(MultiSigGuardianship.MultiSigGuardianship__OwnerToReplaceNotFound.selector);
        account.proposeOwnerReplacement(randomUser, address(0));
    }
    
    function testProposeOwnerReplacementRevertsIfOldAndNewOwnerAreSame() public {
        vm.prank(owner1);
        vm.expectRevert(MultiSigGuardianship.MultiSigGuardianship__SameOwnerAddresses.selector);
        account.proposeOwnerReplacement(owner2, owner2);
    }
    
    function testNonceIncrementsAfterProposeOwnerReplacement() public {
        assertEq(account.nonce(), 0);

        vm.prank(owner1);
        bytes32 opId = account.proposeOwnerReplacement(owner2, randomUser);

        vm.prank(owner3);
        account.confirmOwnerReplacement(opId);

        assertEq(account.nonce(), 1);
    }
    
    function testOwnerCannotConfirmReplacementTwice() public {
        vm.prank(owner1);
        bytes32 opId = account.proposeOwnerReplacement(owner2, randomUser);

        vm.prank(owner1);
        vm.expectRevert(MultiSigGuardianship.MultiSigGuardianship__OwnerAlreadyVoted.selector);
        account.confirmOwnerReplacement(opId);
    }

    
    // --- Access Control Tests---

    function testProposeTransactionRevertsIfNotOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(MultiSigGuardianship.MultiSigGuardianship__CallerIsNotOwner.selector);
        account.proposeTransaction(randomUser, 1 ether, emptyBytes);
    }
    
    function testConfirmTransactionRevertsIfNotOwner() public {
        vm.prank(owner1);
        bytes32 txId = account.proposeTransaction(randomUser, SEND_AMOUNT, emptyBytes);

        vm.prank(randomUser);
        vm.expectRevert(MultiSigGuardianship.MultiSigGuardianship__CallerIsNotOwner.selector);
        account.confirmTransaction(txId);
    }
    
    function testProposeOwnerReplacementRevertsIfNotOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(MultiSigGuardianship.MultiSigGuardianship__CallerIsNotOwner.selector);
        account.proposeOwnerReplacement(owner3, randomUser);
    }
    
    function testConfirmOwnerReplacementRevertsIfNotOwner() public {
        vm.prank(owner1);
        bytes32 opId = account.proposeOwnerReplacement(owner3, randomUser);

        vm.prank(randomUser);
        vm.expectRevert(MultiSigGuardianship.MultiSigGuardianship__CallerIsNotOwner.selector);
        account.confirmOwnerReplacement(opId);
    }
}