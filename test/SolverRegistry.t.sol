// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {M0SolverRegistry} from "src/base/Periphery/SolverRegistry.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {Test} from "@forge-std/Test.sol";

contract SolverRegistryTest is Test {
    M0SolverRegistry registry;
    RolesAuthority rolesAuthority;

    uint8 constant ADMIN_ROLE = 1;

    address vedaAdmin = address(0x69);
    address solver = address(0x420);
    address newSolver = address(0x421);
    address unauthorized = address(0x42069);

    ERC20 tokenIn = ERC20(address(0x1111));
    ERC20 tokenOut = ERC20(address(0x2222));

    event SolverSet(ERC20 indexed tokenIn, ERC20 indexed tokenOut, address indexed solver);
    event SolverRemoved(ERC20 indexed tokenIn, ERC20 indexed tokenOut, address indexed solver);
    event SolverOverwrite(ERC20 indexed tokenIn, ERC20 indexed tokenOut, address indexed solver);

    function setUp() public {
        registry = new M0SolverRegistry();
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        registry.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(registry), M0SolverRegistry.setSolver.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(registry), M0SolverRegistry.removeSolver.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(registry), M0SolverRegistry.overwriteSolver.selector, true);
        rolesAuthority.setUserRole(vedaAdmin, ADMIN_ROLE, true);
    }

    function testSetSolver() public {
        bytes32 routeId = registry.getRouteId(tokenIn, tokenOut);

        vm.expectEmit(true, true, true, true);
        emit SolverSet(tokenIn, tokenOut, solver);
        vm.prank(vedaAdmin);
        registry.setSolver(tokenIn, tokenOut, solver);

        assertEq(registry.solvers(routeId), solver);
    }

    function testRemoveSolver() public {
        bytes32 routeId = registry.getRouteId(tokenIn, tokenOut);

        vm.prank(vedaAdmin);
        registry.setSolver(tokenIn, tokenOut, solver);

        vm.expectEmit(true, true, true, true);
        emit SolverRemoved(tokenIn, tokenOut, solver);
        vm.prank(vedaAdmin);
        registry.removeSolver(tokenIn, tokenOut, solver);

        assertEq(registry.solvers(routeId), address(0));
    }

    function testOverwriteSolver() public {
        bytes32 routeId = registry.getRouteId(tokenIn, tokenOut);

        vm.prank(vedaAdmin);
        registry.setSolver(tokenIn, tokenOut, solver);

        vm.expectEmit(true, true, true, true);
        emit SolverOverwrite(tokenIn, tokenOut, newSolver);
        vm.prank(vedaAdmin);
        registry.overwriteSolver(tokenIn, tokenOut, solver, newSolver);

        assertEq(registry.solvers(routeId), newSolver);
    }

    function testGetRouteIdIsDirectional() public view {
        assertTrue(registry.getRouteId(tokenIn, tokenOut) != registry.getRouteId(tokenOut, tokenIn));
    }

    function testSetSolverRevertsWhenAlreadySet() public {
        vm.prank(vedaAdmin);
        registry.setSolver(tokenIn, tokenOut, solver);

        vm.expectRevert(M0SolverRegistry.M0SolverRegistry__SolverAlreadySetForRoute.selector);
        vm.prank(vedaAdmin);
        registry.setSolver(tokenIn, tokenOut, newSolver);
    }

    function testSetSolverRevertsWhenZeroAddress() public {
        vm.expectRevert(M0SolverRegistry.M0SolverResgistry__SolverZeroAddress.selector);
        vm.prank(vedaAdmin);
        registry.setSolver(tokenIn, tokenOut, address(0));
    }

    function testRemoveSolverRevertsWhenSolverMismatch() public {
        vm.prank(vedaAdmin);
        registry.setSolver(tokenIn, tokenOut, solver);

        vm.expectRevert(M0SolverRegistry.M0SolverResgistry__SolverDoesNotMatch.selector);
        vm.prank(vedaAdmin);
        registry.removeSolver(tokenIn, tokenOut, newSolver);
    }

    function testOverwriteSolverRevertsWhenOldSolverMismatch() public {
        vm.prank(vedaAdmin);
        registry.setSolver(tokenIn, tokenOut, solver);

        vm.expectRevert(M0SolverRegistry.M0SolverResgistry__SolverDoesNotMatch.selector);
        vm.prank(vedaAdmin);
        registry.overwriteSolver(tokenIn, tokenOut, newSolver, newSolver);
    }

    function testOwnerCanSetWithoutRole() public {
        bytes32 routeId = registry.getRouteId(tokenIn, tokenOut);
        registry.setSolver(tokenIn, tokenOut, solver);
        assertEq(registry.solvers(routeId), solver);
    }

    function testSetSolverRevertsWhenUnauthorized() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(unauthorized);
        registry.setSolver(tokenIn, tokenOut, solver);
    }

    function testRemoveSolverRevertsWhenUnauthorized() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(unauthorized);
        registry.removeSolver(tokenIn, tokenOut, solver);
    }

    function testOverwriteSolverRevertsWhenUnauthorized() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(unauthorized);
        registry.overwriteSolver(tokenIn, tokenOut, solver, newSolver);
    }
}
