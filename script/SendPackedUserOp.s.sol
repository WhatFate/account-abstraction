// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title SendPackedUserOp
 * @notice Utility script for generating and signing a PackedUserOperation for use with EntryPoint.
 * @dev Intended for use with Account Abstraction flows and testing with Foundry.
 */
contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    /**
     * @notice Generates and signs a `PackedUserOperation` using a local or provided private key.
     * @param callData Encoded function call to be included in the user operation.
     * @param config The network configuration containing EntryPoint and signing account.
     * @param minimalAccount The address of the smart contract account sending the operation.
     * @return userOp A signed `PackedUserOperation` ready to be sent to EntryPoint.
     */
    function generatedSignedUserOperation(
        bytes memory callData, 
        HelperConfig.NetworkConfig memory config, 
        address minimalAccount
    ) public view returns(PackedUserOperation memory userOp) {
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);

        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if(block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        userOp.signature = abi.encodePacked(r, s, v);
    }

    /**
     * @notice Constructs an unsigned `PackedUserOperation` with default gas and fee parameters.
     * @dev This function assumes no initCode and no paymaster; adjust accordingly for real use cases.
     * @param callData Encoded function call to be executed.
     * @param sender Address of the smart contract account (MinimalAccount).
     * @param nonce Current nonce of the sender account.
     * @return The unsigned `PackedUserOperation`.
     */
    function _generateUnsignedUserOperation(
        bytes memory callData, 
        address sender, 
        uint256 nonce
    ) internal pure returns(PackedUserOperation memory) {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""

        });
    }
}