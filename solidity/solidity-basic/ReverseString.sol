// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract ReverseString{
    function reverse(string memory input)public pure returns(string memory){
        bytes memory s=bytes(input);
        bytes memory result=new bytes(s.length);
        for (uint i=0; i<s.length;i++){
            result[s.length-1-i]=s[i];
        }
        return string(result);
    }
}