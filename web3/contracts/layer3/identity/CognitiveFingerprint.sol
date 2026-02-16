// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CognitiveFingerprint is Ownable {

    struct Fingerprint {
        uint256 identityId;
        bytes32 fingerprintHash;

        uint256 problemSolvingStyle;
        uint256 learningSpeed;
        uint256 adaptationRate;
        uint256 memoryRetention;
        uint256 patternRecognition;
        uint256 creativeThinking;
        uint256 logicalReasoning;

        uint256 lastUpdated;
    }

    mapping(uint256 => Fingerprint) public fingerprints;
    mapping(bytes32 => uint256) public hashToIdentity;
    mapping(uint256 => address) public identityOwner;

    event FingerprintGenerated(uint256 indexed identityId, bytes32 fingerprintHash);
    event FingerprintUpdated(uint256 indexed identityId, bytes32 newHash);

    constructor() Ownable(msg.sender) {}

    function generateFingerprint(
        uint256 identityId,
        uint256 problemSolving,
        uint256 learning,
        uint256 adaptation,
        uint256 memoryRetention,   // ✅ FIXED
        uint256 pattern,
        uint256 creative,
        uint256 logical
    ) external returns (bytes32) {

        require(identityOwner[identityId] == address(0), "Identity already claimed");

        bytes32 hash = keccak256(abi.encodePacked(
            msg.sender,
            identityId,
            problemSolving,
            learning,
            adaptation,
            memoryRetention,
            pattern,
            creative,
            logical
        ));

        fingerprints[identityId] = Fingerprint(
            identityId,
            hash,
            problemSolving,
            learning,
            adaptation,
            memoryRetention,
            pattern,
            creative,
            logical,
            block.timestamp
        );

        identityOwner[identityId] = msg.sender;
        hashToIdentity[hash] = identityId;

        emit FingerprintGenerated(identityId, hash);

        return hash;
    }

    function compareFingerprints(uint256 id1, uint256 id2) external view returns (uint256) {

        Fingerprint storage fp1 = fingerprints[id1];
        Fingerprint storage fp2 = fingerprints[id2];

        uint256 diff = 0;

        diff += _abs(fp1.problemSolvingStyle, fp2.problemSolvingStyle);
        diff += _abs(fp1.learningSpeed, fp2.learningSpeed);
        diff += _abs(fp1.adaptationRate, fp2.adaptationRate);

        if (diff >= 300) return 0;

        return 100 - ((diff * 100) / 300);
    }

    function _abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function getFingerprint(uint256 identityId) external view returns (Fingerprint memory) {
        return fingerprints[identityId];
    }
}
