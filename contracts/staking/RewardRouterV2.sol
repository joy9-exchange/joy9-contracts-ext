// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../libraries/utils/Address.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IVester.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
import "../access/Governable.sol";

contract RewardRouterV2 is ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public weth;

    address public joy9;
    address public esJoy9;
    address public bnJoy9;

    address public stakedJoy9Tracker;
    address public bonusJoy9Tracker;
    address public feeJoy9Tracker;

    address public joy9Vester;

    mapping (address => address) public pendingReceivers;

    event StakeJoy9(address account, address token, uint256 amount);
    event UnstakeJoy9(address account, address token, uint256 amount);

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }

    function initialize(
        address _weth,
        address _joy9,
        address _esJoy9,
        address _bnJoy9,
        address _stakedJoy9Tracker,
        address _bonusJoy9Tracker,
        address _feeJoy9Tracker,
        address _joy9Vester
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        weth = _weth;

        joy9 = _joy9;
        esJoy9 = _esJoy9;
        bnJoy9 = _bnJoy9;

        stakedJoy9Tracker = _stakedJoy9Tracker;
        bonusJoy9Tracker = _bonusJoy9Tracker;
        feeJoy9Tracker = _feeJoy9Tracker;

        joy9Vester = _joy9Vester;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeJoy9ForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyGov {
        address _joy9 = joy9;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeJoy9(msg.sender, _accounts[i], _joy9, _amounts[i]);
        }
    }

    function stakeJoy9ForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeJoy9(msg.sender, _account, joy9, _amount);
    }

    function stakeJoy9(uint256 _amount) external nonReentrant {
        _stakeJoy9(msg.sender, msg.sender, joy9, _amount);
    }

    function stakeEsJoy9(uint256 _amount) external nonReentrant {
        _stakeJoy9(msg.sender, msg.sender, esJoy9, _amount);
    }

    function unstakeJoy9(uint256 _amount) external nonReentrant {
        _unstakeJoy9(msg.sender, joy9, _amount, true);
    }

    function unstakeEsJoy9(uint256 _amount) external nonReentrant {
        _unstakeJoy9(msg.sender, esJoy9, _amount, true);
    }

    function claim() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeJoy9Tracker).claimForAccount(account, account);

        IRewardTracker(stakedJoy9Tracker).claimForAccount(account, account);
    }

    function claimEsJoy9() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedJoy9Tracker).claimForAccount(account, account);
    }

    function claimFees() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeJoy9Tracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(address _account) external nonReentrant onlyGov {
        _compound(_account);
    }

    function handleRewards(
        bool _shouldClaimJoy9,
        bool _shouldStakeJoy9,
        bool _shouldClaimEsJoy9,
        bool _shouldStakeEsJoy9,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external nonReentrant {
        address account = msg.sender;

        uint256 joy9Amount = 0;
        if (_shouldClaimJoy9) {
            joy9Amount = IVester(joy9Vester).claimForAccount(account, account);
        }

        if (_shouldStakeJoy9 && joy9Amount > 0) {
            _stakeJoy9(account, account, joy9, joy9Amount);
        }

        uint256 esJoy9Amount = 0;
        if (_shouldClaimEsJoy9) {
            esJoy9Amount = IRewardTracker(stakedJoy9Tracker).claimForAccount(account, account);
        }

        if (_shouldStakeEsJoy9 && esJoy9Amount > 0) {
            _stakeJoy9(account, account, esJoy9, esJoy9Amount);
        }

        if (_shouldStakeMultiplierPoints) {
            uint256 bnJoy9Amount = IRewardTracker(bonusJoy9Tracker).claimForAccount(account, account);
            if (bnJoy9Amount > 0) {
                IRewardTracker(feeJoy9Tracker).stakeForAccount(account, account, bnJoy9, bnJoy9Amount);
            }
        }

        if (_shouldClaimWeth) {
            if (_shouldConvertWethToEth) {
                uint256 weth0 = IRewardTracker(feeJoy9Tracker).claimForAccount(account, address(this));
                uint256 wethAmount = weth0;
                IWETH(weth).withdraw(wethAmount);

                payable(account).sendValue(wethAmount);
            } else {
                IRewardTracker(feeJoy9Tracker).claimForAccount(account, account);
            }
        }
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function signalTransfer(address _receiver) external nonReentrant {
        require(IERC20(joy9Vester).balanceOf(msg.sender) == 0, "RewardRouter: sender has vested tokens");

        _validateReceiver(_receiver);
        pendingReceivers[msg.sender] = _receiver;
    }

    function acceptTransfer(address _sender) external nonReentrant {
        require(IERC20(joy9Vester).balanceOf(_sender) == 0, "RewardRouter: sender has vested tokens");

        address receiver = msg.sender;
        require(pendingReceivers[_sender] == receiver, "RewardRouter: transfer not signalled");
        delete pendingReceivers[_sender];

        _validateReceiver(receiver);
        _compound(_sender);

        uint256 stakedJoy9 = IRewardTracker(stakedJoy9Tracker).depositBalances(_sender, joy9);
        if (stakedJoy9 > 0) {
            _unstakeJoy9(_sender, joy9, stakedJoy9, false);
            _stakeJoy9(_sender, receiver, joy9, stakedJoy9);
        }

        uint256 stakedEsJoy9 = IRewardTracker(stakedJoy9Tracker).depositBalances(_sender, esJoy9);
        if (stakedEsJoy9 > 0) {
            _unstakeJoy9(_sender, esJoy9, stakedEsJoy9, false);
            _stakeJoy9(_sender, receiver, esJoy9, stakedEsJoy9);
        }

        uint256 stakedBnJoy9 = IRewardTracker(feeJoy9Tracker).depositBalances(_sender, bnJoy9);
        if (stakedBnJoy9 > 0) {
            IRewardTracker(feeJoy9Tracker).unstakeForAccount(_sender, bnJoy9, stakedBnJoy9, _sender);
            IRewardTracker(feeJoy9Tracker).stakeForAccount(_sender, receiver, bnJoy9, stakedBnJoy9);
        }

        uint256 esJoy9Balance = IERC20(esJoy9).balanceOf(_sender);
        if (esJoy9Balance > 0) {
            IERC20(esJoy9).transferFrom(_sender, receiver, esJoy9Balance);
        }

        IVester(joy9Vester).transferStakeValues(_sender, receiver);
    }

    function _validateReceiver(address _receiver) private view {
        require(IRewardTracker(stakedJoy9Tracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: stakedJoy9Tracker.averageStakedAmounts > 0");
        require(IRewardTracker(stakedJoy9Tracker).cumulativeRewards(_receiver) == 0, "RewardRouter: stakedJoy9Tracker.cumulativeRewards > 0");

        require(IRewardTracker(bonusJoy9Tracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: bonusJoy9Tracker.averageStakedAmounts > 0");
        require(IRewardTracker(bonusJoy9Tracker).cumulativeRewards(_receiver) == 0, "RewardRouter: bonusJoy9Tracker.cumulativeRewards > 0");

        require(IRewardTracker(feeJoy9Tracker).averageStakedAmounts(_receiver) == 0, "RewardRouter: feeJoy9Tracker.averageStakedAmounts > 0");
        require(IRewardTracker(feeJoy9Tracker).cumulativeRewards(_receiver) == 0, "RewardRouter: feeJoy9Tracker.cumulativeRewards > 0");

        require(IVester(joy9Vester).transferredAverageStakedAmounts(_receiver) == 0, "RewardRouter: joy9Vester.transferredAverageStakedAmounts > 0");
        require(IVester(joy9Vester).transferredCumulativeRewards(_receiver) == 0, "RewardRouter: joy9Vester.transferredCumulativeRewards > 0");

        require(IERC20(joy9Vester).balanceOf(_receiver) == 0, "RewardRouter: joy9Vester.balance > 0");
    }

    function _compound(address _account) private {
        _compoundJoy9(_account);
    }

    function _compoundJoy9(address _account) private {
        uint256 esJoy9Amount = IRewardTracker(stakedJoy9Tracker).claimForAccount(_account, _account);
        if (esJoy9Amount > 0) {
            _stakeJoy9(_account, _account, esJoy9, esJoy9Amount);
        }

        uint256 bnJoy9Amount = IRewardTracker(bonusJoy9Tracker).claimForAccount(_account, _account);
        if (bnJoy9Amount > 0) {
            IRewardTracker(feeJoy9Tracker).stakeForAccount(_account, _account, bnJoy9, bnJoy9Amount);
        }
    }

    function _stakeJoy9(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedJoy9Tracker).stakeForAccount(_fundingAccount, _account, _token, _amount);
        IRewardTracker(bonusJoy9Tracker).stakeForAccount(_account, _account, stakedJoy9Tracker, _amount);
        IRewardTracker(feeJoy9Tracker).stakeForAccount(_account, _account, bonusJoy9Tracker, _amount);

        emit StakeJoy9(_account, _token, _amount);
    }

    function _unstakeJoy9(address _account, address _token, uint256 _amount, bool _shouldReduceBnJoy9) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 balance = IRewardTracker(stakedJoy9Tracker).stakedAmounts(_account);

        IRewardTracker(feeJoy9Tracker).unstakeForAccount(_account, bonusJoy9Tracker, _amount, _account);
        IRewardTracker(bonusJoy9Tracker).unstakeForAccount(_account, stakedJoy9Tracker, _amount, _account);
        IRewardTracker(stakedJoy9Tracker).unstakeForAccount(_account, _token, _amount, _account);

        if (_shouldReduceBnJoy9) {
            uint256 bnJoy9Amount = IRewardTracker(bonusJoy9Tracker).claimForAccount(_account, _account);
            if (bnJoy9Amount > 0) {
                IRewardTracker(feeJoy9Tracker).stakeForAccount(_account, _account, bnJoy9, bnJoy9Amount);
            }

            uint256 stakedBnJoy9 = IRewardTracker(feeJoy9Tracker).depositBalances(_account, bnJoy9);
            if (stakedBnJoy9 > 0) {
                uint256 reductionAmount = stakedBnJoy9.mul(_amount).div(balance);
                IRewardTracker(feeJoy9Tracker).unstakeForAccount(_account, bnJoy9, reductionAmount, _account);
                IMintable(bnJoy9).burn(_account, reductionAmount);
            }
        }

        emit UnstakeJoy9(_account, _token, _amount);
    }
}
