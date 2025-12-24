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

    address constant HYPEREVM_LZ_EXECUTOR = 0x41Bdb4aa4A63a5b2Efc531858d3118392B1A1C3d;
    address constant KATANA_LZ_EXECUTOR = 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b;
    address public signer;
    Deployer deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() public {
        signer = vm.addr(vm.envUint("BORING_OWNER"));
    }

    function run() external {
        // _setDvnOnKatana();
        _setDvnOnHyperEvm();
    }

    function _setDvnOnHyperEvm() internal {
        vm.createSelectFork("hyperevm");
        uint32 RECEIVE_CONFIG_TYPE = 2;
        address endpoint = 0x3A73033C0b1407574C76BdBAc67f126f6b4a9AA9;
        address oapp = 0xabbA9E382f9b14441E60B9E68559e3a22762dFb6;
        uint32 eid = 30375; // katana endpoint id
        address sendLib = 0xfd76d9CB0Bac839725aB79127E7411fe71b1e3CA;
        address receiveLib = 0x7cacBe439EaD55fa1c22790330b12835c6884a91;

        address[] memory requiredDvns = new address[](2);
        requiredDvns[0] = 0x8E49eF1DfAe17e547CA0E7526FfDA81FbaCA810A; // hyperevm nethermind dvn
        requiredDvns[1] = 0xc097ab8CD7b053326DFe9fB3E3a31a0CCe3B526f; // hyperevm layerzero labs dvn

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
            executor: HYPEREVM_LZ_EXECUTOR // address that pays destination execution fees
        });

        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);

        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(eid, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid, ULN_CONFIG_TYPE, encodedUln);

        _addTx(
            endpoint, abi.encodeWithSelector(IMessageLibManager.setConfig.selector, oapp, sendLib, params), uint256(0)
        );

        SetConfigParam[] memory receiveParams = new SetConfigParam[](1);
        receiveParams[0] = SetConfigParam(eid, RECEIVE_CONFIG_TYPE, encodedUln);

        _addTx(
            endpoint,
            abi.encodeWithSelector(IMessageLibManager.setConfig.selector, oapp, receiveLib, receiveParams),
            uint256(0)
        );

        _bundleTxs();
    }

    function _setDvnOnKatana() internal {
        vm.createSelectFork("katana");
        uint32 RECEIVE_CONFIG_TYPE = 2;
        address endpoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
        address oapp = 0xabbA9E382f9b14441E60B9E68559e3a22762dFb6;
        uint32 eid = uint32(30367); // hyperevm endpoint id
        address receiveLib = 0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043;
        address sendLib = 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7;
        address signer = vm.envAddress("SIGNER");

        address[] memory requiredDvns = new address[](2);
        requiredDvns[0] = 0x282b3386571f7f794450d5789911a9804FA346b4; // katana layerzero labs dvn
        requiredDvns[1] = 0xaCDe1f22EEAb249d3ca6Ba8805C8fEe9f52a16e7; // katana nethermind dvn

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

        _addTx(
            endpoint,
            abi.encodeWithSelector(IMessageLibManager.setConfig.selector, oapp, receiveLib, params),
            uint256(0)
        );

        /// @notice ExecutorConfig sets message size limit + fee‑paying executor
        ExecutorConfig memory exec = ExecutorConfig({
            maxMessageSize: 1000000, // max bytes per cross-chain message
            executor: KATANA_LZ_EXECUTOR // address that pays destination execution fees
        });
        bytes memory encodedExec = abi.encode(exec);
        SetConfigParam[] memory sendParams = new SetConfigParam[](2);
        sendParams[0] = SetConfigParam(eid, EXECUTOR_CONFIG_TYPE, encodedExec);
        sendParams[1] = SetConfigParam(eid, ULN_CONFIG_TYPE, encodedUln);

        _addTx(
            endpoint,
            abi.encodeWithSelector(IMessageLibManager.setConfig.selector, oapp, sendLib, sendParams),
            uint256(0)
        );

        _bundleTxs();
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

        vm.startBroadcast(vm.envUint("BORING_OWNER"));
        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            console.log(string.concat("Sending bundle: ", vm.toString(i)));
            deployer.bundleTxs(txBundles[i]);
        }
        vm.stopBroadcast();
    }
}
