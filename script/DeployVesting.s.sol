// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/VestingWallet.sol";
import "../src/VestingNFT.sol";

contract DeployVestingWallet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Adresse du jeton sur Sepolia (ex: WETH ou un jeton de test que tu as créé)
        address tokenAddress = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; 

        vm.startBroadcast(deployerPrivateKey);

        // 1. Déployer le contrat NFT
        VestingNFT nft = new VestingNFT();
        
        // 2. Déployer le Wallet en lui donnant l'adresse du NFT
        VestingWallet wallet = new VestingWallet(tokenAddress, address(nft));
        
        // 3. Configurer le NFT pour autoriser le Wallet à mint
        nft.setVestingWallet(address(wallet));

        vm.stopBroadcast();

        console.log("NFT Contract deployed at:", address(nft));
        console.log("Vesting Wallet deployed at:", address(wallet));
    }
}