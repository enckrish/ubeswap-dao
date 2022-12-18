// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../src/UbeswapGrants.sol";
import "./mock/MockERC20.sol";

contract UbeswapGrantTest is Test {
    UbeswapGrants instance;
    MockERC20 token;

    address CONTRIB_0 = getAddressFromString("CONTRIB_0");

    function getAddressFromString(bytes memory str) private pure returns (address) {
        return address(uint160(uint256(keccak256(str))));
    }

    function setUp() public {
        instance = new UbeswapGrants(msg.sender);
        token = new MockERC20();
    }

    function testIsOwner() public {
        assertEq(instance.owner(), msg.sender);
    }
}
