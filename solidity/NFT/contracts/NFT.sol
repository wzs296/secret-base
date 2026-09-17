// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title NFT
/// @notice A simple ERC721 NFT contract with mint and transfer functionality
contract NFT is ERC721, ERC721Enumerable, Ownable {
    using Strings for uint256;

    /// @notice Base URI for metadata
    string private _baseTokenURI;

    /// @notice Counter for generating unique token IDS
    uint256 private _tokenIdCounter;

    /// @notice Emitted when a new token is minted
    event TokenMinted(address indexed to, uint256 indexed tokenId);

    /// @notice Emitted when base URI is updated
    event BaseURIUpdated(string newBaseURI);

    /// @notice Initializes the NFT contract
    /// @param initialBaseURI The initial base URI for token metadata
    constructor(
        string memory initialBaseURI
    ) ERC721("NFT", "NFT") Ownable(msg.sender) {
        _baseTokenURI = initialBaseURI;
        _tokenIdCounter = 1;
    }

    /// @notice Mints a new NFT to the specified address
    /// @param to The address to mint the NFT to
    /// @return tokenId The ID of the newly minted token
    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
        emit TokenMinted(to, tokenId);
        return tokenId;
    }

    /// @notice Mints multiple NFTs to the specified address
    /// @param to The address to mint NFTs to
    /// @param quantity The number of NFTs to mint
    /// @return tokenIds Array of newly minted token IDs
    function mintBatch(
        address to,
        uint256 quantity
    ) external onlyOwner returns (uint256[] memory) {
        require(quantity > 0, "Quantity must be greater than 0");
        uint256[] memory tokenids = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter;
            _tokenIdCounter++;
            _safeMint(to, tokenId);
            tokenids[i] = tokenId;
            emit TokenMinted(to, tokenId);
        }
        return tokenids;
    }

    /// @notice Sets the base URI for token metadata
    /// @param newBaseURI The new base URI
    function setBaseURI(
        string calldata newBaseURI
    ) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /// @notice Returns the base URI
    function baseURI() external view returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Returns the total number of tokens minted
    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter - 1;
    }

    /// @notice Returns the token URI for a given token ID
    /// @param tokenId The token ID
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI_ = _baseTokenURI;
        return
            bytes(baseURI_).length > 0
                ? string(
                    abi.encodePacked(baseURI_, tokenId.toString(), ".json")
                )
                : "";
    }

    /// @notice Handles the required overrides from multiple inheritance
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    /// @notice Handles the required overrides from multiple inheritance
    function _update(address to, uint256 tokenId, address auth)internal override(ERC721, ERC721Enumerable) returns(address) {
        return super._update(to,tokenId,auth);
    }

        /// @notice Handles the required overrides from multiple inheritance
        function _increaseBalance(address account,uint128 value)internal override(ERC721, ERC721Enumerable) {
            super._increaseBalance(account,value);
        }
}
