// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint256 deployerKey;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    event EnteredRaffle(address indexed player);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE); // fund our fake user with funds
    }

    function testRaffleInitiatizesInOPENState() public view {
        //check whether it starts in open state
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenNotEnoughETH() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__NotEnoughETHSend.selector);

        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenEntering() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        assert(raffle.getPlayer(0) == address(PLAYER));
    }

    function TestEmitEventOnEntry() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle)); // Only 1 true because only one indexed event

        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleClosed() public raffleEnteredAndTimeOK {
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleClosed.selector);

        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1); // change the time
        vm.roll(block.number + 1); // change the block number

        // Act

        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        // Assert

        assert(upKeepNeeded == false);
    }

    function testFalseIfRaffleNotOpen() public raffleEnteredAndTimeOK {
        raffle.performUpkeep(""); // raffle is calculation and thus closed

        // Act

        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assert(upKeepNeeded == false);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEnteredAndTimeOK
    {
        //Act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 playersNumber = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                playersNumber,
                raffleState
            )
        );
        raffle.performUpkeep(""); // we expect this to fail
    }

    modifier raffleEnteredAndTimeOK() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimeOK
    {
        // Act
        vm.recordLogs(); // records all emitted events and save them
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint(raffleState) == 1); // 1 is calculating
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return; // means skip
        }
        _;
    }

    function testFullfilRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId // create fake random numbers
    ) public raffleEnteredAndTimeOK skipFork {
        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimeOK
        skipFork
    {
        // Arrange

        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE); // give the player 1 ether and prank it
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 previousTimeStamp = raffle.getLastTimeStamp();
        uint256 totalPrize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs(); // records all emitted events and save them
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Act

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //assert

        assert(uint256(raffle.getRaffleState()) == 0); // raffle is done, raffle should be reopened
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getNumberPlayers() == 0); // make sure we reset the players
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE + totalPrize - entranceFee
        );
    }
}
