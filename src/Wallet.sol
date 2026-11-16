// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

contract Wallet {
    address public walletOwner;

    error NotOwner();
    error ZeroAddress();
    error TransferFailed(uint256 amount, address recipient);
    error CallFailed();

    event Received(address indexed sender, uint256 amount);
    event Executed(address indexed to, uint256 value, bytes data);

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
}
