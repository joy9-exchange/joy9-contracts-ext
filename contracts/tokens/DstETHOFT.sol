// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../libraries/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./oft/OFT.sol";
import "./interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DstETHOFT is OFT, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool public isInitialized;

    address public weth;

    event Deposit(address indexed _dst, uint _amount);
    event Withdrawal(address indexed _src, uint _amount);

    constructor(string memory _name, string memory _symbol, address _lzEndpoint) OFT(_name, _symbol, _lzEndpoint) {}

    function initialize(
        address _weth
    ) external onlyOwner {
        require(!isInitialized, "DstETHOFT: already initialized");
        isInitialized = true;

        weth = _weth;

        //TODO mint oft token to DepositHandler
    }

    function sendFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) public payable virtual override(OFTCore, IOFTCore) {
        revert("no support!");
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint _amount) public nonReentrant {
        require(balanceOf(msg.sender) >= _amount, "DstETHOFT: Insufficient balance.");
        _burn(msg.sender, _amount);
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "DstETHOFT: failed to unwrap");
        emit Withdrawal(msg.sender, _amount);
    }

    function depositWETH(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Transfer amount must be greater than zero");
		require(IERC20(weth).balanceOf(msg.sender) >= _amount, "DstETHOFT: Insufficient balance.");
		
    	IERC20(weth).transferFrom(msg.sender, address(this), _amount);
    	IWETH(weth).withdraw(_amount);

        _mint(msg.sender, _amount);
    }

	function withdrawWETH(uint256 _amount) external nonReentrant {
		require(_amount > 0, "Transfer amount must be greater than zero");
		require(balanceOf(msg.sender) >= _amount, "DstETHOFT: Insufficient balance.");
	    
		_burn(msg.sender, _amount);
		
        IWETH(weth).deposit{value: _amount}();
		IWETH(weth).transfer(msg.sender, _amount);
	}

    function _creditTo(uint16, address _toAddress, uint _amount) internal virtual override returns(uint) {
        _mint(_toAddress, _amount);
        return _amount;
    }

    receive() external payable {
        deposit();
    }
}
