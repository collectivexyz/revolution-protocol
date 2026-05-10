# Vrbs one-community VRGDA migration

This patch is for the existing Vrbs community on Base only. It intentionally does not change `RevolutionBuilder` deployment wiring.

Live Vrbs addresses used by these scripts:

- DAO: `0x613B7dDCA4B05355B3541F8c018B374987549E79`
- Executor: `0x9bcb4E5978FFAFfDAbE72C2962957479F0E3b598`
- Token: `0x9ea7fd1B8823a271BEC99b205B6c0C56d7C3eAe9`
- Auction: `0x4153b0310354B189E18797D5d7Dfda2C924bdC3D`
- Culture Index: `0x5DA551c18109B58831abE8A5b9eDc5f9a8e4887c`
- Vrb Votes Emitter: `0xEA0aF4b42Cb72C58A11E63a2175B99b2c809Fc28`

The scripts assume AuctionHouse is already paused and settled. They will revert if the auction has an unsettled token.

## Required code fix

The included `CultureIndex` patch lets governance call:

```solidity
setLegacyQuorumExcludedTokenHolder(auction, type(uint256).max)
```

During execution this binds the cutoff to the current block. The quorum check then uses the legacy holder for pieces created at or before that cutoff block. This avoids same-block quorum drift during the DAO cutover.

## Run order

Run all commands from `packages/revolution` on Base (`CHAIN_ID=8453`).

### 1. Deploy new implementations and fresh TokenSale proxy

Required env:

- `PRIVATE_KEY`: deployer key
- `PROTOCOL_REWARDS`: protocol rewards contract address to use in the new TokenSale constructor
- `PROTOCOL_FEE_RECIPIENT`: revolution/protocol fallback reward recipient for the new TokenSale constructor
- `VRGDA_MIN_PRICE_WEI`
- `VRGDA_TARGET_PRICE_WAD`
- `VRGDA_PRICE_DECAY_PERCENT_WAD`
- `VRGDA_TOKENS_PER_TIME_UNIT_WAD`

Optional env:

- `TOKEN_SALE_OWNER`, defaults to the Vrbs Executor and must remain the Vrbs Executor for the DAO cutover
- `VRGDA_CREATOR_RATE_BPS`, defaults to current AuctionHouse value
- `VRGDA_ENTROPY_RATE_BPS`, defaults to current AuctionHouse value
- `VRGDA_MIN_CREATOR_RATE_BPS`, defaults to current AuctionHouse value
- `VRGDA_GRANTS_RATE_BPS`, defaults to current AuctionHouse value
- `VRGDA_GRANTS_ADDRESS`, defaults to current AuctionHouse value
- `VRGDA_SALE_START_TIME`, defaults to current block timestamp
- `VRGDA_SOLD_BY_VRGDA`, defaults to `0`
- `VRGDA_PRICE_UPDATE_INTERVAL`, defaults to `900`
- `VRGDA_POOL_SIZE`, defaults to `10`

```bash
PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY \
PROTOCOL_REWARDS=0x... \
PROTOCOL_FEE_RECIPIENT=0x... \
VRGDA_MIN_PRICE_WEI=10000000000000000 \
VRGDA_TARGET_PRICE_WAD=1000000000000000000 \
VRGDA_PRICE_DECAY_PERCENT_WAD=310000000000000000 \
VRGDA_TOKENS_PER_TIME_UNIT_WAD=1000000000000000000 \
forge script script/vrgda/DeployVrbsVRGDASale.s.sol:DeployVrbsVRGDASale \
  --rpc-url $BASE_RPC_URL --broadcast
```

Output: `deploys/8453.vrbs-vrgda-deploy.txt`.

Export the generated values:

```bash
export VRGDA_NEW_TOKEN_IMPL=0x...
export VRGDA_NEW_CULTURE_INDEX_IMPL=0x...
export TOKEN_SALE_IMPL=0x...
export TOKEN_SALE_PROXY=0x...
```

### 2. Register exact upgrades with the Revolution upgrade manager

This must be done by the manager owner before the Vrbs DAO proposal can execute. The manager address is read from the live AuctionHouse `manager()` getter.

For a read-only output file containing the manager-owner calls:

```bash
VRGDA_NEW_TOKEN_IMPL=$VRGDA_NEW_TOKEN_IMPL \
VRGDA_NEW_CULTURE_INDEX_IMPL=$VRGDA_NEW_CULTURE_INDEX_IMPL \
TOKEN_SALE_IMPL=$TOKEN_SALE_IMPL \
forge script script/vrgda/BuildVrbsManagerRegistration.s.sol:BuildVrbsManagerRegistration \
  --rpc-url $BASE_RPC_URL
```

Output: `deploys/8453.vrbs-vrgda-manager-registration.txt`.

