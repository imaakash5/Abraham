//SPDX-License-Identifier:MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./PancakeSwap/IPancakeV2Factory.sol";
import "./PancakeSwap/IPancakeV2Pair.sol";
import "./PancakeSwap/IPancakeV2Router01.sol";
import "./PancakeSwap/IPancakeV2Router02.sol";
import {stdError, console, Test} from "forge-std/Test.sol";

contract Token is ERC20, Ownable2Step {
    IPancakeV2Router02 public pancakeV2Router;
    IPancakeV2Factory public pancakeV2Factory;
    address public WBNB;
    address public pancakeV2pair;
    //@AUDIT this variable is setting treasury to null adress.
    //initialized the treasury in the constructor
    address public treasury;
    //@AUDIT this variable is setting fees to 0 by default.
    //set the sellFees to 250 by default
    uint256 public sellFees = 250;
    //@AUDIT the multiplier here is 10000 that means for 1% it needs 100 / 10000

    uint256 public percentageMultiplier = 10_000;
    //@AUDIT the maxSupply need to be on Ether, example 100_000_000 ethere. and should be used in the constructor to mint the maxSupply.
    //mint maxsupply in constructor
    uint256 public constant maxSupply = 100_000_000 ether;
    address public routerAddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
    mapping(address => bool) public isAutomatedMarketMakerPair;
    mapping(address => bool) public excludeFromFees;

    event AutomatedMarketMakerUpdate(address ammAddress, bool indexed isAmmDEX);
    event SellFeeSet(uint256 indexed newFeesAllocate);
    event TreasurerSet(address indexed newTreasurer);
    event ExcludedListSet(address indexed addressTobeExcludedFromTxFees, bool indexed value);
    event FeesCalculated(uint256 indexed FeesApplied);

    /*//////////////////////////////////////////////////////////////
    CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_, address initialTreasury)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {
        //@AUDIT - Initial Distribution maybe wrong here, as is less than 1 token, consder doing mint by token distribution. This is now flagged on audit.
        //mint tokens
        require(initialTreasury != address(0), "Token: treasury could not be zero address");
        _mint(msg.sender, maxSupply);
        pancakeV2Router = IPancakeV2Router02(routerAddress);
        WBNB = pancakeV2Router.WETH();
        pancakeV2pair = IPancakeV2Factory(pancakeV2Router.factory()).createPair(address(this), WBNB);
        setAutomatedMarketMaker(pancakeV2pair, true);
        treasury = initialTreasury;
        excludeFromFees[msg.sender] = true;
        excludeFromFees[address(this)] = true;
        excludeFromFees[pancakeV2pair] = true;
        excludeFromFees[routerAddress] = true;
    }

    /*//////////////////////////////////////////////////////////////
    ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function burn(uint256 tokenAmount_) external {
        require(tokenAmount_ > 0, "Token: burn amount is 0");
        _burn(msg.sender, tokenAmount_);
    }

    function transferFrom(address sender_, address recipient_, uint256 amount_)
        public
        virtual
        override
        returns (bool)
    {
        address spender = _msgSender();
        require(sender_ != address(0), "Token: transfer from the zero address");
        require(recipient_ != address(0), "Token: transfer to the zero address");
        require(balanceOf(sender_) >= amount_, "Token: transfer amount exceeds balance");
        uint256 feeCollected;
        _spendAllowance(sender_, spender, amount_);
        if (isAutomatedMarketMakerPair[recipient_]) {
            if (excludeFromFees[sender_]) {
                feeCollected = 0;
            } else {
                feeCollected = calculateFees(amount_, sellFees);
                _transfer(sender_, treasury, feeCollected);
            }
        }
        _transfer(sender_, recipient_, amount_ - feeCollected);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
    ADMIN SETTERS
    //////////////////////////////////////////////////////////////*/

    function setAutomatedMarketMaker(address ammAddress_, bool isAmm_) public onlyOwner {
        require(ammAddress_ != address(0), "Token: AMM(DEX) is zero address");
        isAutomatedMarketMakerPair[ammAddress_] = isAmm_;
        emit AutomatedMarketMakerUpdate(ammAddress_, isAmm_);
    }

    function setSellFee(uint256 newSellFee_) external onlyOwner {
        require(newSellFee_ < 501 && newSellFee_ >= 0, "Token: Sell fee is more than 5 or is 0");
        sellFees = newSellFee_;
        emit SellFeeSet(sellFees);
    }

    function setTreasury(address newTreasury_) external onlyOwner {
        require(newTreasury_ != address(0), "Token: Tax collector is zero address");
        treasury = newTreasury_;
        emit TreasurerSet(treasury);
    }
    //@AUDIT --- missing require function to avoid 0x0 address.
    //changes made

    function setExcludeFromFees(address user_, bool value_) external onlyOwner {
        require(user_ != address(0), "Token: user is a zero address");
        excludeFromFees[user_] = value_;
        emit ExcludedListSet(user_, value_);
    }

    /*//////////////////////////////////////////////////////////////
    INTERNALS
    //////////////////////////////////////////////////////////////*/

    function calculateFees(uint256 tokenAmount_, uint256 feesPercent_) internal returns (uint256 fees_) {
        //@AUDIT - you cannot send tokens to 0x0 address or will become a honeypot.
        require(tokenAmount_ > 0, "Fees levying on zero tokens");
        fees_ = (tokenAmount_ * feesPercent_) / percentageMultiplier;
        emit FeesCalculated(fees_);
    }
}
