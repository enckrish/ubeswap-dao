// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

contract UbeswapGrants {
    struct Grant {
        address contributor;
        uint256 totalPayment;
    }

    address dao;

    error SenderNotDAO();
    error SenderNotContributor();

    modifier onlyDAO() {
        if (msg.sender != dao) revert SenderNotDAO();
        _;
    }

    modifier onlyGrantContributor(Grant memory grant) {
        if (msg.sender != grant.contributor) revert SenderNotContributor();
        _;
    }
}
