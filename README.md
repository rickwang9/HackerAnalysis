## [solidity智能合约安全攻击事件分析](https://github.com/rickwang9/HackerAnalysis)

更多的文章都发布在 [登链社区](https://learnblockchain.cn/people/3908).

### 具体攻击案例的代码重现和详细分析

- case 1: KaoyaSwap ( [POC代码](src/defisec/dex/Kaoya_exp.sol) | [详细分析](src/defisec/dex/kaoya.md) )
- case 2: Sushiswap ( [POC代码](src/defisec/dex/Sushiswap_exp.sol) | [详细分析](src/defisec/dex/sushiswap.md) )
- case 3: Platypus  ( [POC代码](src/defisec/lending/Plat_exp.sol) | [详细分析](src/defisec/lending/plat.md))
- case 4: Sentiment ( [POC代码](src/defisec/lending/Sentiment_exp.sol) | [详细分析](src/defisec/lending/Sentiment_exp.md))
- case 5: THORChain ( [POC代码](src/defisec/bridge/THORChain_exp.sol) | [详细分析](src/defisec/bridge/thorChain.md))
                                                                                                     
---




### 20220823 KaoyaSwap - bad logic of the swap

### Lost: >$118k

Testing

```
forge test --contracts ./src/defisec/dex/Kaoya_exp.sol -vv
```

#### Contract

[Kaoya_exp.sol](src/defisec/dex/Kaoya_exp.sol)

#### Link Reference

https://x.com/BlockSecTeam/status/1562286943957708800


---

### 20230409 SushiSwap - Unchecked User Input

### Lost: >$3.3M

Testing

```
forge test --contracts ./src/defisec/dex/Sushiswap_exp.sol -vv
```

#### Contract

[Sushiswap_exp.sol](src/defisec/dex/Sushiswap_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1644907207530774530

https://twitter.com/SlowMist_Team/status/1644936375924584449

https://twitter.com/AnciliaInc/status/1644925421006520320

---


### 20231012 Platypus - Business-Logic-Flaw

### Lost: ~$2M

Test

```
forge test --contracts ./src/defisec/lending/Plat_exp.sol -vv 
```

#### Contract

[Plat_exp.sol](src/defisec/lending/Plat_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1712445197538468298

https://twitter.com/peckshield/status/1712354198246035562

---


### 20230405 Sentiment - Read-Only-Reentrancy

### Lost: $1M

Testing

```
forge test --contracts ./src/defisec/lending/Sentiment_exp.sol -vv
```

#### Contract

[Sentiment_exp.sol](src/defisec/lending/Sentiment_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1643417467879059456

https://twitter.com/spreekaway/status/1643313471180644360

https://medium.com/coinmonks/theoretical-practical-balancer-and-read-only-reentrancy-part-1-d6a21792066c

---




