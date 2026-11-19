// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Test.sol";
import "../src/Wallet.sol";
import "./mock/MaliciousTarget.sol";
import "./mock/ReentrantOwner.sol";

contract WalletTest is Test {
    Wallet wallet;
    MaliciousTarget maliciousTarget;
    CounterTarget counter;
    RevertingTarget revertingTarget;
    ReentrantOwner reentrantOwner;
    DelegatecallTarget delegatecallTarget;

    address walletOwner = makeAddr("walletOwner");
    address externalUser = makeAddr("externalUser");
    address payable payableAddress = payable(makeAddr("payableAddress"));
    address unassignedowner;
    address payable payableUnassignedAddress;

    function setUp() public {
        wallet = new Wallet(walletOwner);
        counter = new CounterTarget();
        maliciousTarget = new MaliciousTarget();
        revertingTarget = new RevertingTarget();
        reentrantOwner = new ReentrantOwner();
        delegatecallTarget = new DelegatecallTarget();

        vm.deal(walletOwner, 1000 ether);
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

    // function testNonOwnerExecuteRevert() public {
    //     vm.expectRevert(Wallet.NotOwner.selector);
    //     vm.prank(externalUser);
    //     wallet.execute(
    //         payableAddress,
    //         10,
    //         abi.encodeWithSignature("setNumber(uint256)", (42))
    //     );
    // }

    function testNonOwnerExecuteRevert() public {
        vm.expectRevert(Wallet.NotOwner.selector);

        vm.prank(externalUser);

        wallet.execute(
            payable(address(counter)),
            0,
            abi.encodeCall(CounterTarget.setNumber, (42))
        );
    }

    // function testOwnerExecutesETHTransferSuccess() public {
    //     vm.deal(address(wallet), 1000 ether);
    //     uint256 currentBalance = address(wallet).balance;
    //     uint128 etherAmountToBeSent = 10 ether;

    //     vm.prank(walletOwner);
    //     wallet.execute(
    //         payableAddress,
    //         etherAmountToBeSent,
    //         abi.encodeWithSignature("setNumber(uint256)", (42))
    //     );

    //     assertEq(address(wallet).balance, currentBalance - etherAmountToBeSent);
    //     assertEq(address(payableAddress).balance, 10 ether);
    // }

    function testOwnerExecutesETHTransferSuccess() public {
        vm.deal(address(wallet), 1000 ether);

        uint256 initialWalletBalance = address(wallet).balance;
        uint256 initialRecipientBalance = payableAddress.balance;

        vm.prank(walletOwner);

        wallet.execute(payableAddress, 10 ether, "");

        assertEq(address(wallet).balance, initialWalletBalance - 10 ether);

        assertEq(payableAddress.balance, initialRecipientBalance + 10 ether);
    }

    // function testExecuteAgainstZeroAddressRevert() public {
    //     uint128 etherAmountToBeSent = 10 ether;
    //     vm.expectRevert();
    //     vm.prank(walletOwner);
    //     wallet.execute(
    //         payableUnassignedAddress,
    //         etherAmountToBeSent,
    //         abi.encodeWithSignature("setNumber(uint256)", (42))
    //     );
    // }

    function testExecuteAgainstZeroAddressRevert() public {
        vm.expectRevert(Wallet.ZeroAddress.selector);

        vm.prank(walletOwner);

        wallet.execute(payable(address(0)), 0, "");
    }

    // function testTargetRevertsWithCustomError() public {
    //     vm.prank(walletOwner);
    //     vm.expectRevert(Wallet.CallFailed.selector);
    //     wallet.execute(
    //         payableAddress,
    //         10,
    //         abi.encodeWithSignature("setNumber(uint256)", (42))
    //     );
    // }

    function testTargetRevertsWithCustomError() public {
        vm.expectRevert(RevertingTarget.InsufficientBalance.selector);

        vm.prank(walletOwner);

        wallet.execute(
            payable(address(revertingTarget)),
            0,
            abi.encodeCall(RevertingTarget.revertWithCustomError, ())
        );
    }

    // function testTargetRevertsWithoutData() public {
    //     vm.deal(address(wallet), 10 ether);
    //     vm.prank(walletOwner);
    //     vm.expectRevert();
    //     wallet.execute(
    //         payableAddress,
    //         10,
    //         abi.encodeWithSignature("setNumber(uint8)", (42))
    //     );
    // }

    function testTargetRevertsWithoutData() public {
        vm.expectRevert(Wallet.CallFailed.selector);

        vm.prank(walletOwner);

        wallet.execute(
            payable(address(revertingTarget)),
            0,
            abi.encodeCall(RevertingTarget.revertWithoutData, ())
        );
    }

    // function testExecuteFromAnotherContract() public {
    //     vm.expectRevert(Wallet.NotOwner.selector);
    //     // maliciousTarget.attemptToExecute(
    //     //     payableAddress,
    //     //     10,
    //     //     abi.encodeWithSignature("setNumber(uint8)", (42))
    //     // );
    // }

    function testExecuteFromAnotherContract() public {
        vm.expectRevert(Wallet.NotOwner.selector);

        maliciousTarget.attemptToExecute(
            wallet,
            payable(address(counter)),
            0,
            abi.encodeCall(CounterTarget.setNumber, (42))
        );
    }

    function testOwnerExecutesContractCall() public {
        vm.prank(walletOwner);

        wallet.execute(
            payable(address(counter)),
            0,
            abi.encodeCall(CounterTarget.setNumber, (42))
        );

        assertEq(counter.number(), 42);
    }

    function testMsgSenderAndTxOrigin() public {
        vm.prank(walletOwner, walletOwner);

        maliciousTarget.forwardInspect(wallet);
    }

    function testContractOwnerCanReenterWallet() public {
        // 1. Deploy ReentrantOwner.
        // 2. Get its wallet.
        // 3. Deploy CounterTarget.
        // 4. Encode CounterTarget.increment().
        // 5. Call ReentrantOwner.initiate().
        // 6. Assert counter.number() == 1.

        bytes memory data = abi.encodeCall(CounterTarget.increment, ());

        reentrantOwner.initiate(address(counter), data);

        assertEq(counter.number(), 1);
        // assertEq(counter.lastCaller(), address(wallet));
        // assertEq(counter.lastThis(), address(counter));
        // assertEq(counter.lastValue(), 0);
    }

    function testCallAndDelegateCall() public {
        //One invokes target.call(data).
        //The other invokes target.delegatecall(data).

        bytes memory data = abi.encodeCall(DelegatecallTarget.increment, ());
        (bool success, ) = address(counter).call(data);
        (bool ok, ) = address(counter).delegatecall(data);

        if (success) assertEq(counter.number(), 1);
        if (ok) assertEq(counter.number(), 1);
    }
}

//forge test --match-test testCallAndDelegateCall -vvvv
