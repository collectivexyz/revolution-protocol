
[<img width="200" alt="get in touch with Consensys Diligence" src="https://user-images.githubusercontent.com/2865694/56826101-91dcf380-685b-11e9-937c-af49c2510aa0.png">](https://diligence.consensys.net)<br/>
<sup>
[[  🌐  ](https://diligence.consensys.net)  [  📩  ](mailto:diligence@consensys.net)  [  🔥  ](https://consensys.github.io/diligence/)]
</sup><br/><br/>



# Solidity Metrics for 'CLI'

## Table of contents

- [Scope](#t-scope)
    - [Source Units in Scope](#t-source-Units-in-Scope)
    - [Out of Scope](#t-out-of-scope)
        - [Excluded Source Units](#t-out-of-scope-excluded-source-units)
        - [Duplicate Source Units](#t-out-of-scope-duplicate-source-units)
        - [Doppelganger Contracts](#t-out-of-scope-doppelganger-contracts)
- [Report Overview](#t-report)
    - [Risk Summary](#t-risk)
    - [Source Lines](#t-source-lines)
    - [Inline Documentation](#t-inline-documentation)
    - [Components](#t-components)
    - [Exposed Functions](#t-exposed-functions)
    - [StateVariables](#t-statevariables)
    - [Capabilities](#t-capabilities)
    - [Dependencies](#t-package-imports)
    - [Totals](#t-totals)

## <span id=t-scope>Scope</span>

This section lists files that are in scope for the metrics report. 

- **Project:** `'CLI'`
- **Included Files:** 
    - ``
- **Excluded Paths:** 
    - ``
- **File Limit:** `undefined`
    - **Exclude File list Limit:** `undefined`

- **Workspace Repository:** `unknown` (`undefined`@`undefined`)

### <span id=t-source-Units-in-Scope>Source Units in Scope</span>

Source Units Analyzed: **`8`**<br>
Source Units in Scope: **`8`** (**100%**)

| Type | File   | Logic Contracts | Interfaces | Lines | nLines | nSLOC | Comment Lines | Complex. Score | Capabilities |
| ---- | ------ | --------------- | ---------- | ----- | ------ | ----- | ------------- | -------------- | ------------ | 
| 📝 | CultureIndex.sol | 1 | **** | 603 | 565 | 255 | 207 | 218 | **<abbr title='Payable Functions'>💰</abbr><abbr title='Uses Hash-Functions'>🧮</abbr><abbr title='Handles Signatures: ecrecover'>🔖</abbr><abbr title='Unchecked Blocks'>Σ</abbr>** |
| 📝 | MaxHeap.sol | 1 | **** | 167 | 167 | 82 | 58 | 69 | **<abbr title='Payable Functions'>💰</abbr>** |
| 📝 | VerbsToken.sol | 1 | **** | 336 | 328 | 142 | 125 | 125 | **<abbr title='Payable Functions'>💰</abbr><abbr title='TryCatch Blocks'>♻️</abbr><abbr title='Unchecked Blocks'>Σ</abbr>** |
| 📝 | AuctionHouse.sol | 1 | **** | 434 | 428 | 201 | 146 | 192 | **<abbr title='Uses Assembly'>🖥</abbr><abbr title='Payable Functions'>💰</abbr><abbr title='Initiates ETH Value Transfer'>📤</abbr><abbr title='TryCatch Blocks'>♻️</abbr><abbr title='Unchecked Blocks'>Σ</abbr>** |
| 📝 | ERC20TokenEmitter.sol | 1 | **** | 320 | 310 | 156 | 102 | 155 | **<abbr title='Payable Functions'>💰</abbr><abbr title='Unchecked Blocks'>Σ</abbr>** |
| 📝 | NontransferableERC20Votes.sol | 1 | **** | 166 | 155 | 59 | 71 | 50 | **<abbr title='Payable Functions'>💰</abbr>** |
| 📝 | Descriptor.sol | 1 | **** | 190 | 181 | 78 | 68 | 69 | **<abbr title='Payable Functions'>💰</abbr>** |
| 📝 | libs/VRGDAC.sol | 1 | **** | 97 | 97 | 61 | 21 | 34 | **<abbr title='Unchecked Blocks'>Σ</abbr>** |
| 📝 | **Totals** | **8** | **** | **2313**  | **2231** | **1034** | **798** | **912** | **<abbr title='Uses Assembly'>🖥</abbr><abbr title='Payable Functions'>💰</abbr><abbr title='Initiates ETH Value Transfer'>📤</abbr><abbr title='Uses Hash-Functions'>🧮</abbr><abbr title='Handles Signatures: ecrecover'>🔖</abbr><abbr title='TryCatch Blocks'>♻️</abbr><abbr title='Unchecked Blocks'>Σ</abbr>** |

<sub>
Legend: <a onclick="toggleVisibility('table-legend', this)">[➕]</a>
<div id="table-legend" style="display:none">

<ul>
<li> <b>Lines</b>: total lines of the source unit </li>
<li> <b>nLines</b>: normalized lines of the source unit (e.g. normalizes functions spanning multiple lines) </li>
<li> <b>nSLOC</b>: normalized source lines of code (only source-code lines; no comments, no blank lines) </li>
<li> <b>Comment Lines</b>: lines containing single or block comments </li>
<li> <b>Complexity Score</b>: a custom complexity score derived from code statements that are known to introduce code complexity (branches, loops, calls, external interfaces, ...) </li>
</ul>

</div>
</sub>


#### <span id=t-out-of-scope>Out of Scope</span>

##### <span id=t-out-of-scope-excluded-source-units>Excluded Source Units</span>

Source Units Excluded: **`0`**

<a onclick="toggleVisibility('excluded-files', this)">[➕]</a>
<div id="excluded-files" style="display:none">
| File   |
| ------ |
| None |

</div>


##### <span id=t-out-of-scope-duplicate-source-units>Duplicate Source Units</span>

Duplicate Source Units Excluded: **`0`** 

<a onclick="toggleVisibility('duplicate-files', this)">[➕]</a>
<div id="duplicate-files" style="display:none">
| File   |
| ------ |
| None |

</div>

##### <span id=t-out-of-scope-doppelganger-contracts>Doppelganger Contracts</span>

Doppelganger Contracts: **`0`** 

<a onclick="toggleVisibility('doppelganger-contracts', this)">[➕]</a>
<div id="doppelganger-contracts" style="display:none">
| File   | Contract | Doppelganger | 
| ------ | -------- | ------------ |


</div>


## <span id=t-report>Report</span>

### Overview

The analysis finished with **`0`** errors and **`0`** duplicate files.





#### <span id=t-risk>Risk</span>

<div class="wrapper" style="max-width: 512px; margin: auto">
			<canvas id="chart-risk-summary"></canvas>
</div>

#### <span id=t-source-lines>Source Lines (sloc vs. nsloc)</span>

<div class="wrapper" style="max-width: 512px; margin: auto">
    <canvas id="chart-nsloc-total"></canvas>
</div>

#### <span id=t-inline-documentation>Inline Documentation</span>

- **Comment-to-Source Ratio:** On average there are`1.4` code lines per comment (lower=better).
- **ToDo's:** `2` 

#### <span id=t-components>Components</span>

| 📝Contracts   | 📚Libraries | 🔍Interfaces | 🎨Abstract |
| ------------- | ----------- | ------------ | ---------- |
| 8 | 0  | 0  | 0 |

#### <span id=t-exposed-functions>Exposed Functions</span>

This section lists functions that are explicitly declared public or payable. Please note that getter methods for public stateVars are not included.  

| 🌐Public   | 💰Payable |
| ---------- | --------- |
| 77 | 9  | 

| External   | Internal | Private | Pure | View |
| ---------- | -------- | ------- | ---- | ---- |
| 41 | 90  | 4 | 5 | 33 |

#### <span id=t-statevariables>StateVariables</span>

| Total      | 🌐Public  |
| ---------- | --------- |
| 65  | 56 |

#### <span id=t-capabilities>Capabilities</span>

| Solidity Versions observed | 🧪 Experimental Features | 💰 Can Receive Funds | 🖥 Uses Assembly | 💣 Has Destroyable Contracts | 
| -------------------------- | ------------------------ | -------------------- | ---------------- | ---------------------------- |
| `^0.8.22`<br/>`0.8.22` |  | `yes` | `yes` <br/>(1 asm blocks) | **** | 

| 📤 Transfers ETH | ⚡ Low-Level Calls | 👥 DelegateCall | 🧮 Uses Hash Functions | 🔖 ECRecover | 🌀 New/Create/Create2 |
| ---------------- | ----------------- | --------------- | ---------------------- | ------------ | --------------------- |
| `yes` | **** | **** | `yes` | `yes` | **** | 

| ♻️ TryCatch | Σ Unchecked |
| ---------- | ----------- |
| `yes` | `yes` |

#### <span id=t-package-imports>Dependencies / External Imports</span>

| Dependency / Import Path | Count  | 
| ------------------------ | ------ |
| @collectivexyz/protocol-rewards/src/abstract/TokenEmitter/TokenEmitterRewards.sol | 1 |
| @openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol | 7 |
| @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol | 1 |
| @openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol | 3 |
| @openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol | 5 |
| @openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol | 2 |
| @openzeppelin/contracts/token/ERC721/IERC721.sol | 1 |
| @openzeppelin/contracts/utils/Base64.sol | 1 |
| @openzeppelin/contracts/utils/Strings.sol | 3 |

#### <span id=t-totals>Totals</span>

##### Summary

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar"></canvas>
</div>

##### AST Node Statistics

###### Function Calls

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar-ast-funccalls"></canvas>
</div>

###### Assembly Calls

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar-ast-asmcalls"></canvas>
</div>

###### AST Total

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar-ast"></canvas>
</div>

##### Inheritance Graph

<a onclick="toggleVisibility('surya-inherit', this)">[➕]</a>
<div id="surya-inherit" style="display:none">
<div class="wrapper" style="max-width: 512px; margin: auto">
    <div id="surya-inheritance" style="text-align: center;"></div> 
</div>
</div>

##### CallGraph

<a onclick="toggleVisibility('surya-call', this)">[➕]</a>
<div id="surya-call" style="display:none">
<div class="wrapper" style="max-width: 512px; margin: auto">
    <div id="surya-callgraph" style="text-align: center;"></div>
</div>
</div>

###### Contract Summary

<a onclick="toggleVisibility('surya-mdreport', this)">[➕]</a>
<div id="surya-mdreport" style="display:none">
 Sūrya's Description Report

 Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| CultureIndex.sol | [object Promise] |
| MaxHeap.sol | [object Promise] |
| VerbsToken.sol | [object Promise] |
| AuctionHouse.sol | [object Promise] |
| ERC20TokenEmitter.sol | [object Promise] |
| NontransferableERC20Votes.sol | [object Promise] |
| Descriptor.sol | [object Promise] |
| libs/VRGDAC.sol | [object Promise] |


 Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **CultureIndex** | Implementation | ICultureIndex, VersionedContract, UUPS, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, EIP712Upgradeable |||
| └ | <Constructor> | Public ❗️ |  💵 | initializer |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | validateMediaType | Internal 🔒 |   | |
| └ | validateCreatorsArray | Internal 🔒 |   | |
| └ | createPiece | Public ❗️ | 🛑  |NO❗️ |
| └ | _emitPieceCreatedEvents | Internal 🔒 | 🛑  | |
| └ | hasVoted | External ❗️ |   |NO❗️ |
| └ | getVotes | External ❗️ |   |NO❗️ |
| └ | getPastVotes | External ❗️ |   |NO❗️ |
| └ | _calculateVoteWeight | Internal 🔒 |   | |
| └ | _getVotes | Internal 🔒 |   | |
| └ | _getPastVotes | Internal 🔒 |   | |
| └ | _vote | Internal 🔒 | 🛑  | |
| └ | vote | Public ❗️ | 🛑  | nonReentrant |
| └ | voteForMany | Public ❗️ | 🛑  | nonReentrant |
| └ | _voteForMany | Internal 🔒 | 🛑  | |
| └ | voteForManyWithSig | External ❗️ | 🛑  | nonReentrant |
| └ | batchVoteForManyWithSig | External ❗️ | 🛑  | nonReentrant |
| └ | _verifyVoteSignature | Internal 🔒 | 🛑  | |
| └ | getPieceById | Public ❗️ |   |NO❗️ |
| └ | getVote | Public ❗️ |   |NO❗️ |
| └ | getTopVotedPiece | Public ❗️ |   |NO❗️ |
| └ | pieceCount | External ❗️ |   |NO❗️ |
| └ | topVotedPieceId | Public ❗️ |   |NO❗️ |
| └ | _setQuorumVotesBPS | External ❗️ | 🛑  | onlyOwner |
| └ | quorumVotes | Public ❗️ |   |NO❗️ |
| └ | dropTopVotedPiece | Public ❗️ | 🛑  | nonReentrant onlyOwner |
| └ | _authorizeUpgrade | Internal 🔒 |   | onlyOwner |
||||||
| **MaxHeap** | Implementation | VersionedContract, UUPS, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable |||
| └ | <Constructor> | Public ❗️ |  💵 | initializer |
| └ | initialize | Public ❗️ | 🛑  | initializer |
| └ | parent | Private 🔐 |   | |
| └ | swap | Private 🔐 | 🛑  | |
| └ | maxHeapify | Public ❗️ | 🛑  | onlyOwner |
| └ | insert | Public ❗️ | 🛑  | onlyOwner |
| └ | updateValue | Public ❗️ | 🛑  | onlyOwner |
| └ | extractMax | External ❗️ | 🛑  | onlyOwner |
| └ | getMax | Public ❗️ |   |NO❗️ |
| └ | _authorizeUpgrade | Internal 🔒 |   | onlyOwner |
||||||
| **VerbsToken** | Implementation | IVerbsToken, VersionedContract, UUPS, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, ERC721CheckpointableUpgradeable |||
| └ | <Constructor> | Public ❗️ |  💵 | initializer |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | contractURI | Public ❗️ |   |NO❗️ |
| └ | setContractURIHash | External ❗️ | 🛑  | onlyOwner |
| └ | mint | Public ❗️ | 🛑  | onlyMinter nonReentrant |
| └ | burn | Public ❗️ | 🛑  | onlyMinter nonReentrant |
| └ | tokenURI | Public ❗️ |   |NO❗️ |
| └ | dataURI | Public ❗️ |   |NO❗️ |
| └ | setMinter | External ❗️ | 🛑  | onlyOwner nonReentrant whenMinterNotLocked |
| └ | lockMinter | External ❗️ | 🛑  | onlyOwner whenMinterNotLocked |
| └ | setDescriptor | External ❗️ | 🛑  | onlyOwner nonReentrant whenDescriptorNotLocked |
| └ | lockDescriptor | External ❗️ | 🛑  | onlyOwner whenDescriptorNotLocked |
| └ | setCultureIndex | External ❗️ | 🛑  | onlyOwner whenCultureIndexNotLocked nonReentrant |
| └ | lockCultureIndex | External ❗️ | 🛑  | onlyOwner whenCultureIndexNotLocked |
| └ | getArtPieceById | Public ❗️ |   |NO❗️ |
| └ | _mintTo | Internal 🔒 | 🛑  | |
| └ | _authorizeUpgrade | Internal 🔒 |   | onlyOwner |
||||||
| **AuctionHouse** | Implementation | IAuctionHouse, PausableUpgradeable, ReentrancyGuardUpgradeable, Ownable2StepUpgradeable |||
| └ | <Constructor> | Public ❗️ |  💵 | initializer |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | settleCurrentAndCreateNewAuction | External ❗️ | 🛑  | nonReentrant whenNotPaused |
| └ | settleAuction | External ❗️ | 🛑  | whenPaused nonReentrant |
| └ | createBid | External ❗️ |  💵 | nonReentrant |
| └ | pause | External ❗️ | 🛑  | onlyOwner |
| └ | setCreatorRateBps | External ❗️ | 🛑  | onlyOwner |
| └ | setMinCreatorRateBps | External ❗️ | 🛑  | onlyOwner |
| └ | setEntropyRateBps | External ❗️ | 🛑  | onlyOwner |
| └ | unpause | External ❗️ | 🛑  | onlyOwner |
| └ | setTimeBuffer | External ❗️ | 🛑  | onlyOwner |
| └ | setReservePrice | External ❗️ | 🛑  | onlyOwner |
| └ | setMinBidIncrementPercentage | External ❗️ | 🛑  | onlyOwner |
| └ | _createAuction | Internal 🔒 | 🛑  | |
| └ | _settleAuction | Internal 🔒 | 🛑  | |
| └ | _safeTransferETHWithFallback | Private 🔐 | 🛑  | |
||||||
| **ERC20TokenEmitter** | Implementation | IERC20TokenEmitter, ReentrancyGuardUpgradeable, TokenEmitterRewards, Ownable2StepUpgradeable, PausableUpgradeable |||
| └ | <Constructor> | Public ❗️ |  💵 | TokenEmitterRewards initializer |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | _mint | Private 🔐 | 🛑  | |
| └ | totalSupply | Public ❗️ |   |NO❗️ |
| └ | decimals | Public ❗️ |   |NO❗️ |
| └ | balanceOf | Public ❗️ |   |NO❗️ |
| └ | pause | External ❗️ | 🛑  | onlyOwner |
| └ | unpause | External ❗️ | 🛑  | onlyOwner |
| └ | buyToken | Public ❗️ |  💵 | nonReentrant whenNotPaused |
| └ | buyTokenQuote | Public ❗️ |   |NO❗️ |
| └ | getTokenQuoteForEther | Public ❗️ |   |NO❗️ |
| └ | getTokenQuoteForPayment | External ❗️ |   |NO❗️ |
| └ | setEntropyRateBps | External ❗️ | 🛑  | onlyOwner |
| └ | setCreatorRateBps | External ❗️ | 🛑  | onlyOwner |
| └ | setCreatorsAddress | External ❗️ | 🛑  | onlyOwner nonReentrant |
||||||
| **NontransferableERC20Votes** | Implementation | Initializable, ERC20VotesUpgradeable, Ownable2StepUpgradeable |||
| └ | <Constructor> | Public ❗️ |  💵 | initializer |
| └ | __NontransferableERC20Votes_init | Internal 🔒 | 🛑  | onlyInitializing |
| └ | __NontransferableERC20Votes_init_unchained | Internal 🔒 | 🛑  | onlyInitializing |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | decimals | Public ❗️ |   |NO❗️ |
| └ | transfer | Public ❗️ | 🛑  |NO❗️ |
| └ | _transfer | Internal 🔒 | 🛑  | |
| └ | transferFrom | Public ❗️ | 🛑  |NO❗️ |
| └ | approve | Public ❗️ | 🛑  |NO❗️ |
| └ | _mint | Internal 🔒 | 🛑  | |
| └ | mint | Public ❗️ | 🛑  | onlyOwner |
| └ | _approve | Internal 🔒 | 🛑  | |
| └ | _approve | Internal 🔒 | 🛑  | |
| └ | _spendAllowance | Internal 🔒 | 🛑  | |
||||||
| **Descriptor** | Implementation | IDescriptor, VersionedContract, UUPS, Ownable2StepUpgradeable |||
| └ | <Constructor> | Public ❗️ |  💵 | initializer |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | constructTokenURI | Public ❗️ |   |NO❗️ |
| └ | toggleDataURIEnabled | External ❗️ | 🛑  | onlyOwner |
| └ | setBaseURI | External ❗️ | 🛑  | onlyOwner |
| └ | tokenURI | External ❗️ |   |NO❗️ |
| └ | dataURI | Public ❗️ |   |NO❗️ |
| └ | genericDataURI | Public ❗️ |   |NO❗️ |
| └ | _authorizeUpgrade | Internal 🔒 |   | onlyOwner |
||||||
| **VRGDAC** | Implementation |  |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | xToY | Public ❗️ |   |NO❗️ |
| └ | yToX | Public ❗️ |   |NO❗️ |
| └ | pIntegral | Internal 🔒 |   | |


 Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
 

</div>
____
<sub>
Thinking about smart contract security? We can provide training, ongoing advice, and smart contract auditing. [Contact us](https://diligence.consensys.net/contact/).
</sub>


