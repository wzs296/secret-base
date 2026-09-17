// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {AuctionUpgradeable} from "./AuctionUpgradeable.sol";

contract AuctionUpgradeableV2 is AuctionUpgradeable {
    uint256 public version;

    function initializeV2() external reinitializer(2) {
        version = 2;
    }

    function getVersion() external view returns (uint256) {
        return version;
    }
}
