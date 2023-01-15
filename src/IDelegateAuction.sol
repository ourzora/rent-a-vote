// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";

interface IDelegateAuction {
    /// @notice The auction storage layout
    /// @param auctionId The auction id
    /// @param highestBid The highest amount of ETH raised
    /// @param highestBidder The leading bidder
    /// @param startTime The timestamp the auction starts
    /// @param endTime The timestamp the auction ends
    /// @param settled If the auction has been settled
    struct Auction {
        uint256 highestBid;
        address highestBidder;
        uint40 startTime;
        uint40 endTime;
        bool settled;
    }

    error ONLY_OWNER();
    error ONLY_PENDING_OWNER();
    error AUCTION_OVER();
    error RESERVE_PRICE_NOT_MET();
    error MIN_BID_NOT_MET();
    error FAILING_WETH_TRANSFER();
    error AUCTION_SETTLED();
    error AUCTION_ACTIVE();
    error AUCTION_SHUTDOWN_NOT_QUEUED();
    error AUCTION_PERMANENTLY_CLOSED();
    error INSOLVENT();
    error DURATION_TOO_SMALL();
    error DURATION_TOO_LARGE();

    event AuctionCreated(uint40 startTime, uint40 endTime);

    event AuctionBid(address bidder, uint256 amount, uint40 endTime);

    event AuctionSettled(address highestBidder, uint256 highestBid);

    event AuctionShutdown();

    event NewOwner(address newOwner);

    function initialize(
        address owner,
        address escrow,
        uint40 duration,
        uint256 reservePrice
    ) external;

    function createBid() external payable;

    function settleAuction() external;

    function createAuction() external payable;

    function queueShutdown(bool queue) external;

    function transferOwnership(address newOwner) external;

    function safeTransferOwnership(address newOwner) external;

    function acceptOwnershipTransfer() external;
}
