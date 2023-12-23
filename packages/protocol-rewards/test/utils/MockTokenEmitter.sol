// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { TokenEmitterRewards } from "../../src/abstract/TokenEmitter/TokenEmitterRewards.sol";
import { ERC20TokenEmitter, NontransferableERC20Votes, IRevolutionBuilder } from "./TokenEmitterLibrary.sol";

contract MockTokenEmitter is ERC20TokenEmitter {
    constructor(
        address _initialOwner,
        NontransferableERC20Votes _erc20Token,
        address _protocolRewards,
        address _revolutionRewardRecipient
    ) ERC20TokenEmitter(_initialOwner, _protocolRewards, _revolutionRewardRecipient) {}
}
