# Merkle Payments Chain

This contract allows for offchain computation of merkle trees that contain aggregated payments. Merkle trees are published to IPFS by the proposer role, and validated by the validator role.

Deposits and withdrawals emit events that can be queried by address. However, the contract does not store a balance per address.

Clients can fetch the series of merkle trees using the IPFS hashes stored in the contract. These can be used in combination with the contract desposit events to calculate balances. The merkle tree can also be used to generate a proof for withdrawal. By providing a proof to the contract, a client is able to withdraw funds that have been commited to them in each merkle tree.

### This is a Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```
