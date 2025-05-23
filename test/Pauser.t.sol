// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {MockPausable} from "test/mocks/MockPausable.sol";
import {Pauser, IPausable} from "src/base/Roles/Pauser.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract PauserTest is Test {
    IPausable[] public pausables;
    Pauser public pauser;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20083900;

        _startFork(rpcKey, blockNumber);

        // Setup pausables.
        pausables.push(new MockPausable());
        pausables.push(new MockPausable());
        pausables.push(new MockPausable());

        // Setup pauser.
        pauser = new Pauser(address(this), Authority(address(0)), pausables);
    }

    struct Withdrawal {
        address staker;
        address delegatedTo;
        address withdrawer;
        uint256 nonce;
        uint32 startBlock;
        address[] strategies;
        uint256[] scaledShares;
    }

    struct QWP {
        address[] strategies;
        uint256[] shares;
        address deprecated;
    }

    function testHunch() external view {
        address decoderAndSanitizer = 0xBF76C48401f7f690f46F0C481Ee9f193D0c43062;
        address target = 0xb814C334748dc8D12145b009020e2783624c0775; // itb position manager
        bytes4 selector = 0xb61d27f6; // execute function selector
        bytes memory packedArgumentAddresses = abi.encodePacked(0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A);

        bytes32 leaf =
            keccak256(abi.encodePacked(decoderAndSanitizer, target, false, selector, packedArgumentAddresses));

        console.log("Pepe SAVE ITB");
        console.logBytes32(leaf);

        Withdrawal[] memory w = new Withdrawal[](1);
        address[] memory s0 = new address[](1);
        s0[0] = 0xaCB55C530Acdb2849e6d4f36992Cd8c9D50ED8F7;
        uint256[] memory ss0 = new uint256[](1);
        // ss0[0] = 100000000000000000000000;
        // w[0] = Withdrawal({
        //     staker: 0xb814C334748dc8D12145b009020e2783624c0775,
        //     delegatedTo: 0xDcAE4FAf7C7d0f4A78abe147244c6e9d60cFD202,
        //     withdrawer: 0xb814C334748dc8D12145b009020e2783624c0775,
        //     nonce: 8,
        //     startBlock: 22189661,
        //     strategies: s0,
        //     scaledShares: ss0
        // });
        // uint256[] memory ss1 = new uint256[](1);
        // ss1[0] = 150000000000000000000000;
        // w[1] = Withdrawal({
        //     staker: 0xb814C334748dc8D12145b009020e2783624c0775,
        //     delegatedTo: 0xDcAE4FAf7C7d0f4A78abe147244c6e9d60cFD202,
        //     withdrawer: 0xb814C334748dc8D12145b009020e2783624c0775,
        //     nonce: 9,
        //     startBlock: 22217882,
        //     strategies: s0,
        //     scaledShares: ss1
        // });
        // uint256[] memory ss2 = new uint256[](1);
        // ss2[0] = 200000000000000000000000;
        // w[2] = Withdrawal({
        //     staker: 0xb814C334748dc8D12145b009020e2783624c0775,
        //     delegatedTo: 0xDcAE4FAf7C7d0f4A78abe147244c6e9d60cFD202,
        //     withdrawer: 0xb814C334748dc8D12145b009020e2783624c0775,
        //     nonce: 10,
        //     startBlock: 22227062,
        //     strategies: s0,
        //     scaledShares: ss2
        // });
        ss0[0] = 1735001000000000000000000;
        w[0] = Withdrawal({
            staker: 0xb814C334748dc8D12145b009020e2783624c0775,
            delegatedTo: 0xDcAE4FAf7C7d0f4A78abe147244c6e9d60cFD202,
            withdrawer: 0xb814C334748dc8D12145b009020e2783624c0775,
            nonce: 11,
            startBlock: 22378804,
            strategies: s0,
            scaledShares: ss0
        });

        address[][] memory tokens = new address[][](1);
        tokens[0] = new address[](1);
        // tokens[1] = new address[](1);
        // tokens[2] = new address[](1);

        tokens[0][0] = 0xec53bF9167f50cDEB3Ae105f56099aaaB9061F83;
        // tokens[1][0] = 0xec53bF9167f50cDEB3Ae105f56099aaaB9061F83;
        // tokens[2][0] = 0xec53bF9167f50cDEB3Ae105f56099aaaB9061F83;

        bool[] memory receiveAsTokens = new bool[](1);
        receiveAsTokens[0] = true;
        // receiveAsTokens[1] = true;
        // receiveAsTokens[2] = true;

        bytes memory d = abi.encodeWithSelector(0x9435bb43, w, tokens, receiveAsTokens);

        bytes memory executeData = abi.encodeWithSelector(0xb61d27f6, 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A, 0, d);

        console.log("PEPPERPEPPE");
        console.logBytes(executeData);

        // uint256[] memory shares = new uint256[](1);
        // shares[0] = 1735001000000000000000000;
        // QWP memory qwp = QWP({strategies: s0, shares: shares, deprecated: 0xb814C334748dc8D12145b009020e2783624c0775});
        // QWP[] memory qwps = new QWP[](1);
        // qwps[0] = qwp;

        // d = abi.encodeWithSelector(0x0dd8dd02, qwps);

        // executeData = abi.encodeWithSelector(0xb61d27f6, 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A, 0, d);

        // console.log("PEPPERPEPPE PART 2");
        // console.logBytes(executeData);

        require(false);
    }

    function testPauseAll() external {
        pauser.pauseAll();

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(MockPausable(address(pausables[i])).isPaused(), true, "MockPausable should be paused");
        }

        pauser.unpauseAll();

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(MockPausable(address(pausables[i])).isPaused(), false, "MockPausable should be unpaused");
        }
    }

    function testSenderPause() external {
        pauser.updateSenderToPausable(address(this), pausables[0]);

        pauser.senderPause();

        assertEq(MockPausable(address(pausables[0])).isPaused(), true, "MockPausable should be paused");

        pauser.senderUnpause();

        assertEq(MockPausable(address(pausables[0])).isPaused(), false, "MockPausable should be unpaused");
    }

    function testPauseSingle() external {
        pauser.pauseSingle(pausables[0]);

        assertEq(MockPausable(address(pausables[0])).isPaused(), true, "MockPausable should be paused");

        pauser.unpauseSingle(pausables[0]);

        assertEq(MockPausable(address(pausables[0])).isPaused(), false, "MockPausable should be unpaused");
    }

    function testPauseMultiple() external {
        pauser.pauseMultiple(pausables);

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(MockPausable(address(pausables[i])).isPaused(), true, "MockPausable should be paused");
        }

        pauser.unpauseMultiple(pausables);

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(MockPausable(address(pausables[i])).isPaused(), false, "MockPausable should be unpaused");
        }
    }

    function testGetPausables() external view {
        IPausable[] memory _pausables = pauser.getPausables();

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(address(_pausables[i]), address(pausables[i]), "Pausables should be equal");
        }
    }

    function testUpdateSenderToPausable() external {
        pauser.updateSenderToPausable(address(this), pausables[0]);

        IPausable pausable = pauser.senderToPausable(address(this));

        assertEq(address(pausable), address(pausables[0]), "Pausables should be equal");
    }

    function testUpdatePausables() external {
        MockPausable newPausable = new MockPausable();

        pauser.addPausable(newPausable);

        pauser.removePausable(0);
        pauser.removePausable(1);
        pauser.removePausable(1);

        IPausable[] memory _pausables = pauser.getPausables();

        assertEq(_pausables.length, 1, "Pausables length should be 1");
        assertEq(address(_pausables[0]), address(newPausable), "Pausables should be equal");

        // Try removing an out of bounds index.
        vm.expectRevert(bytes(abi.encodeWithSelector(Pauser.Pauser__IndexOutOfBounds.selector)));
        pauser.removePausable(1);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
