// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../libraries/chain/Chain.sol";

contract BlockInfo {
    function getChainId() public view returns (uint256) {
        return block.chainid;
    }

    function currentArbBlockNumber() public view returns (uint256) {
        return Chain.currentBlockNumber();
    }

    function currentSolidityBlockNumber() public view returns (uint256) {
        return block.number;
    }

    function getArbBlockHash(uint256 blockNumber) public view returns (bytes32) {
        return Chain.getBlockHash(blockNumber);
    }

    function getSolidityBlockHash(uint256 blockNumber) public view returns (bytes32) {
        return blockhash(blockNumber);
    }
}