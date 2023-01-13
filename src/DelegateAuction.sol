// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {IDelegateAuction} from "./IDelegateAuction.sol";
import {IDelegateEscrow} from "./IDelegateEscrow.sol";

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);
}

contract DelegateAuction is Initializable, IDelegateAuction {
    /// @notice Iniital time buffer for auction bids
    uint40 public immutable timeBuffer = 5 minutes;

    /// @notice Min bid increment BPS
    uint8 public immutable minBidIncrementPercent = 10;

    address public immutable WETH;

    // @notice The reserve price of the auction
    uint256 public reservePrice;

    /// @notice The duration of feach auction
    uint256 public duration;

    // @notice the owner of the auction
    address public owner;

    // @notice the pending owner of the auction
    address public pendingOwner;

    // @notice the escrow contract of the auction
    address public escrow;

    // @notice the current auction's details
    Auction public auction;

    // @notice shutdown start time - used to ensure shutdown does not lock any funds.
    bool private isShutdown;

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert ONLY_OWNER();
        }

        _;
    }

    modifier notShutdown() {
        if (isShutdown) {
            revert AUCTION_PERMANENTLY_CLOSED();
        }

        _;
    }

    constructor(address _weth) {
        WETH = _weth;
    }

    function initialize(
        address _owner,
        address _escrow,
        uint40 _duration,
        uint256 _reservePrice
    ) external initializer {
        owner = _owner;
        escrow = _escrow;
        duration = _duration;
        reservePrice = _reservePrice;
    }

    /// @notice Create a bid. If the auction hasn't started yet, this also starts the auction.
    function createBid() public payable notShutdown {
        if (auction.startTime != 0 && auction.endTime <= block.timestamp) {
            revert AUCTION_OVER();
        }

        address lastHighestBidder = auction.highestBidder;
        uint256 lastHighestBid = auction.highestBid;

        bool extend;

        // Cannot overflow, would've reverted above.
        unchecked {
            extend = (auction.endTime - block.timestamp) < timeBuffer;

            if (extend) {
                auction.endTime = uint40(block.timestamp + timeBuffer);
            }
        }

        // If this is the first bid
        if (lastHighestBidder == address(0)) {
            if (msg.value < reservePrice || msg.value == 0) {
                revert RESERVE_PRICE_NOT_MET();
            }

            // Else if this is a subsequent bid
        } else {
            uint256 minBid;

            unchecked {
                minBid =
                    lastHighestBid +
                    ((lastHighestBid * minBidIncrementPercent) / 100);
            }

            if (msg.value < minBid || msg.value == 0) {
                revert MIN_BID_NOT_MET();
            }

            // Refund the last bidder
            _handleOutgoingTransfer(lastHighestBidder, lastHighestBid);
        }
    }

    /// @notice Settle a completed auction
    function settleAuction() external notShutdown {
        _settleAuction();
    }

    /// @notice Create a new auction, settling the previous auction if required.
    function createAuction() external payable notShutdown {
        if (!auction.settled) {
            _settleAuction();
        }
        _createAuction();
        createBid();
    }

    /// @notice Forcefully shuts down the auction. Reimburses highest bidder, and opens up escrow contract for withdrawal. This is a one-way operation and cannot be undone.
    function shutdown() external onlyOwner notShutdown {
        if (!auction.settled) {
            // refund the highest bidder
            _handleOutgoingTransfer(auction.highestBidder, auction.highestBid);
        }

        IDelegateEscrow(escrow).setAuctionActivity(false);

        isShutdown = true;

        emit AuctionShutdown();
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        _setOwner(_newOwner);
    }

    function safeTransferOwnership(address _newOwner) external onlyOwner {
        pendingOwner = _newOwner;
    }

    function acceptOwnershipTransfer() external {
        if (msg.sender != pendingOwner) {
            revert ONLY_PENDING_OWNER();
        }

        _setOwner(pendingOwner);
    }

    function _createAuction() private {
        auction.startTime = uint40(block.timestamp);
        auction.endTime = uint40(block.timestamp + duration);
        auction.highestBid = 0;
        auction.highestBidder = address(0);
        auction.settled = false;

        emit AuctionCreated(auction.startTime, auction.endTime);
    }

    function _settleAuction() private {
        // Get a copy of the current auction
        Auction memory _auction = auction;

        // Ensure the auction wasn't already settled
        if (_auction.settled) revert AUCTION_SETTLED();

        // Ensure the auction had started
        if (_auction.startTime == 0) revert AUCTION_NOT_STARTED();

        // Ensure the auction is over
        if (block.timestamp < _auction.endTime) revert AUCTION_ACTIVE();

        // Mark the auction as settled
        auction.settled = true;

        _handleOutgoingTransfer(owner, auction.highestBid);

        IDelegateEscrow(escrow).setDelegate(auction.highestBidder);

        emit AuctionSettled(auction.highestBidder, auction.highestBid);
    }

    function _setOwner(address _newOwner) private {
        owner = _newOwner;
        IDelegateEscrow(escrow).setOwner(_newOwner);

        emit NewOwner(_newOwner);
    }

    /// @notice Transfer ETH/WETH from the contract
    /// @param _to The recipient address
    /// @param _amount The amount transferring
    function _handleOutgoingTransfer(address _to, uint256 _amount) private {
        // Ensure the contract has enough ETH to transfer
        if (address(this).balance < _amount) revert INSOLVENT();

        // Used to store if the transfer succeeded
        bool success;

        assembly {
            // Transfer ETH to the recipient
            // Limit the call to 50,000 gas
            success := call(50000, _to, _amount, 0, 0, 0, 0)
        }

        // If the transfer failed:
        if (!success) {
            // Wrap as WETH
            IWETH(WETH).deposit{value: _amount}();

            // Transfer WETH instead
            bool wethSuccess = IWETH(WETH).transfer(_to, _amount);

            // Ensure successful transfer
            if (!wethSuccess) {
                revert FAILING_WETH_TRANSFER();
            }
        }
    }
}
