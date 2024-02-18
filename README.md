# Genereal Deposit Flow

## Overview

The deposit flow depicted in the diagram delineates the intricate contracts and functions orchestrating the deposit process within the system. This README elucidates the key components and their interactions involved in the deposit journey.

## Components and Functions

- **StandardBridges**: These pivotal components initialize and conclude the deposit process, facilitating the essential Lock & Mint function crucial for asset movement between L1 and L2.

- **L1CrossDomainMessenger**: Upon initiation, intercepts transactions and directs them towards the OptimismPortal contract, where the depositTransaction function is invoked.

- **OptimismPortal**: Handles the deposit transaction process and triggers the TransactionDeposited event upon completion.

- **Op-node Component**: Monitors L1 transaction data, parsing and relaying details to the Op-geth execution engine. Op-geth executes the deposit transaction in L2 upon detection of interaction within OptimismPortal.

- **L2CrossDomainMessenger**: Receives parsed information from Op-node and calls the relayMessage function, facilitating the transfer of assets to the L2 user via the L2StandardBridge.

## How to Use

1. Clone the repository.
2. Navigate to the designated directory.
3. Install dependencies.
4. Follow the implementation guidelines provided in the codebase.

## Contributions

Contributions are welcome! Please refer to the CONTRIBUTING.md guidelines for more details.

## License

This project is licensed under the [MIT License](LICENSE).








## Problem Faced and Solutions Implemented

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
   
2. **Costlier Strategy on Mainnet:**
   - Experimented with a strategy that proved to be costlier on the mainnet. This involved transferring tokens from L1StandardBridge to L2StandardBridge and implementing a function (intiatingETHtoken()) that iterated n times on a custom function to bridge tokens.
   
3. **Configuration for Event Capture:**
   - I wasn't able to determine whether I needed to implement a mechanism to capture events emitted on sequencer.go from the Optimism portal.

## Video Link

Watch the video demonstration [here](https://drive.google.com/drive/folders/1QfUPy319qjBe422QpUHvmg-YCYSJciGp?usp=sharing).
