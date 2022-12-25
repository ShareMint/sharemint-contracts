// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// sharemint.xyz

import "./ISignatureReferERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

abstract contract SignatureReferERC721 is EIP712, ISignatureReferERC721 {
    using ECDSA for bytes32;

    bytes32 private constant TYPEHASH =
        keccak256(
            "ReferRequest(address referrer,uint256 referralRewardBps,uint256 quantity,uint256 pricePerToken,address currency,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
        );

    /// @dev Mapping from refer request UID => whether the refer request is processed.
    mapping(bytes32 => bool) private referred;

    constructor() EIP712("SignatureReferERC721", "1") {}

    /// @dev Verifies that a refer request is signed by an authorized account.
    function verify(ReferRequest calldata _req, bytes calldata _signature)
        public
        view
        override
        returns (bool success, address signer)
    {
        signer = _recoverAddress(_req, _signature);
        success = !referred[_req.uid] && _canSignReferRequest(signer);
    }

    /// @dev Returns whether a given address is authorized to sign refer requests.
    function _canSignReferRequest(address _signer) internal view virtual returns (bool);

    /// @dev Verifies a refer request and marks the request as referred.
    function _processRequest(ReferRequest calldata _req, bytes calldata _signature) internal returns (address signer) {
        bool success;
        (success, signer) = verify(_req, _signature);

        if (!success) {
            revert("Invalid req");
        }

        if (_req.validityStartTimestamp > block.timestamp || block.timestamp > _req.validityEndTimestamp) {
            revert("Req expired");
        }
        require(_req.referrer != address(0), "referrer undefined");

        referred[_req.uid] = true;
    }

    /// @dev Returns the address of the signer of the refer request.
    function _recoverAddress(ReferRequest calldata _req, bytes calldata _signature) internal view returns (address) {
        return _hashTypedDataV4(keccak256(_encodeRequest(_req))).recover(_signature);
    }

    /// @dev Resolves 'stack too deep' error in `recoverAddress`.
    function _encodeRequest(ReferRequest calldata _req) internal pure returns (bytes memory) {
        return
            abi.encode(
                TYPEHASH,
                _req.referrer,
                _req.referralRewardBps,
                _req.quantity,
                _req.pricePerToken,
                _req.currency,
                _req.validityStartTimestamp,
                _req.validityEndTimestamp,
                _req.uid
            );
    }
}
