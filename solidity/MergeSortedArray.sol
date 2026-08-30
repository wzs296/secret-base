// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MergeSortedArray {
    function mergeSortedArray(uint256[] calldata nums1, uint256[] calldata nums2)
        public
        pure
        returns (uint256[] memory)
    {
        uint256[] memory merged = new uint256[](nums1.length + nums2.length);

        uint256 i = 0;
        uint256 j = 0;
        uint256 k = 0;

        while (i < nums1.length && j < nums2.length) {
            if (nums1[i] <= nums2[j]) {
                merged[k] = nums1[i];
                i++;
            } else {
                merged[k] = nums2[j];
                j++;
            }
            k++;
        }

        while (i < nums1.length) {
            merged[k] = nums1[i];
            i++;
            k++;
        }

        while (j < nums2.length) {
            merged[k] = nums2[j];
            j++;
            k++;
        }

        return merged;
    }
}