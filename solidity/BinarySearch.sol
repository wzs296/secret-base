// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BinarySearch{

    function binarySearch(uint256[] memory nums,uint256 target )
    public
    pure
    returns (uint256)
    {
        int256 left = 0;
        int256 right = int256(nums.length) - 1;

        while (left <= right) {
            int256 mid = left + (right - left) / 2;

            if (target > nums[uint256(mid)]) {
                left = mid + 1;
            } else if (target < nums[uint256(mid)]) {
                right = mid - 1;
            } else {
                return uint256(mid);
            }
        }

        revert("not found");
    }
}