// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Drop.sol";

contract ERC721ShareMint is ERC721Drop {
    /*///////////////////////////////////////////////////////////////
                            State variables
    //////////////////////////////////////////////////////////////*/

    uint256 public referralRewardBps;

    /// @dev The ID for the active claim condition.
    bytes32 private conditionId;

    /*///////////////////////////////////////////////////////////////
                                Mappings
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Map from a claim condition uid and account to supply claimed by account.
     */
    mapping(bytes32 => mapping(address => uint256)) private supplyClaimedByWallet;

    /*///////////////////////////////////////////////////////////////
                            Drop logic
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        address _primarySaleRecipient,
        uint256 _referralRewardBps
    )
        ERC721Drop(
            _name,
            _symbol,
            _royaltyRecipient,
            _royaltyBps,
            _primarySaleRecipient
        )
    {
        referralRewardBps = _referralRewardBps;
    }

    /// @dev Lets an account claim tokens with a referrer.
    function claim(
        address _receiver,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        address _referrer,
        AllowlistProof calldata _allowlistProof,
        bytes memory _data
    ) public payable {
        require(_referrer != msg.sender, "Cannot refer yourself");
        require(_referrer != address(0), "Referrer cannot be zero address");

        _beforeClaim(_receiver, _quantity, _currency, _pricePerToken, _allowlistProof, _data);

        bytes32 activeConditionId = conditionId;

        verifyClaim(_dropMsgSender(), _quantity, _currency, _pricePerToken, _allowlistProof);

        // Update contract state.
        claimCondition.supplyClaimed += _quantity;
        supplyClaimedByWallet[activeConditionId][_dropMsgSender()] += _quantity;

        uint256 reward = _referralReward(_quantity, _pricePerToken);

        // If there's a price, collect price.
        _collectPriceOnClaimWithReferrer(address(0), _quantity, _currency, _pricePerToken, _referrer, reward);

        // Mint the relevant NFTs to claimer.
        uint256 startTokenId = _transferTokensOnClaim(_receiver, _quantity);

        emit TokensClaimed(_dropMsgSender(), _receiver, startTokenId, _quantity);

        _afterClaim(_receiver, _quantity, _currency, _pricePerToken, _allowlistProof, _data);
    }

    /// @dev Collects and distributes the primary sale value of NFTs being claimed.
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

    function _referralReward(uint256 _quantity, uint256 _pricePerToken) private view returns (uint256) {
        uint256 totalPrice = _quantity * _pricePerToken;
        return (totalPrice * referralRewardBps) / 10000;
    }
}
