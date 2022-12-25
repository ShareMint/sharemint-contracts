// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// sharemint.xyz

/**
 *  The 'signature referral' mechanism is used to payouts referral rewards at the time of mint.
 */
interface ISignatureReferERC721 {
    /**
     *  @notice The body of a request to mint tokens with a referral reward.
     *
     *  @param referrer The recipient of the referral reward
     *  @param referralRewardBps The percentage of the token's primary sales sent to the referrer.
     *  @param quantity The quantity of tokens to mint.
     *  @param pricePerToken The price to pay per quantity of tokens minted.
     *  @param currency The currency in which to pay the price per token minted.
     *  @param validityStartTimestamp The unix timestamp after which the payload is valid.
     *  @param validityEndTimestamp The unix timestamp at which the payload expires.
     *  @param uid A unique identifier for the payload.
     */
    struct ReferRequest {
        address referrer;
        uint256 referralRewardBps;
        uint256 quantity;
        uint256 pricePerToken;
        address currency;
        uint128 validityStartTimestamp;
        uint128 validityEndTimestamp;
        bytes32 uid;
    }

    /// @dev Emitted when a referral is made.
    event ReferralPayment(address indexed referrer, uint256 reward);

    /**
     *  @notice Verifies that a referral request is signed by an authorized signer (at the time of the function call).
     *
     *  @param req The payload / refer request.
     *  @param signature The signature produced by an account signing the refer request.
     *
     *  returns (success, signer) Result of verification and the recovered address.
     */
    function verify(
        ReferRequest calldata req,
        bytes calldata signature
    ) external view returns (bool success, address signer);
}
