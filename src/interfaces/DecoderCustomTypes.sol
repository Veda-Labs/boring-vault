// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;
contract DecoderCustomTypes {
    // ========================================= BALANCER =========================================
    struct JoinPoolRequest {
        address[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct ExitPoolRequest {
        address[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address recipient;
        bool toInternalBalance;
    }

    // ========================================= UNISWAP V3 =========================================

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactInputParamsRouter02 {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct PancakeSwapExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    // ========================================= UNISWAP V4 =========================================
    
    struct SwapParams {
        /// Whether to swap token0 for token1 or vice versa
        bool zeroForOne;
        /// The desired input amount if negative (exactIn), or the desired output amount if positive (exactOut)
        int256 amountSpecified;
        /// The sqrt price at which, if reached, the swap will stop executing
        uint160 sqrtPriceLimitX96;
    }

    struct PoolKey {
        /// @notice The lower currency of the pool, sorted numerically
        address currency0;
        /// @notice The higher currency of the pool, sorted numerically
        address currency1;
        /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
        uint24 fee;
        /// @notice Ticks that involve positions must be a multiple of tick spacing
        int24 tickSpacing;
        /// @notice The hooks of the pool
        address hooks;
    }

    /// @dev comes from IV4 Router
    struct ExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        bytes hookData;
    }

     /// @notice Parameters for a single-hop exact-output swap
    struct ExactOutputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountOut;
        uint128 amountInMaximum;
        bytes hookData;
    }


    // ========================================= MORPHO BLUE =========================================

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    // ========================================= 1INCH =========================================

    struct SwapDescription {
        address srcToken;
        address dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    // ========================================= PENDLE =========================================
    struct TokenInput {
        // TOKEN DATA
        address tokenIn;
        uint256 netTokenIn;
        address tokenMintSy;
        // AGGREGATOR DATA
        address pendleSwap;
        SwapData swapData;
    }

    struct TokenOutput {
        // TOKEN DATA
        address tokenOut;
        uint256 minTokenOut;
        address tokenRedeemSy;
        // AGGREGATOR DATA
        address pendleSwap;
        SwapData swapData;
    }

    struct ApproxParams {
        uint256 guessMin;
        uint256 guessMax;
        uint256 guessOffchain; // pass 0 in to skip this variable
        uint256 maxIteration; // every iteration, the diff between guessMin and guessMax will be divided by 2
        uint256 eps; // the max eps between the returned result & the correct result, base 1e18. Normally this number will be set
            // to 1e15 (1e18/1000 = 0.1%)
    }

    struct SwapData {
        SwapType swapType;
        address extRouter;
        bytes extCalldata;
        bool needScale;
    }

    enum SwapType {
        NONE,
        KYBERSWAP,
        ONE_INCH,
        // ETH_WETH not used in Aggregator
        ETH_WETH
    }

    struct LimitOrderData {
        address limitRouter;
        uint256 epsSkipMarket; // only used for swap operations, will be ignored otherwise
        FillOrderParams[] normalFills;
        FillOrderParams[] flashFills;
        bytes optData;
    }

    struct FillOrderParams {
        Order order;
        bytes signature;
        uint256 makingAmount;
    }

    struct Order {
        uint256 salt;
        uint256 expiry;
        uint256 nonce;
        OrderType orderType;
        address token;
        address YT;
        address maker;
        address receiver;
        uint256 makingAmount;
        uint256 lnImpliedRate;
        uint256 failSafeRate;
        bytes permit;
    }

    enum OrderType {
        SY_FOR_PT,
        PT_FOR_SY,
        SY_FOR_YT,
        YT_FOR_SY
    }

    // ========================================= EIGEN LAYER =========================================

    struct QueuedWithdrawalParams {
        // Array of strategies that the QueuedWithdrawal contains
        address[] strategies;
        // Array containing the amount of shares in each Strategy in the `strategies` array
        uint256[] shares;
        // The address of the withdrawer
        address withdrawer;
    }

    struct Withdrawal {
        // The address that originated the Withdrawal
        address staker;
        // The address that the staker was delegated to at the time that the Withdrawal was created
        address delegatedTo;
        // The address that can complete the Withdrawal + will receive funds when completing the withdrawal
        address withdrawer;
        // Nonce used to guarantee that otherwise identical withdrawals have unique hashes
        uint256 nonce;
        // Block number when the Withdrawal was created
        uint32 startBlock;
        // Array of strategies that the Withdrawal contains
        address[] strategies;
        // Array containing the amount of shares in each Strategy in the `strategies` array
        uint256[] shares;
    }

    struct SignatureWithExpiry {
        // the signature itself, formatted as a single bytes object
        bytes signature;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    struct EarnerTreeMerkleLeaf {
        address earner;
        bytes32 earnerTokenRoot;
    }

    struct TokenTreeMerkleLeaf {
        address token;
        uint256 cumulativeEarnings;
    }

    struct RewardsMerkleClaim {
        uint32 rootIndex;
        uint32 earnerIndex;
        bytes earnerTreeProof;
        EarnerTreeMerkleLeaf earnerLeaf;
        uint32[] tokenIndices;
        bytes[] tokenTreeProofs;
        TokenTreeMerkleLeaf[] tokenLeaves;
    }

    // ========================================= CCIP =========================================

    // If extraArgs is empty bytes, the default is 200k gas limit.
    struct EVM2AnyMessage {
        bytes receiver; // abi.encode(receiver address) for dest EVM chains
        bytes data; // Data payload
        EVMTokenAmount[] tokenAmounts; // Token transfers
        address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
    }

    /// @dev RMN depends on this struct, if changing, please notify the RMN maintainers.
    struct EVMTokenAmount {
        address token; // token address on the local chain.
        uint256 amount; // Amount of tokens.
    }

    struct EVMExtraArgsV1 {
        uint256 gasLimit;
    }

    // ========================================= OFT =========================================

    struct SendParam {
        uint32 dstEid; // Destination endpoint ID.
        bytes32 to; // Recipient address.
        uint256 amountLD; // Amount to send in local decimals.
        uint256 minAmountLD; // Minimum amount to send in local decimals.
        bytes extraOptions; // Additional options supplied by the caller to be used in the LayerZero message.
        bytes composeMsg; // The composed message for the send() operation.
        bytes oftCmd; // The OFT command to be executed, unused in default OFT implementations.
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }
    // ========================================= L1StandardBridge =========================================

    struct WithdrawalTransaction {
        uint256 nonce;
        address sender;
        address target;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    struct OutputRootProof {
        bytes32 version;
        bytes32 stateRoot;
        bytes32 messagePasserStorageRoot;
        bytes32 latestBlockhash;
    }

    // ========================================= Mantle L1StandardBridge =========================================

    struct MantleWithdrawalTransaction {
        uint256 nonce;
        address sender;
        address target;
        uint256 mntValue;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    // ========================================= Linea Bridge =========================================

    struct ClaimMessageWithProofParams {
        bytes32[] proof;
        uint256 messageNumber;
        uint32 leafIndex;
        address from;
        address to;
        uint256 fee;
        uint256 value;
        address payable feeRecipient;
        bytes32 merkleRoot;
        bytes data;
    }

    // ========================================= Scroll Bridge =========================================

    struct L2MessageProof {
        uint256 batchIndex;
        bytes merkleProof;
    }

    // ========================================= Camelot V3 / Algebra V3  =========================================

    struct CamelotMintParams {
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    // ========================================= Algebra V4 =========================================
    
    struct AlgebraMintParams {
        address token0;
        address token1;
        address deployer;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    // ========================================= Velodrome V3 =========================================

    struct VelodromeMintParams {
        address token0;
        address token1;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
        uint160 sqrtPriceX96;
    }

    // ========================================= Karak =========================================

    struct QueuedWithdrawal {
        address staker;
        address delegatedTo;
        uint256 nonce;
        uint256 start;
        WithdrawRequest request;
    }

    struct WithdrawRequest {
        address[] vaults;
        uint256[] shares;
        address withdrawer;
    }

    // ========================================= Term Finance ==================================

    /// @dev TermAuctionOfferSubmission represents an offer submission to offeror an amount of money for a specific interest rate
    struct TermAuctionOfferSubmission {
        /// @dev For an existing offer this is the unique onchain identifier for this offer. For a new offer this is a randomized input that will be used to generate the unique onchain identifier.
        bytes32 id;
        /// @dev The address of the offeror
        address offeror;
        /// @dev Hash of the offered price as a percentage of the initial loaned amount vs amount returned at maturity. This stores 9 decimal places
        bytes32 offerPriceHash;
        /// @dev The maximum amount of purchase tokens that can be lent
        uint256 amount;
        /// @dev The address of the ERC20 purchase token
        address purchaseToken;
    }

    // ========================================= Dolomite Finance ==================================

    enum BalanceCheckFlag {
        Both,
        From,
        To,
        None
    }

    // ========================================= Silo Finance ==================================
    /// @dev There are 2 types of accounting in the system: for non-borrowable collateral deposit called "protected" and
    ///      for borrowable collateral deposit called "collateral". System does
    ///      identical calculations for each type of accounting but it uses different data. To avoid code duplication
    ///      this enum is used to decide which data should be read.
    enum CollateralType {
        Protected, // default
        Collateral
    }

    enum ActionType {
        Deposit,
        Mint,
        Repay,
        RepayShares
    }

    struct Action {
        // what do you want to do?
        uint8 actionType;
        // which Silo are you interacting with?
        address silo;
        // what asset do you want to use?
        address asset;
        // options specific for actions
        bytes options;
    }

    struct AnyAction {
        // how much assets or shares do you want to use?
        uint256 amount;
        // are you using Protected, Collateral
        uint8 assetType;
    }

    // ========================================= LBTC Bridge ==================================
    struct DepositBridgeAction {
        uint256 fromChain;
        bytes32 fromContract;
        uint256 toChain;
        address toContract;
        address recipient;
        uint64 amount;
        uint256 nonce;
    }

    // ========================================= Odos ==================================
    
    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    struct swapTokenInfoOogaBooga {
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }
    // ========================================= Level ==================================
    
    /// @dev for reference 
    //enum OrderType {
    //    MINT,
    //    REDEEM
    //}
    
    struct LevelOrder {
        uint8 order_type;
        address benefactor;
        address beneficiary;
        address collateral_asset;
        uint256 collateral_amount;
        uint256 lvlusd_amount;
    }    

    struct LevelOrderV2 {
        address beneficiary;
        address collateral_asset;
        uint256 collateral_amount;
        uint256 min_lvlusd_amount;
    }

    struct Route {
        address[] addresses;
        uint256[] ratios;
    }


    // ========================================= Royco ==================================
    struct APOffer { // RecipeMarketHub
        uint256 offerID;
        bytes32 targetMarketHash;
        address ap;
        address fundingVault;
        uint256 quantity;
        uint256 expiry;
        address[] incentivesRequested;
        uint256[] incentiveAmountsRequested;
    }
    struct APOfferVault { // VaultMarketHub (renamed to avoid collision)
        uint256 offerID;
        address targetVault;
        address ap;
        address fundingVault;
        uint256 expiry;
        address[] incentivesRequested;
        uint256[] incentivesRatesRequested;
    }

    struct Reward {
        uint48 startEpoch;
        uint48 endEpoch;
        address token;
        uint256 rewardRate;
    }

    // ========================================= Permit2 ==================================
    
    struct TokenSpenderPair {
        address token; 
        address spender;
    }

    // ========================================= OnChainQueue ==================================
    
    struct OnChainWithdraw {
        uint96 nonce; // read from state, used to make it impossible for request Ids to be repeated.
        address user; // msg.sender
        address assetOut; // input sanitized
        uint128 amountOfShares; // input transfered in
        uint128 amountOfAssets; // derived from amountOfShares and price
        uint40 creationTime; // time withdraw was made
        uint24 secondsToMaturity; // in contract, from withdrawAsset?
        uint24 secondsToDeadline; // in contract, from withdrawAsset? To get the deadline you take the creationTime add seconds to maturity, add the secondsToDeadline
    }

    // ========================================= Beraborrow ==================================
    
    struct OpenDenVaultParams {
        address denManager;
        address collVault;
        uint256 _maxFeePercentage;
        uint256 _debtAmount;
        uint256 _collAssetToDeposit;
        address _upperHint;
        address _lowerHint;
        uint256 _minSharesMinted;
        uint256 _collIndex;
        bytes _preDeposit;
    }

    struct AdjustDenVaultParams {
        address denManager;
        address collVault;
        uint256 _maxFeePercentage;
        uint256 _collAssetToDeposit;
        uint256 _collWithdrawal;
        uint256 _debtChange;
        bool _isDebtIncrease;
        address _upperHint;
        address _lowerHint;
        bool unwrap;
        uint256 _minSharesMinted;
        uint256 _minAssetsWithdrawn;
        uint256 _collIndex;
        bytes _preDeposit;
    }

     struct RedeemCollateralVaultParams {
        address denManager;
        address collVault;
        uint256 _debtAmount;
        address _firstRedemptionHint;
        address _upperPartialRedemptionHint;
        address _lowerPartialRedemptionHint;
        uint256 _partialRedemptionHintNICR;
        uint256 _maxIterations;
        uint256 _maxFeePercentage;
        uint256 _minSharesWithdrawn;
        uint256 minAssetsWithdrawn;
        uint256 collIndex;
        bool unwrap;
    }

    struct AddCollParams {
        address upperHint;
        address lowerHint;
        uint256 minSharesOut;
        uint256 minCollVaultShares;
    }

    struct ExternalRebalanceParams {
        address swapper;
        bytes payload;
        uint256 minRebalanceOut;
    }

    // ========================================= Tac Crosschain Layer ==================================
    
    struct TokenAmount {
        address evmAddress;
        uint256 amount;
    }

    struct NFTAmount {
        address evmAddress;
        uint256 tokenId;
        uint256 amount;
    }

    struct OutMessageV1 {
        uint64 shardsKey;
        string tvmTarget;
        string tvmPayload;
        uint256 tvmProtocolFee;
        uint256 tvmExecutorFee;
        string[] tvmValidExecutors;
        TokenAmount[] toBridge;
        NFTAmount[] toBridgeNFT;
    }

    // ========================================= Valantis ==================================
    
    struct DirectSwapParams {
        bool[] isUniversalPool;
        address[] pools;
        uint256[] amountInSpecified;
        bytes[] payloads;
        bool isTokenOutEth;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 amountOutMin;
        uint256 deadline;
        bytes32 code;
    }    

    struct UniversalPoolSwapPayload {
        bool isZeroToOne;
        address recipient;
        int24 limitPriceTick;
        uint256 amountOutMin;
        uint8[] almOrdering;
        bytes[] externalContext;
        bytes swapFeeModuleContext;
    }

  /**
   * @notice Internal struct used for single swap payloads in Sovereign pools.
   */
  struct SovereignPoolSwapPayload {
      bool isZeroToOne;
      address recipient;
      address swapTokenOut;
      uint256 amountOutMin;
      bytes externalContext;
      bytes verificationContext;
      bytes swapFeeModuleContext;
  }

    struct SovereignPoolSwapContextData {
        bytes externalContext;
        bytes verifierContext;
        bytes swapCallbackContext;
        bytes swapFeeModuleContext;
    }

    struct SovereignPoolSwapParams {
        bool isSwapCallback;
        bool isZeroToOne;
        uint256 amountIn;
        uint256 amountOutMin;
        uint256 deadline;
        address recipient;
        address swapTokenOut;
        SovereignPoolSwapContextData swapContext;
    }

    struct UniversalSwapParams {
        bool isZeroToOne;
        bool isSwapCallback;
        int24 limitPriceTick;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMin;
        uint256 deadline;
        bytes swapCallbackContext;
        bytes swapFeeModuleContext;
        uint8[] almOrdering;
        bytes[] externalContext;
    }

    // ========================================= Ethena Minting ==================================
    enum EthenaOrderType {
        MINT,
        REDEEM
    }
    
    struct EthenaOrder {
        string order_id;
        EthenaOrderType order_type;
        uint120 expiry;
        uint128 nonce;
        address benefactor;
        address beneficiary;
        address collateral_asset;
        uint128 collateral_amount;
        uint128 usde_amount;
    }

    struct EthenaRoute {
        address[] addresses;
        uint128[] ratios;
    }
    
    enum SignatureType {
        EIP712,
        EIP1271
    }

    struct EthenaSignature {
        SignatureType signature_type;
        bytes signature_bytes;
    }

    // ========================================= GlueX ==================================

    struct Interaction {
        address target;
        uint256 value;
        bytes callData;
    }
    
    struct RouteDescription {
        address inputToken; // Token used as input for the route
        address outputToken; // Token received as output from the route
        address payable inputReceiver; // Address to receive the input token
        address payable outputReceiver; // Address to receive the output token
        address payable partnerAddress; // Address of the partner receiving surplus share
        uint256 inputAmount; // Amount of input token
        uint256 outputAmount; // Optimizer output amount
        uint256 partnerFee; // Fee charged by the partner
        uint256 routingFee; // Fee charged for routing operation
        uint256 partnerSurplusShare; // Percentage (in bps) of surplus shared with the partner
        uint256 protocolSurplusShare; // Percentage (in bps) of surplus shared with GlueX
        uint256 partnerSlippageShare; // Percentage (in bps) of slippage shared with the partner
        uint256 protocolSlippageShare; // Percentage (in bps) of slippage shared with GlueX
        uint256 effectiveOutputAmount; // Effective output amount for the user
        uint256 minOutputAmount; // Minimum acceptable output amount
        bool isPermit2; // Whether to use Permit2 for token transfers
        bytes32 uniquePID; // Unique identifier for the partner
    }

}
