// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/DelegateAuctionFactory.sol";
import "../src/DelegateAuction.sol";
import "../src/DelegateEscrow.sol";
import "../src/IDelegateEscrow.sol";
import "./utils/WETH.sol";
import "./utils/MockERC721.sol";
import "./utils/MockGovernor.sol";

contract DelegateEscrowTest is Test {
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

        uint256[] memory _tokenIds = new uint256[](3);
        _tokenIds[0] = 1;
        _tokenIds[1] = 2;
        _tokenIds[2] = 3;
        token.setApprovalForAll(address(factory), true);
        (address auctionAddr, address escrowAddr) = factory.deployPropAuction(
            address(token),
            _tokenIds,
            address(governor),
            60 * 60 * 24,
            1 gwei
        );
        auction = DelegateAuction(auctionAddr);
        escrow = DelegateEscrow(escrowAddr);
    }

    function test_SetAuctionActivity(bool _active) public {
        vm.prank(address(auction));
        escrow.setAuctionActivity(_active);

        assertEq(escrow.auctionActive(), _active);
    }

    function test_RevertSetAuctionActivityOnlyAuction() public {
        vm.expectRevert(IDelegateEscrow.ONLY_AUCTION.selector);
        escrow.setAuctionActivity(true);
    }

    function test_setDelegate(address _newDelegate) public {
        vm.prank(address(auction));
        escrow.setDelegate(_newDelegate);

        assertEq(escrow.currentDelegate(), _newDelegate);
    }

    function test_RevertSetDelegateOnlyAuction() public {
        vm.expectRevert(IDelegateEscrow.ONLY_AUCTION.selector);
        escrow.setDelegate(address(0));
    }

    function test_setOwner(address _newOwner) public {
        vm.prank(address(auction));
        escrow.setOwner(_newOwner);

        assertEq(escrow.owner(), _newOwner);
    }

    function test_RevertSetOwner() public {
        vm.expectRevert(IDelegateEscrow.ONLY_AUCTION.selector);
        escrow.setOwner(address(0));
    }

    function test_withdraw(uint256 _tokenId, address _destination) public {
        vm.assume(_tokenId > 0 && _tokenId < 4);
        vm.prank(address(auction));
        escrow.setOwner(address(this));

        vm.prank(address(auction));
        escrow.setAuctionActivity(false);

        escrow.withdraw(_tokenId, _destination);
    }

    function test_RevertWithdrawOnlyOwner(address _randomUser) public {
        vm.assume(_randomUser != escrow.owner());

        vm.prank(escrow.auction());
        escrow.setAuctionActivity(false);
        vm.prank(_randomUser);
        vm.expectRevert(IDelegateEscrow.ONLY_OWNER.selector);
        escrow.withdraw(1, address(this));
    }

    function test_RevertWithdrawOnlyAuctionInactive() public {
        vm.prank(escrow.owner());
        vm.expectRevert(IDelegateEscrow.ONLY_AUCTION_INACTIVE.selector);
        escrow.withdraw(1, address(this));
    }

    function test_executeGovernanceTransaction() public {
        bytes memory _calldata = abi.encodeWithSelector(
            MockGovernor.vote.selector
        );

        vm.prank(escrow.currentDelegate());
        escrow.executeGovernanceTransaction(_calldata);

        assertEq(MockGovernor(escrow.governor()).hasVoted(), true);
    }

    function test_RevertExecuteGovernanceTransactionOnlyDelegate(
        address _randomUser
    ) public {
        vm.assume(_randomUser != escrow.currentDelegate());
        vm.prank(_randomUser);
        vm.expectRevert(IDelegateEscrow.ONLY_CURRENT_DELEGATE.selector);
        escrow.executeGovernanceTransaction("");
    }
}
