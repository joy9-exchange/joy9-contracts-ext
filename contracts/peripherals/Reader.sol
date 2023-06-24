// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../libraries/token/IERC20.sol";
import "../libraries/math/SafeMath.sol";

import "../tokens/interfaces/IYieldTracker.sol";
import "../tokens/interfaces/IYieldToken.sol";

import "../staking/interfaces/IVester.sol";
import "../access/Governable.sol";

contract Reader is Governable {
    using SafeMath for uint256;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant POSITION_PROPS_LENGTH = 9;
    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant USDG_DECIMALS = 18;

    bool public hasMaxGlobalShortSizes;

    function setConfig(bool _hasMaxGlobalShortSizes) public onlyGov {
        hasMaxGlobalShortSizes = _hasMaxGlobalShortSizes;
    }

    function getTotalStaked(address[] memory _yieldTokens) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](_yieldTokens.length);
        for (uint256 i = 0; i < _yieldTokens.length; i++) {
            IYieldToken yieldToken = IYieldToken(_yieldTokens[i]);
            amounts[i] = yieldToken.totalStaked();
        }
        return amounts;
    }

    function getStakingInfo(address _account, address[] memory _yieldTrackers) public view returns (uint256[] memory) {
        uint256 propsLength = 2;
        uint256[] memory amounts = new uint256[](_yieldTrackers.length * propsLength);
        for (uint256 i = 0; i < _yieldTrackers.length; i++) {
            IYieldTracker yieldTracker = IYieldTracker(_yieldTrackers[i]);
            amounts[i * propsLength] = yieldTracker.claimable(_account);
            amounts[i * propsLength + 1] = yieldTracker.getTokensPerInterval();
        }
        return amounts;
    }

    function getVestingInfo(address _account, address[] memory _vesters) public view returns (uint256[] memory) {
        uint256 propsLength = 7;
        uint256[] memory amounts = new uint256[](_vesters.length * propsLength);
        for (uint256 i = 0; i < _vesters.length; i++) {
            IVester vester = IVester(_vesters[i]);
            amounts[i * propsLength] = vester.pairAmounts(_account);
            amounts[i * propsLength + 1] = vester.getVestedAmount(_account);
            amounts[i * propsLength + 2] = IERC20(_vesters[i]).balanceOf(_account);
            amounts[i * propsLength + 3] = vester.claimedAmounts(_account);
            amounts[i * propsLength + 4] = vester.claimable(_account);
            amounts[i * propsLength + 5] = vester.getMaxVestableAmount(_account);
            amounts[i * propsLength + 6] = vester.getCombinedAverageStakedAmount(_account);
        }
        return amounts;
    }

    function getTokenSupply(IERC20 _token, address[] memory _excludedAccounts) public view returns (uint256) {
        uint256 supply = _token.totalSupply();
        for (uint256 i = 0; i < _excludedAccounts.length; i++) {
            address account = _excludedAccounts[i];
            uint256 balance = _token.balanceOf(account);
            supply = supply.sub(balance);
        }
        return supply;
    }

    function getTotalBalance(IERC20 _token, address[] memory _accounts) public view returns (uint256) {
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < _accounts.length; i++) {
            address account = _accounts[i];
            uint256 balance = _token.balanceOf(account);
            totalBalance = totalBalance.add(balance);
        }
        return totalBalance;
    }

    function getTokenBalances(address _account, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                balances[i] = _account.balance;
                continue;
            }
            balances[i] = IERC20(token).balanceOf(_account);
        }
        return balances;
    }

    function getTokenBalancesWithSupplies(address _account, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 2;
        uint256[] memory balances = new uint256[](_tokens.length * propsLength);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                balances[i * propsLength] = _account.balance;
                balances[i * propsLength + 1] = 0;
                continue;
            }
            balances[i * propsLength] = IERC20(token).balanceOf(_account);
            balances[i * propsLength + 1] = IERC20(token).totalSupply();
        }
        return balances;
    }
}
