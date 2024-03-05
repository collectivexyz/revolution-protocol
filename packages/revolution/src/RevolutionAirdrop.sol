// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IRevolutionPoints } from "./interfaces/IRevolutionPoints.sol";

contract RevolutionAirdrop is Ownable {
    IRevolutionPoints private tokenContract;
    address private token;

    constructor(address _tokenContractAddress, address _owner) Ownable(_owner) {
        token = _tokenContractAddress;
        tokenContract = IRevolutionPoints(_tokenContractAddress);
    }

    /**
     * @notice Distributes amounts to a list of addresses. Only mintable through ownership of the `RevolutionPoints` contract
     * @param _addresses The addresses to airdrop to
     * @param _amounts The amounts to airdrop
     */
    function airdrop(address[] calldata _addresses, uint256[] calldata _amounts) public payable onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            tokenContract.mint(_addresses[i], _amounts[i]);
        }
    }
}
