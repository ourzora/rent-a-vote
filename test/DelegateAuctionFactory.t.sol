// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/DelegateAuctionFactory.sol";
import "../src/DelegateAuction.sol";
import "../src/DelegateEscrow.sol";
import "./utils/WETH.sol";
import "./utils/MockERC721.sol";
import "./utils/MockGovernor.sol";

contract DelegateAuctionFactoryTest is Test {
    DelegateAuctionFactory internal factory;
    DelegateAuction internal auctionImplementation;
    DelegateEscrow internal escrowImplementation;
    WETH internal weth;
    MockERC721 internal token;
    MockGovernor internal governor;

    address userA;
    address userB;

    function setUp() public {
        weth = new WETH();
        auctionImplementation = new DelegateAuction(address(weth));
        escrowImplementation = new DelegateEscrow();
        factory = new DelegateAuctionFactory(
            address(escrowImplementation),
            address(auctionImplementation)
        );
        governor = new MockGovernor();
        token = new MockERC721();
        token.mint(address(this), 1);
        token.mint(address(this), 2);
        token.mint(address(this), 3);
    }

    function test_DeployPropAuction(uint40 _duration, uint256 _reservePrice)
        public
    {
        uint256[] memory _tokenIds = new uint256[](3);
        _tokenIds[0] = 1;
        _tokenIds[1] = 2;
        _tokenIds[2] = 3;

        token.setApprovalForAll(address(factory), true);

        (address auctionAddr, address escrowAddr) = factory.deployPropAuction(
            address(token),
            _tokenIds,
            address(governor),
            _duration,
            _reservePrice
        );
        DelegateAuction _auction = DelegateAuction(auctionAddr);
        DelegateEscrow _escrow = DelegateEscrow(escrowAddr);

        assertEq(_auction.owner(), address(this));
        assertEq(_auction.escrow(), address(_escrow));
        assertEq(_auction.duration(), _duration);
        assertEq(_auction.reservePrice(), _reservePrice);

        assertEq(_escrow.governor(), address(governor));
        assertEq(_escrow.token(), address(token));
        assertEq(_escrow.auction(), address(_auction));
        assertEq(_escrow.owner(), address(this));
        assertEq(_escrow.auctionActive(), true);
        assertEq(_escrow.currentDelegate(), address(this));
    }
}
