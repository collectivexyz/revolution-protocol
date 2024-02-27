// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ISplitMain } from "./interfaces/ISplitMain.sol";
import { SplitWallet } from "./SplitWallet.sol";
import { Clones } from "./libraries/Clones.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IRevolutionPointsEmitter } from "./interfaces/IPointsEmitterLike.sol";
import { SplitsVersion } from "./version/SplitsVersion.sol";
import { UUPS } from "@cobuild/utility-contracts/src/proxy/UUPS.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";

/**

                                             █████████
                                          ███████████████                  █████████
                                         █████████████████               █████████████                 ███████
                                        ███████████████████             ███████████████               █████████
                                        ███████████████████             ███████████████              ███████████
                                        ███████████████████             ███████████████               █████████
                                         █████████████████               █████████████                 ███████
                                          ███████████████                  █████████
                                             █████████

                             ███████████
                          █████████████████                 █████████
                         ███████████████████             ███████████████                  █████████
                        █████████████████████           █████████████████               █████████████                ███████
                       ███████████████████████         ███████████████████             ███████████████              █████████
                       ███████████████████████         ███████████████████             ███████████████             ███████████
                       ███████████████████████         ███████████████████             ███████████████              █████████
                        █████████████████████           █████████████████               █████████████                ███████
                         ███████████████████              █████████████                   █████████
                          █████████████████                 █████████
                             ███████████

           ███████████
       ███████████████████                  ███████████
     ███████████████████████              ███████████████                  █████████
    █████████████████████████           ███████████████████             ███████████████               █████████
   ███████████████████████████         █████████████████████           █████████████████            █████████████              ███████
   ███████████████████████████        ███████████████████████         ███████████████████          ███████████████            █████████
   ███████████████████████████        ███████████████████████         ███████████████████          ███████████████           ███████████
   ███████████████████████████        ███████████████████████         ███████████████████          ███████████████            █████████
   ███████████████████████████         █████████████████████           █████████████████            █████████████              ███████
    █████████████████████████           ███████████████████              █████████████                █████████
      █████████████████████               ███████████████                  █████████
        █████████████████                   ███████████
           ███████████

                             ███████████
                          █████████████████                 █████████
                         ███████████████████             ███████████████                  █████████
                        █████████████████████           █████████████████               █████████████                ███████
                       ███████████████████████         ███████████████████             ███████████████              █████████
                       ███████████████████████         ███████████████████             ███████████████             ███████████
                       ███████████████████████         ███████████████████             ███████████████              █████████
                        █████████████████████           █████████████████               █████████████                ███████
                         ███████████████████              █████████████                   █████████
                          █████████████████                 █████████
                             ███████████

                                             █████████
                                          ███████████████                  █████████
                                         █████████████████               █████████████                 ███████
                                        ███████████████████             ███████████████               █████████
                                        ███████████████████             ███████████████              ███████████
                                        ███████████████████             ███████████████               █████████
                                         █████████████████               █████████████                 ███████
                                          ███████████████                  █████████
                                             █████████

 */

/**
 * ERRORS
 */

/// @notice Unauthorized sender `sender`
/// @param sender Transaction sender
error Unauthorized(address sender);

/// @notice Invalid percent specified to split with the Points Emitter `pointsPercent`
/// @param pointsPercent percent specified to go to the Points Emitter
error InvalidSplit__InvalidPointsPercent(uint32 pointsPercent);

/// @notice Invalid number of accounts `accountsLength`, must have at least 2
/// @param accountsLength Length of accounts array
error InvalidSplit__TooFewAccounts(uint256 accountsLength);

/// @notice Invalid number of points accounts `accountsLength`, must have at least 1
/// @param pointsAccountsLength Length of points accounts array
error InvalidSplit__TooFewPointsAccounts(uint256 pointsAccountsLength);

/// @notice Array lengths of accounts & percentAllocations don't match (`accountsLength` != `allocationsLength`)
/// @param accountsLength Length of accounts array
/// @param allocationsLength Length of percentAllocations array
error InvalidSplit__AccountsAndAllocationsMismatch(uint256 accountsLength, uint256 allocationsLength);

/// @notice Array lengths of points accounts & percentAllocations don't match (`accountsLength` != `allocationsLength`)
/// @param accountsLength Length of points accounts array
/// @param allocationsLength Length of points percentAllocations array
error InvalidSplit__PointsAccountsAndAllocationsMismatch(uint256 accountsLength, uint256 allocationsLength);

