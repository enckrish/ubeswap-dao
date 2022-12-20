# Ubseswap Milestone-based Payment Contract

Made during Ubeswap Destiny Hackathon 2022 on Gitcoin

This contract facilitates contributors to apply for grants to the Ubeswap DAO which can bemanaged then by the DAO multisig.

# External Methods

The contract includes the following external functions:

## For Contributors

```solidity
// For applying for a grant, the decision to take for the grant is taken by the DAO
function applyForGrant(bytes32 detailsHash_, address token_, uint8[] calldata msTimestamps_, uint256[] calldata msPayments_) external;

// For withdrawing a grant proposal if it is not accepted
function withdrawProposal(uint256 grantId) external;

// For changing the eneficiary address of the grant's funds, useful if the organisation working on the grants changes
function transferGrantOwnership(uint256 grantId, address newOwner) external;
```

## For DAO

```solidity
// for changing the DAO's address, uses a 2-step transfer for security, so new address has to accept ownership
function updateDAOAddress(address newAddress) external;

// accepts a grant that is in pending state
function acceptGrantProposal(uint256 grantId) external;

// releases payment for the grant's current milestone
 function releasePayment(uint256 grantId) external;

 // useful for stopping a grant, in cases where the continuation of grant provides no value
function discontinueGrant(uint256 grantId, bool pullRemaining) external;

// pull funds from this contract to the DAO
function pullFunds(address token, uint256 amount) external;
```

# Things to Note

The contract doesn't check for availability of funds when a grant proposal is accepted. This is done since, for long term grants, the DAO may not have the all the required funds available at the time, but can possibly accumulate it before each milestone payments.

The DAO has the power to discontinue a grant midway. This can be helpful to axe non-performing grants or grants that have lost their purpose since. This privilege can also be maliciously used. But since that would undermine the DAOs reputation, it is highly unlikely.
