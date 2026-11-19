// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
import "../../src/Wallet.sol";

contract ReentrantOwner {
    Wallet public immutable wallet;

    error Unauthorized();

    uint256 public spendingLimit = 10 ether;

    constructor() {
        // Deploy Wallet with address(this) as owner
        wallet = new Wallet(address(this));
        spendingLimit = wallet.spendingLimit();
    }

    function initiate(address target, bytes calldata data) external {
        // Call wallet.execute()
        // Target should be address(this)
        // Calldata should invoke callback()

        wallet.execute(
            payable(address(this)),
            0,
            abi.encodeCall(this.callback, (payable(target), data))
        );
    }

    function callback(address payable target, bytes calldata data) external {
        // Ensure only the wallet can invoke this callback.
        // Call wallet.execute() again.
        if (msg.sender != address(wallet)) revert Unauthorized();
        wallet.execute(target, 0, data);
    }
}

// Modify ReentrantOwner so that:
// 1. Its wallet has a spending limit of 10 ETH.
// 2. Its callback attempts another 6 ETH execution.
// 3. The initial execution also sends 6 ETH.
// 4. You write a Foundry test asserting that the nested execution reverts and spent remains 0 ETH after the whole transaction reverts.
// Important: You will need to think about how the spending limit gets configured. Our wallet doesn't yet have a setter, so add a minimal owner-only setter for this experiment.
