// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// sharemint.xyz

import "@thirdweb-dev/contracts/base/ERC721Drop.sol";
import "./SignatureReferERC721.sol";

// This contract is based off of the thirdweb ERC721Drop contract, but with the addition of a referral mechanism.
contract ERC721DropRefer is ERC721Drop, SignatureReferERC721 {
    /// @dev The default referral percentage reward in basis points.
    uint256 public referralRewardBps;

    /// @dev The admin address of the referral signer.
    address public referralSigner;

    /// @dev The ID for the active claim condition.
    bytes32 private conditionId;

    /**
     *  @dev Map from a claim condition uid and account to supply claimed by account.
     */
    mapping(bytes32 => mapping(address => uint256)) private supplyClaimedByWallet;

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        address _primarySaleRecipient,
        uint256 _referralRewardBps,
        address _referralSigner
    ) ERC721Drop(_name, _symbol, _royaltyRecipient, _royaltyBps, _primarySaleRecipient) {
        referralRewardBps = _referralRewardBps;
        referralSigner = _referralSigner;
    }

    /// @dev Lets an account claim tokens with an optional referrer. Uses the default referral reward.
    function claim(
        address _receiver,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        address _referrer,
        AllowlistProof calldata _allowlistProof,
        bytes memory _data
    ) public payable {
        _claim(_receiver, _quantity, _currency, _pricePerToken, _referrer, referralRewardBps, _allowlistProof, _data);
    }

    /// @dev Lets an account claim tokens with a referrer via signature with a custom reward.
    function claimWithReferSignature(
        address _receiver,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        ReferRequest calldata _req,
        bytes calldata _signature,
        AllowlistProof calldata _allowlistProof,
        bytes memory _data
    ) external payable returns (address signer) {
        // Verify and process payload.
        signer = _processRequest(_req, _signature);
        address referrer = _req.referrer;
        uint256 rewardBps = _req.referralRewardBps;

        _claim(_receiver, _quantity, _currency, _pricePerToken, referrer, rewardBps, _allowlistProof, _data);
    }

    function _claim(
        address _receiver,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        address _referrer,
        uint256 _referRewardBps,
        AllowlistProof calldata _allowlistProof,
        bytes memory _data
    ) internal {
        require(_referrer != msg.sender, "Cannot refer yourself");

        uint256 rewardBps = _referrer == address(0) ? 0 : _referRewardBps;

        _beforeClaim(_receiver, _quantity, _currency, _pricePerToken, _allowlistProof, _data);

        bytes32 activeConditionId = conditionId;

        verifyClaim(_dropMsgSender(), _quantity, _currency, _pricePerToken, _allowlistProof);

        // Update contract state.
        claimCondition.supplyClaimed += _quantity;
        supplyClaimedByWallet[activeConditionId][_dropMsgSender()] += _quantity;

        uint256 reward = _referralReward(_quantity, _pricePerToken, _referRewardBps);

        // If there's a price, collect price.
        _collectPriceOnClaimWithReferrer(address(0), _quantity, _currency, _pricePerToken, _referrer, rewardBps);

        // Mint the relevant NFTs to claimer.
        uint256 startTokenId = _transferTokensOnClaim(_receiver, _quantity);

        emit TokensClaimed(_dropMsgSender(), _receiver, startTokenId, _quantity);

        if (_referrer != address(0) && reward > 0) {
            emit ReferralPayment(_referrer, reward);
        }

        _afterClaim(_receiver, _quantity, _currency, _pricePerToken, _allowlistProof, _data);
    }

    /// @dev Collects and distributes the primary sale value of NFTs being claimed as well as the referral reward.
    function _collectPriceOnClaimWithReferrer(
        address _primarySaleRecipient,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken,
        address _referrer,
        uint256 _referrerReward
    ) internal {
        if (_pricePerToken == 0) {
            return;
        }

        uint256 totalPrice = _quantityToClaim * _pricePerToken;

        if (_currency == CurrencyTransferLib.NATIVE_TOKEN) {
            if (msg.value != totalPrice) {
                revert("Must send total price");
            }
        }

        address saleRecipient = _primarySaleRecipient == address(0) ? primarySaleRecipient() : _primarySaleRecipient;
        CurrencyTransferLib.transferCurrency(_currency, msg.sender, saleRecipient, totalPrice - _referrerReward);
        CurrencyTransferLib.transferCurrency(_currency, msg.sender, _referrer, _referrerReward);
    }

    /// @dev Calculates referral reward.
    function _referralReward(
        uint256 _quantity,
        uint256 _pricePerToken,
        uint256 _referRewardBps
    ) private pure returns (uint256) {
        require(_referRewardBps <= 10000, "Referral reward cannot be greater than 100%");
        uint256 totalPrice = _quantity * _pricePerToken;
        return (totalPrice * _referRewardBps) / 10000;
    }

    /// @dev Returns whether a given address is authorized to sign referrals.
    function _canSignReferRequest(address _signer) internal view virtual override returns (bool) {
        return _signer == referralSigner;
    }
}
