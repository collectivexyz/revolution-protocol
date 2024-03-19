# @collectivexyz/revolution

## 0.4.8

### Patch Changes

- 392f7a4: add Contests extension
- 796cc43: snapshot points

## 0.4.7

### Patch Changes

- 08c105f: add airdrop contracts
- Updated dependencies [08c105f]
- Updated dependencies [08c105f]
  - @cobuild/splits@0.11.6
  - @cobuild/protocol-rewards@0.11.3

## 0.4.6

### Patch Changes

- df050c7: make points 1 step upgradeable not 2
- df050c7: make RevolutionPoints owner and minter set to `initialOwner` to start to allow for airdrop

## 0.4.5

### Patch Changes

- Updated dependencies [fe89b36]
  - @cobuild/splits@0.11.5

## 0.4.4

### Patch Changes

- 61d290d: Fix ERC20 distribution
- 470ad34: Fix ETH splits balances by account
- 438bed6: fix creator rate out of range bug in Auction
- f73da35: fix bug with escape function in Descriptor breaking over 255 len strings
- da0ce2f: Don't escape single quotes
- 438bed6: reduce max refund priority fee for DAO
- Updated dependencies [61d290d]
- Updated dependencies [470ad34]
- Updated dependencies [15a300d]
  - @cobuild/splits@0.11.4

## 0.4.3

### Patch Changes

- 28b7503: rm bwr
- 3e6ce28: Add settledBlockWad to historical auction data
- 5c591c2: Save amuont paid to owner in historical auctions
- 7ac3648: Add historical auction prices
- 24a194b: Add function to deploy create culture index
- 3b48eb1: Save purchase history and cost basis on the points emitter
- c463b00: Manifestos
- Updated dependencies [abc7062]
  - @cobuild/splits@0.11.3

## 0.4.2

### Patch Changes

- e316500: fix abi types
- Updated dependencies [e316500]
  - @cobuild/protocol-rewards@0.11.2
  - @cobuild/splits@0.11.2

## 0.4.1

### Patch Changes

- Updated dependencies [025ccff]
  - @cobuild/utility-contracts@0.11.1
  - @cobuild/protocol-rewards@0.11.1
  - @cobuild/splits@0.11.1

## 0.4.0

### Minor Changes

- 33f69f7: Add splits functionality to RevolutionBuilder
- abc6d39: Adds new utility contracts for proxy + upgrade contracts, makes SplitMain upgradeable + initialized in RevolutionBuilder

### Patch Changes

- bb7fe93: Points Emitter creator -> founder rewards
- 2329ce1: Bid with reason :)
- 2329ce1: Add grants payments to Auction House
- 89f920c: Add grants payments on PointsEmitter
- Updated dependencies [bb7fe93]
- Updated dependencies [33f69f7]
- Updated dependencies [abc6d39]
  - @cobuild/protocol-rewards@0.11.0
  - @cobuild/splits@0.11.0
  - @cobuild/utility-contracts@0.11.0

## 0.3.16

### Patch Changes

- 4af1ac5: Add flag, purpose to DAO, and checklist and template to culture index

## 0.3.15

### Patch Changes

- 77d0b4e: remove snapshot for points voting in CultureIndex (assumes nontransferability)
- 77d0b4e: adds SVG requirement and media type requirements to CultureIndex

## 0.3.14

### Patch Changes

- 5b94905: readability improvements

## 0.3.13

### Patch Changes

- 6b611b1: add vrgda to builder contract, increase cultureindex image max, emit ethPaidToCreators in auction
- 0008cff: make points and emitter upgradeable
- 6b611b1: make VRGDA follow initializable
- Updated dependencies [6b611b1]
  - @cobuild/protocol-rewards@0.10.1

## 0.3.12

### Patch Changes

- 7caa196: auction events in separate interface

## 0.3.11

### Patch Changes

- 0757c8c: rm unmodified OpenZeppelin contracts and import directly from OZ pkg
- fa843b8: handle case where auction creation fails gracefully

## 0.3.10

### Patch Changes

- e9c1c86: add 2 configurable voting power minimums to the CultureIndex for voting and creating

## 0.3.9

### Patch Changes

- 1aa9001: add voting power helper function to CultureIndex and referral to auction

## 0.3.8

### Patch Changes

- 50e418a: add votingpower abi

## 0.3.7

### Patch Changes

- dc8d678: more verbose errors for CultureIndex

## 0.3.6

### Patch Changes

- 1cb84f5: reduce max num creators in the CultureIndex

## 0.3.5

### Patch Changes

- 2fca317: rm test function, use interfaces in VotingPower

## 0.3.4

### Patch Changes

- 2d6e515: test deploy function

## 0.3.3

### Patch Changes

- 28791fd: make executor a versioned contract

## 0.3.2

### Patch Changes

- 1de2dd3: fix deployer script implementation addr initialization

## 0.3.1

### Patch Changes

- cafed37: make RevolutionPoints owned by the DAO Executor contract, and add a minter to it for the PointsEmitter

## 0.3.0

### Minor Changes

- 0398ceb: first round of audit fixes, adds DAO proxy contract and uses new VRGDA logic

### Patch Changes

- c32834b: fix high severity bug with VotesUpgradeable delegate functionality
- cbebcc5: make all contracts owned by DAO Executory, increases gas threshold
- Updated dependencies [0398ceb]
  - @cobuild/protocol-rewards@0.10.0

## 0.2.4

### Patch Changes

- ea77155: fix package org

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
