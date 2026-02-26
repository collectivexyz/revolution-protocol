## Intro

Splits empower people to earn for themselves and the community treasury, and receive votes in the process. Splits can receive ETH or ERC20 tokens, and split funds. 

Revolution splits are forked from [0xSplits](https://splits.org/) contracts @ https://github.com/0xSplits/splits-contracts. They enable community members to split onchain revenue with the DAO treasury and any other relevant people or accounts. 

Each revolution split sends an amount of ether to the DAO treasury, routed via the [PointsEmitter](https://github.com/collectivexyz/revolution-protocol/blob/main/packages/revolution/src/RevolutionPointsEmitter.sol). 

Each split specifies a list of recipients who receive ether, and a list of recipients who receive points which are purchased when the Split distributes money earned to the treasury via the `PointsEmitter` contract's `buyToken` call. 


## Lifecycle of a split
A user who wants to earn money for the treasury and themselves creates a split via `createSplit`

The split address can be used in any protocol or website where an address is provided, and can receive any ETH or ERC20 tokens. 

ETH or ERC20s pile up in the splits contract. 

`distributeEth` is called which withdraws ETH and ERC20s from the split contract into the `SplitMain` contract. Based on the accounts and percent allocations of the split, funds are distributed to all account balances in the `SplitMain` contract. 

Users are then able to call `withdraw` on the `SplitMain` contract to receive their balances of ether, ERC20, and points. 

## Creating a split
Call [`createSplit`](https://github.com/collectivexyz/revolution-protocol/blob/main/packages/splits/src/SplitMain.sol#L363) on the [SplitMain](https://github.com/collectivexyz/revolution-protocol/blob/main/packages/splits/src/SplitMain.sol) contract.

Specify a list of `accounts` to split funds between, and `percentAllocations` which dictate the proportion of funds split. 

Specify the `pointsData` which contains a percentage dictating the amount of ether that is reserved for the treasury, and a list of `accounts` and `percentAllocations` to split the points purchased with. 

## Distributing a split
Call `distributeEth` on the `SplitMain` contract to initiate a withdrawal from the Split contract into the main split manager. 

In this call, accounts `ethBalances` and `ethPointsBalances` are updated per the percentages and accounts specified on the split. 

The ETH held in `ethPointsBalances` when withdrew is used to purchase the account points, at the time of withdrawal, via the `PointsEmitter` contract.

## Withdrawing
Call `withdraw` on `SplitMain` to withdraw funds from a split to a given account

## Coming soon
An auto-updating liquid split that changes `pointsData` `percentAllocations` and `accounts` based on who sends money to the split. Imagine giving all Zora collectors on a mint points based on how much they collected. 




