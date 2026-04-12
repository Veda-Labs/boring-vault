// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringSolver, Auth} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployBoringSolver.s.sol:DeploySolver --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeploySolver is Script, ContractNames, Test {
    uint256 public privateKey;
    error DeployError(string message);

    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant CAN_SOLVE_ROLE = 31;
    uint8 public constant ONLY_QUEUE_ROLE = 32;
    uint8 public constant SOLVER_ORIGIN_ROLE = 33;

    Deployer deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    Deployer.Tx[] internal txs;

    address owner = 0x1b514df3413DA9931eB31f2Ab72e32c0A507Cad5;
    address auth = 0x4000FCaDf9D4803b8C5304af3D4Ca80C71252C63;
    address queue = 0x073882E7A050B09667eC7fBFfc77F3375809A873;

    uint256 internal logLevel;

    function _log(string memory message, uint256 level) internal view {
        if (logLevel >= level) {
            if (level == 1) {
                revert DeployError(message);
            } else if (level == 2) {
                message = string.concat("[WARN]: ", message);
            } else if (level == 3) {
                message = string.concat("[INFO]: ", message);
            } else if (level == 4) {
                message = string.concat("[DEBUG]: ", message);
            }
            console.log(message);
        }
    }

    function _getAddressAndIfDeployed(string memory name) internal view returns (address, bool) {
        address deployedAt = deployer.getAddress(name);
        uint256 size;
        assembly {
            size := extcodesize(deployedAt)
        }
        return (deployedAt, size > 0);
    }

    function _addRoleCapabilityIfNotPresent(uint8 role, address target, bytes4 selector) internal {
        _addTx(auth, abi.encodeWithSelector(RolesAuthority.setRoleCapability.selector, role, target, selector, true), 0);
    }

    function getTxs() public view returns (Deployer.Tx[] memory) {
        return txs;
    }

    function _addTx(address target, bytes memory data, uint256 value) internal {
        txs.push(Deployer.Tx(target, data, value));
    }

    function _bundleTxs(uint256 desiredNumberOfDeploymentTxs) internal {
        Deployer.Tx[] memory txsToSend = getTxs();
        uint256 txsLength = txsToSend.length;

        if (txsLength == 0) {
            _log("no txs to bundle", 3);
            return;
        }

        if (desiredNumberOfDeploymentTxs == 0) {
            _log("desired number of deployment txs is 0", 1);
        }
        desiredNumberOfDeploymentTxs =
            desiredNumberOfDeploymentTxs > txsLength ? txsLength : desiredNumberOfDeploymentTxs;
        uint256 txsPerBundle = txsLength / desiredNumberOfDeploymentTxs;
        uint256 lastIndexDeployed;
        Deployer.Tx[][] memory txBundles = new Deployer.Tx[][](desiredNumberOfDeploymentTxs);

        _log(string.concat("tx bundles to send: ", vm.toString(desiredNumberOfDeploymentTxs)), 4);
        _log(string.concat("total txs: ", vm.toString(txsLength)), 4);

        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            uint256 txsInBundle;
            if (i == desiredNumberOfDeploymentTxs - 1 && txsLength % txsPerBundle != 0) {
                txsInBundle = txsLength - lastIndexDeployed;
            } else {
                txsInBundle = txsPerBundle;
            }
            txBundles[i] = new Deployer.Tx[](txsInBundle);
            for (uint256 j; j < txBundles[i].length; j++) {
                txBundles[i][j] = txsToSend[lastIndexDeployed + j];
            }
            lastIndexDeployed += txsInBundle;
        }

        vm.startBroadcast(privateKey);
        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            _log(string.concat("sending bundle: ", vm.toString(i)), 4);
            deployer.bundleTxs(txBundles[i]);
        }
        vm.stopBroadcast();
    }

    function setUp() external {
        privateKey = vm.envUint("PRIVATE_KEY_1");
        vm.createSelectFork("https://rpc-arch-mainnet-lucidly.tac.build");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;

        creationCode = type(BoringSolver).creationCode;
        constructorArgs = abi.encode(owner, auth, queue);

        (address solverAddress,) = _getAddressAndIfDeployed("BoinkersUSD BoringSolverV0.2");

        _addTx(
            address(deployer),
            abi.encodeWithSelector(
                deployer.deployContract.selector, "BoinkersUSD BoringSolverV0.2", creationCode, constructorArgs, 0
            ),
            uint256(0)
        );

        // _addRoleCapabilityIfNotPresent(ONLY_QUEUE_ROLE, solverAddress, BoringSolver.boringSolve.selector);
        // _addRoleCapabilityIfNotPresent(OWNER_ROLE, solverAddress, Auth.setAuthority.selector);
        // _addRoleCapabilityIfNotPresent(OWNER_ROLE, solverAddress, Auth.transferOwnership.selector);
        // _addRoleCapabilityIfNotPresent(SOLVER_ORIGIN_ROLE, solverAddress, BoringSolver.boringRedeemSolve.selector);
        // _addRoleCapabilityIfNotPresent(SOLVER_ORIGIN_ROLE, solverAddress, BoringSolver.boringRedeemMintSolve.selector);

        _bundleTxs(1);
    }
}
