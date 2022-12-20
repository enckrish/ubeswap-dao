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

    /// @notice applies for grant
    /// @dev does not use milestone dates since they are not practically enforceable without strict control over the contributing person/org
    /// @param detailsHash_ CIDv1 ipfs hash of any details, such as grant proposal and details required for filling the agreement form
    /// @param token_ token that contributor wants payments in
    /// @param msPayments_ proposed payments per milestone
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

    /// @notice withdraw a pending grant proposal
    /// @param grantId ID of the grant proposal to withdraw
    function withdrawProposal(uint256 grantId) external {
        Grant storage grant = _grants[grantId];
        _revertIfNonContributor(grant);
        _revertIfNotState(grant, State.Pending);

        grant.state = State.Withdrawn;
        emit Withdrawn(grantId);
    }

    /// @notice change beneficiary of the grant payments
    /// @param grantId ID of the grant to change beneficiary in
    /// @param newOwner address of the new beneficiary
    function transferGrantOwnership(uint256 grantId, address newOwner) external {
        Grant storage grant = _grants[grantId];
        _revertIfNonContributor(grant);

        emit GrantOwnershipTransferred(grantId, grant.contributor, newOwner);
        grant.contributor = newOwner;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 DAO METHODS                                */
    /* -------------------------------------------------------------------------- */

    /// @notice accept a pending grant proposal
    /// @param grantId ID of the grant proposal to accept
    function acceptGrantProposal(uint256 grantId) external onlyOwner {
        Grant storage grant = _grants[grantId];
        _revertIfNotState(grant, State.Pending);
        grant.state = State.Active;
        emit GrantAccepted(grantId);
    }

    /// @notice releases payment for current milestone of the grant
    /// @param grantId ID of the grant to release payment to
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

    /// @notice discontinue funding an active grant
    /// @param grantId ID of grant to dicontinue
    /// @param pullRemaining if set to true, funds for remaining milestones will be sent to DAO
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

    /// @notice Pull funds from this contract to the DAO
    /// @param token address of the token for which funds are to be pulled (address(0) for CELO/ETH)
    /// @param amount amount of funds to pull
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
