// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITimelock {
    function setAdmin(address _admin) external;
    function enableLeverage(address _vault) external;
    function disableLeverage(address _vault) external;
    function setIsLeverageEnabled(address _vault, bool _isLeverageEnabled) external;
    function setIsToUseOraclePrice(address _vault, bool _isToUseOraclePrice) external;
    function setIsSyntheticTradeEnabled(address _vault, bool _isSyntheticTradeEnabled) external;
    function signalSetGov(address _target, address _gov) external;
}
