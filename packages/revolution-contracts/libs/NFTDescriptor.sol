// SPDX-License-Identifier: GPL-3.0

/// @title A library used to construct ERC721 token URIs

pragma solidity ^0.8.22;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

library NFTDescriptor {
    struct TokenURIParams {
        string name;
        string description;
        string image;
        string animation_url;
    }

    /**
     * @notice Construct an ERC721 token URI.
     */
    function constructTokenURI(TokenURIParams memory params) public pure returns (string memory) {
        string memory json = string(
            abi.encodePacked(
                '{"name":"',
                params.name,
                '", "description":"',
                params.description,
                '", "image": "',
                params.image,
                '", "animation_url": "',
                params.animation_url,
                '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }
}
