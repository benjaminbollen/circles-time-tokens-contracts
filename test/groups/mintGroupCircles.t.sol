// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "../../src/errors/Errors.sol";
import "./setup.sol";

contract MintGroupCirclesTest is Test, GroupSetup, IHubErrors {
    // State variables
    address group;

    // Constructor

    constructor() GroupSetup() {}

    // Setup

    function setUp() public {
        groupSetup();

        // register a group already
        group = addresses[35];
        vm.prank(group);
        hub.registerGroup(mintPolicy, "Group1", "G1", bytes32(0));

        // G1 trusts first 5 humans
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(addresses[35]);
            hub.trust(addresses[i], INDEFINITE_FUTURE);
        }
    }

    // Positive Tests

    function testGroupMint() public {
        // mint to group
        address[] memory collateral = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        collateral[0] = addresses[0];
        amounts[0] = 1 * CRC;
        vm.prank(addresses[0]);
        hub.groupMint(group, collateral, amounts, "");

        // check balances
        uint256 aliceG1 = hub.balanceOf(addresses[0], uint256(uint160(group)));
        assertEq(aliceG1, 1 * CRC);

        // check total supply through Standard Vault
        StandardTreasury treasury = mockDeployment.treasury();

        // assert that the vault has been created
        address vault = address(treasury.vaults(group));
        assertTrue(vault != address(0));
        // assert that Vault holds Alice's 1 CRC;
        // todo: total supply is not (yet) implemented in hub erc1155
        assertEq(hub.balanceOf(vault, uint256(uint160(addresses[0]))), 1 * CRC);
    }

    function testGroupMintMany() public {
        // mint to group
        for (uint256 i = 0; i < 5; i++) {
            address[] memory collateral = new address[](1);
            uint256[] memory amounts = new uint256[](1);
            collateral[0] = addresses[i];
            amounts[0] = 1 * CRC;

            vm.prank(addresses[i]);
            hub.groupMint(group, collateral, amounts, "");
        }

        // check balances
        StandardTreasury treasury = mockDeployment.treasury();
        address vault = address(treasury.vaults(group));
        for (uint256 i = 0; i < 5; i++) {
            // check each has the group CRC
            uint256 balance = hub.balanceOf(addresses[i], uint256(uint160(group)));
            assertEq(balance, 1 * CRC);
            // check that the personal CRC's are in the vault
            assertEq(hub.balanceOf(vault, uint256(uint160(addresses[i]))), 1 * CRC);
        }
    }

    function testGroupMintMultiCollateral() public {
        // all send to Alice
        for (uint256 i = 1; i < 5; i++) {
            vm.prank(addresses[i]);
            hub.safeTransferFrom(addresses[i], addresses[0], uint256(uint160(addresses[i])), (i + 1) * CRC, "");
        }

        // mint to group
        address[] memory collateral = new address[](5);
        uint256[] memory amounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            collateral[i] = addresses[i];
            amounts[i] = (i + 1) * CRC;
        }
        vm.prank(addresses[0]);
        hub.groupMint(group, collateral, amounts, "");

        // check balances
        StandardTreasury treasury = mockDeployment.treasury();
        address vault = address(treasury.vaults(group));
        assertEq(hub.balanceOf(addresses[0], uint256(uint160(group))), 15 * CRC);

        // check that the personal CRC's are in the vault
        for (uint256 i = 0; i < 5; i++) {
            assertEq(hub.balanceOf(vault, uint256(uint160(addresses[i]))), (i + 1) * CRC);
        }
    }

    function testSequentialGroupMint() public {
        // mint to group
        address[] memory collateral = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        collateral[0] = addresses[0];
        amounts[0] = 1 * CRC;
        vm.prank(addresses[0]);
        hub.groupMint(group, collateral, amounts, "");

        // mint to group again
        vm.prank(addresses[0]);
        hub.groupMint(group, collateral, amounts, "");

        // mint for Bob
        collateral[0] = addresses[1];
        vm.prank(addresses[1]);
        hub.groupMint(group, collateral, amounts, "");

        // check balances
        StandardTreasury treasury = mockDeployment.treasury();
        address vault = address(treasury.vaults(group));
        assertEq(hub.balanceOf(addresses[0], uint256(uint160(group))), 2 * CRC);
        assertEq(hub.balanceOf(addresses[1], uint256(uint160(group))), 1 * CRC);

        // check that the personal CRC's are in the vault
        assertEq(hub.balanceOf(vault, uint256(uint160(addresses[0]))), 2 * CRC);
        assertEq(hub.balanceOf(vault, uint256(uint160(addresses[1]))), 1 * CRC);
    }

    // Negative Tests

    function testGroupMintFail() public {
        // mint to group
        address[] memory collateral = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        // G1 does not trust address[5]
        collateral[0] = addresses[5];
        amounts[0] = 1 * CRC;
        vm.prank(addresses[5]);
        vm.expectRevert();
        hub.groupMint(group, collateral, amounts, "");
    }

    function testDirectSelfGroupMintFails() public {
        // group trusts itself, but editing own trust relationship is not allowed
        // and groups don't trust themselves by default
        vm.prank(group);
        vm.expectRevert();
        hub.trust(group, INDEFINITE_FUTURE);

        // mint to group
        address[] memory collateral = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        collateral[0] = addresses[0];
        amounts[0] = 1 * CRC;
        vm.prank(addresses[0]);
        hub.groupMint(group, collateral, amounts, "");

        // assert Alice has 1 group CRC
        assertEq(hub.balanceOf(addresses[0], uint256(uint160(group))), 1 * CRC);

        // now use this to mint to the Group again
        // reverts because CirclesHubCirclesAreNotTrustedByReceiver
        collateral[0] = group;
        vm.prank(addresses[0]);
        vm.expectRevert();
        hub.groupMint(group, collateral, amounts, "");
    }
}
