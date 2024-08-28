pragma solidity ^0.8.10;
import "forge-std/console.sol";
import "forge-std/Test.sol";

contract MyLog is Test{


    function log_named_decimal_uint1 (string memory key1,string memory key2, uint val, uint decimals) public {
        string memory key = string(abi.encodePacked(key1, " ", key2, " "));
        uint value = val/(10 ** decimals );
        if(value < 1){
            log_named_decimal_uint1(key ,val, decimals);
        }else{
            emit log_named_uint(key, value);
        }
    }

    function log_named_decimal_uint1 (string memory key, uint val, uint decimals) public {
        emit log_named_decimal_uint(key, val, decimals);
    }
}