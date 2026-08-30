// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IntegerToRoman {
    function integerToRoman(uint i) public pure returns (string memory) {
      require(i>0&& i<=3999,"Number must be between 1 and 39999");

      uint256[13] memory values=[uint256(1000), uint256(900), uint256(500), uint256(400), uint256(100), uint256(90), uint256(50), uint256(40), uint256(10), uint256(9), uint256(5), uint256(4), uint256(1)];
      string[13] memory symbols=["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"];

      bytes memory result=new bytes(0);
      for(uint256 j=0;j<values.length;j++){
        while(i>=values[j]){
            result=abi.encodePacked(result,symbols[j]);
            i-=values[j];
        }
      }
      return string(result);
    }
}