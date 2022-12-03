// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "murky/Merkle.sol";

import "../src/library/SafeAccessControlUpgradeable.sol";

contract SafeAccessControlTest is Test {
    MockSafeAccessControl public mock;

    address public immutable OWNER = address(bytes20(keccak256("OWNER")));

    bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0);
    bytes32 public constant ROLE_A = keccak256("ROLE_A");
    bytes32 public constant ROLE_B = keccak256("ROLE_B");

    address public constant ALICE = address(bytes20(keccak256("ALICE")));
    address public constant BOB = address(bytes20(keccak256("BOB")));
    address public constant CAROL = address(bytes20(keccak256("CAROL")));

    function setUp() public {
        vm.prank(OWNER);
        mock = new MockSafeAccessControl();
    }

    function testForRoles() public {
        _assertHasRole(DEFAULT_ADMIN_ROLE, true, false, false, false);
        _assertHasRole(ROLE_A, false, false, false, false);
        _assertHasRole(ROLE_B, false, false, false, false);

        vm.prank(OWNER);
        mock.grantRole(ROLE_A, ALICE);

        _assertHasRole(ROLE_A, false, true, false, false);
        _assertHasRole(ROLE_B, false, false, false, false);

        vm.prank(OWNER);
        mock.grantRole(ROLE_A, BOB);

        _assertHasRole(ROLE_A, false, true, true, false);
        _assertHasRole(ROLE_B, false, false, false, false);

        vm.prank(OWNER);
        mock.grantRole(ROLE_B, ALICE);

        _assertHasRole(ROLE_A, false, true, true, false);
        _assertHasRole(ROLE_B, false, true, false, false);

        vm.prank(OWNER);
        mock.grantRole(ROLE_B, CAROL);

        _assertHasRole(ROLE_A, false, true, true, false);
        _assertHasRole(ROLE_B, false, true, false, true);
    }

    function testGrantRoleRevertForNonOwnerOrAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeAccessControlUpgradeable.SafeAccessControl__OnlyOwnerOrRole.selector, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        mock.grantRole(ROLE_A, ALICE);

        bytes32 ROLE_B_ADMIN = keccak256("ROLE_B_ADMIN");

        vm.startPrank(OWNER);
        mock.setAdminRole(ROLE_B, ROLE_B_ADMIN);
        mock.grantRole(ROLE_B, ALICE);
        mock.grantRole(ROLE_B_ADMIN, BOB);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeAccessControlUpgradeable.SafeAccessControl__OnlyOwnerOrRole.selector, ROLE_B_ADMIN
            )
        );
        vm.prank(ALICE);
        mock.grantRole(ROLE_B, ALICE);

        vm.prank(BOB);
        mock.grantRole(ROLE_B, CAROL);

        vm.startPrank(OWNER);

        vm.expectRevert(SafeAccessControlUpgradeable.SafeAccessControl__DefaultAdminRoleBoundToOwner.selector);
        mock.grantRole(DEFAULT_ADMIN_ROLE, ALICE);

        vm.expectRevert(SafeAccessControlUpgradeable.SafeAccessControl__DefaultAdminRoleBoundToOwner.selector);
        mock.grantRole(DEFAULT_ADMIN_ROLE, BOB);

        vm.expectRevert(SafeAccessControlUpgradeable.SafeAccessControl__DefaultAdminRoleBoundToOwner.selector);
        mock.grantRole(DEFAULT_ADMIN_ROLE, CAROL);

        mock.grantRole(DEFAULT_ADMIN_ROLE, OWNER);
        vm.stopPrank();
    }

    function testFunctionOnlyOwnerRevertsOnNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(ALICE);
        mock.onlyCallableByOwner();

        vm.prank(OWNER);
        mock.onlyCallableByOwner();
    }

    function testFunctionOnlyOwnerOrRoleRevertsOnNonOwnerOrRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(SafeAccessControlUpgradeable.SafeAccessControl__OnlyOwnerOrRole.selector, ROLE_A)
        );
        vm.prank(ALICE);
        mock.onlyCallableByOwnerOrRole(ROLE_A);

        vm.prank(OWNER);
        mock.onlyCallableByOwnerOrRole(ROLE_A);

        vm.startPrank(OWNER);
        mock.grantRole(ROLE_A, ALICE);
        vm.stopPrank();

        vm.prank(ALICE);
        mock.onlyCallableByOwnerOrRole(ROLE_A);

        vm.prank(OWNER);
        mock.onlyCallableByOwnerOrRole(ROLE_A);
    }

    function testFunctionOnlyRoleRevertsOnNonRole() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(ALICE),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(ROLE_A), 32)
            )
        );
        vm.prank(ALICE);
        mock.onlyCallableByRole(ROLE_A);

        vm.startPrank(OWNER);
        mock.grantRole(ROLE_A, ALICE);
        vm.stopPrank();

        vm.prank(ALICE);
        mock.onlyCallableByRole(ROLE_A);
    }

    function testRevokeRole() public {
        vm.startPrank(OWNER);
        mock.grantRole(ROLE_A, ALICE);
        mock.grantRole(ROLE_A, BOB);
        mock.grantRole(ROLE_B, ALICE);
        mock.grantRole(ROLE_B, CAROL);
        vm.stopPrank();

        _assertHasRole(ROLE_A, false, true, true, false);
        _assertHasRole(ROLE_B, false, true, false, true);

        vm.startPrank(OWNER);
        mock.revokeRole(ROLE_A, ALICE);
        vm.stopPrank();

        _assertHasRole(ROLE_A, false, false, true, false);
        _assertHasRole(ROLE_B, false, true, false, true);

        vm.startPrank(OWNER);
        mock.revokeRole(ROLE_A, BOB);
        vm.stopPrank();

        _assertHasRole(ROLE_A, false, false, false, false);
        _assertHasRole(ROLE_B, false, true, false, true);

        vm.startPrank(OWNER);
        mock.revokeRole(ROLE_B, ALICE);
        vm.stopPrank();

        _assertHasRole(ROLE_A, false, false, false, false);
        _assertHasRole(ROLE_B, false, false, false, true);

        vm.startPrank(OWNER);
        mock.revokeRole(ROLE_B, CAROL);
        vm.stopPrank();

        _assertHasRole(ROLE_A, false, false, false, false);
        _assertHasRole(ROLE_B, false, false, false, false);
    }

    function testRevokeRoleRevertForNonOwnerOrAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeAccessControlUpgradeable.SafeAccessControl__OnlyOwnerOrRole.selector, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        mock.revokeRole(ROLE_A, ALICE);

        bytes32 ROLE_B_ADMIN = keccak256("ROLE_B_ADMIN");

        vm.startPrank(OWNER);
        mock.setAdminRole(ROLE_B, ROLE_B_ADMIN);
        mock.grantRole(ROLE_B, ALICE);
        mock.grantRole(ROLE_B_ADMIN, BOB);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeAccessControlUpgradeable.SafeAccessControl__OnlyOwnerOrRole.selector, ROLE_B_ADMIN
            )
        );
        vm.prank(ALICE);
        mock.revokeRole(ROLE_B, ALICE);

        _assertHasRole(ROLE_B, false, true, false, false);

        vm.prank(BOB);
        mock.revokeRole(ROLE_B, ALICE);

        vm.startPrank(OWNER);

        // Shoudn't revert
        mock.revokeRole(DEFAULT_ADMIN_ROLE, BOB);
        mock.revokeRole(DEFAULT_ADMIN_ROLE, CAROL);

        vm.expectRevert(SafeAccessControlUpgradeable.SafeAccessControl__DefaultAdminRoleBoundToOwner.selector);
        mock.revokeRole(DEFAULT_ADMIN_ROLE, OWNER);
        vm.stopPrank();
    }

    function testRenounceRole() public {
        vm.startPrank(OWNER);
        mock.grantRole(ROLE_A, ALICE);
        mock.grantRole(ROLE_A, BOB);
        mock.grantRole(ROLE_B, ALICE);
        mock.grantRole(ROLE_B, CAROL);
        vm.stopPrank();

        _assertHasRole(ROLE_A, false, true, true, false);
        _assertHasRole(ROLE_B, false, true, false, true);

        vm.prank(ALICE);
        mock.renounceRole(ROLE_A, ALICE);

        _assertHasRole(ROLE_A, false, false, true, false);
        _assertHasRole(ROLE_B, false, true, false, true);

        vm.prank(BOB);
        mock.renounceRole(ROLE_A, BOB);

        _assertHasRole(ROLE_A, false, false, false, false);
        _assertHasRole(ROLE_B, false, true, false, true);

        vm.prank(ALICE);
        mock.renounceRole(ROLE_B, ALICE);

        _assertHasRole(ROLE_A, false, false, false, false);
        _assertHasRole(ROLE_B, false, false, false, true);

        vm.prank(CAROL);
        mock.renounceRole(ROLE_B, CAROL);

        _assertHasRole(ROLE_A, false, false, false, false);
        _assertHasRole(ROLE_B, false, false, false, false);
    }

    function testRenounceRoleRevert() public {
        vm.expectRevert(SafeAccessControlUpgradeable.SafeAccessControl__DefaultAdminRoleBoundToOwner.selector);
        vm.prank(OWNER);
        mock.renounceRole(DEFAULT_ADMIN_ROLE, OWNER);

        vm.expectRevert("AccessControl: can only renounce roles for self");
        vm.prank(ALICE);
        mock.renounceRole(DEFAULT_ADMIN_ROLE, BOB);

        vm.prank(OWNER);
        mock.grantRole(ROLE_A, ALICE);

        _assertHasRole(ROLE_A, false, true, false, false);

        vm.prank(ALICE);
        mock.renounceRole(ROLE_A, ALICE);

        _assertHasRole(ROLE_A, false, false, false, false);
    }

    function testGrantDefaultAdminRoleOnTransferOwnership() public {
        assertEq(mock.hasRole(DEFAULT_ADMIN_ROLE, OWNER), true);
        assertEq(mock.hasRole(DEFAULT_ADMIN_ROLE, ALICE), false);

        assertEq(mock.owner(), OWNER);

        vm.prank(OWNER);
        mock.transferOwnership(ALICE);

        vm.prank(ALICE);
        mock.acceptOwnership();

        assertEq(mock.hasRole(DEFAULT_ADMIN_ROLE, ALICE), true);
        assertEq(mock.hasRole(DEFAULT_ADMIN_ROLE, OWNER), false);

        assertEq(mock.owner(), ALICE);
    }

    function _assertHasRole(bytes32 role, bool ownerHasRole, bool aliceHasRole, bool bobHasRole, bool carolHasRole)
        private
    {
        assertEq(mock.hasRole(role, OWNER), ownerHasRole);
        assertEq(mock.hasRole(role, ALICE), aliceHasRole);
        assertEq(mock.hasRole(role, BOB), bobHasRole);
        assertEq(mock.hasRole(role, CAROL), carolHasRole);
    }
}

contract MockSafeAccessControl is SafeAccessControlUpgradeable {
    uint256 private _shh;

    constructor() {
        initialize();
    }

    function initialize() public initializer {
        __SafeAccessControl_init();
    }

    function onlyCallableByOwner() external onlyOwner {
        _shh = 0;
    }

    function onlyCallableByOwnerOrRole(bytes32 role) external onlyOwnerOrRole(role) {
        _shh = 0;
    }

    function onlyCallableByRole(bytes32 role) external onlyRole(role) {
        _shh = 0;
    }

    function setAdminRole(bytes32 role, bytes32 adminRole) external onlyOwner {
        _setRoleAdmin(role, adminRole);
    }
}
