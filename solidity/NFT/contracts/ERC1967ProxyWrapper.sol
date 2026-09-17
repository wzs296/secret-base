// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ERC1967ProxyWrapper is ERC1967Proxy {
    constructor(address implementation, bytes memory data) payable ERC1967Proxy(implementation, data) {}
}
