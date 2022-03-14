// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Presale is AccessControl {
    using SafeERC20 for IERC20;

    struct SaleInfo {
        uint256 stableTokenAmount; //Total allocation bought in stablecoins
        uint256 loopTokenAmount; //Total bought LOOP tokens after IDO
        uint256 claimedLoopTokenAmount; //Total claimed by user so far
        uint8 nextVestingIndex; //Pointer to next claimable tranche
    }

    mapping(address => bool) public whitelists;
    mapping(address => SaleInfo) public presaleList;
    mapping(address => bool) public acceptTokens;

    struct BuyHistory {
        address buyerAddress;
        address stablecoinAddress;
        uint256 stableTokenAmount;
        uint256 buyTime;
    }

    BuyHistory[] private buyHistory; // Buying history

    bool private isPause;
    uint8 public constant maxDecimals = 18;

    address public immutable loopAddress;

    struct SaleRules {
        uint256 round2Multiplier;
        uint256 fcfsMultiplier;
        uint256 round2Minutes;
        uint256 fcfsMinutes;
        bool round2RequireWhitelist;
        bool fcfsRequireWhitelist;
    }

    struct VestingTranche {
        uint16 Percentage; //Percentage Vested in Basis points 10,000 = 100%
        uint256 Date; //UNIX Timestamp of Vesting
    }

    SaleRules public saleRules;
    VestingTranche[] public vestingSchedule;

    uint256 public saleStartTime;
    uint256 public saleEndTime;
    uint256 public immutable tokenPrice;
    uint256 public immutable allowedTokenAmount;
    
    uint256 public soldToken;
    uint256 public immutable presaleTokenAmount;

    event TokenPurchased(address userAddress, uint256 purchasedAmount);
    event TokenClaimed(address userAddress, uint256 purchasedAmount);

    constructor(
        address _loopAddress, 
        uint256 _saleStartTime, 
        uint256 _saleEndTime, 
        uint256 _tokenPrice, 
        uint256 _allowedTokenAmount,
        SaleRules memory _saleRules,
        VestingTranche[] memory _vestingSchedule,
        address[] memory _acceptTokens,
        uint256 _presaleTokenAmount
        ) {

        require(_saleEndTime >= _saleStartTime);
        require(_saleRules.round2Minutes >= 0);
        require(_saleRules.fcfsMinutes >= 0);
        require(_tokenPrice > 0);
        require(_allowedTokenAmount >= 0);
        require(_presaleTokenAmount >= 0);
        require(_saleRules.round2Multiplier >= 1);
        require(_saleRules.fcfsMultiplier >= 1);
        require(_vestingSchedule.length > 0);

        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
        saleRules.round2Minutes = _saleRules.round2Minutes;
        saleRules.fcfsMinutes = _saleRules.fcfsMinutes;
        saleRules.round2Multiplier = _saleRules.round2Multiplier;
        saleRules.fcfsMultiplier = _saleRules.fcfsMultiplier;
        saleRules.fcfsRequireWhitelist =_saleRules.fcfsRequireWhitelist;
        saleRules.fcfsRequireWhitelist =_saleRules.fcfsRequireWhitelist;

        //Assign vesting vesting schedule
        for(uint i = 0; i < _vestingSchedule.length; i++) {
            vestingSchedule.push(_vestingSchedule[i]);
        }

        require(checkVestingPercentage(_vestingSchedule), "Vesting percentages don't add up to 100%. Please make sure that values are in basis points");
        require(checkVestingScheduleOrdered(_vestingSchedule), "Vesting schedule is not ordered from older to newest");

        tokenPrice = _tokenPrice;
        allowedTokenAmount = _allowedTokenAmount;
        
        loopAddress = _loopAddress;
        for (uint i = 0; i < _acceptTokens.length; i ++) {
            acceptTokens[_acceptTokens[i]] = true;
        }
        presaleTokenAmount = _presaleTokenAmount;
        soldToken = 0;
        isPause = false;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier executable() {
        require(!isPause, "Contract is paused");
        _;
    }

    modifier checkEventTime() {
        require(block.timestamp >= saleStartTime && block.timestamp <= saleEndTime, "Out of presale period");
        _;
    }

    modifier checkAfterTime() {
        require(block.timestamp > saleEndTime, "Presale not finished");
        _;
    }

    function setStartTime(uint256 _saleStartTime) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        saleStartTime = _saleStartTime;
    }

    function setEndTime(uint256 _saleEndTime) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        saleEndTime = _saleEndTime;
    }

    function setSaleRules(SaleRules calldata _saleRules) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        saleRules = _saleRules;
    }

    function setRound2Multiplier(uint256 _round2Multiplier) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        saleRules.round2Multiplier = _round2Multiplier;
    }

    function setFCFSMultiplier(uint256 _fcfsMultiplier) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        saleRules.fcfsMultiplier = _fcfsMultiplier;
    }

    function setRound2Minutes(uint256 _round2Minutes) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        saleRules.round2Minutes = _round2Minutes;
    }

    function setFCFSMinutes(uint256 _fcfsMinutes) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        saleRules.fcfsMinutes = _fcfsMinutes;
    }

    function setRound2RequireWhitelist(bool _flag) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        saleRules.round2RequireWhitelist = _flag;
    }

    function setFCFSRequireWhitelist(bool _flag) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        saleRules.fcfsRequireWhitelist = _flag;
    
    }



    function getSoldToken() public view returns(uint) {
        return soldToken;
    }

    function stopContract(bool _pause) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isPause = _pause;
    }
    
    function getPauseStatus() external view returns(bool) {
        return isPause;
    }
    
    function addWhitelist(address _whiteAddress) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelists[_whiteAddress] = true;
    }

    function removeWhitelist(address _whiteAddress) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelists[_whiteAddress] = false;
    }

    function addWhitelists(address[] calldata _whiteAddresses) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < _whiteAddresses.length; i++) {
            whitelists[_whiteAddresses[i]] = true;
        }
    }

    function removeWhitelists(address[] calldata _whiteAddresses) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < _whiteAddresses.length; i++) {
            whitelists[_whiteAddresses[i]] = false;
        }
    }

	function addAcceptTokens(address _acceptTokenAddress) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        acceptTokens[_acceptTokenAddress] = true;
    }

    function removeAcceptTokens(address _acceptTokenAddress) external executable onlyRole(DEFAULT_ADMIN_ROLE) {
        acceptTokens[_acceptTokenAddress] = false;
    }

    function buyToken(address _stableTokenAddress, uint256 _amount) external executable checkEventTime {
        require(soldToken != presaleTokenAmount, "All Loop Tokens are sold out");
        
        //Whitelist enforcement
        if(block.timestamp < saleEndTime - saleRules.round2Minutes * 1 minutes) { //Round 1
            require(whitelists[msg.sender] == true, "Not whitelist address"); //Enforce Whitelist
        }
        else if ((block.timestamp >= saleEndTime - saleRules.round2Minutes * 1 minutes) && (block.timestamp < saleEndTime - saleRules.fcfsMinutes * 1 minutes) && saleRules.round2RequireWhitelist) {
            require(whitelists[msg.sender] == true, "Not whitelist address");
        }
        else if ((block.timestamp >= saleEndTime - saleRules.fcfsMinutes * 1 minutes) && saleRules.fcfsRequireWhitelist) {
            require(whitelists[msg.sender] == true, "Not whitelist address");
        }

        //End Whitelist enforcement

        require(acceptTokens[_stableTokenAddress] == true, "Not stableToken address");

        SaleInfo storage saleInfo = presaleList[msg.sender];

        uint8 tokenDecimal = ERC20(_stableTokenAddress).decimals();
        uint256 tokenAmount = _amount;

        if (tokenDecimal < maxDecimals) {
            tokenAmount = tokenAmount * 10 ** (maxDecimals - tokenDecimal);
        }

        uint256 loopTokenAmount = tokenAmount / tokenPrice * 10 ** ERC20(loopAddress).decimals();

        require(soldToken + loopTokenAmount <= presaleTokenAmount, "Cannot buy more LOOP tokens than amount up for presale");


        if (block.timestamp < saleEndTime - saleRules.round2Minutes * 1 minutes) {
            require(saleInfo.stableTokenAmount + tokenAmount <= allowedTokenAmount, 
                "Exceeding presale token limit during round1 period");
        } else if ((block.timestamp >= saleEndTime - saleRules.round2Minutes * 1 minutes) && (block.timestamp < saleEndTime - saleRules.fcfsMinutes * 1 minutes)) {
            require(saleInfo.stableTokenAmount + tokenAmount <= allowedTokenAmount * saleRules.round2Multiplier, 
                "Exceeding presale token limit during round2 period");
        } else if (block.timestamp >= saleEndTime - saleRules.fcfsMinutes * 1 minutes) {
            require(saleInfo.stableTokenAmount + tokenAmount <= allowedTokenAmount * saleRules.fcfsMultiplier, 
                "Exceeding presale token limit during FCFS period");
        }

        saleInfo.stableTokenAmount += tokenAmount;
        saleInfo.loopTokenAmount += loopTokenAmount;
        saleInfo.claimedLoopTokenAmount = 0;
        saleInfo.nextVestingIndex = 0;

        soldToken += loopTokenAmount;

        IERC20(_stableTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        
        //Add Buy History
        BuyHistory memory tempHistory;
        tempHistory.buyerAddress = msg.sender;
        tempHistory.stablecoinAddress = _stableTokenAddress;
        tempHistory.stableTokenAmount = _amount;
        tempHistory.buyTime = block.timestamp;

        addBuyHistory(tempHistory);

        emit TokenPurchased(msg.sender, loopTokenAmount);
    }
    
    /*
    This function claims all vested tranches of Loop tokens
    */
    function claimToken() external executable checkAfterTime {
        SaleInfo storage saleInfo = presaleList[msg.sender];
        require((saleInfo.loopTokenAmount - saleInfo.claimedLoopTokenAmount) > 0, "No claimToken amount");
        require(block.timestamp >= vestingSchedule[saleInfo.nextVestingIndex].Date, "No tokens available for claim yet");

        uint256 claimAmount = 0; //Amount claimable now

        //Claim all eligible vesting tranches
        while(block.timestamp >= vestingSchedule[saleInfo.nextVestingIndex].Date) {
            claimAmount += (vestingSchedule[saleInfo.nextVestingIndex].Percentage * saleInfo.loopTokenAmount) / 10000;

            saleInfo.nextVestingIndex++;

            if(saleInfo.nextVestingIndex == vestingSchedule.length) {
                break;
            }
        }

        uint balance = IERC20(loopAddress).balanceOf(address(this));
        require(balance > 0 && claimAmount <= balance, string(abi.encodePacked(Strings.toString(balance), abi.encodePacked("Insufficient balance for claim amount: ", Strings.toString(claimAmount)))));

        saleInfo.claimedLoopTokenAmount += claimAmount;

        IERC20(loopAddress).safeTransfer(msg.sender, claimAmount);
        emit TokenClaimed(msg.sender, claimAmount);
    }

    function withdrawAllToken(address _withdrawAddress, address[] calldata _stableTokens) external executable onlyRole(DEFAULT_ADMIN_ROLE) checkAfterTime {
        //Withdraw all unsold LOOP tokens
        uint256 unsoldLoopTokenAmount = IERC20(loopAddress).balanceOf(address(this)) - soldToken;

        if(unsoldLoopTokenAmount > 0) {
            IERC20(loopAddress).safeTransfer(_withdrawAddress, unsoldLoopTokenAmount);
        }
        
        //Withdraw all stablecoins
        for (uint i = 0; i < _stableTokens.length; i ++) {
            uint stableTokenAmount = IERC20(_stableTokens[i]).balanceOf(address(this));
            IERC20(_stableTokens[i]).safeTransfer(_withdrawAddress, stableTokenAmount);
        }
    }

    function giveBackToken(address _withdrawAddress, address _tokenAddress) external executable onlyRole(DEFAULT_ADMIN_ROLE) checkAfterTime {
        require(acceptTokens[_tokenAddress] == false, "Cannot withdraw pre-sale swap stablecoin tokens from presale using this function.");
        require(loopAddress != _tokenAddress, "Cannot withdraw Loop tokens from presale using this function.");
        uint tokenAmount = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeTransfer(_withdrawAddress, tokenAmount);
    }

    function checkVestingPercentage(VestingTranche[] memory _vestingSchedule) pure private returns (bool vestingPercentageCorrect) {
        vestingPercentageCorrect = false;

        uint16 totalPercentage = 0;

        for (uint i = 0; i < _vestingSchedule.length; i++)
        {
            totalPercentage += _vestingSchedule[i].Percentage;
        }

        if (totalPercentage == 10000) {
            vestingPercentageCorrect = true;
        }
    }

   function checkVestingScheduleOrdered(VestingTranche[] memory _vestingSchedule) pure private returns (bool vestingScheduleOrdered) {
        vestingScheduleOrdered = true;

        for (uint i = 0; i < _vestingSchedule.length - 1; i++)
        {
            if(_vestingSchedule[i].Date > _vestingSchedule[i+1].Date) {
                vestingScheduleOrdered = false;
                break;
            }
        }

        return vestingScheduleOrdered;
    }

    /* 
    Allow Admin to modify vesting schedule. Checks to be made that there are no clashes
    */
    function modifyVestingSchedule(VestingTranche[] memory _newVestingSchedule) onlyRole(DEFAULT_ADMIN_ROLE) external {
        //Basic pre-checks on new vesting schedule
        require(checkVestingPercentage(_newVestingSchedule), "Vesting percentages don't add up to 100%. Please make sure that values are in basis points");
        require(checkVestingScheduleOrdered(_newVestingSchedule), "Vesting schedule is not ordered from older to newest");
        
        
        //Check length of new vesting schedule vs old vesting schedule
        VestingTranche[] memory oldVestingSchedule;
        VestingTranche memory tranche;
        
        oldVestingSchedule = vestingSchedule; //Copy


        delete vestingSchedule; //Clear the vesting schedule

        //Set new vesting parameters

        for (uint i = 0; i < _newVestingSchedule.length; i++) {

            if(i < oldVestingSchedule.length) { //Prevent addressing of invalid entries
                if(oldVestingSchedule[i].Date < block.timestamp) {
                    //Copy old vesting values if tranches are in the past
                    tranche.Date = oldVestingSchedule[i].Date;
                    tranche.Percentage = oldVestingSchedule[i].Percentage;   
                }
                else {
                    //Copy for anything where claims have not started
                    tranche.Date = _newVestingSchedule[i].Date;
                    tranche.Percentage = _newVestingSchedule[i].Percentage;
                }
            } 
            else { //Anything longer than old vesting schedule, we just copy
                tranche.Date = _newVestingSchedule[i].Date;
                tranche.Percentage = _newVestingSchedule[i].Percentage;
            }
            
            vestingSchedule.push(tranche);
        }
        
        //Basic checks on validity of vesting parameters
        require(checkVestingPercentage(vestingSchedule), "User tried to modify earlier tranches of vesting schedule that created inconsistencies");
        require(checkVestingScheduleOrdered(vestingSchedule), "User tried to modify earlier tranches of vesting schedule that created inconsistencies");
        
    }

    function addBuyHistory(BuyHistory memory _buyHistory) private {
        buyHistory.push(_buyHistory);
    }

    function getBuyHistory() view external onlyRole(DEFAULT_ADMIN_ROLE) returns (BuyHistory[] memory bHistory) {
        return buyHistory;
    }
}