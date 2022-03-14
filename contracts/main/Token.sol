// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Token is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for ERC20;
    uint8 public _decimals;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _ddecimals
    ) ERC20(_name, _symbol) {
        _decimals = _ddecimals;
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}