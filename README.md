# Merkle Commitments Contract

Inspired by these fine projects:

- https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol
- https://github.com/bloq/sol-mass-payouts/blob/master/contracts/MerkleBox.sol

This contract allows for offchain computation of merkle trees that contain aggregated payment commitments.

- Offchain EIP-712 signatures and transaction metadata are published to IPFS by the Proposer role in a form that excludes the sender address.
- The proposer constructs a merkle tree of all of the payment data, and proposes the merkle tree root to the contract along with the IPFS address of the metadata.
- The Validator role fetches the data from IPFS, and attempts to verify all of the signatures. It derives the sender address from each signature and aggregates the payments when the sender has sent multiple payments to the same destination. Finally, it constructs a merkle tree. If it is successfully able to recreate the same merkle tree that was proposed, then it can validate it by calling the function of the contract.

## Calculating offchain balances

Deposits and withdrawals emit events that can be queried by address. However, the contract does not store a balance per address.

Clients can fetch the series of metadata using the IPFS hashes stored in the contract, in the same way as the validator. These can be used in combination with the contract desposit events to calculate balances. The client can reconstruct a merkle tree to be used to generate a proof for withdrawal. By providing a proof to the contract, a client is able to withdraw funds that have been commited to them in each merkle tree.

### This is a Hardhat Project

This project demonstrates a basic Hardhat use case.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```
