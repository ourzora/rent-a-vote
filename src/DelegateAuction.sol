// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {IDelegateAuction} from "./IDelegateAuction.sol";

contract DelegateAuction is Initializable, IDelegateAuction {
    address public governorAddress;
    address public tokenAddress;
    uint256[] public tokenIds;
    address public owner;
    AuctionSettings public settings;
    Auction public auction;

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert ONLY_OWNER();
        }

        _;
    }

    function initialize() external initializer {}

    function createBid(uint256 auctionId) external payable {}

    function settleAuction() external {}

    function selfDestruct() external onlyOwner {}

    function transferOwnership() external onlyOwner {}

    function safeTransferOwnership() external onlyOwner {}

    function acceptOwnershipTransfer() external {
        //check pending owner
    }
}
