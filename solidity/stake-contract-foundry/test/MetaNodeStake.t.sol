// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/MetaNodeStake.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock token", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RevertingReceiver {
    MetaNodeStake internal stake;

    function setStake(address _stake) external {
        stake = MetaNodeStake(_stake);
    }

    function depositStake(uint256 amount) external payable {
        stake.depositETH{value: amount}();
    }

    function requestUnstake(uint256 pid, uint256 amount) external {
        stake.unstake(pid, amount);
    }

    function withdrawStake(uint256 pid) external {
        stake.withdraw(pid);
    }

    function claimStake(uint256 pid) external {
        stake.claim(pid);
    }

    receive() external payable {
        revert("receive reverted");
    }
}

contract MetaNodeStakeTest is Test {
    MetaNodeStake internal stake;
    MockERC20 internal rewardToken;
    MockERC20 internal stakingToken;

    address internal admin = address(0xA11CE);
    address internal alice = address(0xBEEF);
    address internal bob = address(0xC0FFEE);

    function setUp() public {
        rewardToken = new MockERC20();
        stakingToken = new MockERC20();

        vm.prank(admin);
        stake = new MetaNodeStake();

        vm.prank(admin);
        stake.initialize(IERC20(address(rewardToken)), 10, 1000, 10);

        rewardToken.mint(address(stake), 1_000_000 ether);
        stakingToken.mint(alice, 10_000 ether);
        stakingToken.mint(bob, 10_000 ether);
    }

    function test_initialize_and_admin_role_behavior() public {
        MetaNodeStake badStake = new MetaNodeStake();

        vm.expectRevert("invalid parameters");
        badStake.initialize(IERC20(address(rewardToken)), 100, 10, 0);

        vm.prank(admin);
        badStake.initialize(IERC20(address(rewardToken)), 10, 200, 10);

        vm.expectRevert();
        vm.prank(alice);
        badStake.setMetaNode(IERC20(address(0xBEEF)));

        vm.prank(admin);
        badStake.setMetaNode(IERC20(address(0x1234)));
        assertEq(address(badStake.MetaNode()), address(0x1234));

        vm.prank(admin);
        badStake.setStartBlock(20);
        vm.prank(admin);
        badStake.setEndBlock(200);
        vm.prank(admin);
        badStake.setMetaNodePerBlock(25);

        assertEq(badStake.startBlock(), 20);
        assertEq(badStake.endBlock(), 200);
        assertEq(badStake.MetaNodePerBlock(), 25);

        vm.expectRevert("start block must be smaller than end block");
        vm.prank(admin);
        badStake.setStartBlock(201);

        vm.expectRevert("start block must be smaller than end block");
        vm.prank(admin);
        badStake.setEndBlock(10);
    }

    function test_pool_management_and_queries() public {
        vm.roll(20);

        vm.prank(admin);
        stake.addPool(address(0), 100, 1 ether, 10, false);

        vm.prank(admin);
        stake.addPool(address(stakingToken), 50, 2 ether, 20, false);

        assertEq(stake.poolLength(), 2);

        vm.expectRevert("invalid staking token address");
        vm.prank(admin);
        stake.addPool(address(0), 10, 1 ether, 5, false);

        vm.expectRevert("invalid withdraw locked blocks");
        vm.prank(admin);
        stake.addPool(address(stakingToken), 10, 1 ether, 0, false);

        vm.expectRevert("invalid pool weight");
        vm.prank(admin);
        stake.setPoolWeight(1, 0, false);

        vm.prank(admin);
        stake.setPoolWeight(1, 80, false);
        assertEq(stake.totalPoolWeight(), 180);

        vm.prank(admin);
        stake.updatePool(1, 3 ether, 30);

        (address stTokenAddress, uint256 poolWeight, uint256 lastRewardBlock, uint256 accMetaNodePerST, uint256 stTokenAmount, uint256 minDeposit, uint256 lockBlocks) = stake.pool(1);
        assertEq(stTokenAddress, address(stakingToken));
        assertEq(poolWeight, 80);
        assertEq(minDeposit, 3 ether);
        assertEq(lockBlocks, 30);
        assertEq(stTokenAmount, 0);
        assertEq(accMetaNodePerST, 0);
        assertGt(lastRewardBlock, 0);

        vm.expectRevert("invalid pid");
        stake.pendingMetaNode(99, alice);

        vm.expectRevert("invalid pid");
        stake.stakingBalance(99, alice);

        vm.expectRevert("invalid pid");
        stake.withdrawAmount(99, alice);

        vm.expectRevert("invalid block");
        stake.getMultiplier(100, 10);

        uint256 multiplier = stake.getMultiplier(10, 30);
        assertGt(multiplier, 0);

        assertEq(stake.pendingMetaNode(1, alice), 0);

        vm.prank(alice);
        stakingToken.approve(address(stake), 100 ether);
        vm.prank(alice);
        stake.deposit(1, 10 ether);

        vm.roll(60);
        assertGt(stake.pendingMetaNode(1, alice), 0);

        vm.prank(alice);
        stake.unstake(1, 5 ether);

        (uint256 reqAmount, uint256 pendingWithdraw) = stake.withdrawAmount(1, alice);
        assertEq(reqAmount, 5 ether);
        assertEq(pendingWithdraw, 0);

        vm.roll(90);
        (reqAmount, pendingWithdraw) = stake.withdrawAmount(1, alice);
        assertEq(reqAmount, 5 ether);
        assertEq(pendingWithdraw, 5 ether);
    }

    function test_deposit_eth_and_erc20_and_claim_flow() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        vm.prank(admin);
        stake.addPool(address(0), 100, 1 ether, 10, false);

        vm.prank(admin);
        stake.addPool(address(stakingToken), 50, 2 ether, 15, false);

        vm.prank(alice);
        stake.depositETH{value: 2 ether}();

        vm.prank(bob);
        stakingToken.approve(address(stake), 100 ether);
        vm.prank(bob);
        stake.deposit(1, 10 ether);

        vm.roll(50);

        assertGt(stake.pendingMetaNode(0, alice), 0);
        assertGt(stake.pendingMetaNode(1, bob), 0);

        vm.prank(alice);
        stake.unstake(0, 1 ether);

        vm.prank(bob);
        stake.unstake(1, 5 ether);

        vm.roll(100);

        vm.prank(alice);
        stake.withdraw(0);

        vm.prank(bob);
        stake.withdraw(1);

        vm.roll(120);

        vm.prank(alice);
        stake.claim(0);

        vm.prank(bob);
        stake.claim(1);

        assertGt(rewardToken.balanceOf(alice), 0);
        assertGt(rewardToken.balanceOf(bob), 0);
        assertEq(stake.stakingBalance(0, alice), 1 ether);
        assertEq(stake.stakingBalance(1, bob), 5 ether);
    }

    function test_claim_and_withdraw_pauses_and_reverts() public {
        vm.deal(alice, 100 ether);

        vm.prank(admin);
        stake.addPool(address(0), 100, 1 ether, 5, false);

        vm.prank(alice);
        stake.depositETH{value: 2 ether}();

        vm.prank(admin);
        stake.pauseClaim();
        vm.expectRevert("claim is paused");
        vm.prank(alice);
        stake.claim(0);
        vm.prank(admin);
        stake.unpauseClaim();

        vm.prank(admin);
        stake.pauseWithdraw();
        vm.expectRevert("withdraw is paused");
        vm.prank(alice);
        stake.unstake(0, 1 ether);
        vm.prank(admin);
        stake.unpauseWithdraw();

        vm.prank(alice);
        stake.unstake(0, 1 ether);

        vm.roll(35);
        vm.prank(alice);
        stake.withdraw(0);

        vm.expectRevert("Not enough staking token balance");
        vm.prank(alice);
        stake.unstake(0, 100 ether);

        vm.expectRevert("deposit amount is too small");
        vm.prank(alice);
        stake.depositETH{value: 0.5 ether}();

        vm.prank(admin);
        stake.addPool(address(stakingToken), 10, 2 ether, 5, false);
        vm.prank(alice);
        stakingToken.approve(address(stake), 1 ether);

        vm.expectRevert("deposit amount is too small");
        vm.prank(alice);
        stake.deposit(1, 1 ether);
    }

    function test_minimum_deposit_accepts_the_exact_threshold_for_erc20() public {
        vm.prank(admin);
        stake.addPool(address(0), 100, 1 ether, 10, false);

        vm.prank(admin);
        stake.addPool(address(stakingToken), 50, 2 ether, 10, false);

        stakingToken.mint(alice, 10 ether);

        vm.prank(alice);
        stakingToken.approve(address(stake), 10 ether);

        vm.prank(alice);
        stake.deposit(1, 2 ether);

        assertEq(stake.stakingBalance(1, alice), 2 ether);
    }

    function test_claim_uses_available_reward_balance_and_eth_withdraw_reverts() public {
        RevertingReceiver receiver = new RevertingReceiver();
        receiver.setStake(address(stake));

        vm.deal(address(receiver), 10 ether);

        vm.prank(admin);
        stake.addPool(address(0), 100, 1 ether, 5, false);

        receiver.depositStake{value: 2 ether}(2 ether);
        receiver.requestUnstake(0, 1 ether);

        vm.roll(block.number + 6);

        vm.expectRevert();
        receiver.withdrawStake(0);

        receiver.claimStake(0);
        assertEq(rewardToken.balanceOf(address(receiver)), 0);
    }

    function test_zero_reward_and_noop_paths_cover_more_branches() public {
        vm.deal(alice, 10 ether);

        vm.prank(admin);
        stake.addPool(address(0), 100, 1 ether, 5, false);

        vm.prank(alice);
        stake.depositETH{value: 2 ether}();

        vm.prank(alice);
        stake.claim(0);

        vm.prank(alice);
        stake.unstake(0, 0);

        (uint256 requestAmount, uint256 pendingWithdrawAmount) = stake.withdrawAmount(0, alice);
        assertEq(requestAmount, 0);
        assertEq(pendingWithdrawAmount, 0);

        vm.prank(alice);
        stake.withdraw(0);

        stake.updatePool(0);
        assertEq(stake.pendingMetaNode(0, alice), 0);
    }

    function test_updatepool_withdraw_and_transfer_safety_branches() public {
        vm.deal(alice, 20 ether);

        vm.prank(admin);
        stake.addPool(address(0), 100, 1 ether, 5, false);

        vm.prank(alice);
        stake.depositETH{value: 2 ether}();

        vm.prank(admin);
        stake.updatePool(0);

        vm.roll(30);

        vm.prank(alice);
        stake.unstake(0, 1 ether);

        vm.roll(40);

        (uint256 requestAmount, uint256 pendingWithdrawAmount) = stake.withdrawAmount(0, alice);
        assertEq(requestAmount, 1 ether);
        assertEq(pendingWithdrawAmount, 1 ether);

        vm.prank(alice);
        stake.withdraw(0);

        vm.prank(alice);
        stake.claim(0);

        assertEq(stake.pendingMetaNode(0, alice), 0);
        assertLt(rewardToken.balanceOf(address(stake)), 1_000_000 ether);
    }

    function test_mixed_unlocks_and_zero_reward_balance_branches() public {
        vm.deal(alice, 50 ether);

        MockERC20 zeroRewardToken = new MockERC20();
        MetaNodeStake zeroRewardStake = new MetaNodeStake();

        vm.prank(admin);
        zeroRewardStake.initialize(IERC20(address(zeroRewardToken)), 10, 1000, 10);

        vm.prank(admin);
        zeroRewardStake.addPool(address(0), 100, 1 ether, 10, false);

        vm.prank(alice);
        zeroRewardStake.depositETH{value: 5 ether}();

        vm.roll(25);
        vm.prank(alice);
        zeroRewardStake.unstake(0, 1 ether);

        vm.roll(30);
        vm.prank(alice);
        zeroRewardStake.unstake(0, 2 ether);

        vm.roll(35);
        (uint256 requestAmount, uint256 pendingWithdrawAmount) = zeroRewardStake.withdrawAmount(0, alice);
        assertEq(requestAmount, 3 ether);
        assertEq(pendingWithdrawAmount, 1 ether);

        vm.prank(alice);
        zeroRewardStake.withdraw(0);

        vm.roll(50);
        vm.prank(alice);
        zeroRewardStake.claim(0);

        assertEq(zeroRewardStake.pendingMetaNode(0, alice), 0);
        assertEq(zeroRewardToken.balanceOf(address(zeroRewardStake)), 0);
    }

    function test_updatepool_early_return_and_withdraw_break_branch() public {
        vm.deal(alice, 20 ether);

        vm.prank(admin);
        stake.addPool(address(0), 100, 1 ether, 10, false);

        vm.prank(alice);
        stake.depositETH{value: 5 ether}();

        vm.roll(20);
        vm.prank(alice);
        stake.unstake(0, 2 ether);

        vm.roll(30);
        vm.prank(alice);
        stake.unstake(0, 1 ether);

        vm.roll(35);
        (uint256 requestAmount, uint256 pendingWithdrawAmount) = stake.withdrawAmount(0, alice);
        assertEq(requestAmount, 3 ether);
        assertEq(pendingWithdrawAmount, 2 ether);

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        stake.withdraw(0);

        assertEq(alice.balance, balanceBefore + 2 ether);
    }

    function test_claim_transfers_only_available_reward_balance() public {
        MockERC20 shortfallToken = new MockERC20();
        MetaNodeStake shortfallStake = new MetaNodeStake();

        vm.prank(admin);
        shortfallStake.initialize(IERC20(address(shortfallToken)), 10, 1000, 1_000_000 ether);

        vm.prank(admin);
        shortfallStake.addPool(address(0), 100, 1 ether, 5, false);

        vm.deal(alice, 20 ether);
        vm.prank(alice);
        shortfallStake.depositETH{value: 10 ether}();

        vm.prank(admin);
        shortfallStake.setMetaNodePerBlock(1_000_000 ether);

        vm.roll(30);
        uint256 pendingBefore = shortfallStake.pendingMetaNode(0, alice);
        assertGt(pendingBefore, 0);

        shortfallToken.mint(address(shortfallStake), 1 ether);

        vm.prank(alice);
        shortfallStake.claim(0);

        assertEq(shortfallToken.balanceOf(alice), 1 ether);
        assertEq(shortfallToken.balanceOf(address(shortfallStake)), 0);
    }

    function test_multiplier_clamping_and_reward_shortfall_branches() public {
        vm.prank(admin);
        stake.addPool(address(0), 100, 1 ether, 5, false);

        vm.prank(admin);
        stake.addPool(address(stakingToken), 50, 2 ether, 5, false);

        vm.prank(alice);
        stakingToken.approve(address(stake), 100 ether);
        vm.prank(alice);
        stake.deposit(1, 10 ether);

        uint256 clamped = stake.getMultiplier(0, 2000);
        assertEq(clamped, 9900);

        MetaNodeStake shortfallStake = new MetaNodeStake();
        MockERC20 shortfallToken = new MockERC20();

        vm.prank(admin);
        shortfallStake.initialize(IERC20(address(shortfallToken)), 10, 1000, 10);
        vm.prank(admin);
        shortfallStake.addPool(address(0), 100, 1 ether, 5, false);

        vm.deal(alice, 20 ether);
        vm.prank(alice);
        shortfallStake.depositETH{value: 5 ether}();

        vm.roll(100);
        assertGt(shortfallStake.pendingMetaNode(0, alice), 0);

        shortfallToken.mint(address(shortfallStake), 1 ether);

        vm.prank(alice);
        shortfallStake.claim(0);

        assertGt(shortfallToken.balanceOf(alice), 0);
        assertLt(shortfallToken.balanceOf(address(shortfallStake)), 100 ether);

        vm.roll(110);
        vm.prank(admin);
        stake.updatePool(0);
        vm.prank(admin);
        stake.updatePool(1);
    }

    function test_transfer_safety_and_zero_supply_edges() public {
        MetaNodeStake zeroStake = new MetaNodeStake();
        MockERC20 zeroToken = new MockERC20();

        vm.prank(admin);
        zeroStake.initialize(IERC20(address(zeroToken)), 10, 100, 1);

        vm.prank(admin);
        zeroStake.addPool(address(0), 50, 1 ether, 4, false);

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        zeroStake.depositETH{value: 2 ether}();

        vm.roll(30);
        vm.prank(alice);
        zeroStake.unstake(0, 1 ether);

        vm.roll(40);
        vm.prank(alice);
        zeroStake.withdraw(0);

        vm.prank(alice);
        zeroStake.claim(0);
        assertEq(zeroStake.pendingMetaNode(0, alice), 0);

        vm.expectRevert("invalid pid");
        zeroStake.updatePool(3);

        vm.prank(admin);
        zeroStake.pauseWithdraw();
        vm.expectRevert("withdraw is paused");
        vm.prank(alice);
        zeroStake.withdraw(0);

        vm.prank(admin);
        zeroStake.unpauseWithdraw();
    }
}
