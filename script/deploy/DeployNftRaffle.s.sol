// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {NftRaffle} from "../../src/NftRaffle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployNftRaffle is Script {
    address[] tokens;

    uint256 deployerKey;

    function run()
        external
        returns (NftRaffle, HelperConfig, address[] memory)
    {
        HelperConfig helperConfig = new HelperConfig();
        (tokens, deployerKey) = helperConfig.getActiveNetworkConfig();
        //
        //
        //deploy NFT_Raffle
        vm.startBroadcast();
        NftRaffle nftRaffle = new NftRaffle(tokens);
        vm.stopBroadcast();
        //
        //
        //
        return (nftRaffle, helperConfig, tokens);
    }
}
