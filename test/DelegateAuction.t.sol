// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/DelegateAuctionFactory.sol";
import "../src/DelegateAuction.sol";
import "../src/DelegateEscrow.sol";
import "./utils/WETH.sol";
import "./utils/MockERC721.sol";
import "./utils/MockGovernor.sol";

contract DelegateAuctionTest is Test {
    DelegateAuctionFactory internal factory;
    DelegateAuction internal auctionImplementation;
    DelegateEscrow internal escrowImplementation;
    DelegateAuction internal auction;
    DelegateEscrow internal escrow;
    WETH internal weth;
    MockERC721 internal token;
    MockGovernor internal governor;

    address userA;
    address userB;

    modifier withSaneDuration(uint40 _duration) {
        vm.assume(_duration > 15 minutes && _duration < 365 days);

        _;
    }

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
        token.setApprovalForAll(address(factory), true);

        userA = vm.addr(0xa);
        userB = vm.addr(0xb);
    }

    function deploy(uint40 _duration, uint256 _reservePrice) internal {
        uint256[] memory _tokenIds = new uint256[](3);
        _tokenIds[0] = 1;
        _tokenIds[1] = 2;
        _tokenIds[2] = 3;
        (address auctionAddr, address escrowAddr) = factory.deployPropAuction(
            address(token),
            _tokenIds,
            address(governor),
            _duration,
            _reservePrice
        );
        auction = DelegateAuction(auctionAddr);
        escrow = DelegateEscrow(escrowAddr);
    }

    function test_createAuction(
        uint40 _duration,
        uint256 _reservePrice,
        uint256 _bidAmount
    ) public withSaneDuration(_duration) {
        vm.assume(_bidAmount > _reservePrice);
        deploy(_duration, _reservePrice);

        vm.deal(userA, _bidAmount);
        vm.warp(1);
        vm.prank(userA);
        auction.createAuction{value: _bidAmount}();

        (
            uint256 highestBid,
            address highestBidder,
            uint40 startTime,
            uint40 endTime,
            bool settled
        ) = auction.auction();

        assertEq(highestBid, _bidAmount);
        assertEq(highestBidder, userA);
        assertEq(startTime, uint40(block.timestamp));
        assertEq(endTime, uint40(block.timestamp + _duration));
        assertEq(settled, false);
    }

    function test_RevertCreateAuctionReservePriceNotMet(
        uint40 _duration,
        uint256 _reservePrice,
        uint256 _bidAmount
    ) public withSaneDuration(_duration) {
        vm.assume(_bidAmount < _reservePrice);
        deploy(_duration, _reservePrice);

        vm.deal(userA, _bidAmount);
        vm.warp(1);
        vm.prank(userA);
        vm.expectRevert(IDelegateAuction.RESERVE_PRICE_NOT_MET.selector);
        auction.createAuction{value: _bidAmount}();
    }

    function test_createBid(
        uint40 _duration,
        uint256 _reservePrice,
        uint256 _bid1Amount,
        uint256 _bid2Amount
    ) public withSaneDuration(_duration) {
        vm.assume(_bid1Amount > _reservePrice);
        vm.assume(_bid2Amount < 10000000 ether); // let's be sane
        vm.assume(_bid2Amount > _bid1Amount);
        deploy(_duration, _reservePrice);

        uint8 minBidIncPercent = auction.minBidIncrementPercent();
        vm.assume(
            _bid2Amount >
                (_bid1Amount + ((_bid1Amount * minBidIncPercent) / 100))
        );

        vm.deal(userA, _bid1Amount);
        vm.deal(userB, _bid2Amount);

        vm.warp(1);
        vm.prank(userA);
        auction.createAuction{value: _bid1Amount}();

        vm.prank(userB);
        auction.createBid{value: _bid2Amount}();

        (uint256 highestBid, address highestBidder, , , ) = auction.auction();

        assertEq(highestBid, _bid2Amount);
        assertEq(highestBidder, userB);
        assertEq(userA.balance, _bid1Amount);
    }

    function test_RevertCreateBid_AuctionOver(uint40 _duration)
        public
        withSaneDuration(_duration)
    {
        deploy(_duration, 1 ether);

        vm.deal(userA, 1 ether);
        vm.prank(userA);
        auction.createAuction{value: 1 ether}();

        vm.warp(block.timestamp + _duration);
        vm.expectRevert(IDelegateAuction.AUCTION_OVER.selector);
        auction.createBid();
    }

    function test_RevertCreateBid_MinBidNotMet(
        uint40 _duration,
        uint256 _reservePrice,
        uint256 _bid1Amount,
        uint256 _bid2Amount
    ) public withSaneDuration(_duration) {
        vm.assume(_bid1Amount > _reservePrice);
        vm.assume(_bid1Amount < 10000000 ether); // let's be sane
        deploy(_duration, _reservePrice);

        uint8 minBidIncPercent = auction.minBidIncrementPercent();
        vm.assume(
            _bid2Amount <
                (_bid1Amount + ((_bid1Amount * minBidIncPercent) / 100))
        );

        vm.deal(userA, _bid1Amount);
        vm.deal(userB, _bid2Amount);

        vm.warp(1);
        vm.prank(userA);
        auction.createAuction{value: _bid1Amount}();

        vm.prank(userB);
        vm.expectRevert(IDelegateAuction.MIN_BID_NOT_MET.selector);
        auction.createBid{value: _bid2Amount}();
    }

    function test_settleAuction(
        uint40 _duration,
        uint256 _reservePrice,
        uint256 _bidAmount
    ) public withSaneDuration(_duration) {
        uint256 beforeBalance = address(this).balance;
        vm.assume(_bidAmount > _reservePrice);
        vm.assume(_bidAmount < 1000 ether);
        deploy(_duration, _reservePrice);

        vm.deal(userA, _bidAmount);
        vm.warp(1);
        vm.prank(userA);
        auction.createAuction{value: _bidAmount}();

        vm.warp(block.timestamp + _duration);
        auction.settleAuction();

        (uint256 highestBid, address highestBidder, , , bool settled) = auction
            .auction();

        assertEq(settled, true);
        assertEq(_bidAmount, highestBid);
        assertEq(userA, highestBidder);
        assertEq(address(this).balance, beforeBalance + _bidAmount);
        assertEq(escrow.currentDelegate(), userA);
    }

    function test_RevertSettleAuction_AuctionSettled() public {
        deploy(1 days, 1 ether);

        vm.deal(userA, 1 ether);
        vm.warp(1);
        vm.prank(userA);
        auction.createAuction{value: 1 ether}();

        vm.warp(block.timestamp + 1 days);
        auction.settleAuction();

        vm.expectRevert(IDelegateAuction.AUCTION_SETTLED.selector);
        auction.settleAuction();
    }

    function test_RevertSettleAuction_AuctionActive() public {
        deploy(1 days, 1 ether);

        vm.deal(userA, 1 ether);
        vm.warp(1);
        vm.prank(userA);
        auction.createAuction{value: 1 ether}();

        vm.expectRevert(IDelegateAuction.AUCTION_ACTIVE.selector);
        auction.settleAuction();
    }

    function test_queueShutdown(bool _queue) public {
        deploy(1 days, 1 ether);
        vm.prank(auction.owner());
        auction.queueShutdown(_queue);

        assertEq(auction.isShutdownQueued(), _queue);
    }

    function test_RevertQueueShutdown_OnlyOwner(address _randomUser) public {
        deploy(1 days, 1 ether);
        vm.assume(_randomUser != auction.owner());
        vm.prank(_randomUser);
        vm.expectRevert(IDelegateAuction.ONLY_OWNER.selector);
        auction.queueShutdown(true);
    }

    function test_shutdown(
        uint40 _duration,
        uint256 _reservePrice,
        uint256 _bidAmount
    ) public withSaneDuration(_duration) {
        vm.assume(_bidAmount > _reservePrice);
        deploy(_duration, _reservePrice);

        vm.deal(userA, _bidAmount);
        vm.warp(1);
        vm.prank(userA);
        auction.createAuction{value: _bidAmount}();

        auction.queueShutdown(true);

        vm.warp(block.timestamp + _duration);
        auction.settleAuction();

        (, , , , bool settled) = auction.auction();

        assertEq(settled, true);
        assertEq(userA.balance, _bidAmount);
        assertEq(escrow.currentDelegate(), auction.owner());
        assertEq(auction.isShutdown(), true);

        vm.expectRevert(IDelegateAuction.AUCTION_PERMANENTLY_CLOSED.selector);
        auction.createAuction();
    }

    function test_transferOwnership(address _dest) public {
        deploy(1 days, 1 ether);
        vm.assume(_dest != auction.owner());

        vm.prank(auction.owner());
        auction.transferOwnership(_dest);

        assertEq(auction.owner(), _dest);
        assertEq(escrow.owner(), _dest);
    }

    function test_RevertTransferOwnership_OnlyOwner(address _randomUser)
        public
    {
        deploy(1 days, 1 ether);
        vm.assume(_randomUser != auction.owner());

        vm.expectRevert(IDelegateAuction.ONLY_OWNER.selector);
        vm.prank(_randomUser);
        auction.transferOwnership(_randomUser);
    }

    function test_safeTransferOwnership(address _dest) public {
        deploy(1 days, 1 ether);
        vm.assume(_dest != auction.owner());

        vm.prank(auction.owner());
        auction.safeTransferOwnership(_dest);

        assertEq(auction.pendingOwner(), _dest);
    }

    function test_RevertSafeTransferOwnership_OnlyOwner(address _randomUser)
        public
    {
        deploy(1 days, 1 ether);
        vm.assume(_randomUser != auction.owner());

        vm.expectRevert(IDelegateAuction.ONLY_OWNER.selector);
        vm.prank(_randomUser);
        auction.safeTransferOwnership(_randomUser);
    }

    function test_acceptOwnershipTransfer(address _dest) public {
        deploy(1 days, 1 ether);
        vm.assume(_dest != auction.owner());

        vm.prank(auction.owner());
        auction.safeTransferOwnership(_dest);

        vm.prank(_dest);
        auction.acceptOwnershipTransfer();

        assertEq(auction.owner(), _dest);
        assertEq(escrow.owner(), _dest);
    }

    function test_RevertAcceptOwnershipTransfer_OnlyPendingOwner(
        address _randomUser
    ) public {
        deploy(1 days, 1 ether);
        vm.assume(_randomUser != auction.owner());

        vm.expectRevert(IDelegateAuction.ONLY_PENDING_OWNER.selector);
        vm.prank(_randomUser);
        auction.acceptOwnershipTransfer();
    }

    receive() external payable {}
}
