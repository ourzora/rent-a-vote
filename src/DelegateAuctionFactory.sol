// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {Clones} from "openzeppelin/proxy/Clones.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IDelegateEscrow} from "./IDelegateEscrow.sol";
import {IDelegateAuction} from "./IDelegateAuction.sol";

contract PropAuctionFactory {
    using Clones for address;

    address public immutable escrowImplemenation;
    address public immutable auctionImplementation;

    event PropAuctionDeployed(address auction, address escrow);

    constructor(address _escrowImplementation, address _auctionImplementation) {
        escrowImplemenation = _escrowImplementation;
        auctionImplementation = _auctionImplementation;
    }

    /// @notice Deploy a prop auction contract for a given treasury
    /// @param _erc721VotesToken The token address used to create proposals with
    /// @param _erc721VotesTokenIds The token IDs to hold in escrow (should be higher than proposalThreshold for the governor contract)
    /// @param _governor The Governor contract to create proposals on
    function deployPropAuction(
        address _erc721VotesToken,
        uint256[] memory _erc721VotesTokenIds,
        address _governor
    ) external returns (address, address) {
        address _escrow = escrowImplemenation.clone();
        address _auction = auctionImplementation.clone();

        IDelegateAuction(_auction).initialize();
        IDelegateEscrow(_escrow).initialize(
            _governor,
            _erc721VotesToken,
            _auction,
            msg.sender
        );

        for (uint256 i = 0; i < _erc721VotesTokenIds.length; i++) {
            IERC721(_erc721VotesToken).transferFrom(
                msg.sender,
                _escrow,
                _erc721VotesTokenIds[i]
            );
        }

        emit PropAuctionDeployed(_auction, _escrow);

        return (_auction, _escrow);
    }
}