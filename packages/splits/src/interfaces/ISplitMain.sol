// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IRevolutionPointsEmitter } from "./IPointsEmitterLike.sol";

/**
 * @title ISplitMain
 * @author 0xSplits <will@0xSplits.xyz>
 */
interface ISplitMain {
    /**
     * STRUCTS
     */
    struct PointsData {
        uint32 pointsPercent;
        address[] accounts;
        uint32[] percentAllocations;
    }

    /**
     * FUNCTIONS
     */

    /**
     * @notice Initializes the SplitMain contract
     * @param initialOwner The address to set as the initial owner of the contract
     * @param pointsEmitter The address of the points emitter to buy tokens through
     */
    function initialize(address initialOwner, address pointsEmitter) external;

    function walletImplementation() external returns (address);

    function pointsEmitter() external returns (IRevolutionPointsEmitter);

    function createSplit(
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address controller
    ) external returns (address);

    function predictImmutableSplitAddress(
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    ) external view returns (address);

    function updateSplit(
        address split,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    ) external;

    function PERCENTAGE_SCALE() external returns (uint256);

    function getHash(address split) external view returns (bytes32);

    function getETHBalance(address account) external view returns (uint256);

    function getERC20Balance(address account, ERC20 token) external view returns (uint256);

    function getETHPointsBalance(address account) external view returns (uint256);

    function getPointsBalance(address account) external view returns (int256);

    function transferControl(address split, address newController) external;

    function cancelControlTransfer(address split) external;

    function acceptControl(address split) external;

    function makeSplitImmutable(address split) external;

    function distributeETH(
        address split,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    ) external;

    function updateAndDistributeETH(
        address split,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    ) external;

    function distributeERC20(
        address split,
        ERC20 token,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    ) external;

    function updateAndDistributeERC20(
        address split,
        ERC20 token,
        PointsData calldata pointsData,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    ) external;

    function withdraw(address account, uint256 withdrawETH, uint256 withdrawPoints, ERC20[] calldata tokens) external;

    /**
     * EVENTS
     */

    /** @notice emitted after each successful split creation
     *  @param split Address of the created split
     */
    event CreateSplit(
        address indexed split,
        PointsData pointsData,
        address[] accounts,
        uint32[] percentAllocations,
        uint32 distributorFee,
        address controller
    );

    /** @notice emitted after each successful split update
     *  @param split Address of the updated split
     */
    event UpdateSplit(address indexed split);

    /** @notice emitted after each initiated split control transfer
     *  @param split Address of the split control transfer was initiated for
     *  @param newPotentialController Address of the split's new potential controller
     */
    event InitiateControlTransfer(address indexed split, address indexed newPotentialController);

    /** @notice emitted after each canceled split control transfer
     *  @param split Address of the split control transfer was canceled for
     */
    event CancelControlTransfer(address indexed split);

    /** @notice emitted after each successful split control transfer
     *  @param split Address of the split control was transferred for
     *  @param previousController Address of the split's previous controller
     *  @param newController Address of the split's new controller
     */
    event ControlTransfer(address indexed split, address indexed previousController, address indexed newController);

    /** @notice emitted after each successful ETH balance split
     *  @param split Address of the split that distributed its balance
     *  @param amount Amount of ETH distributed
     *  @param distributorAddress Address to credit distributor fee to
     */
    event DistributeETH(address indexed split, uint256 amount, address indexed distributorAddress);

    /** @notice emitted after each successful ERC20 balance split
     *  @param split Address of the split that distributed its balance
     *  @param token Address of ERC20 distributed
     *  @param amount Amount of ERC20 distributed
     *  @param distributorAddress Address to credit distributor fee to
     */
    event DistributeERC20(
        address indexed split,
        ERC20 indexed token,
        uint256 amount,
        address indexed distributorAddress
    );

    /** @notice emitted after each successful withdrawal
     *  @param account Address that funds were withdrawn to
     *  @param ethAmount Amount of ETH withdrawn
     *  @param tokens Addresses of ERC20s withdrawn
     *  @param tokenAmounts Amounts of corresponding ERC20s withdrawn
     *  @param pointsSold Amount of points withdrawn
     */
    event Withdrawal(
        address indexed account,
        uint256 ethAmount,
        ERC20[] tokens,
        uint256[] tokenAmounts,
        uint256 pointsSold
    );
}
