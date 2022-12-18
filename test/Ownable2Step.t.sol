// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../src/utils/Ownable2Step.sol";

contract OwnableT is Ownable2Step {}

contract UbeswapGrantTest is Test {
    OwnableT instance;
    address NEW_OWNER = getAddressFromString("NEW_OWNER");

    function getAddressFromString(bytes memory str) private pure returns (address) {
        return address(uint160(uint256(keccak256(str))));
    }

    function setUp() public {
        instance = new OwnableT();
    }

    function testIsOwner() public {
        assertEq(instance.owner(), address(this));
    }

    function testPendingOwnerIsZero() public {
        assertEq(instance.pendingOwner(), address(0));
    }

    function testTransferOwnership() public {
        instance.transferOwnership(NEW_OWNER);
        assertEq(instance.pendingOwner(), NEW_OWNER);

        vm.prank(NEW_OWNER);
        instance.acceptOwnership();
        assertEq(instance.owner(), NEW_OWNER);

        testPendingOwnerIsZero();
    }

    function testRenounceOwnership() public {
        instance.transferOwnership(NEW_OWNER);
        instance.renounceOwnership();

        testPendingOwnerIsZero();
        assertEq(instance.owner(), address(0));
    }
}
