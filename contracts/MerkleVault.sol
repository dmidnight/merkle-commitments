// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract MerkleVault is AccessControl {
  using SafeERC20 for IERC20;

  bytes32 public constant PROPOSAL_ROLE = keccak256("PROPOSAL_ROLE");
  bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

  struct MerkleRoot {
    bytes32 merkleRoot; // root of claims merkle tree
    address erc20; // the ERC20 token address this is for
    uint256 merkleNumber;
    uint256 amountCommited; // the total of all leaves
    uint endTime; // time in seconds that this block ended
    bytes4 ipfs_cid_prefix; // see https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    bytes32 ipfs_cid_hash; // see https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
  }

  mapping(address => uint256) public balance; // balance[tokenAddress]
  mapping(address => uint256) public merkleRootCount;
  mapping(address => mapping(uint256 => MerkleRoot)) public merkleRoots;
  mapping(address => uint256) public proposedRootCount;
  mapping(address => mapping(uint256 => MerkleRoot)) public proposedRoots;

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

  event ProposedMerkleTree(
    address indexed erc20,
    uint256 indexed proposalNumber
  );

  event NewMerkleTree(
    address indexed erc20,
    uint256 indexed merkleNumber
  );

  constructor(address proposal, address validator) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(PROPOSAL_ROLE, proposal);
    _grantRole(VALIDATOR_ROLE, validator);
  }

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

  function depositTokenFor(
    address _erc20,
    uint256 _amount,
    address _recipient // gift a deposit to someone else
  ) external {
    require(_amount > 0, 'Value cannot be zero');

    // transfer token to this contract
    IERC20 token = IERC20(_erc20);
    token.safeTransferFrom(msg.sender, address(this), _amount);

    balance[_erc20] += _amount;

    emit NewDeposit(_erc20, _recipient, _amount);
  }

  function proposeRoot(
    bytes32 _merkleRoot,
    address _erc20, // the ERC20 token address this is for
    uint256 _merkleNumber,
    uint256 _amountCommited, // the total of all leaves
    uint _endTime, // exclusive
    bytes4 _ipfs_cid_prefix, // see https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    bytes32 _ipfs_cid_hash
  ) external onlyRole(PROPOSAL_ROLE) {
    require(_merkleRoot != 0, "Merkle cannot be zero");
    require(_amountCommited != 0, "Amount cannot be zero");
    require(_amountCommited <= balance[_erc20], "Insufficient balance");
    require(_merkleNumber == merkleRootCount[_erc20] + 1, "Invalid sequence");

    proposedRootCount[_erc20] = proposedRootCount[_erc20] + 1;
    proposedRoots[_erc20][proposedRootCount[_erc20]] = MerkleRoot(
      _merkleRoot, _erc20, _merkleNumber, _amountCommited, _endTime, _ipfs_cid_prefix, _ipfs_cid_hash
    );

    emit ProposedMerkleTree(_erc20, proposedRootCount[_erc20]);
  }

  function validateRoot(
    address _erc20, // the ERC20 token address this is for
    uint256 _proposalNumber
  ) external onlyRole(VALIDATOR_ROLE) {

    MerkleRoot memory proposed = proposedRoots[_erc20][_proposalNumber];
    require(proposed.erc20 == _erc20, "Does not match proposal");
    require(proposed.amountCommited <= balance[_erc20], "Insufficient balance");
    require(proposed.merkleNumber == merkleRootCount[_erc20] + 1, "Invalid sequence");

    merkleRootCount[_erc20] = merkleRootCount[_erc20] + 1;
    balance[_erc20] = balance[_erc20] - proposed.amountCommited;
    merkleRoots[_erc20][merkleRootCount[_erc20]] = proposed;

    emit NewMerkleTree(_erc20, merkleRootCount[_erc20]);
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