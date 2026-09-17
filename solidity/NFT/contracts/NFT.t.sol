// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import { Test } from "forge-std/Test.sol";
import { NFT } from "./NFT.sol";

contract NFTTest is Test {
    NFT nft;
    address owner;
    address alice;
    address bob;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);
        nft = new NFT("https://example.com/metadata/");
    }

    function test_Initialization() public view {
        assertEq(nft.name(), "NFT");
        assertEq(nft.symbol(), "NFT");
        assertEq(nft.totalMinted(), 0);
    }

    function test_Mint() public {
        uint256 tokenId = nft.mint(alice);
        
        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.totalMinted(), 1);
    }

    function test_MintMultiple() public {
        uint256[] memory tokenIds = nft.mintBatch(alice, 3);
        
        assertEq(tokenIds.length, 3);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
        assertEq(tokenIds[2], 3);
        assertEq(nft.balanceOf(alice), 3);
        assertEq(nft.totalMinted(), 3);
    }

    function test_MintEmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit NFT.TokenMinted(alice, 1);
        nft.mint(alice);
    }

    function test_Transfer() public {
        uint256 tokenId = nft.mint(alice);
        
        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);
        
        assertEq(nft.ownerOf(tokenId), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_SafeTransfer() public {
        uint256 tokenId = nft.mint(alice);
        
        vm.prank(alice);
        nft.safeTransferFrom(alice, bob, tokenId);
        
        assertEq(nft.ownerOf(tokenId), bob);
    }

    function test_Approve() public {
        uint256 tokenId = nft.mint(alice);
        
        vm.prank(alice);
        nft.approve(bob, tokenId);
        
        assertEq(nft.getApproved(tokenId), bob);
    }

    function test_ApprovedTransfer() public {
        uint256 tokenId = nft.mint(alice);
        
        vm.prank(alice);
        nft.approve(bob, tokenId);
        
        vm.prank(bob);
        nft.transferFrom(alice, bob, tokenId);
        
        assertEq(nft.ownerOf(tokenId), bob);
    }

    function test_SetApprovalForAll() public {
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        
        assertTrue(nft.isApprovedForAll(alice, bob));
    }

    function test_MintOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.mint(alice);
    }

    function test_MintBatchOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.mintBatch(alice, 3);
    }

    function test_MintBatchZeroQuantity() public {
        vm.expectRevert("Quantity must be greater than 0");
        nft.mintBatch(alice, 0);
    }

    function test_TokenURI() public {
        uint256 tokenId = nft.mint(alice);
        string memory uri = nft.tokenURI(tokenId);
        
        assertEq(uri, "https://example.com/metadata/1.json");
    }

    function test_SetBaseURI() public {
        string memory newURI = "https://new.example.com/";
        nft.setBaseURI(newURI);
        
        uint256 tokenId = nft.mint(alice);
        string memory uri = nft.tokenURI(tokenId);
        
        assertEq(uri, "https://new.example.com/1.json");
    }

    function test_SetBaseURIOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.setBaseURI("https://new.example.com/");
    }
}