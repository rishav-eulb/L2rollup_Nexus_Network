## Watch the video demonstration [here](https://drive.google.com/drive/folders/1QfUPy319qjBe422QpUHvmg-YCYSJciGp?usp=sharing).

## Transaction Histroy of bridging ETH from L1 chain to Rollup [here](https://sepolia.etherscan.io/address/0xf0fe6b146198ee65ce160a0849b8e516563138b7#internaltx).
---

# Generel Deposit Flow

## Overview

![Deposit Flow Diagram](https://www.alchemy.com/_next/image?url=https%3A%2F%2Fwww.datocms-assets.com%2F105223%2F1704208402-optimistic-rollup-architecture.png&w=1080&q=75)

The deposit flow depicted in the diagram orchestrates the deposit process within the system. This README elucidates the key components and their interactions involved in the deposit journey.

## Components and Functions

- **StandardBridges**: These pivotal components initialize and conclude the deposit process, facilitating the essential Lock & Mint function crucial for asset movement between L1 and L2.

- **L1CrossDomainMessenger**: Upon initiation, intercepts transactions and directs them towards the OptimismPortal contract, where the depositTransaction function is invoked.

- **OptimismPortal**: Handles the deposit transaction process and triggers the TransactionDeposited event upon completion.

- **Op-node Component**: Monitors L1 transaction data, parsing and relaying details to the Op-geth execution engine. Op-geth executes the deposit transaction in L2 upon detection of interaction within OptimismPortal.

- **L2CrossDomainMessenger**: Receives parsed information from Op-node and calls the relayMessage function, facilitating the transfer of assets to the L2 user via the L2StandardBridge.

---

# Custom Deposit Flow

## Overview of Part 2

This part aims to enable users on Ethereum to distribute rewards in the form of ETH to users on a Rollup network. The process involves modifying the bridge contract and the sequencer to facilitate the distribution of rewards from Ethereum to Rollup users.

## Approach

To achieve the task of enabling reward distribution on the Rollup network, the following approach was implemented:

1. **Modify OptimisticPortal.sol:**
    - Added a function to the bridge contract that allows users to specify a list of addresses and corresponding reward amounts to be distributed.
    - Implemented the functionality to store the ETH rewards on the bridge and emit an event (`RewardDistributed`) upon successful distribution.

2. **Update Sequencer (sequencer.go):**
    - Implemented a function (`IncludeRewardDistributedEventInBlock`) in the sequencer to catch the `RewardDistributed` event emitted by OptimisticPortal.sol.
    - Modified the sequencer to include the `RewardDistributed` event in the block during block creation.
    - Ensured that the inclusion of the event in the block increases the user balances on the Rollup network.

## Functions Developed

### OptimisticPortal.sol

#### distributeRewards(address[] memory recipients, uint256[] memory amounts) external payable

- Allows users to distribute rewards in the form of ETH to specified recipients on the Rollup network.
- Users provide a list of recipient addresses and corresponding reward amounts.
- The function stores the ETH rewards on the bridge and emits a `RewardDistributed` event upon successful distribution.

### Sequencer (sequencer.go)

#### IncludeRewardDistributedEventInBlock()

- Catches the `RewardDistributed` event emitted by OptimisticPortal.sol.
- Includes the event in the block during block creation on the Rollup network.
- Increases the user balances on the Rollup network based on the rewards distributed.

---

# Problem Faced

### Part 1:

1. **Memory Space Efficiency:**
   - Due to limited space in the root hard drive, I needed to prioritize memory space efficiency.
   
2. **Installing direnv Package:**
   - Initially, I encountered difficulties installing the direnv package. However, I overcame this obstacle by practicing Linux commands and referring to the official documentation on direnv.
   
3. **Time Efficiency in Deployment:**
   - Deploying the L1 contracts essential for the chain's functionality required time efficiency. During peak times, the estimated amount of ETH required was notably higher, approximately $10k if executed on the mainnet.
   
4. **Optimistic Rollup Documentation:**
   - The official documentation of Optimistic Rollup lacked clarity regarding running op-geth, op-node, batchr, proposer concurrently.

### Part 2:

1. **Finding Specific Documentation:**
   - I encountered challenges in locating specific documentation required to complete Part 2. To address this, I utilized OpenAI and Gemini AI to better understand the concepts involved.
   
2. **Implented Standard Deposit Flow strategy:**
   - Experimented with a strategy that proved to be costlier on the mainnet. This involved following standard Deposit Flow approach of  transferring tokens from L1StandardBridge to L2StandardBridge and implementing a function (intiatingETHtoken()) that iterated n times on a custom function to bridge tokens.
   
3. **Configuration for Event Capture:**
   - I wasn't able to determine whether I needed to implement a mechanism to capture events emitted on sequencer.go from the Optimism portal.


