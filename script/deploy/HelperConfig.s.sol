// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

error HelperConfig__ChainIdNotAvailable(uint256 chainId);

contract HelperConfig is Script {
    NetworkConfig activeNetworkConfig;

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address[] tokens;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else if (block.chainid == 31337) {
            activeNetworkConfig = getAnvilEthConfig();
        } else {
            revert HelperConfig__ChainIdNotAvailable(block.chainid);
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory networkConfig)
    {
        address[] memory tokens = new address[](1);
        tokens[0] = 0x7f11f79DEA8CE904ed0249a23930f2e59b43a385;
        networkConfig = NetworkConfig({
            tokens: tokens,
            deployerKey: vm.envUint("METAMASK_PRIVATE_KEY_1")
        });
    }

    function getMainnetEthConfig()
        public
        view
        returns (NetworkConfig memory networkConfig)
    {
        address[] memory tokens = new address[](1);
        tokens[0] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        networkConfig = NetworkConfig({
            tokens: tokens,
            deployerKey: vm.envUint("METAMASK_PRIVATE_KEY_1")
        });
    }

    function getAnvilEthConfig()
        public
        returns (NetworkConfig memory networkConfig)
    {
        address[] memory tokens = new address[](1);
        tokens[0] = deployERC20Mock();

        networkConfig = NetworkConfig({
            tokens: tokens,
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }

    function deployERC20Mock() private returns (address token) {
        vm.startBroadcast();
        ERC20Mock mockToken = new ERC20Mock();
        vm.stopBroadcast();
        return token = address(mockToken);
    }

    function getActiveNetworkConfig()
        public
        view
        returns (address[] memory token, uint256 deployerKey)
    {
        token = activeNetworkConfig.tokens;
        deployerKey = activeNetworkConfig.deployerKey;

        return (token, deployerKey);
    }
}
