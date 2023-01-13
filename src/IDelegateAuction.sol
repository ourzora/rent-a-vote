// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";

interface IDelegateAuction {
    /// @notice The settings for the auction
    /// @param duration The time duration of each auction
    /// @param timeBuffer The minimum time to place a bid
    /// @param minBidIncrement The minimum percentage an incoming bid must raise the highest bid
    /// @param reservePrice The reserve price of each auction
    struct AuctionSettings {
        uint40 duration;
        uint40 timeBuffer;
        uint8 minBidIncrement;
        uint256 reservePrice;
    }

    /// @notice The auction storage layout
    /// @param auctionId The auction id
    /// @param highestBid The highest amount of ETH raised
    /// @param highestBidder The leading bidder
    /// @param startTime The timestamp the auction starts
    /// @param endTime The timestamp the auction ends
    /// @param settled If the auction has been settled
    struct Auction {
        uint256 auctionId;
        uint256 highestBid;
        address highestBidder;
        uint40 startTime;
        uint40 endTime;
        bool settled;
    }

    error ONLY_OWNER();

    function initialize() external;

    function createBid(uint256 auctionId) external payable;

    function settleAuction() external;

    function selfDestruct() external;

    function transferOwnership() external;

    function safeTransferOwnership() external;

    function acceptOwnershipTransfer() external;
}
