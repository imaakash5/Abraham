//SPDX - License - Identifier :MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./Token.sol";
import "./Token2.sol";

contract Presale is Ownable2Step {
    struct UserInfo {
        // packing to save gas
        uint128 amtSale1;
        uint128 amtSale2;
    }

    struct SaleInfo {
        // packing to save gas
        uint128 maxTokensForSale;
        uint64 presaleStartTime;
        uint64 presaleEndTime;
        uint128 totalTokensSold;
        uint64 salePrice;
        uint64 vestingStartTime;
    }

    mapping(address => UserInfo) public userInfo;
    mapping(uint256 => SaleInfo) public saleInfo;
    mapping(address => uint256) public totalTokensClaimedPerUser;
    mapping(address => uint256) public vestedMonth; //months that already been vested
    uint256 public currentSaleRound;
    uint256 public tokenAllocated;
    address public saleToken;
    uint256 public timeElapsed;
    uint256 public remainingTokens;
    uint256 public totalTokensPurchased;

    event saleStopped(uint256 amount_);
    event unsoldTokensTransferred(uint256 leftoverAmount_);

    modifier isSaleDuration() {
        //require(currentSaleRound < 2, "Presale: InvalidRoundId");
        if(saleInfo[currentSaleRound].presaleStartTime==0){
            require(
                uint64(block.timestamp) < saleInfo[currentSaleRound].presaleStartTime, "Presale: Sale hasn't started yet");
            }
        else{
            require(
                uint64(block.timestamp) > saleInfo[currentSaleRound].presaleStartTime, "Presale: Sale hasn't already started");
            }
        require(uint64(block.timestamp) < saleInfo[currentSaleRound].presaleEndTime, "Presale: Sale has ended");
        _;
    }


    /*//////////////////////////////////////////////////////////////
    CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address token_) Ownable(msg.sender) {
        require(token_ != address(0), "Presale: token is zero address");
        saleToken = token_;
    }

    //check sale should be ended for vesting

    /*//////////////////////////////////////////////////////////////
    ADMIN SETTERS
    //////////////////////////////////////////////////////////////*/

    function setSaleInfo(
        uint256 roundId_,
        uint128 maxTokensForSale_,
        uint64 presaleStartTime_,
        uint64 presaleEndTime_,
        uint64 salePrice_,
        uint64 vestingStartTime_
    ) external onlyOwner {
        require(roundId_ < 2, "Presale: InvalidRoundId");
        //require((saleInfo[roundId_]+1).preSaleStartTime>saleInfo[roundId_].preSaleEndTime,"Sale 1 is in progress");
        require(block.timestamp > saleInfo[roundId_].presaleEndTime, "Presale: Sale has not ended or force stopped");
        saleInfo[roundId_].vestingStartTime = vestingStartTime_;
        if (saleInfo[roundId_].presaleStartTime > 0) {
            require(block.timestamp < saleInfo[roundId_].presaleStartTime, "PreSale: Sale has already started");
        }
        saleInfo[roundId_].maxTokensForSale = maxTokensForSale_;
        saleInfo[roundId_].presaleStartTime = presaleStartTime_;
        saleInfo[roundId_].presaleEndTime = presaleEndTime_;
        saleInfo[roundId_].salePrice = salePrice_;
        IERC20(saleToken).transferFrom(msg.sender, address(this), saleInfo[roundId_].maxTokensForSale);
        currentSaleRound = roundId_;
    }

    function stopSale(uint256 roundId_) external onlyOwner {
        require(roundId_ < 2, "Presale: InvalidRoundId");
        require(block.timestamp > saleInfo[roundId_].presaleStartTime, "Presale: Sale hasn't started yet");
        if (block.timestamp < saleInfo[roundId_].presaleEndTime) {
            saleInfo[roundId_].presaleEndTime = uint64(block.timestamp);
            emit saleStopped(saleInfo[roundId_].presaleEndTime);
        }
    }


    /*//////////////////////////////////////////////////////////////
    BUYING  
    //////////////////////////////////////////////////////////////*/

    function buyToken(uint128 amount) external payable isSaleDuration{
        
        // amount is number of abraham to buy
        uint256 roundId = currentSaleRound; // cache to save gas
        require(amount > 0, "Presale: can not buy 0 tokens");
        require(amount * saleInfo[roundId].salePrice <= msg.value, "Presale: buyer has not enough funds");
        require(
            saleInfo[roundId].totalTokensSold + amount < (saleInfo[roundId].maxTokensForSale + 1),
            "Presale: max token amount sale reached"
        );
        // update mapping
        saleInfo[roundId].totalTokensSold += amount;
        if (roundId == 0) {
            userInfo[msg.sender].amtSale1 += amount;
            return;
        }
        userInfo[msg.sender].amtSale2 += amount;
    }

    function claimVestedTokens() external {
        //31 days
        //30 days
        require(block.timestamp > saleInfo[currentSaleRound].vestingStartTime, "Presale: currentTime < vesting time");
        timeElapsed = uint256(block.timestamp - saleInfo[currentSaleRound].vestingStartTime);
        timeElapsed = timeElapsed / (30 * 24 * 60 * 60);
        timeElapsed -= vestedMonth[msg.sender];
        require(timeElapsed > 0, "Presale: Invalid vesting month");
        vestedMonth[msg.sender] += timeElapsed;
        if (currentSaleRound == 0) {
            totalTokensPurchased = userInfo[msg.sender].amtSale1;
             } else {
            totalTokensPurchased = userInfo[msg.sender].amtSale2;
             }

        //uint256 a = totalTokensClaimedPerUser[msg.sender];
        require(
        totalTokensClaimedPerUser[msg.sender]
             < totalTokensPurchased, "Presale: token balance < withdrawing amount");
        tokenAllocated = uint128(totalTokensPurchased / 12) * timeElapsed;
        totalTokensClaimedPerUser[msg.sender] += tokenAllocated;
    }

    function withdrawUnsoldTokens() external onlyOwner {
        uint256 leftoverAmount = saleInfo[0].maxTokensForSale + saleInfo[1].maxTokensForSale
            - saleInfo[0].totalTokensSold - saleInfo[1].totalTokensSold;
        require(leftoverAmount > 0, "Presale: no tokens to withdraw");
        IERC20(saleToken).transfer(msg.sender, leftoverAmount);
        emit unsoldTokensTransferred(leftoverAmount);
    }

    function tokenBalanceAfterVesting() external  returns(uint256) {
        remainingTokens=totalTokensPurchased - totalTokensClaimedPerUser[msg.sender];
        return remainingTokens;
    }
}
