// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RomanToInteger {
    function romanToInt(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;

        for (uint256 i = 0; i < b.length; i++) {
            uint256 current = getValue(b[i]);

            if (i + 1 < b.length && current < getValue(b[i + 1])) {
                result -= current;
            } else {
                result += current;
            }
        }

        return result;
    }

    function getValue(bytes1 ch) private pure returns (uint256) {
        if (ch == "I") return 1;
        if (ch == "V") return 5;
        if (ch == "X") return 10;
        if (ch == "L") return 50;
        if (ch == "C") return 100;
        if (ch == "D") return 500;
        if (ch == "M") return 1000;

        revert("Invalid Roman numeral");
    }
}