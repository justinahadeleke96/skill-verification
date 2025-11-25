Skill Verification Smart Contract

Overview

This smart contract enables a decentralized system for verifying professional skills. Users can stake tokens to vouch for the skills of other users. False or dishonest vouches can be challenged, leading to slashing of the vouching stake. The system maintains reputation scores for participants and ensures accountability through staking.

Key Features

Staking Mechanism

Users deposit STX tokens to their staking balance.

Minimum vouch stake is enforced to ensure commitment.

Vouching

Professionals can vouch for another user’s skill by staking tokens.

Vouches increase the voucher’s reputation.

A user cannot vouch for themselves.

Challenging Vouches

Vouches can be challenged as false by staking a challenge amount.

Challenges mark the vouch as contested until resolved.

Resolution

The contract owner resolves challenges as either valid or invalid.

Valid challenges slash the vouching stake and reward the challenger.

Invalid challenges return stakes to the voucher and penalize the challenger.

Reputation Tracking

Users earn reputation for providing vouches.

Reputation is decreased if a vouch is found false.

Withdrawals

Users can withdraw uncommitted stakes at any time.

Read-only Queries

Check available stake balance.

Retrieve vouch and challenge details.

View reputation scores.

Get total vouches for a skill.

Retrieve contract statistics.

Constants
Constant	Description
min-vouch-stake	Minimum stake required to vouch (1 STX in microstacks)
challenge-stake	Stake required to challenge a vouch (0.5 STX)
slash-percentage	Percentage of stake slashed for false vouches (50%)
Data Structures

user-stakes: Tracks each user's available staking balance.

vouches: Maps {voucher, skill-name, vouchee} to vouch details (stake, id, active/challenged flags).

challenges: Maps challenge ID to challenge details.

reputation-scores: Tracks the reputation score for each user.

skill-vouch-count: Counts total vouches received per skill for a user.

Public Functions
Staking

deposit-stake(amount) → Deposit tokens to staking balance.

withdraw-stake(amount) → Withdraw available stake.

Vouching

vouch-for-skill(vouchee, skill-name, stake-amount) → Vouch for another user’s skill by staking tokens.

Challenging

challenge-vouch(voucher, skill-name, vouchee) → Challenge a vouch as false.

resolve-challenge(challenge-id, challenge-is-valid) → Contract owner resolves a challenge.

Read-only Functions

get-user-stake(user) → Returns user's available stake.

get-vouch(voucher, skill-name, vouchee) → Returns vouch details.

get-challenge(challenge-id) → Returns challenge details.

get-reputation(user) → Returns reputation score.

get-skill-vouch-count(vouchee, skill-name) → Returns total vouches for a skill.

get-stats() → Returns contract statistics including total vouches, challenges, and nonces.

Error Codes
Error	Description
u100	Owner-only function called by non-owner
u101	Insufficient stake for vouch
u102	Invalid amount
u103	Vouch not found
u104	Vouch already challenged
u105	Challenge not found
u106	Caller is not challenger
u107	Challenge already resolved
u108	Cannot vouch for self
u109	Insufficient balance
u110	Vouch already exists
Deployment Notes

The contract owner acts as the arbiter for resolving challenges.

Minimum staking amounts and slashing percentages can be adjusted in the contract constants.

Security Considerations

Vouches and challenges are immutable once resolved.

Reputation and staking ensure economic incentives align with honest behavior.

Only the contract owner can resolve disputes, so trust in the owner is required.

License

MIT License