/// @notice Invalid percentAllocations sum `allocationsSum` must equal `PERCENTAGE_SCALE`
/// @param allocationsSum Sum of percentAllocations array
error InvalidSplit__InvalidAllocationsSum(uint32 allocationsSum);

/// @notice Invalid points percentAllocations sum `allocationsSum` must equal `PERCENTAGE_SCALE`
/// @param allocationsSum Sum of points percentAllocations array
error InvalidSplit__InvalidPointsAllocationsSum(uint32 allocationsSum);

/// @notice Invalid accounts ordering at `index`
/// @param index Index of out-of-order account
error InvalidSplit__AccountsOutOfOrder(uint256 index);

/// @notice Invalid points accounts ordering at `index`
/// @param index Index of out-of-order account
error InvalidSplit__PointsAccountsOutOfOrder(uint256 index);

/// @notice Invalid percentAllocation of zero at `index`
/// @param index Index of zero percentAllocation
error InvalidSplit__AllocationMustBePositive(uint256 index);

/// @notice Invalid points percentAllocation of zero at `index`
/// @param index Index of zero percentAllocation
error InvalidSplit__PointsAllocationMustBePositive(uint256 index);

/// @notice Invalid distributorFee `distributorFee` cannot be greater than 10% (1e5)
/// @param distributorFee Invalid distributorFee amount
error InvalidSplit__InvalidDistributorFee(uint32 distributorFee);

/// @notice Invalid hash `hash` from split data (accounts, percentAllocations, distributorFee)
/// @param hash Invalid hash
error InvalidSplit__InvalidHash(bytes32 hash);

/// @notice Invalid new controlling address `newController` for mutable split
/// @param newController Invalid new controller
error InvalidNewController(address newController);

/// @notice Invalid manager sender
error SenderNotManager();

/**
 * @title SplitMain
 * @author 0xSplits <will@0xSplits.xyz>
 * @notice A composable and gas-efficient protocol for deploying splitter contracts.
 * @dev Split recipients, ownerships, and keeper fees are stored onchain as calldata & re-passed as args / validated
 * via hashing when needed. Each split gets its own address & proxy for maximum composability with other contracts onchain.
 * For these proxies, we extended EIP-1167 Minimal Proxy Contract to avoid `DELEGATECALL` inside `receive()` to accept
 * hard gas-capped `sends` & `transfers`.
 */
