# Unstoppable

試試水溫題。目標要讓一個閃電貸合約的閃電貸功能失效。

- 題目
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity 0.8.17;

  import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
  import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

  /**
   * @title DamnValuableToken
   * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
   */
  contract UnstoppableLender is ReentrancyGuard {
      IERC20 public immutable damnValuableToken;
      uint256 public poolBalance;

      error MustDepositOneTokenMinimum();
      error TokenAddressCannotBeZero();
      error MustBorrowOneTokenMinimum();
      error NotEnoughTokensInPool();
      error FlashLoanHasNotBeenPaidBack();
      error AssertionViolated();

      constructor(address tokenAddress) {
          if (tokenAddress == address(0)) revert TokenAddressCannotBeZero();
          damnValuableToken = IERC20(tokenAddress);
      }

      function depositTokens(uint256 amount) external nonReentrant {
          if (amount == 0) revert MustDepositOneTokenMinimum();
          // Transfer token from sender. Sender must have first approved them.
          damnValuableToken.transferFrom(msg.sender, address(this), amount);
          poolBalance = poolBalance + amount;
      }

      function flashLoan(uint256 borrowAmount) external nonReentrant {
          if (borrowAmount == 0) revert MustBorrowOneTokenMinimum();

          uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
          if (balanceBefore < borrowAmount) revert NotEnoughTokensInPool();

          // Ensured by the protocol via the `depositTokens` function
          if (poolBalance != balanceBefore) revert AssertionViolated();

          damnValuableToken.transfer(msg.sender, borrowAmount);

          IReceiver(msg.sender).receiveTokens(address(damnValuableToken), borrowAmount);

          uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
          if (balanceAfter < balanceBefore) revert FlashLoanHasNotBeenPaidBack();
      }
  }

  interface IReceiver {
      function receiveTokens(address tokenAddress, uint256 amount) external;
  }
  ```

可以看到我們的目標是要讓 `poolBalance` 不等於 `balanceBefore`。

```solidity
if (poolBalance != balanceBefore) revert AssertionViolated();
```

前者是 `depositTokens()` 在維護，後者則是直接呼叫 ERC20 的 balanceOf() 取得，由此可知，我們可以不透過 `depositTokens()`，**直接用 ERC20 的 transfer 把 token 轉給合約**，這樣就會讓兩者產生不同步，也就讓 flashLoan 這個 function 失效了。

<aside>
💡 直接用 ERC20 的 transfer 把 token 轉給合約。

</aside>

# Naive Receiver

有兩個合約，一個簡易 lending pool 具備 flashloan 功能；一個 naive-receiver 具備 flashloan 的 callback。我們的目標是讓 naive-receiver 的 ether 全部跑到 lending pool 裏面。

這個 lending protocol 是可以幫別人 flashloan，而且還收取高額的手續費 1 ether。因此我們就可以幫 naive-receiver flashloan，讓它傻傻地被抽走大量的手續費，最終沒錢，確實 naive。

Naive-receiver 一開始有 10 ether，而我們的目標是讓他的 balance = 0，因此只要幫他呼叫 flashloan 10 次即可。如果要在一個 transaction 做完，就要寫成合約。

<aside>
💡 為 naive-receiver 呼叫 flashloan 十次。

</aside>

# Truster

有個提供 flashloan 的 pool，我們的目標是取走裡面所有的錢。

這題終於讓我卡了十幾分鐘。

後來發現 lending pool 的 callback 是任何 target 的 low level call，於是就利用這個去 call 了 token 的 approve，把全部的 token 都 approve 給 attacker。這樣 flashloan 完之後，就可以用 transferFrom 把錢全部移走。

不過題目有說可以用一個 transaction 就好，但上述方法要用兩個 transaction，除非利用部署合約大法，不知道還有沒有其他方式可以只用一個 transaction。

<aside>
💡 利用 target.functionCall(data) 這個彈性極大的 external call 來幹壞事，approve 全部的 tokens。

</aside>

# SideEntrance

這題的 lender pool 沒有檢查 reentrance，所以可以在 flashloan 的時候，用 deposit 來還錢。最後再 withdraw 全部的錢。

```solidity
function attack() external {
    lenderPool.flashLoan(1_000e18);
    lenderPool.withdraw();
    payable(msg.sender).sendValue(1_000e18);
}

