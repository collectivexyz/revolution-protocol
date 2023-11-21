// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {TokenEmitterRewards} from "../../src/abstract/TokenEmitter/TokenEmitterRewards.sol";
import {TokenEmitter, NontransferableERC20} from "./TokenEmitter.sol";

contract MockTokenEmitter is TokenEmitterRewards {
    error MOCK_TOKENEMITTER_INVALID_REMAINING_VALUE();

    address public treasury;

    constructor(
        address _treasury,
        address _protocolRewards,
        address _revolutionRewardRecipient
    )  TokenEmitterRewards(_protocolRewards, _revolutionRewardRecipient) {
        treasury = _treasury;
    }

    function purchaseWithRewards(address builderReferral, address purchaseReferral, address deployer) external payable {
        uint256 remainingValue = _handleRewardsAndGetValueToSend(msg.value, builderReferral, purchaseReferral, deployer);

        // TODO add buy token call
    }
}
