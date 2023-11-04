// SPDX-License-Identifier: GPL-3.0

/// @title The Verbs ERC-721 token

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.6;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC721Checkpointable } from "./base/ERC721Checkpointable.sol";
import { INounsDescriptorMinimal } from "./interfaces/INounsDescriptorMinimal.sol";
import { INounsSeeder } from "./interfaces/INounsSeeder.sol";
import { IVerbsToken } from "./interfaces/IVerbsToken.sol";
import { ERC721 } from "./base/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IProxyRegistry } from "./external/opensea/IProxyRegistry.sol";

contract VerbsToken is IVerbsToken, Ownable, ERC721Checkpointable {
    // The nounders DAO address (creators org)
    address public noundersDAO;

    // An address who has permissions to mint Verbs
    address public minter;

    // The Verbs token URI descriptor
    INounsDescriptorMinimal public descriptor;

    // The Verbs token seeder
    INounsSeeder public seeder;

    // Whether the minter can be updated
    bool public isMinterLocked;

    // Whether the descriptor can be updated
    bool public isDescriptorLocked;

    // Whether the seeder can be updated
    bool public isSeederLocked;

    // The verb seeds
    mapping(uint256 => INounsSeeder.Seed) public seeds;

    // The internal verb ID tracker
    uint256 private _currentVerbId;

    // IPFS content hash of contract-level metadata
    string private _contractURIHash = "QmZi1n79FqWt2tTLwCqiy6nLM6xLGRsEPQ5JmReJQKNNzX";

    // OpenSea's Proxy Registry
    IProxyRegistry public immutable proxyRegistry;

    /**
     * @notice Require that the minter has not been locked.
     */
    modifier whenMinterNotLocked() {
        require(!isMinterLocked, "Minter is locked");
        _;
    }

    /**
     * @notice Require that the descriptor has not been locked.
     */
    modifier whenDescriptorNotLocked() {
        require(!isDescriptorLocked, "Descriptor is locked");
        _;
    }

    /**
     * @notice Require that the seeder has not been locked.
     */
    modifier whenSeederNotLocked() {
        require(!isSeederLocked, "Seeder is locked");
        _;
    }

    /**
     * @notice Require that the sender is the nounders DAO.
     */
    modifier onlyNoundersDAO() {
        require(msg.sender == noundersDAO, "Sender is not the nounders DAO");
        _;
    }

    /**
     * @notice Require that the sender is the minter.
     */
    modifier onlyMinter() {
        require(msg.sender == minter, "Sender is not the minter");
        _;
    }

    constructor(
        address _noundersDAO,
        address _minter,
        INounsDescriptorMinimal _descriptor,
        INounsSeeder _seeder,
        IProxyRegistry _proxyRegistry
    ) ERC721("Verbs", "VERB") {
        noundersDAO = _noundersDAO;
        minter = _minter;
        descriptor = _descriptor;
        seeder = _seeder;
        proxyRegistry = _proxyRegistry;
    }

    /**
     * @notice The IPFS URI of contract-level metadata.
     */
    function contractURI() public view returns (string memory) {
        return string(abi.encodePacked("ipfs://", _contractURIHash));
    }

    /**
     * @notice Set the _contractURIHash.
     * @dev Only callable by the owner.
     */
    function setContractURIHash(string memory newContractURIHash) external onlyOwner {
        _contractURIHash = newContractURIHash;
    }

    /**
     * @notice Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator) public view override(IERC721, ERC721) returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @notice Mint a Verb to the minter.
     * @dev Call _mintTo with the to address(es).
     */
    function mint() public override onlyMinter returns (uint256) {
        return _mintTo(minter, _currentVerbId++);
    }

    /**
     * @notice Burn a verb.
     */
    function burn(uint256 verbId) public override onlyMinter {
        _burn(verbId);
        emit VerbBurned(verbId);
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "VerbsToken: URI query for nonexistent token");
        return descriptor.tokenURI(tokenId, seeds[tokenId]);
    }

    /**
     * @notice Similar to `tokenURI`, but always serves a base64 encoded data URI
     * with the JSON contents directly inlined.
     */
    function dataURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "VerbsToken: URI query for nonexistent token");
        return descriptor.dataURI(tokenId, seeds[tokenId]);
    }

    /**
     * @notice Set the nounders DAO.
     * @dev Only callable by the nounders DAO when not locked.
     */
    function setNoundersDAO(address _noundersDAO) external onlyNoundersDAO {
        noundersDAO = _noundersDAO;

        emit NoundersDAOUpdated(_noundersDAO);
    }

    /**
     * @notice Set the token minter.
     * @dev Only callable by the owner when not locked.
     */
    function setMinter(address _minter) external override onlyOwner whenMinterNotLocked {
        minter = _minter;

        emit MinterUpdated(_minter);
    }

    /**
     * @notice Lock the minter.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockMinter() external override onlyOwner whenMinterNotLocked {
        isMinterLocked = true;

        emit MinterLocked();
    }

    /**
     * @notice Set the token URI descriptor.
     * @dev Only callable by the owner when not locked.
     */
    function setDescriptor(INounsDescriptorMinimal _descriptor) external override onlyOwner whenDescriptorNotLocked {
        descriptor = _descriptor;

        emit DescriptorUpdated(_descriptor);
    }

    /**
     * @notice Lock the descriptor.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockDescriptor() external override onlyOwner whenDescriptorNotLocked {
        isDescriptorLocked = true;

        emit DescriptorLocked();
    }

    /**
     * @notice Set the token seeder.
     * @dev Only callable by the owner when not locked.
     */
    function setSeeder(INounsSeeder _seeder) external override onlyOwner whenSeederNotLocked {
        seeder = _seeder;

        emit SeederUpdated(_seeder);
    }

    /**
     * @notice Lock the seeder.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockSeeder() external override onlyOwner whenSeederNotLocked {
        isSeederLocked = true;

        emit SeederLocked();
    }

    /**
     * @notice Mint a Verb with `verbId` to the provided `to` address.
     */
    function _mintTo(address to, uint256 verbId) internal returns (uint256) {
        INounsSeeder.Seed memory seed = seeds[verbId] = seeder.generateSeed(verbId, descriptor);

        _mint(owner(), to, verbId);
        emit VerbCreated(verbId, seed);

        return verbId;
    }
}
