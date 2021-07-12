pragma solidity 0.4.17;
//MintyDEFI2 is optimized for low gas usage and security
library SafeMath {
	function add(uint x, uint y) internal pure returns (uint z) {
		require((z = x + y) >= x);
	}

	function sub(uint x, uint y) internal pure returns (uint z) {
		require((z = x - y) <= x);
	}

	function mul(uint x, uint y) internal pure returns (uint z) {
		require(y == 0 || (z = x * y) / y == x);
	}
	function min(uint x, uint y) internal pure returns (uint z) {
		z = x < y ? x : y;
	}
	function sqrt(uint y) internal pure returns (uint z) {
		if (y > 3) {
			z = y;
			uint x = y / 2 + 1;
			while (x < z) {
				z = x;
				x = (y / x + x) / 2;
			}
		} else if (y != 0) {
			z = 1;
		}
	}
}
/**
 * @dev Interface of the ERC777Token standard as defined in the EIP.
 *
 * This contract uses the
 * [ERC1820 registry standard](https://eips.ethereum.org/EIPS/eip-1820) to let
 * token holders and recipients react to token movements by using setting implementers
 * for the associated interfaces in said registry. See `IERC1820Registry` and
 * `ERC1820Implementer`.
 */

contract IERC223 {
	/**
	 * @dev Returns the total supply of the token.
	 */
	function totalSupply() external view returns (uint);
	
	/**
	 * @dev Returns the balance of the `who` address.
	 */
	function balanceOf(address who) public view returns (uint);
		
	/**
	 * @dev Transfers `value` tokens from `msg.sender` to `to` address
	 * and returns `true` on success.
	 */
	function transfer(address to, uint value) public returns (bool success);
		
	/**
	 * @dev Transfers `value` tokens from `msg.sender` to `to` address with `data` parameter
	 * and returns `true` on success.
	 */
	function transfer(address to, uint value, bytes memory data) public returns (bool success);
	 
	 /**
	 * @dev Event that is fired on successful transfer.
	 */
	event Transfer(address indexed from, address indexed to, uint value, bytes data);
}
contract IERC223MintableBurnable is IERC223{
	function mint(address account, uint256 amount) external;
	function burn(uint256 _amount) external;
}
contract IMintyDEFI2PairAccount{
	function withdrawToken0(address to, uint256 value) external;
	function withdrawToken1(address to, uint256 value) external;
}
/**
 * @title Contract that will work with ERC223 tokens.
 */
 
