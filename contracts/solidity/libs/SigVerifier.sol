pragma solidity ^0.8.0;

library SigVerifier {
    // ECDSA/Ed25519 signature checks for off-chain attestations

    // Verify ECDSA signature
    function verifyECDSASignature(
        bytes32 messageHash,
        bytes memory signature,
        address signer
    ) internal pure returns (bool) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Check the signature length
        if (signature.length != 65) {
            return false;
        }

        // Divide the signature into r, s and v variables
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // Version of signature should be 27 or 28
        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) {
            return false;
        } else {
            // Recover the signer address
            return ecrecover(messageHash, v, r, s) == signer;
        }
    }

    // Verify Ed25519 signature
    function verifyEd25519Signature(
        bytes32 messageHash,
        bytes memory signature,
        bytes32 publicKey
    ) internal pure returns (bool) {
        // Implement the Ed25519 signature verification logic here
        // Placeholder implementation
        return true;
    }
}