If the manager owner is controlled by an EOA available to you, broadcast directly:

```bash
PRIVATE_KEY=$MANAGER_OWNER_PRIVATE_KEY \
VRGDA_NEW_TOKEN_IMPL=$VRGDA_NEW_TOKEN_IMPL \
VRGDA_NEW_CULTURE_INDEX_IMPL=$VRGDA_NEW_CULTURE_INDEX_IMPL \
TOKEN_SALE_IMPL=$TOKEN_SALE_IMPL \
forge script script/vrgda/RegisterVrbsVRGDAUpgrades.s.sol:RegisterVrbsVRGDAUpgrades \
  --rpc-url $BASE_RPC_URL --broadcast
```

This registers only:

- old Token implementation -> new Token implementation
- old CultureIndex implementation -> new CultureIndex implementation

It never registers AuctionHouse -> TokenSale.

### 3. Prepare CultureIndex ownership if needed

The proposal executor must be able to call `CultureIndex.upgradeTo(...)` and
`CultureIndex.setLegacyQuorumExcludedTokenHolder(...)`. If the CultureIndex owner
is already the Vrbs Executor, no extra step is needed.

If the CultureIndex owner is not the Vrbs Executor, the current CultureIndex
owner must call:

```solidity
CultureIndex.transferOwnership(0x9bcb4E5978FFAFfDAbE72C2962957479F0E3b598)
```

Do not accept ownership manually. The proposal builder will detect
`pendingOwner == Vrbs Executor` and prepend `CultureIndex.acceptOwnership()` to
the DAO proposal so ownership acceptance, CultureIndex upgrade, quorum cutoff,
Token minter cutover, and TokenSale unpause all execute atomically. If neither
`owner` nor `pendingOwner` is the Vrbs Executor, the proposal scripts revert.

### 4. Build the Vrbs DAO proposal

```bash
VRGDA_NEW_TOKEN_IMPL=$VRGDA_NEW_TOKEN_IMPL \
VRGDA_NEW_CULTURE_INDEX_IMPL=$VRGDA_NEW_CULTURE_INDEX_IMPL \
TOKEN_SALE_PROXY=$TOKEN_SALE_PROXY \
forge script script/vrgda/BuildVrbsVRGDAProposal.s.sol:BuildVrbsVRGDAProposal \
  --rpc-url $BASE_RPC_URL
```

Output: `deploys/8453.vrbs-vrgda-dao-proposal.txt`.

Use BaseScan Write Contract on the DAO:

`https://basescan.org/address/0x613B7dDCA4B05355B3541F8c018B374987549E79#writeContract`

Call `propose` with the generated arrays. Use empty signatures and the full calldatas. Keep the generated action order unchanged.

If CultureIndex is already owned by the Vrbs Executor, the action order is:

1. `Vrbs Token.upgradeTo(newTokenImpl)`
2. `CultureIndex.upgradeTo(newCultureIndexImpl)`
3. `CultureIndex.setLegacyQuorumExcludedTokenHolder(auction, type(uint256).max)`
4. `Vrbs Token.setMinter(tokenSaleProxy)`
5. `TokenSale.unpause()`

If CultureIndex ownership is pending to the Vrbs Executor, the proposal prepends:

1. `CultureIndex.acceptOwnership()`

Do not split ownership acceptance, CultureIndex upgrade, quorum cutoff, minter
cutover, and TokenSale unpause across separate blocks.

To submit from a proposer key instead of BaseScan:

```bash
PRIVATE_KEY=$PROPOSER_PRIVATE_KEY \
VRGDA_NEW_TOKEN_IMPL=$VRGDA_NEW_TOKEN_IMPL \
VRGDA_NEW_CULTURE_INDEX_IMPL=$VRGDA_NEW_CULTURE_INDEX_IMPL \
TOKEN_SALE_PROXY=$TOKEN_SALE_PROXY \
forge script script/vrgda/SubmitVrbsVRGDAProposal.s.sol:SubmitVrbsVRGDAProposal \
  --rpc-url $BASE_RPC_URL --broadcast
```

### 5. Verify after proposal execution

```bash
VRGDA_NEW_TOKEN_IMPL=$VRGDA_NEW_TOKEN_IMPL \
VRGDA_NEW_CULTURE_INDEX_IMPL=$VRGDA_NEW_CULTURE_INDEX_IMPL \
TOKEN_SALE_PROXY=$TOKEN_SALE_PROXY \
forge script script/vrgda/VerifyVrbsVRGDAMigration.s.sol:VerifyVrbsVRGDAMigration \
  --rpc-url $BASE_RPC_URL
```

The verifier checks final implementations, auction paused/settled state, token
minter, CultureIndex owner, TokenSale owner/unpause state, WETH/emitter wiring,
and legacy quorum cutoff state.
