// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "solmate-utils/SafeTransferLib.sol";
import "solmate/tokens/ERC20.sol";
import "./utils/Ownable2Step.sol";

contract UbeswapGrants is Ownable2Step {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    enum State {
        Pending,
        Rejected,
        Withdrawn,
        Active,
        Discontinued,
        Fulfilled
    }

    struct Grant {
        /// payment receiving address
        address contributor;
        /// may be address(0) for paying in CELO/ETH
        address token;
        /// current status of the grant request
        State state;
        /// next milestone
        uint8 nextMsId;
        /// payments at each milestone
        uint256[] msPayments;
        /// ipfs hash of details (uses CIDv1)
        bytes32 detailsHash;
    }

    Grant[] internal _grants;

    event RequestSubmitted(address indexed contributor, uint256 indexed grantId);
    event Withdrawn(uint256 indexed grantId);
    event GrantOwnershipTransferred(uint256 indexed grantId, address indexed oldOwner, address indexed newOwner);
    event GrantAccepted(uint256 indexed grantId);
    event PaymentReleased(uint256 indexed grantId, uint256 milestoneId);

    error SenderNotContributor();
    error StateMismatch(State actual, State required);
    error GrantAlreadyFulfilled();

    constructor(address dao_) {
        _transferOwnership(dao_);
    }

    /* -------------------------------------------------------------------------- */
    /*                             ACCESS RESTRICTIONS                            */
    /* -------------------------------------------------------------------------- */
    // these are implemented as function instead of modifiers to save extra SLOADs

    function _revertIfNonContributor(Grant storage grant) internal view {
        if (msg.sender != grant.contributor) revert SenderNotContributor();
    }

    function _revertIfNotState(Grant storage grant, State state) internal view {
        if (grant.state != state) {
            revert StateMismatch(grant.state, state);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                             CONTRIBUTOR METHODS                            */
    /* -------------------------------------------------------------------------- */

    function applyForGrant(bytes32 detailsHash_, address token_, uint256[] calldata msPayments_)
        external
        returns (uint256 grantId)
    {
        _grants.push(
            Grant({
                contributor: msg.sender,
                detailsHash: detailsHash_,
                token: token_,
                nextMsId: 0,
                msPayments: msPayments_,
                state: State.Pending
            })
        );

        grantId = _grants.length - 1;
        emit RequestSubmitted(msg.sender, grantId);
    }

    function withdrawProposal(uint256 grantId) external {
        Grant storage grant = _grants[grantId];
        _revertIfNonContributor(grant);
        _revertIfNotState(grant, State.Pending);

        grant.state = State.Withdrawn;
        emit Withdrawn(grantId);
    }

    function transferGrantOwnership(uint256 grantId, address newOwner) external {
        Grant storage grant = _grants[grantId];
        _revertIfNonContributor(grant);

        emit GrantOwnershipTransferred(grantId, grant.contributor, newOwner);
        grant.contributor = newOwner;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 DAO METHODS                                */
    /* -------------------------------------------------------------------------- */

    function acceptGrantProposal(uint256 grantId) external onlyOwner {
        Grant storage grant = _grants[grantId];
        _revertIfNotState(grant, State.Pending);
        grant.state = State.Active;
        emit GrantAccepted(grantId);
    }

    function releasePayment(uint256 grantId) external onlyOwner {
        Grant storage grant = _grants[grantId];
        _revertIfNotState(grant, State.Active);

        uint8 msId = grant.nextMsId++;
        emit PaymentReleased(grantId, msId);

        if (msId + 1 == grant.msPayments.length) grant.state = State.Fulfilled;

        address payToken = grant.token;
        address contributor = grant.contributor;
        uint256 amountToSend = grant.msPayments[msId];

        if (payToken == address(0)) {
            contributor.safeTransferETH(amountToSend);
        } else {
            ERC20(payToken).safeTransfer(contributor, amountToSend);
        }
    }

    function discontinueGrant(uint256 grantId, bool pullRemaining) external onlyOwner {
        Grant storage grant = _grants[grantId];
        _revertIfNotState(grant, State.Active);

        grant.state = State.Discontinued;

        if (pullRemaining) {
            uint256 msLength = grant.msPayments.length;
            uint256 fundsToPull = 0;
            for (uint256 i = grant.nextMsId; i < msLength; i++) {
                fundsToPull += grant.msPayments[i];
            }
            pullFunds(grant.token, fundsToPull);
        }
    }

    function pullFunds(address token, uint256 amount) public onlyOwner {
        address owner = owner();

        if (token == address(0)) {
            owner.safeTransferETH(amount);
        } else {
            ERC20(token).safeTransfer(owner, amount);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                VIEW METHODS                                */
    /* -------------------------------------------------------------------------- */

    function getGrant(uint256 id) external view returns (Grant memory) {
        return _grants[id];
    }
}
