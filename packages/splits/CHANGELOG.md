# @cobuild/splits

## 0.11.4

### Patch Changes

- 61d290d: Fix ERC20 distribution
- 470ad34: Fix ETH splits balances by account
- 15a300d: Access control check on `withdraw` to gate point withdrawal to the specific account who owns the balance

## 0.11.3

### Patch Changes

- abc7062: emit data about the split in CreateSplit, make min accounts 0 instead of 1

## 0.11.2

### Patch Changes

- e316500: fix abi types
- Updated dependencies [e316500]
  - @cobuild/protocol-rewards@0.11.2

## 0.11.1

### Patch Changes

- Updated dependencies [025ccff]
  - @cobuild/utility-contracts@0.11.1
  - @cobuild/protocol-rewards@0.11.1

## 0.11.0

### Minor Changes

- 33f69f7: Supports buying points on points emitter
- abc6d39: Adds new utility contracts for proxy + upgrade contracts, makes SplitMain upgradeable + initialized in RevolutionBuilder

### Patch Changes

- Updated dependencies [bb7fe93]
- Updated dependencies [abc6d39]
  - @cobuild/protocol-rewards@0.11.0
  - @cobuild/utility-contracts@0.11.0
