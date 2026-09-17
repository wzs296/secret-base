// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PriceOracle} from "./PriceOracle.sol";

/// @title Auction
/// @notice An NFT auction contract supporting ETH and ERC20 bidding with dynamic fees
contract Auction is Ownable, ReentrancyGuard {
    /// @notice Price oracle for USD conversions
    PriceOracle public priceOracle;
    /// @notice Counter for generating unique auction IDs
    uint256 private _auctionIdCounter = 1;

    /// @notice Auction structure
    struct AuctionData {
        address nftAddress;
        uint256 tokenId;
        address seller;
        address highestBidder;
        uint256 highestBid;
        address highestBidToken;
        uint startTime;
        uint256 endTime;
        bool ended;
        bool canceled;
    }

    /// @notice Mapping of auction IDs to auction data
    mapping(uint256 => AuctionData) public auctions;

    /// @notice Mapping of auction ID + bidder to bid amounts (for refunds)
    mapping(uint256 => mapping(address => uint256)) public bidderBalances;

    /// @notice Fee receiver address
    address public feeReceiver;

    /// @notice Fee percentage (1000 = 1%, 10000 = 100%)
    uint256 public feePerCentage = 250;

    /// @notice Events
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address seller,
        uint duration
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        address bidToken
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 finalBid,
        address bidToken
    );

    event AuctionCanceled(uint256 indexed auctionId);

    event FeeUpdated(uint256 newFeePercentage);

    event BidWithdrawn(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );

    /// @notice Initializes the Auction contract
    /// @param _priceOracle Address of the price oracle
    /// @param _feeReceiver Address to receive auction fees
    constructor(
        address _priceOracle,
        address _feeReceiver
    ) Ownable(msg.sender) {
        require(_priceOracle != address(0), "Invalid price oracle");
        require(_feeReceiver != address(0), "Invalide fee receiver");
        priceOracle = PriceOracle(_priceOracle);
        feeReceiver = _feeReceiver;
    }

    /// @notice Creates a new auction
    /// @param nftAddress Address of the NFT contract
    /// @param tokenId ID of the NFT
    /// @param duration Duration of the auction in seconds
    function createAuction(
        address nftAddress,
        uint256 tokenId,
        uint256 duration
    ) external nonReentrant {
        require(nftAddress != address(0), "Invalid NFT address");
        require(duration > 0, "Duration must be positive");
        IERC721(nftAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        uint256 auctionId = _auctionIdCounter++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        auctions[auctionId] = AuctionData({
            nftAddress: nftAddress,
            tokenId: tokenId,
            seller: msg.sender,
            highestBidder: address(0),
            highestBid: 0,
            highestBidToken: address(0),
            startTime: startTime,
            endTime: endTime,
            ended: false,
            canceled: false
        });

        emit AuctionCreated(
            auctionId,
            nftAddress,
            tokenId,
            msg.sender,
            duration
        );
    }

    /// @notice Places a bid on an auction
    /// @param auctionId ID of the auction
    /// @param bidAmount Amount to bid
    /// @param bidToken Token address (address(0) for ETH)
    function placeBid(
        uint256 auctionId,
        uint256 bidAmount,
        address bidToken
    ) external payable nonReentrant {
        AuctionData storage auction = auctions[auctionId];

        require(!auction.canceled, "Auction is canceled");
        require(!auction.ended, "Auction has ended");
        require(block.timestamp < auction.endTime, "Auction time expired");
        require(bidAmount > 0, "Bid amount must be positive");

        if (bidToken == address(0)) {
            require(
                msg.value == bidAmount,
                "Sent ETH doesn't match bid amount"
            );
        } else {
            require(msg.value == 0, "Cannot send ETH with ERC20 bid");
            IERC20(bidToken).transferFrom(msg.sender, address(this), bidAmount);
        }
        uint256 bidUSD = _convertToUSD(bidToken, bidAmount);
        uint256 highestBidUSD = _convertToUSD(
            auction.highestBidToken,
            auction.highestBid
        );
        require(
            bidUSD > highestBidUSD,
            "Bid must be higher than current highest bid"
        );
        if (auction.highestBidder != address(0)) {
            _refundBid(
                auctionId,
                auction.highestBidder,
                auction.highestBid,
                auction.highestBidToken
            );
        }

        // Update auction
        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;
        auction.highestBidToken = bidToken;
        bidderBalances[auctionId][msg.sender] = bidAmount;

        emit BidPlaced(auctionId, msg.sender, bidAmount, bidToken);
    }

    /// @notice Ends an auction
    /// @param auctionId ID of the auction
    function endAuction(uint256 auctionId) external nonReentrant {
        AuctionData storage auction = auctions[auctionId];
        require(!auction.ended, "Auction already ended");
        require(!auction.canceled, "Auction is canceled");
        require(block.timestamp >= auction.endTime, "Auction not finished yet");
        require(
            msg.sender == auction.seller || msg.sender == owner(),
            "Only seller or owner can end auction"
        );
        auction.ended = true;

        if (auction.highestBidder == address(0)) {
            IERC721(auction.nftAddress).safeTransferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );
        } else {
            IERC721(auction.nftAddress).safeTransferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );

            uint256 feeAmount = (auction.highestBid * feePerCentage) / 10000;
            uint256 sellerAmount = auction.highestBid - feeAmount;

            if (auction.highestBidToken == address(0)) {
                // ETH
                (bool sellerSuccess, ) = payable(auction.seller).call{
                    value: sellerAmount
                }("");
                require(sellerSuccess, "Seller transfer failed");

                (bool feeSuccess, ) = payable(feeReceiver).call{
                    value: feeAmount
                }("");
                require(feeSuccess, "Fee transfer failed");
            } else {
                // ERC20
                IERC20(auction.highestBidToken).transfer(
                    auction.seller,
                    sellerAmount
                );
                IERC20(auction.highestBidToken).transfer(
                    feeReceiver,
                    feeAmount
                );
            }
            delete bidderBalances[auctionId][auction.highestBidder];
        }
        emit AuctionEnded(
            auctionId,
            auction.highestBidder,
            auction.highestBid,
            auction.highestBidToken
        );
    }
    /// @notice Cancels an auction (only seller or owner)
    /// @param auctionId ID of the auction
    function cancelAuction(uint256 auctionId) external nonReentrant {
        AuctionData storage auction = auctions[auctionId];

        require(!auction.ended, "Auction already ended");
        require(!auction.canceled, "Auction already canceled");
        require(
            msg.sender == auction.seller || msg.sender == owner(),
            "Only seller or owner can cancel"
        );

        auction.canceled = true;

        // Return NFT to seller
        IERC721(auction.nftAddress).safeTransferFrom(
            address(this),
            auction.seller,
            auction.tokenId
        );

        // Refund highest bidder if any
        if (auction.highestBidder != address(0)) {
            _refundBid(
                auctionId,
                auction.highestBidder,
                auction.highestBid,
                auction.highestBidToken
            );
        }

        emit AuctionCanceled(auctionId);
    }
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 5000, "Fee too high"); // Max 50%
        feePerCentage = newFeePercentage;
        emit FeeUpdated(newFeePercentage);
    }
    /// @param newFeeReceiver New fee receiver address
    function setFeeReceiver(address newFeeReceiver) external onlyOwner {
        require(newFeeReceiver != address(0), "Invalid fee receiver");
        feeReceiver = newFeeReceiver;
    }
    /// @notice Gets auction details
    /// @param auctionId ID of the auction
    function getAuction(
        uint256 auctionId
    ) external view returns (AuctionData memory) {
        return auctions[auctionId];
    }
    /// @notice Gets the current highest bid in USD
    /// @param auctionId ID of the auction
    function getHighestBidUSD(
        uint256 auctionId
    ) external view returns (uint256) {
        AuctionData memory auction = auctions[auctionId];
        return _convertToUSD(auction.highestBidToken, auction.highestBid);
    }
    /// @notice Gets the next auction ID
    function getNextAuctionId() external view returns (uint256) {
        return _auctionIdCounter;
    }

    // ============ Internal Functions ============
    /// @notice Converts a bid amount to USD value
    /// @param bidToken Token address (address(0) for ETH)
    /// @param bidAmount Amount to convert
    function _convertToUSD(
        address bidToken,
        uint256 bidAmount
    ) internal view returns (uint256) {
        if (bidAmount == 0) return 0;
        uint8 tokenDecimals = bidToken == address(0) ? 18 : 18;

        try
            priceOracle.convertToUSD(bidToken, bidAmount, tokenDecimals)
        returns (uint256 usdValue) {
            return usdValue;
        } catch {
            // Fallback: treat amount as-is if oracle fails
            return bidAmount;
        }
    }
    /// @notice Refunds a bid to a bidder
    /// @param auctionId ID of the auction
    /// @param bidder Address of the bidder
    /// @param amount Amount to refund
    /// @param bidToken Token address
    function _refundBid(
        uint256 auctionId,
        address bidder,
        uint256 amount,
        address bidToken
    ) internal {
        if (bidToken == address(0)) {
            (bool success, ) = payable(bidder).call{value: amount}("");
            require(success, "ETH refund failed");
        } else {
            IERC20(bidToken).transfer(bidder, amount);
        }
        emit BidWithdrawn(auctionId, bidder, amount);
    }
    /// @notice Handle incoming ETH
    receive() external payable {}

    /// @notice ERC721 receiver function
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