contract IERC223Recipient { 
/**
 * @dev Standard ERC223 function that will handle incoming token transfers.
 *
 * @param _from  Token sender address.
 * @param _value Amount of tokens.
 * @param _data  Transaction metadata.
 */
	function tokenFallback(address _from, uint _value, bytes memory _data) public;
}
contract MintyDEFI2PairAccount is IERC223Recipient, IERC223MintableBurnable, IMintyDEFI2PairAccount{
	using SafeMath for uint;
	uint256 private _totalSupply;
	//Using Dexaran's ERC-223 implementation
	/**
	 * @dev Returns true if `account` is a contract.
	 *
	 * This test is non-exhaustive, and there may be false-negatives: during the
	 * execution of a contract's constructor, its address will be reported as
	 * not containing a contract.
	 *
	 * > It is unsafe to assume that an address for which this function returns
	 * false is an externally-owned account (EOA) and not a contract.
	 */
	function isContract(address account) internal view returns (bool) {
		// This method relies in extcodesize, which returns 0 for contracts in
		// construction, since the code is only stored at the end of the
		// constructor execution.

		uint256 size;
		// solhint-disable-next-line no-inline-assembly
		assembly { size := extcodesize(account) }
		return size > 0;
	}

	/**
	 * @dev See `IERC223.totalSupply`.
	 */
	function totalSupply() external view returns (uint256) {
		return _totalSupply;
	}

	mapping(address => uint) balances; // List of user balances.
	
	/**
	 * @dev Transfer the specified amount of tokens to the specified address.
	 *	  Invokes the `tokenFallback` function if the recipient is a contract.
	 *	  The token transfer fails if the recipient is a contract
	 *	  but does not implement the `tokenFallback` function
	 *	  or the fallback function to receive funds.
	 *
	 * @param _to	Receiver address.
	 * @param _value Amount of tokens that will be transferred.
	 * @param _data  Transaction metadata.
	 */
	function transfer(address _to, uint _value, bytes memory _data) public returns (bool success){
		// Standard function transfer similar to ERC20 transfer with no _data .
		// Added due to backwards compatibility reasons .
		require(_to != address(0));
		balances[msg.sender] = balances[msg.sender].sub(_value);
		balances[_to] = balances[_to].add(_value);
		if(isContract(_to)) {
			IERC223Recipient receiver = IERC223Recipient(_to);
			receiver.tokenFallback(msg.sender, _value, _data);
		}
		Transfer(msg.sender, _to, _value, _data);
		return true;
	}
	
	/**
	 * @dev Transfer the specified amount of tokens to the specified address.
	 *	  This function works the same with the previous one
	 *	  but doesn't contain `_data` param.
	 *	  Added due to backwards compatibility reasons.
	 *
	 * @param _to	Receiver address.
	 * @param _value Amount of tokens that will be transferred.
	 */
	function transfer(address _to, uint _value) public returns (bool success){
		require(_to != address(0));
		bytes memory empty = hex"00000000";
		balances[msg.sender] = balances[msg.sender].sub(_value);
		balances[_to] = balances[_to].add(_value);
		if(isContract(_to)) {
			IERC223Recipient receiver = IERC223Recipient(_to);
			receiver.tokenFallback(msg.sender, _value, empty);
		}
		Transfer(msg.sender, _to, _value, empty);
		return true;
	}

	
	/**
	 * @dev Returns balance of the `_owner`.
	 *
	 * @param _owner   The address whose balance will be returned.
	 * @return balance Balance of the `_owner`.
	 */
	function balanceOf(address _owner) public view returns (uint balance) {
		return balances[_owner];
	}
	
	//BEGIN MintyDEFI2 implementation
	address private token0;
	address private token1;
	address private factory;
	function tokenFallback(address _from, uint _value, bytes memory _data) public{
		require(msg.sender == token0 || msg.sender == token1);
	}
	function withdrawToken0(address to, uint256 value) external{
		require(msg.sender == factory);
		require(IERC223(token0).transfer(to, value));
	}
	function withdrawToken1(address to, uint256 value) external{
		require(msg.sender == factory);
		require(IERC223(token0).transfer(to, value));
	}
	function MintyDEFI2PairAccount(address _token0, address _token1) public{
		token0 = _token0;
		token1 = _token1;
		factory = msg.sender;
	}
	function mint(address account, uint256 amount) external {
		require(msg.sender == factory && account != address(0));
		balances[account] = balances[account].add(amount);
		_totalSupply = _totalSupply.add(amount);
		if(isContract(account)) {
			IERC223Recipient receiver = IERC223Recipient(account);
			receiver.tokenFallback(address(0), amount, hex"00000000");
		}
		Transfer(address(0),account, amount, hex"00000000");
	}
	function burn(uint256 _amount) external {
		balances[msg.sender] = balances[msg.sender].sub(_amount);
		_totalSupply = _totalSupply.sub(_amount);
		Transfer(msg.sender, address(0), _amount, hex"00000000");
	}
}
interface IERC20 {
	event Approval(address indexed owner, address indexed spender, uint value);
	event Transfer(address indexed from, address indexed to, uint value);

	function name() external view returns (string memory);
	function symbol() external view returns (string memory);
	function decimals() external view returns (uint8);
	function totalSupply() external view returns (uint);
	function balanceOf(address owner) external view returns (uint);
	function allowance(address owner, address spender) external view returns (uint);

