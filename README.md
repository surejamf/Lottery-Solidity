# Raffle Contract

## Overview

This Solidity Project is designed to facilitate a decentralized raffle system on on any EVM blockchain. The project utilizes Chainlink VRF to ensure a fair and transparent selection of winners.

## Features

- **Entrance Fee**: Participants can enter the raffle by sending a specified entrance fee in ETH.
- **Raffle State**: The contract maintains a state to manage the different phases of the raffle, such as 'OPEN' and 'CALCULATING'.
- **Chainlink VRF Integration**: The contract leverages Chainlink VRF to generate random numbers for selecting winners.
- **Upkeep Mechanism**: The contract includes an upkeep mechanism to check whether conditions for conducting a raffle are met, such as the passage of a defined interval and the presence of participants and funds.

## Contract Details

### Constructor

The constructor initializes the contract with the required parameters, including the entrance fee, raffle interval, and Chainlink VRF components.

### Functions

1. **enterRaffle**
   - Allows participants to enter the raffle by sending the required entrance fee.

2. **checkUpkeep**
   - Checks if the contract needs upkeep based on specific conditions, including the time interval, raffle state, available ETH, and the presence of players.

3. **performUpkeep**
   - Initiates Chainlink VRF to request random words when upkeep conditions are met.

4. **pickWinner**
   - Allows the raffle to go through. 

5. **fulfillRandomWords**
   - Internal function called by Chainlink VRF callback to determine and reward the winner.

### Events

1. **EnteredRaffle**
   - Fired when a participant successfully enters the raffle.

2. **WinnerPicked**
   - Fired when a winner is successfully determined.

3. **RequestedRaffleWInner**
   - Fired when a request for a random winner is initiated.

### Getter Functions

1. **getEntranceFee**
   - Returns the configured entrance fee.

2. **getRaffleState**
   - Returns the current state of the raffle.

3. **getPlayer**
   - Returns the address of a participant based on their index.

4. **getNumberPlayers**
   - Returns the total number of participants in the raffle.

5. **getRecentWinner**
   - Returns the address of the most recent winner.

6. **getLastTimeStamp**
   - Returns the timestamp of the last raffle operation.

## Usage

This contract can be deployed on any EVM blockchain to create and manage decentralized raffles. Participants can enter by sending the specified entrance fee, and winners are randomly selected using Chainlink VRF.