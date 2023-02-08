// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract MerkleVault is AccessControl {
  using SafeERC20 for IERC20;
  using BitMaps for BitMaps.BitMap;

  bytes32 public constant PROPOSAL_ROLE = keccak256("PROPOSAL_ROLE");
  bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

  struct MerkleRoot {
    bytes32 merkleRoot; // root of claims merkle tree
    address tokenAddress; // the ERC20 token address this is for
    uint256 merkleNumber;
    uint256 amountCommited; // the total of all leaves
    uint endTime; // time in seconds that this block ended
    bytes4 ipfs_cid_prefix; // see https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    bytes32 ipfs_cid_hash; // see https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
  }

  mapping(address => uint256) public balance; // balance[tokenAddress]
  mapping(address => bool) public allowList;
  mapping(address => uint256) public proposedRootCount;
  mapping(address => mapping(uint256 => MerkleRoot)) public proposedRoots;
  mapping(address => uint256) public merkleRootCount;
  mapping(address => mapping(uint256 => MerkleRoot)) public merkleRoots;
  mapping(address => mapping(uint256 => BitMaps.BitMap)) private bitMaps;

  event NewDeposit(
    address indexed tokenAddress,
    address indexed from,
    uint256 amount
  );

  event NewWithdrawal(
    address indexed tokenAddress,
    address indexed from,
    uint256 amount
  );

  event ProposedMerkleTree(
    address indexed tokenAddress,
    uint256 indexed proposalNumber
  );

  event NewMerkleTree(
    address indexed tokenAddress,
    uint256 indexed merkleNumber
  );

  event AllowListChange(
    address indexed tokenAddress,
    bool allowed
  );

  constructor(address proposal, address validator) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(PROPOSAL_ROLE, proposal);
    _grantRole(VALIDATOR_ROLE, validator);
  }

  receive() external payable {
    require(allowList[address(0)] == true, 'Token not allowed');
    balance[address(0)] += msg.value;
    emit NewDeposit(address(0), msg.sender, msg.value);
  }

  function depositFor(
    address _recipient // gift a deposit to someone else
  ) external payable {
    require(allowList[address(0)] == true, 'Token not allowed');
    balance[address(0)] += msg.value;
    emit NewDeposit(address(0), _recipient, msg.value);
  }

  function setAllowedToken(
    address _tokenAddress,
    bool _allowed
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(allowList[_tokenAddress] != _allowed, 'Already set');
    allowList[_tokenAddress] = _allowed;

    emit AllowListChange(_tokenAddress, _allowed);
  }

  function depositToken(
    address _tokenAddress,
    uint256 _amount
  ) external {
    require(_amount > 0, 'Value cannot be zero');
    require(allowList[_tokenAddress] == true, 'Token not allowed');

    // transfer token to this contract
    IERC20 token = IERC20(_tokenAddress);
    token.safeTransferFrom(msg.sender, address(this), _amount);

    balance[_tokenAddress] += _amount;

    emit NewDeposit(_tokenAddress, msg.sender, _amount);
  }

  function depositTokenFor(
    address _tokenAddress,
    uint256 _amount,
    address _recipient // gift a deposit to someone else
  ) external {
    require(_amount > 0, 'Value cannot be zero');
    require(allowList[_tokenAddress] == true, 'Token not allowed');

    // transfer token to this contract
    IERC20 token = IERC20(_tokenAddress);
    token.safeTransferFrom(msg.sender, address(this), _amount);

    balance[_tokenAddress] += _amount;

    emit NewDeposit(_tokenAddress, _recipient, _amount);
  }

  function proposeRoot(
    bytes32 _merkleRoot,
    address _tokenAddress, // the ERC20 token address this is for
    uint256 _merkleNumber,
    uint256 _amountCommited, // the total of all leaves
    uint _endTime, // exclusive
    bytes4 _ipfs_cid_prefix, // see https://stackoverflow.com/questions/66927626/how-to-store-ipfs-hash-on-ethereum-blockchain-using-smart-contracts
    bytes32 _ipfs_cid_hash
  ) external onlyRole(PROPOSAL_ROLE) {
    require(_merkleRoot != 0, "Merkle cannot be zero");
    require(_amountCommited != 0, "Amount cannot be zero");
    require(_amountCommited <= balance[_tokenAddress], "Insufficient balance");
    require(_merkleNumber == merkleRootCount[_tokenAddress] + 1, "Invalid sequence");

    proposedRootCount[_tokenAddress] = proposedRootCount[_tokenAddress] + 1;
    proposedRoots[_tokenAddress][proposedRootCount[_tokenAddress]] = MerkleRoot(
      _merkleRoot, _tokenAddress, _merkleNumber, _amountCommited, _endTime, _ipfs_cid_prefix, _ipfs_cid_hash
    );

    emit ProposedMerkleTree(_tokenAddress, proposedRootCount[_tokenAddress]);
  }

  function validateRoot(
    address _tokenAddress, // the ERC20 token address this is for
    uint256 _proposalNumber
  ) external onlyRole(VALIDATOR_ROLE) {

    MerkleRoot memory proposed = proposedRoots[_tokenAddress][_proposalNumber];
    require(proposed.tokenAddress == _tokenAddress, "Does not match proposal");
    require(proposed.amountCommited <= balance[_tokenAddress], "Insufficient balance");
    require(proposed.merkleNumber == merkleRootCount[_tokenAddress] + 1, "Invalid sequence");

    merkleRootCount[_tokenAddress] = merkleRootCount[_tokenAddress] + 1;
    balance[_tokenAddress] = balance[_tokenAddress] - proposed.amountCommited;
    merkleRoots[_tokenAddress][merkleRootCount[_tokenAddress]] = proposed;

    emit NewMerkleTree(_tokenAddress, merkleRootCount[_tokenAddress]);
  }

  function isClaimed(address _tokenAddress, uint256 _merkleCount, uint256 index) public view returns (bool) {
        return bitMaps[_tokenAddress][_merkleCount].get(index);
    }

    function _setClaimed(address _tokenAddress, uint256 _merkleCount, uint256 index) private {
       bitMaps[_tokenAddress][_merkleCount].setTo(index, true);
    }

  function withdraw(
    address payable _account,
    address _tokenAddress,
    uint256 _merkleCount,
    uint256 _merkleIndex,
    uint256 _amount,
    bytes32[] calldata _merkleProof
  ) external {
    require(isClaimed(_tokenAddress, _merkleCount, _merkleIndex) == false, "Already claimed");
    require(balance[_tokenAddress] >= _amount, "Insufficient balance");

    bytes32 leaf = _leafHash(_merkleIndex, _account, _amount);

    // merkle proof valid?
    require(MerkleProof.verify(_merkleProof, merkleRoots[_tokenAddress][_merkleCount].merkleRoot, leaf) == true, "Claim not found");

    balance[_tokenAddress] = balance[_tokenAddress] - _amount;
    if(_tokenAddress == address(0)) {
      _account.transfer(_amount);
    } else {
      IERC20(_tokenAddress).safeTransfer(_account, _amount); 
    }

    _setClaimed(_tokenAddress, _merkleCount, _merkleIndex);

    emit NewWithdrawal(_tokenAddress, msg.sender, _amount);
  }

  // generate hash of (claim holder, amount)
  // claim holder must be the caller
  function _leafHash(uint256 index, address account, uint256 amount) internal pure returns (bytes32) {
      return keccak256(bytes.concat(keccak256(abi.encode(index, account, amount))));
  }
}