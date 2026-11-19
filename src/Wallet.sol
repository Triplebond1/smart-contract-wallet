// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

contract Wallet {
    address public walletOwner;

    error NotOwner();
    error ZeroAddress();
    error TransferFailed(uint256 amount, address recipient);
    error CallFailed();
    error ExceedsSpendingLimit();
    error ExecuteFailed();

    uint256 public spendingLimit;
    uint256 public spent;

    event Received(address indexed sender, uint256 amount);
    event Executed(address indexed to, uint256 value, bytes data);
    event ExecuteWithLimit(address indexed to, uint256 value, uint256 spent);

    modifier onlyOwner() {
        if (msg.sender != walletOwner) revert NotOwner();
        _;
    }

    constructor(address _walletOwner) {
        if (_walletOwner == address(0)) revert ZeroAddress();
        walletOwner = _walletOwner;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function execute(
        address payable _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner returns (bytes memory) {
        if (_to == address(0)) {
            revert ZeroAddress();
        }

        (bool success, bytes memory returnData) = _to.call{value: _value}(
            _data
        );
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            } else {
                revert CallFailed();
            }
        }

        emit Executed(_to, _value, _data);
        return returnData;
    }

    function executeWithLimit(
        address payable _target,
        uint256 _value,
        bytes calldata _data
    ) public onlyOwner {
        // Only the owner can call it.
        // It accepts a target, ETH value and calldata.
        // It checks whether spent + value exceeds spendingLimit.
        // It updates spent.
        // It executes the external call.
        // It reverts if the external call fails.
        //if (spent + _value > spendingLimit) revert ExceedsSpendingLimit();
        if (_value > spendingLimit - spent) revert ExceedsSpendingLimit();
        spent += _value;
        (bool success, bytes memory returnData) = _target.call{value: _value}(
            _data
        );
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            } else {
                revert CallFailed();
            }
        }
        emit ExecuteWithLimit(_target, _value, spent);
    }
}
