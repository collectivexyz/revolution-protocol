// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { TokenEmitterRewards } from "../../src/abstract/TokenEmitter/TokenEmitterRewards.sol";
import { TokenEmitter, NontransferableERC20Votes } from "./TokenEmitter.sol";

contract MockTokenEmitter is TokenEmitter {
    address public treasury;

    constructor(
        NontransferableERC20Votes _token,
        address _treasury,
        address _protocolRewards,
        address _revolutionRewardRecipient
    ) TokenEmitter(_token, _protocolRewards, _revolutionRewardRecipient, _treasury, 1e11, 1e17, 1e22) {
        treasury = _treasury;
    }
}
