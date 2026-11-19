// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
import "../../src/Wallet.sol";

contract MaliciousTarget {
    error TxOriginIsNotWalletOwner();
    error TxOriginIsWalletOwner();
    error MsgSenderIsNotWalletOwner();
    error MsgSenderIsWalletOwner();
    error MsgSenderIsMaliciousContract();

    event CallContext(
        address origin,
        address sender,
        address self,
        address owner
    );

    function attemptToExecute(
        Wallet wallet,
        address payable target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory) {
        return wallet.execute(target, value, data);
    }

    // function inspectCallContext(Wallet wallet) external view {
    //     address owner = wallet.walletOwner();
    //     // Add assertions here.
    //     // //tx.origin is the wallet owner
    //     // if (tx.origin != owner) revert TxOriginIsNotWalletOwner();
    //     // if (tx.origin == owner) revert TxOriginIsWalletOwner();

    //     // //msg.sender is not the wallet owner.
    //     // if (msg.sender != owner) revert MsgSenderIsNotWalletOwner();
    //     // if (msg.sender == owner) revert MsgSenderIsWalletOwner();

    //     // //msg.sender is the malicious contract.
    //     // if (msg.sender == address(this)) revert MsgSenderIsMaliciousContract();

    //     // tx.origin must be the wallet owner
    //     assert(tx.origin == owner);

    //     // msg.sender must not be the wallet owner
    //     assert(msg.sender != owner);

    //     // msg.sender must be this malicious contract
    //     assert(msg.sender == address(this));
    // }

    function forwardInspect(Wallet wallet) external view {
        this.inspectCallContext(wallet);
    }

    function inspectCallContext(Wallet wallet) external view {
        address owner = wallet.walletOwner();

        assert(tx.origin == owner);
        assert(msg.sender != owner);
        assert(msg.sender == address(this));
        // emit CallContext(
        //     tx.origin,
        //     msg.sender,
        //     address(this),
        //     wallet.walletOwner()
        // );
    }

    // address public maliciousUser;
    // Wallet wallet;

    // constructor(address walletOwner) {
    //     wallet = new Wallet(walletOwner);
    // }

    receive() external payable {}

    // function attemptToExecute(
    //     address payable _to,
    //     uint256 value,
    //     bytes memory data
    // ) external {
    //     wallet.execute(_to, value, data);
    // }
}

contract CounterTarget {
    uint256 public number;
    address public lastCaller;
    address public lastThis;
    uint256 public lastValue;

    function setNumber(uint256 _number) external {
        number = _number;
    }

    function increment() external payable {
        number++;

        // lastCaller = msg.sender;
        // lastThis = address(this);
        // lastValue = msg.value;
    }
}

contract RevertingTarget {
    error InsufficientBalance();

    function revertWithCustomError() external pure {
        revert InsufficientBalance();
    }

    function revertWithoutData() external pure {
        assembly {
            revert(0, 0)
        }
    }
}

contract DelegatecallTarget {
    uint256 public number;

    function increment() external {
        number++;
    }
}
