// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./oft/OFT.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DstERC20OFT is OFT, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 internal immutable innerToken;

    constructor(string memory _name, string memory _symbol, address _token, address _lzEndpoint) OFT(_name, _symbol, _lzEndpoint) {
        innerToken = IERC20(_token);
    }

    function circulatingSupply() public view virtual override returns (uint) {
        unchecked {
            return innerToken.totalSupply() - innerToken.balanceOf(address(this));
        }
    }

    function token() public view virtual override returns (address) {
        return address(innerToken);
    }

    function sendFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) public payable virtual override(OFTCore, IOFTCore) {
        revert("no support!");
    }
    
    function depositERC20(uint256 _amount) external nonReentrant {
        require(_amount > 0, "DstERC20OFT: Transfer amount must be greater than zero");
		require(innerToken.balanceOf(msg.sender) >= _amount, "DstERC20OFT: Insufficient balance.");
		
    	innerToken.safeTransferFrom(msg.sender, address(this), _amount);
    	
        _mint(msg.sender, _amount);
    }

	function withdrawERC20(uint256 _amount) external nonReentrant {
		require(_amount > 0, "DstERC20OFT: Transfer amount must be greater than zero");
		require(balanceOf(msg.sender) >= _amount, "DstERC20OFT: Insufficient balance.");
	    
		_burn(msg.sender, _amount);
		
		innerToken.safeTransfer(msg.sender, _amount);
	}

    function _debitFrom(address _from, uint16, bytes memory, uint _amount) internal virtual override returns(uint) {
        require(_from == _msgSender(), "DstERC20OFT: owner is not send caller");
        uint before = innerToken.balanceOf(address(this));
        innerToken.safeTransferFrom(_from, address(this), _amount);
        return innerToken.balanceOf(address(this)) - before;
    }

    function _creditTo(uint16, address _toAddress, uint _amount) internal virtual override returns(uint) {
        uint before = innerToken.balanceOf(_toAddress);
        innerToken.safeTransfer(_toAddress, _amount);
        return innerToken.balanceOf(_toAddress) - before;
    }
}
