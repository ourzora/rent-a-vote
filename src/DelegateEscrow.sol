// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IDelegateEscrow} from "./IDelegateEscrow.sol";

contract DelegateEscrow is Initializable, IDelegateEscrow {
    address public governor;
    address public token;
    address public auction;
    address public currentDelegate;
    address public owner;
    bool public auctionActive;

    modifier onlyAuction() {
        if (msg.sender != auction) {
            revert ONLY_AUCTION();
        }

        _;
    }

    function initialize(
        address _governor,
        address _token,
        address _auction,
        address _owner
    ) external initializer {
        governor = _governor;
        token = _token;
        auction = _auction;
        owner = _owner;
        auctionActive = true;
        currentDelegate = owner;
    }

    function setAuctionActivity(bool _active) external onlyAuction {
        auctionActive = _active;
    }

    function withdraw(uint256 _tokenId, address _to) external {
        if (msg.sender != owner) {
            revert ONLY_OWNER();
        }
        if (auctionActive) {
            revert ONLY_AUCTION_INACTIVE();
        }

        IERC721(token).transferFrom(address(this), _to, _tokenId);
    }

    function executeGovernanceTransaction(bytes memory _calldata)
        external
        payable
    {
        if (msg.sender != currentDelegate) {
            revert ONLY_CURRENT_DELEGATE();
        }

        (bool success, ) = governor.call{value: msg.value}(_calldata);

        if (!success) {
            revert EXECUTION_FAILED();
        }

        emit TransactionExecuted(
            currentDelegate,
            governor,
            msg.value,
            _calldata
        );
    }
}
