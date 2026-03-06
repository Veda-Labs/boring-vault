// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {
    ILayerZeroEndpointV2
} from "LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {
    SetConfigParam
} from "LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "LayerZero-v2/packages/layerzero-v2/evm/messagelib/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "LayerZero-v2/packages/layerzero-v2/evm/messagelib/contracts/SendLibBase.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {Deployer} from "src/helper/Deployer.sol";

contract SetSendConfig is Test, MerkleTreeHelper {
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;

    address constant LAYERZEROLABS_DVN = 0x282b3386571f7f794450d5789911a9804FA346b4;
    address constant NETHERMIND_DVN = 0xaCDe1f22EEAb249d3ca6Ba8805C8fEe9f52a16e7;
    address constant BASE_LZ_EXECUTOR = 0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4;
    Deployer deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() public {
        setSourceChainName("katana");
        vm.createSelectFork("katana");
    }

    function test__SetConfig() public {
        address endpoint = vm.envAddress("SOURCE_ENDPOINT_ADDRESS");
        address oapp = vm.envAddress("SENDER_OAPP_ADDRESS");
        uint32 eid = uint32(vm.envUint("REMOTE_EID"));
        address sendLib = vm.envAddress("SEND_LIB_ADDRESS");
        address signer = vm.envAddress("SIGNER");

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
            optionalDVNCount: type(uint8).max, // optional DVNs count, uint8
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: requiredDvns, // sorted list of required DVN addresses
            optionalDVNs: optionalDvns // sorted list of optional DVNs
        });

        /// @notice ExecutorConfig sets message size limit + fee‑paying executor
        ExecutorConfig memory exec = ExecutorConfig({
            maxMessageSize: 10000, // max bytes per cross-chain message
            executor: BASE_LZ_EXECUTOR // address that pays destination execution fees
        });

        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);

        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(eid, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid, ULN_CONFIG_TYPE, encodedUln);

        vm.prank(address(deployer));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);
    }
}
