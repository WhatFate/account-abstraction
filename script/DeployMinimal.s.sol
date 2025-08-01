// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title DeployMinimal
 * @notice Deployment script for deploying the MinimalAccount smart contract with a specified owner set and minimum confirmation threshold.
 * @dev Uses Foundry's broadcast mechanism to send transactions on-chain.
 *      Returns the deployed `MinimalAccount` instance and the `HelperConfig` used for deployment.
 */
contract DeployMinimal is Script {
    function run() public {}

    /**
     * @notice Deploys the MinimalAccount contract with specified owners and confirmation threshold.
     * @dev Uses a helper configuration to determine the account and entry point.
     *      The deployment transaction is broadcasted using Foundry's `vm.startBroadcast`.
     * @param owners Array of addresses that will be designated as account owners.
     * @param minConfirmations Minimum number of confirmations required to execute a transaction.
     * @return helperConfig The configuration used during deployment (contains network parameters).
     * @return minimalAccount The deployed MinimalAccount instance.
     */
    function deployMinimalAccount(address[] memory owners, uint256 minConfirmations) 
        public 
        returns(HelperConfig helperConfig, MinimalAccount minimalAccount)
    {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        minimalAccount = new MinimalAccount(config.entryPoint, owners, minConfirmations);
        vm.stopBroadcast();
    }
}