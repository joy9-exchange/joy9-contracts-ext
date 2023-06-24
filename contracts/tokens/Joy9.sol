// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./oft/OFT.sol";

contract Joy9 is OFT {
    uint256 public constant MAX_MINTABLE_SUPPLY = 500_000_000 ether;

    constructor(address _lzEndpoint, address treasury) OFT("Joy9 Exchange Token", "JOY9", _lzEndpoint) {
        _mint(treasury, MAX_MINTABLE_SUPPLY);
    }
}
