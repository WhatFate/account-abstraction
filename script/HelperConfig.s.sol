// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";

/**
 * @title HelperConfig
 * @notice Provides network-specific configuration for the deployment and testing smart contracts.
 * @dev Designed to support local and testnet deployment with optional mock contract deployment.
 */
contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();
    error HelperConfig__AccountAlreadySet();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    address constant BURNER_WALLET = 0xbF472355Fe13EcEFAd43B0f055Dc42d5eDEE7964;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig config) public networkConfigs;

    /**
     * @notice Initializes the contract with known testnet configurations.
     */
    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    /**
     * @notice Gets the config for the currently active chain.
     * @return The network configuration for the current `block.chainid`.
     */
    function getConfig() public returns(NetworkConfig memory) {
        return getConfigByChainId(block.chainid); 
    }

    /**
     * @notice Gets the config for a specific chain ID.
     * @dev Reverts if the chain ID is not supported or known.
     * @param chainId the ID of the chain to get the config for.
     * @return The corresponding `NetworkConfig`.
     */
    function getConfigByChainId(uint256 chainId) public returns(NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /**
     * @notice Returns the configuration for Ethereum Sepolia.
     * @return A `NetworkConfig` with hardcoded EntryPoint and burner wallet.
     */
    function getEthSepoliaConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: getEntryPointForAllChain(),
            account: BURNER_WALLET
        });
    }

    /**
     * @notice Returns the configuration for zkSync Sepolia.
     * @return A `NetworkConfig` with an empty EntryPoint (to be set later) and burner wallet.
     */
    function getZkSyncSepoliaConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0),
            account: BURNER_WALLET
        });
    }

    /**
     * @notice Deploys mock EntryPoint if not already set, and returns local test config.
     * @dev Uses Foundry's broadcast to deploy EntryPoint contract only once.
     * @return A `NetworkConfig` for local Anvil with deployed mock EntryPoint.
     */
    function getOrCreateAnvilConfig() public returns(NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        console2.log("Deploying mocks...");
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_ACCOUNT});
        
        return localNetworkConfig;
    }

    /**
     * @notice Returns a known EntryPoint address used across all supported networks.
     * @dev This is the canonical EntryPoint used on Ethereum testnets.
     * @return The address of the known EntryPoint contract.
     */
    function getEntryPointForAllChain() public pure returns(address) {
        return 0x0576a174D229E3cFA37253523E645A78A0C91B57;
    }
}