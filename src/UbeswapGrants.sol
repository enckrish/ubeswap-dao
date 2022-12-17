// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "solmate-utils/SafeTransferLib.sol";
import "solmate/tokens/ERC20.sol";

// TODO 🤝 Add fields to fill DAO agreement

contract UbeswapGrants {
    using SafeTransferLib for ERC20;

    enum State {
        Pending,
        Rejected,
        Withdrawn,
        Active,
        // TODO 🪓 add state for cases where a dao axes a grant midway
        Fulfilled
    }

    struct Grant {
        address contributor;
        /// may be address(0) for paying in CELO/ETH
        address token;
        /// current status of the grant request
        State state;
        /// next milestone
        uint8 nextMsId;
        /// milestone dates (TODO maybe only emit it in events)
        uint8[] msTimestamps;
        /// payments at each milestone
        uint256[] msPayments;
        /// ipfs hash of details (uses CIDv1)
        bytes32 detailsHash;
    }

    address public dao;

    Grant[] internal _grants;

    event RequestSubmitted(address indexed contributor, uint256 indexed grantId);
    event Withdrawn(uint256 indexed grantId);
    event GrantOwnershipTransferred(uint256 indexed grantId, address indexed oldOwner, address indexed newOwner);
    event DAOAddressChanged(address oldAddress, address newAddress);
    event GrantAccepted(uint256 indexed grantId);
    event PaymentReleased(uint256 indexed grantId, uint256 milestoneId);

    error SenderNotDAO();
    error SenderNotContributor();
    error MilestoneLengthMismatch();
    error GrantNotPending();
    error GrantNotActive();

    constructor(address dao_) {
        dao = dao_;
    }

    /* -------------------------------------------------------------------------- */
    /*                             ACCESS RESTRICTIONS                            */
    /* -------------------------------------------------------------------------- */

    modifier onlyDAO() {
        if (msg.sender != dao) revert SenderNotDAO();
        _;
    }

    /// @dev uses function instead of modifiers to save extra SLOADs
    function _revertIfNonContributor(Grant storage grant) internal view {
        if (msg.sender != grant.contributor) revert SenderNotContributor();
    }

    /// @dev uses function instead of modifiers to save extra SLOADs
    function _revertIfNotPending(Grant storage grant) internal view {
        if (grant.state != State.Pending) {
            revert GrantNotPending();
        }
    }

    /// @dev uses function instead of modifiers to save extra SLOADs
    function _revertIfNotActive(Grant storage grant) internal view {
        if (grant.state != State.Active) {
            revert GrantNotActive();
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                             CONTRIBUTOR METHODS                            */
    /* -------------------------------------------------------------------------- */

    function applyForGrant(
        bytes32 detailsHash_,
        address token_,
        uint8[] calldata msTimestamps_,
        uint256[] calldata msPayments_
    ) external {
        if (msTimestamps_.length != msPayments_.length) revert MilestoneLengthMismatch();

        _grants.push(
            Grant({
                contributor: msg.sender,
                detailsHash: detailsHash_,
                token: token_,
                nextMsId: 0,
                msTimestamps: msTimestamps_,
                msPayments: msPayments_,
                state: State.Pending
            })
        );

        emit RequestSubmitted(msg.sender, _grants.length - 1);
    }

    function withdrawProposal(uint256 grantId) external {
        Grant storage grant = _grants[grantId];
        _revertIfNonContributor(grant);
        _revertIfNotPending(grant);

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

    function updateDAOAddress(address newAddress) external onlyDAO {
        emit DAOAddressChanged(dao, newAddress);
        dao = newAddress;
    }

    function acceptGrantProposal(uint256 grantId) external onlyDAO {
        Grant storage grant = _grants[grantId];
        _revertIfNotPending(grant);
        grant.state = State.Active;
        emit GrantAccepted(grantId);
    }

    function releasePayment(uint256 grantId) external onlyDAO {
        Grant storage grant = _grants[grantId];
        uint8 msId = grant.nextMsId++;
        emit PaymentReleased(grantId, msId);

        if (msId + 1 == grant.msPayments.length) grant.state = State.Fulfilled;

        address payToken = grant.token;
        address contributor = grant.contributor;
        uint256 amountToSend = grant.msPayments[msId];

        if (payToken == address(0)) {
            (bool success, bytes memory result) = contributor.call{value: amountToSend}("");
            if (success == false) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
        } else {
            ERC20(payToken).safeTransfer(contributor, amountToSend);
        }
    }

    function getGrant(uint256 id) external view returns (Grant memory) {
        return _grants[id];
    }
}
