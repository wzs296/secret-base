// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title PriceOracle
/// @notice Provides price feeds for tokens using Chainlink
contract PriceOracle {
    /// @notice Mapping of token addresses to their Chainlink price feeds
    mapping(address => AggregatorV3Interface) public priceFeeds;

    /// @notice Address of the contract owner
    address public owner;

    /// @notice Emitted when a price feed is registered
    event PriceFeedRegistered(address indexed token, address indexed feed);

    /// @notice Initializes the PriceOracle contract
    constructor() {
        owner = msg.sender;
    }
       /// @notice Registers a price feed for a token
    /// @param token The token address (address(0) for ETH)
    /// @param feed The Chainlink AggregatorV3Interface address
    function registerPriceFeed(address token, address feed)external{
        require(msg.sender==owner,"Only owner can register price feeds");
        require(feed!=address(0),"Invalid feed address");

        priceFeeds[token]=AggregatorV3Interface(feed);
        emit PriceFeedRegistered(token, feed);
    }

        /// @notice Converts a token amount to USD value
    /// @param token The token address (address(0) for ETH)
    /// @param amount The amount of tokens (with token decimals)
    /// @param tokenDecimals The number of decimals for the token
    /// @return usdValue The value in USD (with 8 decimals for Chainlink)
    function convertToUSD(address token,uint256 amount,uint8 tokenDecimals)external view returns(uint256 ) {
        AggregatorV3Interface feed=priceFeeds[token];
        require(address(feed)!=address(0),"Price feed not found");

        (,int256 price,,,)=feed.latestRoundData();
        require(price>0,"Invalid price");

        uint256 usdPrice=uint256(price);

        if(tokenDecimals>=8){
            return (amount* usdPrice)/(10**(tokenDecimals-8));
        }else{
            return(amount*usdPrice)*(10**(8-tokenDecimals));
        }
    }
        /// @notice Gets the price feed for a token
    /// @param token The token address
    /// @return feed The AggregatorV3Interface address
    function getPriceFeed(address token) external view returns(address){
        return address(priceFeeds[token]);
    }
}
