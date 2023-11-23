// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface ITokenEmitter {
    function buyToken(
        address[] memory _addresses,
        uint[] memory _bps,
        address builder,
        address purchaseReferral,
        address deployer
    ) external payable returns (uint);

    function totalSupply() external view returns (uint);

    function balanceOf(address _owner) external view returns (uint);
}