	function approve(address spender, uint value) external returns (bool);
	function transfer(address to, uint value) external returns (bool);
	function transferFrom(address from, address to, uint value) external returns (bool);
}
contract IMintyDEFI2Factory is IERC223Recipient{
	function createPair(address tokenA, address tokenB) external;
	function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint amountOut);
	function quote(uint amountA, uint reserveA, uint reserveB) public pure returns (uint amountB);
	function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired) external returns (uint amountA, uint amountB);
	function safeTransferFrom2(address token, address to, uint amount) public;
	function precalculate(address fromToken, address toToken, uint amountIn) external view returns (uint256);
	function swap(address fromToken, address toToken, uint amountIn) external;
	function getPair(address tokenA, address tokenB) external view returns (address);
	event Swap(address indexed sender, address indexed from, address indexed to, uint256 amountIn);
	event LiquidityMint(address indexed sender, address indexed tokenA, address indexed tokenB, uint256 liquidity);
	event LiquidityBurn(address indexed sender, address indexed tokenA, address indexed tokenB, uint256 liquidity);
}
contract MintyDEFI2Factory is IMintyDEFI2Factory{
	using SafeMath for uint256;
	mapping (address => mapping (address => address)) private pairAccounts;
	mapping (address => address) private Token0;
	mapping (address => address) private Token1;
	function createPair(address tokenA, address tokenB) external{
		require(tokenA != tokenB && tokenA != address(0) && pairAccounts[tokenA][tokenB] == address(0));
		address pair;
		if(tokenA < tokenB){
			pair = new MintyDEFI2PairAccount(tokenA, tokenB);
			Token0[pair] = tokenA;
			Token1[pair] = tokenB;
		} else{
			pair = new MintyDEFI2PairAccount(tokenB, tokenA);
			Token0[pair] = tokenB;
			Token1[pair] = tokenA;
		}
		pairAccounts[tokenA][tokenB] = pair;
		pairAccounts[tokenB][tokenA] = pair;
	}
	function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint amountOut) {
		require(amountIn > 0);
		require(reserveIn > 0 && reserveOut > 0);
		uint256 amountInWithFee = amountIn.mul(997);
		uint256 numerator = amountInWithFee.mul(reserveOut);
		uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
		amountOut = numerator / denominator;
	}
	// given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
	function quote(uint amountA, uint reserveA, uint reserveB) public pure returns (uint amountB) {
		require(amountA > 0);
		require(reserveA > 0 && reserveB > 0);
		amountB = amountA.mul(reserveB) / reserveA;
	}
	uint256 private mutex = 1;
	function addLiquidity(
		address tokenA,
		address tokenB,
		uint amountADesired,
		uint amountBDesired
	) external returns (uint amountA, uint amountB) {
		require(mutex == 1);
		mutex = 0;
		address pair = pairAccounts[tokenA][tokenB];
		uint256 reserveA = 0;
		uint256 reserveB = 0;
		if(pair == address(0)){
			if(tokenA < tokenB){
				pair = new MintyDEFI2PairAccount(tokenA, tokenB);
			} else{
				pair = new MintyDEFI2PairAccount(tokenB, tokenA);
			}
			(amountA, amountB) = (amountADesired, amountBDesired);
		} else{
			reserveA = IERC20(tokenA).balanceOf(pair);
			reserveB = IERC20(tokenB).balanceOf(pair);
			if (reserveA == 0 && reserveB == 0) {
				(amountA, amountB) = (amountADesired, amountBDesired);
			} else {
				uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
				if (amountBOptimal <= amountBDesired) {
					(amountA, amountB) = (amountADesired, amountBOptimal);
				} else {
					uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
					require(amountAOptimal <= amountADesired);
					(amountA, amountB) = (amountAOptimal, amountBDesired);
				}
			}
		}
		uint256 totalSupply = IERC223(pair).totalSupply();
		uint256 liquidity;
		if (totalSupply == 0) {
			liquidity = amountA.mul(amountB).sqrt().sub(1000);
			IERC223MintableBurnable(pair).mint(address(1), 1000);
		} else {
			liquidity = (amountA.mul(totalSupply) / reserveA).min(amountB.mul(totalSupply) / reserveB);
		}
		safeTransferFrom2(tokenA, pair, amountA);
		safeTransferFrom2(tokenB, pair, amountB);
		mutex = 1;
		IERC223MintableBurnable(pair).mint(msg.sender, liquidity);
		if(tokenA < tokenB){
			LiquidityMint(msg.sender, tokenA, tokenB, liquidity);
		} else{
			LiquidityMint(msg.sender, tokenB, tokenA, liquidity);
		}
	}
	function safeTransferFrom2(address token, address to, uint amount) public{
		IERC20 erc20 = IERC20(token);
		require(erc20.transferFrom(msg.sender, to, amount));
	}
	function precalculate(address fromToken, address toToken, uint amountIn) external view returns (uint256){
		address pair = pairAccounts[fromToken][toToken];
		require(pair != address(0));
		return getAmountOut(amountIn, IERC223(fromToken).balanceOf(pair), IERC223(toToken).balanceOf(pair));
	}
	function swap(address fromToken, address toToken, uint amountIn) external{
		require(mutex == 1);
		mutex = 0;
		address pair = pairAccounts[fromToken][toToken];
		require(pair != address(0));
		uint256 amountOut = getAmountOut(amountIn, IERC223(fromToken).balanceOf(pair), IERC223(toToken).balanceOf(pair));
		safeTransferFrom2(fromToken, pair, amountIn);
		if(fromToken < toToken){
			IMintyDEFI2PairAccount(pair).withdrawToken0(msg.sender, amountOut);
		} else{
			IMintyDEFI2PairAccount(pair).withdrawToken1(msg.sender, amountOut);
		}
		mutex = 1;
	}
	function tokenFallback(address _from, uint _value, bytes memory _data) public {
		require(mutex == 1);
		mutex = 0;
		address token0 = Token0[msg.sender];
		require(token0 != address(0));
		address token1 = Token1[msg.sender];
		uint totalSupply = IERC223(msg.sender).totalSupply();
		require(totalSupply != 0);
		IMintyDEFI2PairAccount(msg.sender).withdrawToken0(_from, _value.mul(IERC20(token0).balanceOf(msg.sender)) / totalSupply);
		IMintyDEFI2PairAccount(msg.sender).withdrawToken1(_from, _value.mul(IERC20(token1).balanceOf(msg.sender)) / totalSupply);
		mutex = 1;
		IERC223MintableBurnable(msg.sender).burn(_value);
		LiquidityBurn(msg.sender, token0, token1, _value);

	}
	function getPair(address tokenA, address tokenB) external view returns (address){
		return pairAccounts[tokenA][tokenB];
	}
}
