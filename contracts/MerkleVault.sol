// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract MerkleVault {
  using SafeERC20 for IERC20;

  bytes32 public merkleRoot;
  mapping(address => uint256) public balance; // balance[tokenAddress]

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

  function updateRoot(
    bytes32 _merkleRoot
  ) external {
    require(_merkleRoot != 0, "Merkle cannot be zero");
    merkleRoot = _merkleRoot;
  }

  function withdraw(
    address _account,
    address _erc20,
    uint256 _amount,
    bytes32[] calldata _merkleProof
  ) external {
    require(balance[_erc20] >= _amount, "Insufficient balance");

    bytes32 leaf = _leafHash(_account, _amount);

    // merkle proof valid?
    require(MerkleProof.verify(_merkleProof, merkleRoot, leaf) == true, "Claim not found");

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