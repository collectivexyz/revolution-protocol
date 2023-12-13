# @collectivexyz/revolution

## 0.2.3

### Patch Changes

- 6f1de66: adds tsup and tsconfig to enable publishing, uses new npm org

## 0.2.2

### Patch Changes

- 7f495d2: Token, culture index, and maxheap owned by DAO, adds new cultureindex dropper and maxheap admin

## 0.2.0

### Minor Changes

- 31feec1: added RevolutionBuilder to enable one function deployments of all revolution contracts. Made all contracts Initializable and creatable behind an ERC1967 proxy.
- 388aebf: adds voteWithSig to the cultureIndex. adds bidder param to AuctionHouse createBid function to enable paper checkout
- 611c162: renames batchVote to voteForMany and makes voteWithSig functions accept many pieceIds instead of one per

### Patch Changes

- Updated dependencies [31feec1]
  - @collectivexyz/protocol-rewards@0.2.0
