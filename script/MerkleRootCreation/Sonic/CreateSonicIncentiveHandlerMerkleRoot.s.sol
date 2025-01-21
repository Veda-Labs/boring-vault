
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateSonicIncentiveHandlerMerkleRoot.s.sol:CreateSonicIncentiveHandlerMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateSonicIncentiveHandlerMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x6974778fccA17b42Af410628dEBe04BCF41c2280;
    address public managerAddress = 0x4A2B0a33e57d9eDb2A0851Ec38FB84121E16A7c7;
    address public accountantAddress = address(69);
    address public rawDataDecoderAndSanitizer = 0x668cbc7900c25Bac66Dc4500D295CD229420136A;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Fee and Yield Claiming ==========================
            //scUSD
            ERC20[] memory scUSDFeeAssets = new ERC20[](1); 
            scUSDFeeAssets[0] = getERC20(sourceChain, "USDC"); 
            _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "scUSDAccountant"), scUSDFeeAssets, true); //true to claim yield

            //scETH
            ERC20[] memory scETHFeeAssets = new ERC20[](1); 
            scETHFeeAssets[0] = getERC20(sourceChain, "WETH"); 
            _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "scETHAccountant"), scETHFeeAssets, true); //true to claim yield
        
        // ========================== Tellers ==========================
            ERC20[] memory tellerAssetsUSD = new ERC20[](1);
            tellerAssetsUSD[0] = getERC20(sourceChain, "USDC");
            _addTellerLeafs(leafs, getAddress(sourceChain, "scUSDTeller"), tellerAssetsUSD);

            ERC20[] memory tellerAssetsETH = new ERC20[](1);
            tellerAssetsETH[0] = getERC20(sourceChain, "WETH");
            _addTellerLeafs(leafs, getAddress(sourceChain, "scETHTeller"), tellerAssetsETH);

        // ========================== Rings Voter Contracts ==========================
            //scUSD Voter
            _addRingsVoterLeafs(leafs, getAddress(sourceChain, "scUSDVoter"), getERC20(sourceChain, "scUSD"));  

            //scETH Voter
            _addRingsVoterLeafs(leafs, getAddress(sourceChain, "scETHVoter"), getERC20(sourceChain, "scETH")); 


        // ========================== Veriy and Run ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/SonicIncentiveHandlerLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}

