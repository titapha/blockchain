// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VestingWallet.sol";
import "../src/VestingNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Simulation d'un jeton ERC20 pour les tests
contract MockERC20 is ERC20 {
    constructor() ERC20("Test Token", "TTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract VestingTest is Test {
    VestingWallet wallet;
    VestingNFT nft;
    MockERC20 token;
    
    address admin = address(0xAD);
    address beneficiary = address(0x123);
    address user2 = address(0x456);

    uint256 totalAmount = 1000 * 10**18;
    uint256 duration = 1000;
    uint256 cliff;

    function setUp() public {
        vm.startPrank(admin);
        token = new MockERC20();
        nft = new VestingNFT();
        wallet = new VestingWallet(address(token), address(nft));
        
        // Configuration indispensable entre les contrats
        nft.setVestingWallet(address(wallet));
        
        // Metadata pour les tests NFT
        nft.setGradeMetadata(1, "ipfs://bronze");
        nft.setGradeMetadata(2, "ipfs://argent");
        nft.setGradeMetadata(5, "ipfs://diamant");
        
        cliff = block.timestamp + 100;
        vm.stopPrank();
    }

    // --- 1. TESTS DE SÉCURITÉ ET APPROBATION ---

    function test_OnlyOwnerCanCreate() public {
        vm.prank(address(0xdead));
        vm.expectRevert(); 
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
    }

    function test_RevertIfNoApprove() public {
        vm.startPrank(admin);
        // L'admin n'approuve pas le transfert
        vm.expectRevert(); 
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        vm.stopPrank();
    }

    function test_SuccessfulApproveAndCreate() public {
        vm.startPrank(admin);
        token.approve(address(wallet), totalAmount);
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        assertEq(token.balanceOf(address(wallet)), totalAmount);
        vm.stopPrank();
    }

    function test_RevertOnDuplicateSchedule() public {
        vm.startPrank(admin);
        token.approve(address(wallet), totalAmount * 2);
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        
        vm.expectRevert(VestingWallet.ScheduleAlreadyExists.selector);
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        vm.stopPrank();
    }

    // --- 2. TESTS DE LOGIQUE ET MULTIPLICATEURS ---

    function test_ClaimLinearVesting_NoGrade() public {
        vm.startPrank(admin);
        token.approve(address(wallet), totalAmount);
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        vm.stopPrank();

        vm.warp(cliff + 500); // 50% du temps
        vm.prank(beneficiary);
        wallet.claimVestedTokens();
        
        assertEq(token.balanceOf(beneficiary), 500 * 10**18);
    }

    function test_UpgradeMidVestingAndNFT() public {
        vm.startPrank(admin);
        token.approve(address(wallet), totalAmount);
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        vm.stopPrank();

        // Achat grade Bronze (x2)
        uint256 price = 100 * 10**18;
        deal(address(token), beneficiary, price);
        vm.startPrank(beneficiary);
        token.approve(address(wallet), price);
        wallet.upgradeMyStatus(VestingWallet.Grade.Bronze);
        
        vm.warp(cliff + 250); // 25% temps * x2 multiplier = 50% tokens
        wallet.claimVestedTokens();
        vm.stopPrank();

        assertEq(token.balanceOf(beneficiary), 500 * 10**18);
        assertEq(nft.balanceOf(beneficiary), 1);
    }

    function test_UpgradeToDiamant_InstantClaim() public {
        // Le bénéficiaire devient Diamant (x10)
        uint256 price = 10000 * 10**18;
        deal(address(token), beneficiary, price);
        vm.startPrank(beneficiary);
        token.approve(address(wallet), price);
        wallet.upgradeMyStatus(VestingWallet.Grade.Diamant);
        vm.stopPrank();

        // L'admin crée le plan
        vm.startPrank(admin);
        token.approve(address(wallet), totalAmount);
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        vm.stopPrank();

        vm.warp(cliff + 100); // 10% temps * x10 = 100% tokens
        vm.prank(beneficiary);
        wallet.claimVestedTokens();

        assertEq(token.balanceOf(beneficiary), totalAmount);
    }

    // --- 3. TESTS DE ROBUSTESSE (FUZZING & INDÉPENDANCE) ---

    function testFuzz_VestedAmountNeverExceedsTotal(uint256 timePassed) public {
        vm.assume(timePassed < 365 days); 
        
        vm.startPrank(admin);
        token.approve(address(wallet), totalAmount);
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        vm.stopPrank();

        vm.warp(cliff + timePassed);
        uint256 vested = wallet.getVestedAmount(beneficiary);
        assertTrue(vested <= totalAmount);
    }

    function test_MultipleUsersIndependence() public {
        uint256 amount2 = 500 * 10**18;
        vm.startPrank(admin);
        token.approve(address(wallet), totalAmount + amount2);
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        wallet.createVestingSchedule(user2, amount2, cliff, duration);
        vm.stopPrank();

        vm.warp(cliff + 500); 

        assertEq(wallet.getVestedAmount(beneficiary), 500 * 10**18);
        assertEq(wallet.getVestedAmount(user2), 250 * 10**18);
    }

    function test_PartialClaimAndAccumulation() public {
        vm.startPrank(admin);
        token.approve(address(wallet), totalAmount);
        wallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        vm.stopPrank();

        vm.warp(cliff + 250);
        vm.prank(beneficiary);
        wallet.claimVestedTokens();
        
        vm.warp(cliff + 750);
        vm.prank(beneficiary);
        wallet.claimVestedTokens();

        assertEq(token.balanceOf(beneficiary), 750 * 10**18);
    }
}