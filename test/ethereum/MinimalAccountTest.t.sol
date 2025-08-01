// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {console} from "forge-std/console.sol";
import {MultiSigGuardianship} from "src/ethereum/MultiSigGuardianship.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig config;
    MinimalAccount account;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    address owner1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address owner2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address owner3 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address randomUser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;

    address[] public owners = [owner1, owner2, owner3];
    uint256 public minConfirmations = 2;

    bytes public emptyBytes = "0x";

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        usdc = new ERC20Mock();
        (config, account) = deployMinimal.deployMinimalAccount(owners, minConfirmations);
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(account)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(account), AMOUNT);

        vm.prank(owner1);
        bytes32 txId = account.proposeTransaction(dest, value, functionData);

        vm.prank(owner2);
        account.confirmTransaction(txId);

        assertEq(usdc.balanceOf(address(account)), AMOUNT);
    }

    function testRecoverSignedOp() public {
        assertEq(usdc.balanceOf(address(account)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = 
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(account), AMOUNT);
        bytes memory executeCallData = 
            abi.encodeWithSelector(MultiSigGuardianship.proposeTransaction.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = 
            sendPackedUserOp.generatedSignedUserOperation(executeCallData, config.getConfig(), address(account));
        bytes32 userOperationHash = 
            IEntryPoint(config.getConfig().entryPoint).getUserOpHash(packedUserOp);

        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        assertEq(actualSigner, owner1);
    }

    function testValidationOfUserOps() public {
        assertEq(usdc.balanceOf(address(account)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = 
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(account), AMOUNT);
        bytes memory executeCallData = 
            abi.encodeWithSelector(MultiSigGuardianship.proposeTransaction.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = 
            sendPackedUserOp.generatedSignedUserOperation(executeCallData, config.getConfig(), address(account));
        bytes32 userOperationHash = IEntryPoint(config.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        vm.prank(config.getConfig().entryPoint);
        uint256 validationData = account.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    // function testEntryPointCanExecuteCommands() public {
    //     assertEq(usdc.balanceOf(address(account)), 0);
    //     address dest = address(usdc);
    //     uint256 value = 0;
    //     bytes memory functionData = 
    //         abi.encodeWithSelector(ERC20Mock.mint.selector, address(account), AMOUNT);
    //     bytes memory executeCallData = 
    //         abi.encodeWithSelector(MultiSigGuardianship.proposeTransaction.selector, dest, value, functionData);
    //     PackedUserOperation memory packedUserOp = 
    //         sendPackedUserOp.generatedSignedUserOperation(executeCallData, config.getConfig(), address(account));

    //     vm.deal(address(account), 1e18);

    //     PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    //     ops[0] = packedUserOp;

    //     vm.prank(randomUser);
    //     IEntryPoint(config.getConfig().entryPoint).handleOps(ops, payable(randomUser));

    //     assertEq(usdc.balanceOf(address(account)), AMOUNT);
    // }
}