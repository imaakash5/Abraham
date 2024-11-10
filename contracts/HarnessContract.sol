    //SPDX-License-Identifier:MIT
pragma solidity 0.8.22;

import "../contracts/AbrahamToken.sol";

contract TestInternalFuncHarness is Token {
    constructor(address treasurer_) Token("Abraham", "$ABRA", treasurer_) {}

    function calculateFees_Harness(uint256 amount_, uint256 feesPercent_) external returns (uint256 fees_) {
        fees_ = super.calculateFees(amount_, feesPercent_);
    }
}
