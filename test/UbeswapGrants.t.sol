// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../src/UbeswapGrants.sol";
import "./mock/MockERC20.sol";

contract UbeswapGrantsTest is Test {
    UbeswapGrants instance;
    MockERC20 token;

    address CONTRIB_0 = getAddressFromString("CONTRIB_0");
    address CONTRIB_1 = getAddressFromString("CONTRIB_1");

    bytes32 constant testIpfsHash = keccak256("ipfs_hash");

    function getAddressFromString(bytes memory str) private pure returns (address) {
        return address(uint160(uint256(keccak256(str))));
    }

    function setUp() public {
        instance = new UbeswapGrants(address(this));
        token = new MockERC20();
    }

    function testIsOwner() public {
        assertEq(instance.owner(), address(this));
    }

    function _applyForGrant() internal returns (uint256) {
        uint256[] memory msPayments = new uint256[](4);
        msPayments[0] = 100;
        msPayments[1] = 100;
        msPayments[2] = 400;
        msPayments[3] = 200;
        return instance.applyForGrant(testIpfsHash, address(token), msPayments);
    }

    function testApplyForGrant() public returns (uint256 id) {
        vm.prank(CONTRIB_0);
        id = _applyForGrant();
        vm.stopPrank();
    }

    function testWithdrawUnauth() public {
        uint256 id = testApplyForGrant();

        vm.prank(CONTRIB_1);
        vm.expectRevert(UbeswapGrants.SenderNotContributor.selector);
        instance.withdrawProposal(id);
    }

    function testWithdrawOnActive() public {
        uint256 id = testApplyForGrant();

        instance.acceptGrantProposal(id);
        vm.startPrank(instance.getGrant(id).contributor);

        vm.expectRevert(
            abi.encodeWithSelector(
                UbeswapGrants.StateMismatch.selector, UbeswapGrants.State.Active, UbeswapGrants.State.Pending
            )
        );
        instance.withdrawProposal(id);
    }

    function testWithdraw() public {
        uint256 id = testApplyForGrant();
        vm.startPrank(instance.getGrant(id).contributor);

        instance.withdrawProposal(id);
    }

    function testTransferContributor() public {
        uint256 id = testApplyForGrant();
        vm.startPrank(instance.getGrant(id).contributor);

        address to = address(1234);
        instance.transferGrantOwnership(id, to);
        assertEq(instance.getGrant(id).contributor, to);
    }
}
