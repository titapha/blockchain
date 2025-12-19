// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./VestingNFT.sol";

contract VestingWallet is Ownable, ReentrancyGuard {
    error InvalidAddress();
    error InvalidAmount();
    error InvalidDuration();
    error ScheduleAlreadyExists();
    error NothingToClaim();
    error TransferFailed();
    error InsufficientBalance();
    error InvalidGradeUpgrade();

    enum Grade { Aucun, Bronze, Argent, Or, Platine, Diamant }
    
    IERC20 public immutable token;
    VestingNFT public immutable nftContract;

    struct VestingSchedule {
        address beneficiary;
        uint256 cliff;
        uint256 duration;
        uint256 totalAmount;
        uint256 releasedAmount;
    }

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => Grade) public userGrades;
    mapping(address => bool) public nftRewarded;

    constructor(address tokenAddress, address nftAddress) Ownable(msg.sender) {
        if (tokenAddress == address(0) || nftAddress == address(0)) revert InvalidAddress();
        token = IERC20(tokenAddress);
        nftContract = VestingNFT(nftAddress);
    }

    function createVestingSchedule(address _beneficiary, uint256 _totalAmount, uint256 _cliff, uint256 _duration) external onlyOwner {
        if (vestingSchedules[_beneficiary].totalAmount > 0) revert ScheduleAlreadyExists();
        
        bool success = token.transferFrom(msg.sender, address(this), _totalAmount);
        if (!success) revert TransferFailed();

        vestingSchedules[_beneficiary] = VestingSchedule({
            beneficiary: _beneficiary,
            cliff: _cliff,
            duration: _duration,
            totalAmount: _totalAmount,
            releasedAmount: 0
        });
    }

    function claimVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        uint256 totalVested = getVestedAmount(msg.sender);
        uint256 claimable = totalVested - schedule.releasedAmount;

        if (claimable == 0) revert NothingToClaim();

        if (!nftRewarded[msg.sender] && block.timestamp >= schedule.cliff) {
            nftRewarded[msg.sender] = true;
            nftContract.mintReward(msg.sender, uint8(userGrades[msg.sender]));
        }

        schedule.releasedAmount += claimable;
        bool success = token.transfer(msg.sender, claimable);
        if (!success) revert TransferFailed();
    }

    function upgradeMyStatus(Grade _targetGrade) external {
        uint256 price;
        if (_targetGrade == Grade.Bronze) price = 100 * 10**18;
        else if (_targetGrade == Grade.Argent) price = 500 * 10**18;
        else if (_targetGrade == Grade.Or) price = 1000 * 10**18;
        else if (_targetGrade == Grade.Platine) price = 5000 * 10**18;
        else if (_targetGrade == Grade.Diamant) price = 10000 * 10**18;
        else revert InvalidGradeUpgrade();

        if (_targetGrade <= userGrades[msg.sender]) revert InvalidGradeUpgrade();
        if (token.balanceOf(msg.sender) < price) revert InsufficientBalance();

        bool success = token.transferFrom(msg.sender, address(this), price);
        if (!success) revert TransferFailed();

        userGrades[msg.sender] = _targetGrade;
    }

    function getVestedAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        if (block.timestamp < schedule.cliff) return 0;
        
        uint256 multiplier = 1;
        Grade g = userGrades[_beneficiary];
        if (g == Grade.Bronze) multiplier = 2;
        else if (g == Grade.Argent) multiplier = 4;
        else if (g == Grade.Or) multiplier = 6;
        else if (g == Grade.Platine) multiplier = 8;
        else if (g == Grade.Diamant) multiplier = 10;

        uint256 base = (schedule.totalAmount * (block.timestamp - schedule.cliff)) / schedule.duration;
        uint256 result = base * multiplier;
        return result > schedule.totalAmount ? schedule.totalAmount : result;
    }
}