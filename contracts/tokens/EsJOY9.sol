// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../tokens/MintableBaseToken.sol";

contract EsJOY9 is MintableBaseToken {
    constructor() MintableBaseToken("Escrowed JOY9", "esJOY9", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "esJOY9";
    }
}
