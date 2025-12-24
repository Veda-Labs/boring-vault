// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {console, Script} from "forge-std/Script.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {
    ILayerZeroEndpointV2,
    IMessageLibManager
} from "LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {
    SetConfigParam
} from "LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "LayerZero-v2/packages/layerzero-v2/evm/messagelib/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "LayerZero-v2/packages/layerzero-v2/evm/messagelib/contracts/SendLibBase.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

contract SetSendConfig is Script, MerkleTreeHelper {
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;

    address constant LAYERZEROLABS_DVN = 0x282b3386571f7f794450d5789911a9804FA346b4;
    address constant NETHERMIND_DVN = 0xaCDe1f22EEAb249d3ca6Ba8805C8fEe9f52a16e7;
    address constant KATANA_LZ_EXECUTOR = 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b;
    address public signer;
    Deployer deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() public {
        signer = vm.addr(vm.envUint("BORING_DEVELOPER"));
    }

    function run() external {
        vm.createSelectFork("katana");
        address endpoint = vm.envAddress("SOURCE_ENDPOINT_ADDRESS");
        address oapp = vm.envAddress("SENDER_OAPP_ADDRESS");
        uint32 eid = uint32(vm.envUint("REMOTE_EID"));
        address sendLib = vm.envAddress("SEND_LIB_ADDRESS");

        address[] memory requiredDvns = new address[](2);
        requiredDvns[0] = LAYERZEROLABS_DVN;
        requiredDvns[1] = NETHERMIND_DVN;

        address[] memory optionalDvns = new address[](0);

        /// @notice ULNConfig defines security parameters (DVNs + confirmation threshold)
        /// @notice Send config requests these settings to be applied to the DVNs and Executor
        /// @dev 0 values will be interpretted as defaults, so to apply NIL settings, use:
        /// @dev uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
        /// @dev uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
        UlnConfig memory uln = UlnConfig({
            confirmations: 15, // minimum block confirmations required
            requiredDVNCount: 2, // number of DVNs required
            optionalDVNCount: 0, // optional DVNs count, uint8
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: requiredDvns, // sorted list of required DVN addresses
            optionalDVNs: optionalDvns // sorted list of optional DVNs
        });

        /// @notice ExecutorConfig sets message size limit + fee‑paying executor
        ExecutorConfig memory exec = ExecutorConfig({
            maxMessageSize: 1000000, // max bytes per cross-chain message
            executor: KATANA_LZ_EXECUTOR // address that pays destination execution fees
        });

        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);

        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(eid, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid, ULN_CONFIG_TYPE, encodedUln);

        _addTx(
            endpoint, abi.encodeWithSelector(IMessageLibManager.setConfig.selector, oapp, sendLib, params), uint256(0)
        );

        _bundleTxs();

        _setDvnOnBase();
    }

    function _setDvnOnBase() internal {
        vm.createSelectFork("base");
        uint32 RECEIVE_CONFIG_TYPE = 2;
        address endpoint = 0x1a44076050125825900e736c501f859c50fE728c;
        address oapp = vm.envAddress("SENDER_OAPP_ADDRESS");
        uint32 eid = uint32(30375);
        address receiveLib = 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf;
        address signer = vm.envAddress("SIGNER");

        address[] memory requiredDvns = new address[](2);
        requiredDvns[0] = 0x9e059a54699a285714207b43B055483E78FAac25; // layerzero labs dvn
        requiredDvns[1] = 0xcd37CA043f8479064e10635020c65FfC005d36f6; // base nethermind dvn

        address[] memory optionalDvns = new address[](0);

        /// @notice UlnConfig controls verification threshold for incoming messages
        /// @notice Receive config enforces these settings have been applied to the DVNs and Executor
        /// @dev 0 values will be interpretted as defaults, so to apply NIL settings, use:
        /// @dev uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
        /// @dev uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
        UlnConfig memory uln = UlnConfig({
            confirmations: 15, // min block confirmations from source
            requiredDVNCount: 2, // required DVNs for message acceptance
            optionalDVNCount: 0, // optional DVNs count
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: requiredDvns, // sorted required DVNs
            optionalDVNs: optionalDvns // no optional DVNs
        });

        bytes memory encodedUln = abi.encode(uln);

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(eid, RECEIVE_CONFIG_TYPE, encodedUln);

        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params);
        vm.stopBroadcast();
    }

    Deployer.Tx[] internal txs;

    function getTxs() public view returns (Deployer.Tx[] memory) {
        return txs;
    }

    function _addTx(address target, bytes memory data, uint256 value) internal {
        txs.push(Deployer.Tx(target, data, value));
    }

    function _bundleTxs() internal {
        Deployer.Tx[] memory txsToSend = getTxs();
        uint256 txsLength = txsToSend.length;

        if (txsLength == 0) {
            console.log("No txs to bundle");
            return;
        }

        // Determine how many txs to send
        uint256 desiredNumberOfDeploymentTxs = 1;
        if (desiredNumberOfDeploymentTxs == 0) {
            console.log("Desired number of deployment txs is 0");
        }
        desiredNumberOfDeploymentTxs =
            desiredNumberOfDeploymentTxs > txsLength ? txsLength : desiredNumberOfDeploymentTxs;
        uint256 txsPerBundle = txsLength / desiredNumberOfDeploymentTxs;
        uint256 lastIndexDeployed;
        Deployer.Tx[][] memory txBundles = new Deployer.Tx[][](desiredNumberOfDeploymentTxs);

        console.log(string.concat("Tx bundles to send: ", vm.toString(desiredNumberOfDeploymentTxs)));
        console.log(string.concat("Total txs: ", vm.toString(txsLength)));

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

        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));
        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            console.log(string.concat("Sending bundle: ", vm.toString(i)));
            deployer.bundleTxs(txBundles[i]);
        }
        vm.stopBroadcast();
    }
}
