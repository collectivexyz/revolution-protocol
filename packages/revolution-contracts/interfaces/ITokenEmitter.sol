// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface ITokenEmitter {
    function buyToken(address[] memory _addresses, uint[] memory _percentages, uint256 numChunks) external payable returns (uint256);

    function _getTokenAmountForSinglePurchase(uint256 payment, uint256 supply) external view returns (uint256);

    function getTokenAmountForMultiPurchase(uint256 payment) external view returns (uint256);

    // solhint-disable-next-line func-name-mixedcase
    function UNSAFE_getOverestimateTokenAmount(uint256 payment, uint256 supply) external view returns (uint256);

    function getTokenPrice(uint256 currentTotalSupply) external view returns (uint256);

    function totalSupply() external view returns (uint);

    function balanceOf(address _owner) external view returns (uint);
}
