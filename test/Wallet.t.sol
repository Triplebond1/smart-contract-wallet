// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Test.sol";
import "../src/Wallet.sol";

contract WalletTest is Test {
    Wallet wallet;

    address walletOwner = makeAddr("walletOwner");
    address externalUser = makeAddr("externalUser");
    address payable payableAddress = payable(makeAddr("payableAddress"));
    address unassignedowner;

    function setUp() public {
        wallet = new Wallet(walletOwner);
        vm.deal(walletOwner, 50 ether);
    }

    function testDeployedWithZeroOwner() public {
        vm.expectRevert(Wallet.ZeroAddress.selector);
        wallet = new Wallet(unassignedowner);
    }

    function testInitializedOwnerCorrectAddress() public view {
        assertEq(wallet.walletOwner(), walletOwner);
    }

    function testReceiveEthBalanceIncrease() public {
        uint256 currentBalance = address(wallet).balance;
        uint128 etherAmountToBeSent = 10 ether;
        vm.deal(externalUser, 100 ether);
        vm.prank(externalUser);
        (bool ok, ) = address(wallet).call{value: etherAmountToBeSent}("");
        assertTrue(ok);
        assertEq(address(wallet).balance, currentBalance + etherAmountToBeSent);
    }

    function testNonOwnerExecuteRevert() public {
        vm.expectRevert();
        vm.prank(externalUser);
        wallet.execute(
            payableAddress,
            10,
            abi.encodeWithSignature("setNumber(uint256)", (42))
        );
    }
}
