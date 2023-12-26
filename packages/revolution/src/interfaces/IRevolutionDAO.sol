// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import "../governance/RevolutionDAOInterfaces.sol";
import { IRevolutionBuilder } from "./IRevolutionBuilder.sol";

interface IRevolutionDAO {
    /**
     * @notice Used to initialize the contract during delegator contructor
     * @param executor The address of the DAOExecutor
     * @param revolutionToken The address of the ERC-721 token
     * @param revolutionPoints The address of the ERC-20 token
     * @param govParams The initial governance parameters
     */
    function initialize(
        address executor,
        address revolutionToken,
        address revolutionPoints,
        IRevolutionBuilder.GovParams calldata govParams
    ) external;
}
