// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

contract PropAuctionFactory {
    event PropAuctionDeployed(
        address deploymentAddress,
        address erc721VotesToken
    );

    /// @notice Deploy a prop auction contract for a given treasury
    /// @param _erc721VotesToken The token address used to create proposals with
    /// @param _erc721VotesTokenIds The token IDs to hold in escrow
    /// @param _governorAddress The Compound Governor Bravo compliant
    function deployPropAuction(
        address _erc721VotesToken,
        uint256[] memory _erc721VotesTokenIds,
        address _governorAddress
    ) external {}
}
