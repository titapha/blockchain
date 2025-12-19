// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/VestingWallet.sol";

contract DeployVestingWallet is Script {
    function run() external {
        // Adresse d'un jeton existant ou d'un nouveau déployé
        address tokenAddress = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // WETH Sepolia

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new VestingWallet(tokenAddress);

        vm.stopBroadcast();
    }
}