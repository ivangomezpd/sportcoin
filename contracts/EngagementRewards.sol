// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./SportCoin.sol";

/**
 * @title EngagementRewards
 * @dev Distributes SPC tokens for verified offline events.
 * Uses cryptographic signatures from a trusted Backend (Oracle).
 */
contract EngagementRewards is AccessControl {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    SportCoin public token;
    address public trustedSigner; // The Backend API wallet

    // Mappings to prevent replay attacks
    mapping(bytes32 => bool) public processedNonces;

    event RewardClaimed(address indexed user, uint256 amount, string eventId);
    event SignerUpdated(address oldSigner, address newSigner);

    constructor(address _token, address _trustedSigner) {
        token = SportCoin(_token);
        trustedSigner = _trustedSigner;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Users call this function to claim tokens with a signature provided by the backend.
     * @param amount Amount of tokens to reward.
     * @param nonce Unique ID for this specific claim (UUID or timestamp+random).
     * @param signature Cryptographic signature from the trustedSigner.
     */
    function claimReward(
        uint256 amount,
        string memory nonce,
        bytes memory signature
    ) external {
        // 1. Replay Protection
        bytes32 nonceHash = keccak256(abi.encodePacked(nonce));
        require(!processedNonces[nonceHash], "Reward already claimed");
        processedNonces[nonceHash] = true;

        // 2. Verify Signature
        // The message hashed must be: keccak256(userAddress, amount, nonce, contractAddress)
        // Including contractAddress prevents replay attacks on other forks/networks
        bytes32 messageHash = keccak256(
            abi.encodePacked(msg.sender, amount, nonce, address(this))
        );
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        address recoveredSigner = ethSignedMessageHash.recover(signature);
        require(recoveredSigner == trustedSigner, "Invalid signature");

        // 3. Mint Tokens
        // This contract must have MINTER_ROLE in SportCoin
        token.mint(msg.sender, amount);

        emit RewardClaimed(msg.sender, amount, nonce);
    }

    function updateSigner(
        address _newSigner
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit SignerUpdated(trustedSigner, _newSigner);
        trustedSigner = _newSigner;
    }
}
