// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProxyFactory {
    function deployProxy(
        address implementation,
        bytes memory initData
    ) external returns (address) {
        return address(new ERC1967Proxy(implementation, initData));
    }
}