contract SplitMain is ISplitMain, SplitsVersion, OwnableUpgradeable, UUPS {
    using SafeTransferLib for address;

    /**
     * STRUCTS
     */

    /// @notice holds Split metadata
    struct Split {
        bytes32 hash;
        address controller;
        address newPotentialController;
        // pointsPercent is the percentage of the split that goes to the points emitter
        // need to store so we can return correct balances in the view functions
        uint32 pointsPercent;
    }

    /**
     * STORAGE
     */

    /**
     * STORAGE - CONSTANTS & IMMUTABLES
     */

    /// @notice constant to scale uints into percentages (1e6 == 100%)
    uint256 public constant PERCENTAGE_SCALE = 1e6;
    /// @notice maximum distributor fee; 1e5 = 10% * PERCENTAGE_SCALE
    uint256 internal constant MAX_DISTRIBUTOR_FEE = 1e5;
    /// @notice address of wallet implementation for split proxies
    address public override walletImplementation;
    /// @notice the RevolutionPointsEmitter contract
    IRevolutionPointsEmitter public override pointsEmitter;
    /// @notice The contract upgrade manager
    IUpgradeManager private immutable manager;

    /**
     * STORAGE - VARIABLES - PRIVATE & INTERNAL
     */

    /// @notice mapping to account ETH balances
    mapping(address => uint256) internal ethBalances;

    /// @notice mapping to points account ETH balances
    /// to be spent on the points emitter to buy points for the account
    mapping(address => uint256) internal ethBalancesPoints;

    /// @notice mapping to account ERC20 balances
    mapping(ERC20 => mapping(address => uint256)) internal erc20Balances;

    /// @notice mapping to Split metadata
    mapping(address => Split) internal splits;

    /**
     * MODIFIERS
     */

    /** @notice Reverts if the sender doesn't own the split `split`
     *  @param split Address to check for control
     */
    modifier onlySplitController(address split) {
        if (msg.sender != splits[split].controller) revert Unauthorized(msg.sender);
        _;
    }

    /** @notice Reverts if the sender isn't the new potential controller of split `split`
     *  @param split Address to check for new potential control
     */
    modifier onlySplitNewPotentialController(address split) {
        if (msg.sender != splits[split].newPotentialController) revert Unauthorized(msg.sender);
        _;
    }

    /** @notice Reverts if the split with recipients represented by `accounts` and `percentAllocations` is malformed
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @notice the minimum number of accounts was changed from 2 to 0, to allow for a split with all money going to the revolution treasury
     */
    modifier validSplit(
        PointsData calldata pointsData,
        address[] memory accounts,
        uint32[] memory percentAllocations,
        uint32 distributorFee
    ) {
        // points percent is nonzero
        if (pointsData.pointsPercent == uint32(0) || pointsData.pointsPercent > PERCENTAGE_SCALE)
            revert InvalidSplit__InvalidPointsPercent(pointsData.pointsPercent);

        // at least 1 points account
        if (pointsData.accounts.length < 1) revert InvalidSplit__TooFewPointsAccounts(pointsData.accounts.length);

        // accounts & percentAllocations must be equal length
        if (accounts.length != percentAllocations.length)
            revert InvalidSplit__AccountsAndAllocationsMismatch(accounts.length, percentAllocations.length);

        // pointsAccounts & pointsPercentAllocations must be equal length
        if (pointsData.accounts.length != pointsData.percentAllocations.length)
            revert InvalidSplit__PointsAccountsAndAllocationsMismatch(
                pointsData.accounts.length,
                pointsData.percentAllocations.length
            );

        // _getSum should overflow if any percentAllocation[i] < 0 and sum != PERCENTAGE_SCALE
        if (percentAllocations.length > 0 && _getSum(percentAllocations) != PERCENTAGE_SCALE)
            revert InvalidSplit__InvalidAllocationsSum(_getSum(percentAllocations));

        // _getSum should overflow if any pointsPercentAllocations[i] < 0
        if (_getSum(pointsData.percentAllocations) != PERCENTAGE_SCALE)
            revert InvalidSplit__InvalidPointsAllocationsSum(_getSum(pointsData.percentAllocations));

        // accounts are ordered and unique
        // percent allocations are nonzero
        if (accounts.length > 0) {
            unchecked {
                // overflow should be impossible in for-loop index
                // cache accounts length to save gas
                uint256 loopLength = accounts.length - 1;
                for (uint256 i = 0; i < loopLength; ++i) {
                    // overflow should be impossible in array access math
                    if (accounts[i] >= accounts[i + 1]) revert InvalidSplit__AccountsOutOfOrder(i);
                    if (percentAllocations[i] == uint32(0)) revert InvalidSplit__AllocationMustBePositive(i);
                }
                // overflow should be impossible in array access math with validated equal array lengths
                if (percentAllocations[loopLength] == uint32(0))
                    revert InvalidSplit__AllocationMustBePositive(loopLength);
            }
        }

        // pointsAccounts are ordered and unique
        // pointsPercentAllocations are nonzero
        unchecked {
            // overflow should be impossible in for-loop index
            // cache pointsAccounts length to save gas
            uint256 loopLength = pointsData.accounts.length - 1;
            for (uint256 i = 0; i < loopLength; ++i) {
                // overflow should be impossible in array access math
                if (pointsData.accounts[i] >= pointsData.accounts[i + 1])
                    revert InvalidSplit__PointsAccountsOutOfOrder(i);
                if (pointsData.percentAllocations[i] == uint32(0))
                    revert InvalidSplit__PointsAllocationMustBePositive(i);
            }
            // overflow should be impossible in array access math with validated equal array lengths
            if (pointsData.percentAllocations[loopLength] == uint32(0))
                revert InvalidSplit__PointsAllocationMustBePositive(loopLength);
        }

        // distributorFee is lte than max
        if (distributorFee > MAX_DISTRIBUTOR_FEE) revert InvalidSplit__InvalidDistributorFee(distributorFee);
        _;
    }

    /** @notice Reverts if `newController` is the zero address
     *  @param newController Proposed new controlling address
     */
    modifier validNewController(address newController) {
        if (newController == address(0)) revert InvalidNewController(newController);
        _;
    }

    /**
     * CONSTRUCTOR
     */

    /** @notice Create the contract with a given manager
     *  @param _manager The contract upgrade manager address
     */
    constructor(address _manager) payable initializer {
        manager = IUpgradeManager(_manager);
    }

    /**
     * INITIALIZER
     */

    /** @notice Initialize the contract
     *  @param _pointsEmitter The address of the community's points emitter contract to buy points from
     */
    function initialize(address _initialOwner, address _pointsEmitter) public initializer {
        if (msg.sender != address(manager)) revert SenderNotManager();

        pointsEmitter = IRevolutionPointsEmitter(_pointsEmitter);
        walletImplementation = address(new SplitWallet());

        __Ownable_init(_initialOwner);
    }

    /**
     * FUNCTIONS
     */

    /**
     * FUNCTIONS - PUBLIC & EXTERNAL
     */

    /** @notice Receive ETH
     *  @dev Used by split proxies in `distributeETH` to transfer ETH to `SplitMain`
     *  Funds sent outside of `distributeETH` will be unrecoverable
     */
    receive() external payable {}

    /** @notice Creates a new split with recipients `accounts` with ownerships `percentAllocations`, a keeper fee for splitting of `distributorFee` and the controlling address `controller`
     *  @param pointsData PointsData struct containing pointsPercent [how much ETH is reserved to buy points], pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @param controller Controlling address (0x0 if immutable)
     *  @return split Address of newly created split
     */
    function createSplit(
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address controller
    ) external override validSplit(pointsData, accounts, percentAllocations, distributorFee) returns (address split) {
        bytes32 splitHash = _hashSplit(pointsData, accounts, percentAllocations, distributorFee);
        if (controller == address(0)) {
            // create immutable split
            split = Clones.cloneDeterministic(walletImplementation, splitHash);
        } else {
            // create mutable split
            split = Clones.clone(walletImplementation);
            splits[split].controller = controller;
        }
        // store split's hash in storage for future verification
        splits[split].hash = splitHash;
        // store pointsPercent in storage for balance function calculations
        splits[split].pointsPercent = pointsData.pointsPercent;

        emit CreateSplit(split, pointsData, accounts, percentAllocations, distributorFee, controller);
    }

    /** @notice Predicts the address for an immutable split created with recipients `accounts` with ownerships `percentAllocations` and a keeper fee for splitting of `distributorFee`
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @return split Predicted address of such an immutable split
     */
    function predictImmutableSplitAddress(
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    )
        external
        view
        override
        validSplit(pointsData, accounts, percentAllocations, distributorFee)
        returns (address split)
    {
        bytes32 splitHash = _hashSplit(pointsData, accounts, percentAllocations, distributorFee);
        split = Clones.predictDeterministicAddress(walletImplementation, splitHash);
    }

    /** @notice Updates an existing split with recipients `accounts` with ownerships `percentAllocations` and a keeper fee for splitting of `distributorFee`
     *  @param split Address of mutable split to update
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     */
    function updateSplit(
        address split,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    )
        external
        override
        onlySplitController(split)
        validSplit(pointsData, accounts, percentAllocations, distributorFee)
    {
        _updateSplit(split, pointsData, accounts, percentAllocations, distributorFee);
    }

    /** @notice Begins transfer of the controlling address of mutable split `split` to `newController`
     *  @dev Two-step control transfer inspired by [dharma](https://github.com/dharma-eng/dharma-smart-wallet/blob/master/contracts/helpers/TwoStepOwnable.sol)
     *  @param split Address of mutable split to transfer control for
     *  @param newController Address to begin transferring control to
     */
    function transferControl(
        address split,
        address newController
    ) external override onlySplitController(split) validNewController(newController) {
        splits[split].newPotentialController = newController;
        emit InitiateControlTransfer(split, newController);
    }

    /** @notice Cancels transfer of the controlling address of mutable split `split`
     *  @param split Address of mutable split to cancel control transfer for
     */
    function cancelControlTransfer(address split) external override onlySplitController(split) {
        delete splits[split].newPotentialController;
        emit CancelControlTransfer(split);
    }

    /** @notice Accepts transfer of the controlling address of mutable split `split`
     *  @param split Address of mutable split to accept control transfer for
     */
    function acceptControl(address split) external override onlySplitNewPotentialController(split) {
        delete splits[split].newPotentialController;
        emit ControlTransfer(split, splits[split].controller, msg.sender);
        splits[split].controller = msg.sender;
    }

    /** @notice Turns mutable split `split` immutable
     *  @param split Address of mutable split to turn immutable
     */
    function makeSplitImmutable(address split) external override onlySplitController(split) {
        delete splits[split].newPotentialController;
        emit ControlTransfer(split, splits[split].controller, address(0));
        splits[split].controller = address(0);
    }

    /** @notice Distributes the ETH balance for split `split`
     *  @dev `accounts`, `percentAllocations`, and `distributorFee` are verified by hashing
     *  & comparing to the hash in storage associated with split `split`
     *  @param split Address of split to distribute balance for
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @param distributorAddress Address to pay `distributorFee` to
     */
    function distributeETH(
        address split,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    ) external override validSplit(pointsData, accounts, percentAllocations, distributorFee) {
        // use internal fn instead of modifier to avoid stack depth compiler errors
        _validSplitHash(split, pointsData, accounts, percentAllocations, distributorFee);
        _distributeETH(split, pointsData, accounts, percentAllocations, distributorFee, distributorAddress);
    }

    /** @notice Updates & distributes the ETH balance for split `split`
     *  @dev only callable by SplitController
     *  @param split Address of split to distribute balance for
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @param distributorAddress Address to pay `distributorFee` to
     */
    function updateAndDistributeETH(
        address split,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    )
        external
        override
        onlySplitController(split)
        validSplit(pointsData, accounts, percentAllocations, distributorFee)
    {
        _updateSplit(split, pointsData, accounts, percentAllocations, distributorFee);
        // know splitHash is valid immediately after updating; only accessible via controller
        _distributeETH(split, pointsData, accounts, percentAllocations, distributorFee, distributorAddress);
    }

    /** @notice Distributes the ERC20 `token` balance for split `split`
     *  @dev `accounts`, `percentAllocations`, and `distributorFee` are verified by hashing
     *  & comparing to the hash in storage associated with split `split`
     *  @dev pernicious ERC20s may cause overflow in this function inside
     *  _scaleAmountByPercentage, but results do not affect ETH & other ERC20 balances
     *  @param split Address of split to distribute balance for
     *  @param token Address of ERC20 to distribute balance for
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @param distributorAddress Address to pay `distributorFee` to
     */
    function distributeERC20(
        address split,
        ERC20 token,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    ) external override validSplit(pointsData, accounts, percentAllocations, distributorFee) {
        // use internal fn instead of modifier to avoid stack depth compiler errors
        _validSplitHash(split, pointsData, accounts, percentAllocations, distributorFee);
        _distributeERC20(split, token, accounts, percentAllocations, distributorFee, distributorAddress);
    }

    /** @notice Updates & distributes the ERC20 `token` balance for split `split`
     *  @dev only callable by SplitController
     *  @dev pernicious ERC20s may cause overflow in this function inside
     *  _scaleAmountByPercentage, but results do not affect ETH & other ERC20 balances
     *  @param split Address of split to distribute balance for
     *  @param token Address of ERC20 to distribute balance for
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @param distributorAddress Address to pay `distributorFee` to
     */
    function updateAndDistributeERC20(
        address split,
        ERC20 token,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    )
        external
        override
        onlySplitController(split)
        validSplit(pointsData, accounts, percentAllocations, distributorFee)
    {
        _updateSplit(split, pointsData, accounts, percentAllocations, distributorFee);
        // know splitHash is valid immediately after updating; only accessible via controller
        _distributeERC20(split, token, accounts, percentAllocations, distributorFee, distributorAddress);
    }

    /** @notice Withdraw ETH, ETH as Points, &/ ERC20 balances for account `account`
     *  @param account Address to withdraw on behalf of
     *  @param withdrawETH Withdraw all ETH if nonzero
     *  @param withdrawPoints Withdraw all Points if nonzero
     *  @param tokens Addresses of ERC20s to withdraw
     */
    function withdraw(
        address account,
        uint256 withdrawETH,
        uint256 withdrawPoints,
        ERC20[] calldata tokens
    ) external override {
        uint256[] memory tokenAmounts = new uint256[](tokens.length);
        uint256 ethAmount = 0;
        uint256 pointsSold = 0;
        if (withdrawETH != 0) {
            ethAmount = _withdraw(account);
        }
        if (withdrawPoints != 0) {
            // Since _withdrawPoints market buys points from the emitter, we only allow the account to withdraw its own points
            if (msg.sender != account) {
                revert Unauthorized(msg.sender);
            }
            pointsSold = _withdrawPoints(account);
        }
        unchecked {
            // overflow should be impossible in for-loop index
            for (uint256 i = 0; i < tokens.length; ++i) {
                // overflow should be impossible in array length math
                tokenAmounts[i] = _withdrawERC20(account, tokens[i]);
            }
            emit Withdrawal(account, ethAmount, tokens, tokenAmounts, pointsSold);
        }
    }

    /**
     * FUNCTIONS - VIEWS
     */

    /** @notice Returns the current hash of split `split`
     *  @param split Split to return hash for
     *  @return Split's hash
     */
    function getHash(address split) external view returns (bytes32) {
        return splits[split].hash;
    }

    /** @notice Returns the current controller of split `split`
     *  @param split Split to return controller for
     *  @return Split's controller
     */
    function getController(address split) external view returns (address) {
        return splits[split].controller;
    }

    /** @notice Returns the current newPotentialController of split `split`
     *  @param split Split to return newPotentialController for
     *  @return Split's newPotentialController
     */
    function getNewPotentialController(address split) external view returns (address) {
        return splits[split].newPotentialController;
    }

    /** @notice Returns the current ETH balance of account `account`
     *  @param account Account to return ETH balance for
     *  @return Account's balance of ETH
     */
    function getETHBalance(address account) external view returns (uint256) {
        return
            ethBalances[account] +
            (
                splits[account].hash != 0
                    ? _scaleAmountByPercentage(account.balance, PERCENTAGE_SCALE - splits[account].pointsPercent)
                    : 0
            );
    }

    /** @notice Returns the current ETH points balance of account `account`
     *  @param account Account to return ETH points balance for
     *  @return Account's balance of ETH that will be used to buy points
     */
    function getETHPointsBalance(address account) public view returns (uint256) {
        return
            ethBalancesPoints[account] +
            (splits[account].hash != 0 ? _scaleAmountByPercentage(account.balance, splits[account].pointsPercent) : 0);
    }

    /** @notice Returns the current points balance of account `account` if withdrawed right now
     *  @param account Account to return points balance for
     *  @return Account's balance of points
     */
    function getPointsBalance(address account) external view returns (int256) {
        // Subtract 1 since _withdraw will always leave 1 wei in the account
        return pointsEmitter.getTokenQuoteForPayment(getETHPointsBalance(account) - 1);
    }

    /** @notice Returns the ERC20 balance of token `token` for account `account`
     *  @param account Account to return ERC20 `token` balance for
     *  @param token Token to return balance for
     *  @return Account's balance of `token`
     */
    function getERC20Balance(address account, ERC20 token) external view returns (uint256) {
        return erc20Balances[token][account] + (splits[account].hash != 0 ? token.balanceOf(account) : 0);
    }

    /**
     * FUNCTIONS - PRIVATE & INTERNAL
     */

    /** @notice Sums array of uint32s
     *  @param numbers Array of uint32s to sum
     *  @return sum Sum of `numbers`.
     */
    function _getSum(uint32[] memory numbers) internal pure returns (uint32 sum) {
        // overflow should be impossible in for-loop index
        uint256 numbersLength = numbers.length;
        for (uint256 i = 0; i < numbersLength; ) {
            sum += numbers[i];
            unchecked {
                // overflow should be impossible in for-loop index
                ++i;
            }
        }
    }

    /** @notice Hashes a split
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @return computedHash Hash of the split.
     */
    function _hashSplit(
        PointsData calldata pointsData,
        address[] memory accounts,
        uint32[] memory percentAllocations,
        uint32 distributorFee
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    pointsData.pointsPercent,
                    pointsData.accounts,
                    pointsData.percentAllocations,
                    accounts,
                    percentAllocations,
                    distributorFee
                )
            );
    }

    /** @notice Updates an existing split with recipients `accounts` with ownerships `percentAllocations` and a keeper fee for splitting of `distributorFee`
     *  @param split Address of mutable split to update
     * @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     */
    function _updateSplit(
        address split,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    ) internal {
        bytes32 splitHash = _hashSplit(pointsData, accounts, percentAllocations, distributorFee);
        // store new hash in storage for future verification
        splits[split].hash = splitHash;
        emit UpdateSplit(split);
    }

    /** @notice Checks hash from `accounts`, `percentAllocations`, and `distributorFee` against the hash stored for `split`
     *  @param split Address of hash to check
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     */
    function _validSplitHash(
        address split,
        PointsData calldata pointsData,
        address[] memory accounts,
        uint32[] memory percentAllocations,
        uint32 distributorFee
    ) internal view {
        bytes32 hash = _hashSplit(pointsData, accounts, percentAllocations, distributorFee);
        if (splits[split].hash != hash) revert InvalidSplit__InvalidHash(hash);
    }

    /** @notice Distributes the ETH balance for split `split`
     *  @dev `pointsData`, `accounts`, `percentAllocations`, and `distributorFee` must be verified before calling
     *  @param split Address of split to distribute balance for
     *  @param pointsData PointsData struct containing pointsPercent, pointsAccounts, and pointsPercentAllocations
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @param distributorAddress Address to pay `distributorFee` to
     */
    function _distributeETH(
        address split,
        PointsData calldata pointsData,
        address[] memory accounts,
        uint32[] memory percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    ) internal {
        uint256 mainBalance = ethBalances[split];
        uint256 proxyBalance = split.balance;
        // if mainBalance is positive, leave 1 in SplitMain for gas efficiency
        uint256 amountToSplit;
        unchecked {
            // underflow should be impossible
            if (mainBalance > 0) mainBalance -= 1;
            // overflow should be impossible
            amountToSplit = mainBalance + proxyBalance;
        }
        if (mainBalance > 0) ethBalances[split] = 1;
        // emit event with gross amountToSplit (before deducting distributorFee)
        emit DistributeETH(split, amountToSplit, distributorAddress);
        if (distributorFee != 0) {
            // given `amountToSplit`, calculate keeper fee
            uint256 distributorFeeAmount = _scaleAmountByPercentage(amountToSplit, distributorFee);
            unchecked {
                // credit keeper with fee
                // overflow should be impossible with validated distributorFee
                ethBalances[distributorAddress != address(0) ? distributorAddress : msg.sender] += distributorFeeAmount;
                // given keeper fee, calculate how much to distribute to split recipients
                // underflow should be impossible with validated distributorFee
                amountToSplit -= distributorFeeAmount;
            }
        }

        //distribute etherBalance for points to points accounts
        uint256 pointsAmount = _scaleAmountByPercentage(amountToSplit, pointsData.pointsPercent);

        // cache pointsAccounts length to save gas
        uint256 pointsAccountsLength = pointsData.accounts.length;
        for (uint256 i = 0; i < pointsAccountsLength; ++i) {
            ethBalancesPoints[pointsData.accounts[i]] += _scaleAmountByPercentage(
                pointsAmount,
                pointsData.percentAllocations[i]
            );
        }
        // subtract pointsAmount
        amountToSplit -= pointsAmount;

        unchecked {
            // distribute remaining balance
            // overflow should be impossible in for-loop index
            // cache accounts length to save gas
            uint256 accountsLength = accounts.length;
            for (uint256 i = 0; i < accountsLength; ++i) {
                // overflow should be impossible with validated allocations
                ethBalances[accounts[i]] += _scaleAmountByPercentage(amountToSplit, percentAllocations[i]);
            }
        }
        // flush proxy ETH balance to SplitMain
        // split proxy should be guaranteed to exist at this address after validating splitHash
        // (attacker can't deploy own contract to address with high balance & empty sendETHToMain
        // to drain ETH from SplitMain)
        // could technically check if (change in proxy balance == change in SplitMain balance)
        // before/after external call, but seems like extra gas for no practical benefit
        if (proxyBalance > 0) SplitWallet(split).sendETHToMain(proxyBalance);
    }

    /** @notice Distributes the ERC20 `token` balance for split `split`
     *  @dev `accounts`, `percentAllocations`, and `distributorFee` must be verified before calling
     *  @dev pernicious ERC20s may cause overflow in this function inside
     *  _scaleAmountByPercentage, but results do not affect ETH & other ERC20 balances
     *  @param split Address of split to distribute balance for
     *  @param token Address of ERC20 to distribute balance for
     *  @param accounts Ordered, unique list of addresses with ownership in the split
     *  @param percentAllocations Percent allocations associated with each address
     *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
     *  @param distributorAddress Address to pay `distributorFee` to
     */
    function _distributeERC20(
        address split,
        ERC20 token,
        address[] memory accounts,
        uint32[] memory percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    ) internal {
        uint256 amountToSplit;
        uint256 mainBalance = erc20Balances[token][split];
        uint256 proxyBalance = token.balanceOf(split);
        unchecked {
            // if mainBalance &/ proxyBalance are positive, leave 1 for gas efficiency
            // underflow should be impossible
            if (proxyBalance > 0) proxyBalance -= 1;
            // underflow should be impossible
            if (mainBalance > 0) {
                mainBalance -= 1;
            }
            // overflow should be impossible
            amountToSplit = mainBalance + proxyBalance;
        }
        if (mainBalance > 0) erc20Balances[token][split] = 1;
        // emit event with gross amountToSplit (before deducting distributorFee)
        emit DistributeERC20(split, token, amountToSplit, distributorAddress);
        if (distributorFee != 0) {
            // given `amountToSplit`, calculate keeper fee
            uint256 distributorFeeAmount = _scaleAmountByPercentage(amountToSplit, distributorFee);
            // overflow should be impossible with validated distributorFee
            unchecked {
                // credit keeper with fee
                erc20Balances[token][
                    distributorAddress != address(0) ? distributorAddress : msg.sender
                ] += distributorFeeAmount;
                // given keeper fee, calculate how much to distribute to split recipients
                amountToSplit -= distributorFeeAmount;
            }
        }
        // distribute remaining balance
        // overflows should be impossible in for-loop with validated allocations
        unchecked {
            // cache accounts length to save gas
            uint256 accountsLength = accounts.length;
            for (uint256 i = 0; i < accountsLength; ++i) {
                erc20Balances[token][accounts[i]] += _scaleAmountByPercentage(amountToSplit, percentAllocations[i]);
            }
        }
        // split proxy should be guaranteed to exist at this address after validating splitHash
        // (attacker can't deploy own contract to address with high ERC20 balance & empty
        // sendERC20ToMain to drain ERC20 from SplitMain)
        // doesn't support rebasing or fee-on-transfer tokens
        // flush extra proxy ERC20 balance to SplitMain
        if (proxyBalance > 0) SplitWallet(split).sendERC20ToMain(token, proxyBalance);
    }

    /** @notice Multiplies an amount by a scaled percentage
     *  @param amount Amount to get `scaledPercentage` of
     *  @param scaledPercent Percent scaled by PERCENTAGE_SCALE
     *  @return scaledAmount Percent of `amount`.
     */
    function _scaleAmountByPercentage(
        uint256 amount,
        uint256 scaledPercent
    ) internal pure returns (uint256 scaledAmount) {
        // use assembly to bypass checking for overflow & division by 0
        // scaledPercent has been validated to be < PERCENTAGE_SCALE)
        // & PERCENTAGE_SCALE will never be 0
        // pernicious ERC20s may cause overflow, but results do not affect ETH & other ERC20 balances
        assembly {
            /* eg (100 * 2*1e4) / (1e6) */
            scaledAmount := div(mul(amount, scaledPercent), PERCENTAGE_SCALE)
        }
    }

    /** @notice Withdraw ETH for account `account`
     *  @param account Account to withdrawn ETH for
     *  @return withdrawn Amount of ETH withdrawn
     */
    function _withdraw(address account) internal returns (uint256 withdrawn) {
        // leave balance of 1 for gas efficiency
        // underflow if ethBalance is 0
        withdrawn = ethBalances[account] - 1;
        ethBalances[account] = 1;
        account.safeTransferETH(withdrawn);
    }

    /** @notice Withdraw points for account `account`
     *  @param account Account to withdrawn points for
     *  @return tokensSoldWad Amount of points purchased
     */
    function _withdrawPoints(address account) internal returns (uint256 tokensSoldWad) {
        // leave balance of 1 for gas efficiency
        // underflow if ethBalance is 0
        uint256 withdrawn = ethBalancesPoints[account] - 1;
        ethBalancesPoints[account] = 1;

        address[] memory addresses = new address[](1);
        addresses[0] = account;

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        // slither-disable-next-line arbitrary-send-eth
        tokensSoldWad = pointsEmitter.buyToken{ value: withdrawn }(
            addresses,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                deployer: address(0),
                purchaseReferral: address(0)
            })
        );
    }

    /** @notice Withdraw ERC20 `token` for account `account`
     *  @param account Account to withdrawn ERC20 `token` for
     *  @return withdrawn Amount of ERC20 `token` withdrawn
     */
    function _withdrawERC20(address account, ERC20 token) internal returns (uint256 withdrawn) {
        // leave balance of 1 for gas efficiency
        // underflow if erc20Balance is 0
        withdrawn = erc20Balances[token][account] - 1;
        erc20Balances[token][account] = 1;
        SafeERC20.safeTransfer(token, account, withdrawn);
    }

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
