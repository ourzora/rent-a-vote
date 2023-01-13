// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";

interface IDelegateEscrow {
    error ONLY_AUCTION();
    error ONLY_CURRENT_DELEGATE();
    error ONLY_OWNER();
    error EXECUTION_FAILED();
    error ONLY_AUCTION_INACTIVE();

    event TransactionExecuted(
        address delegate,
        address target,
        uint256 value,
        bytes cd
    );

    function initialize(
        address _governor,
        address _token,
        address _auction,
        address _owner
    ) external;

    function withdraw(uint256 tokenId, address to) external;

    function setAuctionActivity(bool active) external;

    function executeGovernanceTransaction(bytes calldata) external payable;
}
