// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract M0SolverRegistry is Auth {

    // ========================================= ERRORS =========================================
        
    error M0SolverRegistry__SolverAlreadySetForRoute();
    error M0SolverResgistry__SolverDoesNotMatch();
    error M0SolverResgistry__SolverZeroAddress();

    // ========================================= EVENTS =========================================
    
    event SolverSet(ERC20 indexed tokenIn, ERC20 indexed tokenOut, address indexed solver); 
    event SolverRemoved(ERC20 indexed tokenIn, ERC20 indexed tokenOut, address indexed solver); 
    event SolverOverwrite(ERC20 indexed tokenIn, ERC20 indexed tokenOut, address indexed solver); 

    // ========================================= STATE =========================================
    
    mapping(bytes32 routeId => address solver) public solvers; 

    // ========================================= CONSTRUCTOR =========================================
        
    constructor() Auth(msg.sender, Authority(address(0))) {}

    function setSolver(ERC20 tokenIn, ERC20 tokenOut, address solver) external requiresAuth {
        bytes32 routeId = getRouteId(tokenIn, tokenOut);
        if (solvers[routeId] != address(0)) revert M0SolverRegistry__SolverAlreadySetForRoute();
        if (solver == address(0)) revert M0SolverResgistry__SolverZeroAddress();
        solvers[routeId] = solver;
        emit SolverSet(tokenIn, tokenOut, solver);
    }

    function removeSolver(ERC20 tokenIn, ERC20 tokenOut, address solver) external requiresAuth {
        bytes32 routeId = getRouteId(tokenIn, tokenOut);
        if (solvers[routeId] == address(0)) revert M0SolverResgistry__SolverZeroAddress();
        if (solvers[routeId] != solver) revert M0SolverResgistry__SolverDoesNotMatch();
        delete solvers[routeId];
        emit SolverRemoved(tokenIn, tokenOut, solver);
    }

    function overwriteSolver(ERC20 tokenIn, ERC20 tokenOut, address oldSolver, address newSolver) external requiresAuth {
        bytes32 routeId = getRouteId(tokenIn, tokenOut);
        if (solvers[routeId] == address(0)) revert M0SolverResgistry__SolverZeroAddress();
        if (solvers[routeId] != oldSolver) revert M0SolverResgistry__SolverDoesNotMatch();
        if (newSolver == address(0)) revert M0SolverResgistry__SolverZeroAddress();
        solvers[routeId] = newSolver;
        emit SolverOverwrite(tokenIn, tokenOut, newSolver);
    }

    function getSolver(ERC20 tokenIn, ERC20 tokenOut) external view returns (address) {
        bytes32 routeId = getRouteId(tokenIn, tokenOut);
        return solvers[routeId];
    }

    /// @notice Computes the deterministic route identifier for a directional token pair.
    function getRouteId(ERC20 tokenIn, ERC20 tokenOut) public pure returns (bytes32 routeId) {
        assembly {
            mstore(0x00, tokenIn)
            mstore(0x20, tokenOut)
            routeId := keccak256(0x00, 0x40)
        }
    }
}
