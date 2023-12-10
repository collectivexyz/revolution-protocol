// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ITokenEmitter {
    struct ProtocolRewardAddresses {
        address builder;
        address purchaseReferral;
        address deployer;
    }

    function buyToken(
        address[] calldata addresses,
        uint[] calldata bps,
        ProtocolRewardAddresses calldata protocolRewardsRecipients
    ) external payable returns (uint);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function setCreatorRateBps(uint256 creatorRateBps) external;

    function setEntropyRateBps(uint256 entropyRateBps) external;

    function getTokenQuoteForPayment(uint256 paymentAmount) external returns (int);

    function setCreatorsAddress(address creators) external;

    event CreatorsAddressUpdated(address creators);

    event CreatorRateBpsUpdated(uint256 rateBps);

    event EntropyRateBpsUpdated(uint256 rateBps);

    event PurchaseFinalized(
        address indexed buyer,
        uint256 payment,
        uint256 treasuryAmount,
        uint256 protocolRewardsAmount,
        uint256 buyerTokensEmitted,
        uint256 creatorTokensEmitted,
        uint256 creatorDirectPayment
    );

    /**
     * @notice Initialize the token emitter
     * @param initialOwner The initial owner of the token emitter
     * @param token The token contract address
     * @param protocolRewards The protocol rewards contract address
     * @param protocolFeeRecipient The protocol fee recipient address
     * @param treasury The treasury address to pay funds to
     * @param erc20TokenEmitterParams The token emitter settings
     */
    function initialize(
        address initialOwner,
        NontransferableERC20Votes token,
        address protocolRewards,
        address protocolFeeRecipient,
        address treasury,
        IRevolutionBuilder.ERC20TokenEmitterParams calldata erc20TokenEmitterParams
    ) external
}
