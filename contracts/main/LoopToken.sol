// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LoopToken is ERC20, ERC20Burnable, AccessControl {
    using SafeERC20 for ERC20;
    uint256 public _cap;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Max transfer amount rate in basis points. Default is 100% of total
    // supply, and it can't be less than 0.5% of the supply.
    uint16 public _maxTransferAmountRate = 10000;

    // Addresses that are excluded from anti-whale checking.
    mapping(address => bool) private _excludedFromAntiWhale;

    // Events.
    event MaxTransferAmountRateUpdated(uint256 previousRate, uint256 newRate);

    /**
     * @dev Ensures that the anti-whale rules are enforced.
     */
    modifier antiWhale(
        address sender,
        address recipient,
        uint256 amount
    ) {
        if (
            _excludedFromAntiWhale[sender] == false &&
            _excludedFromAntiWhale[recipient] == false
        ) {
            require(
                amount <= maxTransferAmount(),
                "antiWhale: Transfer amount exceeds the maxTransferAmount"
            );
        }
        _;
    }

    constructor() ERC20("Loop", "LOOP") {
        _cap = 1000000000 * 10 ** decimals();
        
        _excludedFromAntiWhale[msg.sender] = true;
        _excludedFromAntiWhale[address(0)] = true;
        _excludedFromAntiWhale[address(this)] = true;
        
        _mint(msg.sender, _cap);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

   /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - minted tokens must not cause the total supply to go over the cap.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override antiWhale(from,to,amount) {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) {
            // When minting tokens
            require(
                (totalSupply() + amount) <= _cap,
                "ERC20Capped: cap exceeded"
            );
        }
    }


    /**
     * @dev Updates the total cap.
     */
    function updateCap(uint256 newCap) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _cap = newCap;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

     /**
     * @dev Update the max transfer amount rate.
     */
    function updateMaxTransferAmountRate(uint16 newMaxTransferAmountRate)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            newMaxTransferAmountRate <= 10000,
            "updateMaxTransferAmountRate: Max transfer amount rate must not exceed the maximum rate."
        );
        emit MaxTransferAmountRateUpdated(
            _maxTransferAmountRate,
            newMaxTransferAmountRate
        );
        _maxTransferAmountRate = newMaxTransferAmountRate;
    }

    /**
     * @dev Calculates the max transfer amount.
     */
    function maxTransferAmount() public view returns (uint256) {
        return totalSupply() * _maxTransferAmountRate / 10000;
    }

    /**
     * @dev Sets an address as excluded or not from the anti-whale checking.
     */
    function setExcludedFromAntiWhale(address _account, bool _excluded)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _excludedFromAntiWhale[_account] = _excluded;
    }
}
