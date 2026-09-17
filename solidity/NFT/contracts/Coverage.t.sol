// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {Counter} from "./Counter.sol";
import {NFT} from "./NFT.sol";
import {PriceOracle} from "./PriceOracle.sol";
import {Auction} from "./Auction.sol";
import {ProxyFactory} from "./ProxyFactory.sol";
import {AuctionUpgradeable} from "./AuctionUpgradeable.sol";
import {AuctionUpgradeableV2} from "./AuctionUpgradeableV2.sol";

contract MockAggregator is AggregatorV3Interface {
    uint8 private _decimals = 8;
    int256 private _price;

    function setPrice(int256 price_) external {
        _price = price_;
    }

    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "mock";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80
    )
        external
        pure
        override
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        revert("not used");
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1, _price, block.timestamp, block.timestamp, 1);
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract InitMock {
    uint256 public value;

    function initialize(uint256 v) external {
        value = v;
    }
}

contract CoverageTest is Test {
    Counter internal counter;
    NFT internal nft;
    PriceOracle internal oracle;
    ProxyFactory internal proxyFactory;
    Auction internal auction;
    AuctionUpgradeable internal auctionUpgradeable;
    AuctionUpgradeableV2 internal auctionUpgradeableV2;
    MockAggregator internal ethFeed;
    MockAggregator internal tokenFeed;
    MockERC20 internal mockToken;

    address internal seller = address(0x1111);
    address internal bidder1 = address(0x2222);
    address internal bidder2 = address(0x3333);
    address internal feeReceiver = address(0x4444);

    function setUp() public {
        counter = new Counter();
        nft = new NFT("https://example.com/metadata/");
        oracle = new PriceOracle();
        ethFeed = new MockAggregator();
        tokenFeed = new MockAggregator();
        mockToken = new MockERC20();
        ethFeed.setPrice(1e8);
        tokenFeed.setPrice(2e8);

        oracle.registerPriceFeed(address(0), address(ethFeed));
        oracle.registerPriceFeed(address(mockToken), address(tokenFeed));

        proxyFactory = new ProxyFactory();
        auction = new Auction(address(oracle), feeReceiver);
    }

    function test_Counter_InitialAndIncBy() public {
        assertEq(counter.x(), 0);

        counter.inc();
        assertEq(counter.x(), 1);

        counter.incBy(5);
        assertEq(counter.x(), 6);
    }

    function test_Counter_IncByZeroReverts() public {
        vm.expectRevert();
        counter.incBy(0);
    }

    function test_NFT_MintBatchTokenURIAndSetBaseURI() public {
        nft.mint(seller);
        assertEq(nft.ownerOf(1), seller);

        uint256[] memory ids = nft.mintBatch(seller, 2);
        assertEq(ids.length, 2);
        assertEq(ids[0], 2);
        assertEq(ids[1], 3);
        assertEq(nft.totalMinted(), 3);
        assertEq(nft.balanceOf(seller), 3);
        assertEq(nft.tokenURI(1), "https://example.com/metadata/1.json");

        nft.setBaseURI("https://new.example.com/");
        assertEq(nft.tokenURI(2), "https://new.example.com/2.json");
    }

    function test_NFT_OnlyOwnerAndZeroQuantityReverts() public {
        vm.prank(bidder1);
        vm.expectRevert();
        nft.mint(bidder1);

        vm.prank(bidder1);
        vm.expectRevert();
        nft.setBaseURI("https://evil.example/");

        vm.expectRevert("Quantity must be greater than 0");
        nft.mintBatch(seller, 0);
    }

    function test_NFT_TransferAndApprovalFlows() public {
        nft.mint(seller);

        vm.prank(seller);
        nft.approve(bidder1, 1);
        assertEq(nft.getApproved(1), bidder1);

        vm.prank(bidder1);
        nft.transferFrom(seller, bidder2, 1);

        assertEq(nft.ownerOf(1), bidder2);
        assertEq(nft.balanceOf(seller), 0);
        assertEq(nft.balanceOf(bidder2), 1);

        vm.prank(bidder2);
        nft.setApprovalForAll(bidder1, true);
        assertTrue(nft.isApprovedForAll(bidder2, bidder1));

        assertTrue(nft.supportsInterface(0x80ac58cd));
        assertFalse(nft.supportsInterface(0xffffffff));
    }

    function test_NFT_EmptyBaseURIAndTokenURIFallback() public {
        NFT emptyNft = new NFT("");
        emptyNft.mint(seller);

        assertEq(emptyNft.baseURI(), "");
        assertEq(emptyNft.tokenURI(1), "");
    }

    function test_PriceOracle_RegisterGetAndConvert() public {
        vm.prank(bidder1);
        vm.expectRevert("Only owner can register price feeds");
        oracle.registerPriceFeed(address(mockToken), address(tokenFeed));

        vm.expectRevert("Invalid feed address");
        oracle.registerPriceFeed(address(mockToken), address(0));

        MockERC20 extraToken = new MockERC20();
        oracle.registerPriceFeed(address(extraToken), address(tokenFeed));
        assertEq(oracle.getPriceFeed(address(extraToken)), address(tokenFeed));

        uint256 usdValue = oracle.convertToUSD(address(0), 1e18, 18);
        assertEq(usdValue, 1e16);

        uint256 tokenUsd = oracle.convertToUSD(address(mockToken), 2e18, 18);
        assertEq(tokenUsd, 4e16);
    }

    function test_PriceOracle_ConvertRevertsWhenFeedMissingOrPriceInvalid() public {
        vm.expectRevert("Price feed not found");
        oracle.convertToUSD(address(0x9999), 1e18, 18);

        ethFeed.setPrice(0);
        vm.expectRevert("Invalid price");
        oracle.convertToUSD(address(0), 1e18, 18);
    }

    function test_ProxyFactory_DeploysProxyWithInitialization() public {
        InitMock implementation = new InitMock();
        bytes memory initData = abi.encodeCall(InitMock.initialize, (123));

        address deployed = proxyFactory.deployProxy(address(implementation), initData);
        assertTrue(deployed != address(0));

        InitMock proxied = InitMock(deployed);
        assertEq(proxied.value(), 123);
    }

    function test_Auction_CreateCancelAndEndWithoutBid() public {
        nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(auction), 1);

        vm.expectRevert("Invalid NFT address");
        auction.createAuction(address(0), 1, 60);

        vm.expectRevert("Duration must be positive");
        vm.prank(seller);
        auction.createAuction(address(nft), 1, 0);

        vm.prank(seller);
        auction.createAuction(address(nft), 1, 60);
        assertEq(auction.getNextAuctionId(), 2);

        vm.warp(block.timestamp + 61);
        auction.endAuction(1);
        assertEq(nft.ownerOf(1), seller);

        nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(auction), 2);
        vm.prank(seller);
        auction.createAuction(address(nft), 2, 60);
        vm.prank(seller);
        auction.cancelAuction(2);
        assertEq(nft.ownerOf(2), seller);
    }

    function test_Auction_BidRefundAndFinalizeWinner() public {
        vm.deal(seller, 10 ether);
        vm.deal(bidder1, 10 ether);
        vm.deal(bidder2, 20 ether);

        nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(auction), 1);

        vm.prank(seller);
        auction.createAuction(address(nft), 1, 60);

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(1, 1 ether, address(0));

        vm.prank(bidder2);
        auction.placeBid{value: 2 ether}(1, 2 ether, address(0));

        Auction.AuctionData memory created = auction.getAuction(1);
        assertEq(created.highestBidder, bidder2);
        assertEq(created.highestBid, 2 ether);

        vm.warp(block.timestamp + 61);
        auction.endAuction(1);

        assertEq(nft.ownerOf(1), bidder2);
        assertEq(auction.getAuction(1).ended, true);
    }

    function test_Auction_ERC20BidRefundCancelAndEnd() public {
        mockToken.mint(bidder1, 1000 ether);
        mockToken.mint(bidder2, 1000 ether);

        vm.prank(bidder1);
        mockToken.approve(address(auction), 1000 ether);
        vm.prank(bidder2);
        mockToken.approve(address(auction), 1000 ether);

        nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(auction), 1);
        vm.prank(seller);
        auction.createAuction(address(nft), 1, 60);

        vm.prank(bidder1);
        auction.placeBid(1, 100 ether, address(mockToken));

        vm.prank(bidder2);
        auction.placeBid(1, 200 ether, address(mockToken));

        uint256 bidder2BalanceBefore = mockToken.balanceOf(bidder2);
        assertEq(auction.getHighestBidUSD(1), 4e18);
        assertEq(auction.getAuction(1).highestBidder, bidder2);

        vm.prank(seller);
        auction.cancelAuction(1);
        assertEq(mockToken.balanceOf(bidder2), bidder2BalanceBefore + 200 ether);

        nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(auction), 2);
        vm.prank(seller);
        auction.createAuction(address(nft), 2, 60);

        vm.prank(bidder1);
        auction.placeBid(2, 100 ether, address(mockToken));
        vm.prank(bidder2);
        auction.placeBid(2, 200 ether, address(mockToken));

        vm.warp(block.timestamp + 61);
        vm.prank(seller);
        auction.endAuction(2);

        assertEq(mockToken.balanceOf(seller), 195 ether);
        assertEq(mockToken.balanceOf(feeReceiver), 5 ether);
    }

    function test_AuctionUpgradeable_ERC20FlowAndOwnerGuards() public {
        auctionUpgradeable = new AuctionUpgradeable();
        bytes memory initData = abi.encodeCall(
            AuctionUpgradeable.initialize,
            (address(oracle), feeReceiver)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(auctionUpgradeable), initData);
        AuctionUpgradeable proxied = AuctionUpgradeable(payable(address(proxy)));

        mockToken.mint(bidder1, 1000 ether);
        mockToken.mint(bidder2, 1000 ether);

        vm.prank(bidder1);
        mockToken.approve(address(proxied), 1000 ether);
        vm.prank(bidder2);
        mockToken.approve(address(proxied), 1000 ether);

        nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(proxied), 1);
        vm.prank(seller);
        proxied.createAuction(address(nft), 1, 60);

        vm.prank(bidder1);
        proxied.placeBid(1, 100 ether, address(mockToken));
        vm.prank(bidder2);
        proxied.placeBid(1, 200 ether, address(mockToken));

        assertEq(proxied.getHighestBidUSD(1), 4e18);
        assertEq(proxied.getAuction(1).highestBidder, bidder2);

        vm.prank(seller);
        proxied.cancelAuction(1);
        assertEq(mockToken.balanceOf(bidder2), 1000 ether);

        vm.prank(address(this));
        proxied.setFeePercentage(500);
        assertEq(proxied.feePerCentage(), 500);

        vm.prank(bidder1);
        vm.expectRevert();
        proxied.setFeePercentage(6000);

        vm.prank(address(this));
        vm.expectRevert("Fee too high");
        proxied.setFeePercentage(6001);
    }

    function test_Auction_SetFeeAndOwnerGuards() public {
        auction.setFeePercentage(500);
        assertEq(auction.feePerCentage(), 500);

        auction.setFeeReceiver(bidder1);
        assertEq(auction.feeReceiver(), bidder1);

        vm.expectRevert("Fee too high");
        auction.setFeePercentage(6001);

        vm.prank(bidder1);
        vm.expectRevert();
        auction.setFeePercentage(6000);

        vm.prank(bidder1);
        vm.expectRevert();
        auction.setFeeReceiver(address(0));
    }

    function test_Auction_ReceiveAndERC721Receiver() public {
        (bool sent, ) = address(auction).call{value: 1 ether}("");
        assertTrue(sent);

        bytes4 selector = auction.onERC721Received(address(0), address(0), 1, hex"");
        assertEq(uint32(selector), uint32(0x150b7a02));
    }

    function test_AuctionUpgradeable_InitializeUpgradeAndVersion() public {
        auctionUpgradeable = new AuctionUpgradeable();

        bytes memory initData = abi.encodeCall(
            AuctionUpgradeable.initialize,
            (address(oracle), feeReceiver)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(auctionUpgradeable), initData);
        AuctionUpgradeable proxied = AuctionUpgradeable(payable(address(proxy)));

        assertEq(proxied.owner(), address(this));
        assertEq(proxied.feeReceiver(), feeReceiver);

        nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(proxied), 1);
        vm.prank(seller);
        proxied.createAuction(address(nft), 1, 60);
        assertEq(proxied.getNextAuctionId(), 2);

        vm.expectRevert("Invalid implementation");
        proxied.upgradeToAndCall(address(0), hex"");

        auctionUpgradeableV2 = new AuctionUpgradeableV2();
        proxied.upgradeToAndCall(address(auctionUpgradeableV2), hex"");

        AuctionUpgradeableV2 upgraded = AuctionUpgradeableV2(payable(address(proxy)));
        upgraded.initializeV2();
        assertEq(upgraded.getVersion(), 2);
    }

    function test_PriceOracle_LowerDecimalsFallbackPath() public {
        MockERC20 alt = new MockERC20();
        oracle.registerPriceFeed(address(alt), address(tokenFeed));

        uint256 usd = oracle.convertToUSD(address(alt), 2e18, 6);
        assertEq(usd, 4e28);
    }
}
