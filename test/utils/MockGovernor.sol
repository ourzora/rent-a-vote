// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

contract MockGovernor {
    bool public hasVoted;
    bool public hasProposed;

    constructor() {}

    function vote() public {
        hasVoted = true;
    }

    function propose() public {
        hasProposed = true;
    }
}