function execute() external payable override {
    lenderPool.deposit{value: msg.value}(); // 用 deposit 還錢
}
```

<aside>
💡 Reentrance 攻擊。

</aside>

# The Rewarder Pool

這題是要利用閃電貸掠奪質押獎勵。

花了一點力氣才搞懂計算 reward 的時間軸：時間軸會以五天為一週期，每個週期的最一開始只要有人呼叫 deposit 或者 distributeRewards 就會去取當下 accounting token 的 snapshot 作為上一週期的 token 分佈，而所有使用者可以在該週期內領取上一週期的 rewards。

因此攻擊方式就是在下一週期的一開始馬上去借一大筆 dvt，並且質押到 rewarder pool 領取，這樣上一週期的 token 分佈就會包含到這筆閃電貸，攻擊者就能取走大部分 reward。

<aside>
💡 這題的重點是要在週期最一開始執行閃電貸，deposit 到 reward pool。

</aside>

# Selfie

有兩個合約，一個是閃電貸合約，裡面有個 drainAllFunds，只能被另一個治理合約呼叫。我們的目標就是要呼叫這個 drainAllFunds 來偷走所有的 tokens。

步驟挺簡單的，就是去閃電貸，然後呼叫 token.snapshot()，有了大量 token 之後就可以去治理合約提出 action，這裡我們就可以提出 drainAllFunds 的 action。在冷卻期過後，就可以 execute 該 action，把全部的錢抽乾。

<aside>
💡 去閃電貸然後很快地 take a snapshot，就可以騙過治理合約。跟 The Rewarder Pool 有點相似。

</aside>

# Compromised

這題和前面幾題蠻不一樣的。從題目敘述可以很快知道這應該是一個私鑰洩漏的漏洞，把題目提供的 hex 拿去 decode 會得到一串 base64 encode 的字串，再用 base64 decode 就會得到一個 uint256 型別的字串，也就是私鑰。

```solidity
// hex
4d48686a4e6a63345a575978595745304e545a6b59545931597a5a6d597a55344e6a466b4e4451344f544a6a5a475a68597a426a4e6d4d34597a49314e6a42695a6a426a4f575a69593252685a544a6d4e44637a4e574535
// base64
MHhjNjc4ZWYxYWE0NTZkYTY1YzZmYzU4NjFkNDQ4OTJjZGZhYzBjNmM4YzI1NjBiZjBjOWZiY2RhZTJmNDczNWE5?
// uint 256 string
'0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9'
```

題目給的兩個私鑰是屬於報價地址的，而題目的 oracle 是用三個報價地址提供的價格取中位數，因此取得兩個私鑰相當於控制了價格。於是我們只要買入前壓低價格，賣出前將價格提高到 exchange balance 就能抽光 exchange。

<aside>
💡 利用洩漏的私鑰來操縱價格。

</aside>

# Puppet

有個合約 puppet 只要抵押兩倍價值的 eth 就可以借出 dvt，然而這個合約判斷價值的方式是去看 uniswap v1 pool 中的池子比例。因此我們可以倒賣 dvt 到 pool 中，此時 puppet 就會認為 dvt 的價值很低，就可以用很低的 eth，借出所有 puppet 擁有的 dvt。

這題用了 foundry cheat sheet 中的 deployCode 來部署 UniswapV1 合約。

<aside>
💡 由於 pool 的流動性很淺，因此少量的 swap 就可以大幅改變價格。跟 Compromised 一樣都是操縱預言機的價格。

</aside>

# PuppetV2

和 puppet 只差在 pool 變成 uniswap v2 了，但是 puppetV2 依然是去看 pool 池子比例來決定價格，因此做法和 puppet 一樣，只需要改變 interface 以及另外處理 weth 的兌換。

```solidity
同 puppet。
```
