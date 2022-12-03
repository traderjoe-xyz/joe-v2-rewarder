// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract MockERC20 is ERC20Upgradeable {
    constructor(string memory name, string memory symbol) initializer {
        __ERC20_init(name, symbol);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
