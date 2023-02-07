// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract MerkleVault {
  using SafeERC20 for IERC20;

  struct MerkleRoot {
    bytes32 merkleRoot; // root of claims merkle tree
    address erc20; // the ERC20 token address this is for
    uint256 amountCommited; // the total of all leaves
    bytes4 ipfs_cid_prefix; // see https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    bytes32 ipfs_cid_hash; // see https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
  }

  mapping(address => uint256) public balance; // balance[tokenAddress]
  mapping(address => uint256) public merkleRootCount;
  mapping(address => mapping(uint256 => MerkleRoot)) public merkleRoots;

  event NewDeposit(
    address indexed erc20,
    address indexed from,
    uint256 amount
  );

  event NewWithdrawal(
    address indexed erc20,
    address indexed from,
    uint256 amount
  );

  event NewMerkleTree(
    address indexed erc20,
    uint256 indexed number,
    uint256 amountCommited
  );

  function depositToken(
    address _erc20,
    uint256 _amount
  ) external {
    require(_amount > 0, 'Value cannot be zero');

    // transfer token to this contract
    IERC20 token = IERC20(_erc20);
    token.safeTransferFrom(msg.sender, address(this), _amount);

    balance[_erc20] += _amount;

    emit NewDeposit(_erc20, msg.sender, _amount);
  }

  function newRoot(
    bytes32 _merkleRoot,
    address _erc20, // the ERC20 token address this is for
    uint256 _amountCommited, // the total of all leaves
    bytes4 _ipfs_cid_prefix, // see https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    bytes32 _ipfs_cid_hash
  ) external {
    require(_merkleRoot != 0, "Merkle cannot be zero");
    require(_amountCommited != 0, "Amount cannot be zero");
    require(_amountCommited <= balance[_erc20], "Insufficient balance");

    merkleRootCount[_erc20] = merkleRootCount[_erc20] + 1;
    merkleRoots[_erc20][merkleRootCount[_erc20]] = MerkleRoot(_merkleRoot, _erc20, _amountCommited, _ipfs_cid_prefix, _ipfs_cid_hash);
    balance[_erc20] = balance[_erc20] - _amountCommited;

    emit NewMerkleTree(_erc20, merkleRootCount[_erc20], _amountCommited);
  }

  function withdraw(
    address _account,
    address _erc20,
    uint256 _merkleCount,
    uint256 _amount,
    bytes32[] calldata _merkleProof
  ) external {
    require(balance[_erc20] >= _amount, "Insufficient balance");

    bytes32 leaf = _leafHash(_account, _amount);

    // merkle proof valid?
    require(MerkleProof.verify(_merkleProof, merkleRoots[_erc20][_merkleCount].merkleRoot, leaf) == true, "Claim not found");

    balance[_erc20] =balance[_erc20] - _amount;
    IERC20(_erc20).safeTransfer(_account, _amount);

    emit NewWithdrawal(_erc20, msg.sender, _amount);
  }

  // generate hash of (claim holder, amount)
  // claim holder must be the caller
  function _leafHash(address account, uint256 amount) internal pure returns (bytes32) {
      return keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
  }
}