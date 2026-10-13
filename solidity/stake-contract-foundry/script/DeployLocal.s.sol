// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MetaNode.sol";
import "../src/MetaNodeStake.sol";

contract DeployLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));

        if (deployerPrivateKey != 0) {
            vm.startBroadcast(deployerPrivateKey);
        } else {
            vm.startBroadcast();
        }

        MetaNodeToken rewardToken = new MetaNodeToken();
        MetaNodeStake stake = new MetaNodeStake();

        uint256 startBlock = block.number + 1;
        uint256 endBlock = startBlock + 1000;
        uint256 rewardPerBlock = 1 ether;

        stake.initialize(IERC20(address(rewardToken)), startBlock, endBlock, rewardPerBlock);
        stake.addPool(address(0), 100, 1 ether, 10, false);
        rewardToken.transfer(address(stake), 1_000_000 ether);

        console2.log("MetaNodeToken", address(rewardToken));
        console2.log("MetaNodeStake", address(stake));
        console2.log("StartBlock", startBlock);
        console2.log("EndBlock", endBlock);

        vm.stopBroadcast();
    }
}
