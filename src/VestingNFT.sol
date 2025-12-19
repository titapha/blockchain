// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestingNFT is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    address public vestingWallet;

    // Mapping pour stocker l'URL de l'image par Grade
    mapping(uint8 => string) public gradeMetadata;

    constructor() ERC721("Vesting Reward", "VRES") Ownable(msg.sender) {}

    // Définit le contrat de Vesting autorisé à créer des NFT
    function setVestingWallet(address _vestingWallet) external onlyOwner {
        vestingWallet = _vestingWallet;
    }

    // Définit l'image/metadata pour un grade
    function setGradeMetadata(uint8 _grade, string calldata _uri) external onlyOwner {
        gradeMetadata[_grade] = _uri;
    }

    // Fonction appelée par le VestingWallet pour donner le NFT
    function mintReward(address _beneficiary, uint8 _grade) external {
        require(msg.sender == vestingWallet, "Seul le contrat de Vesting peut mint");
        
        uint256 tokenId = _nextTokenId++;
        _safeMint(_beneficiary, tokenId);
        _setTokenURI(tokenId, gradeMetadata[_grade]);
    }
}