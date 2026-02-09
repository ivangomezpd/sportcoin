// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SportCoin.sol";

/**
 * @title RedemptionStore
 * @dev Marketplace where users spend SPC for items.
 * Implements deflationary mechanics (Burn & Treasury).
 */
contract RedemptionStore is AccessControl {
    SportCoin public token;
    address public treasury;

    struct Item {
        string name;
        uint256 price; // In Wei (10^18 units usually, or simplified)
        bool active;
        uint256 stock;
    }

    mapping(uint256 => Item) public items;
    uint256 public nextItemId;

    uint256 public burnRate = 50; // 50% burned
    uint256 public treasuryRate = 50; // 50% to treasury

    event ItemRedeemed(
        address indexed user,
        uint256 itemId,
        string itemName,
        uint256 price
    );
    event ItemCreated(
        uint256 itemId,
        string name,
        uint256 price,
        uint256 stock
    );

    constructor(address _token, address _treasury) {
        token = SportCoin(_token);
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createItem(
        string memory name,
        uint256 price,
        uint256 stock
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        items[nextItemId] = Item(name, price, true, stock);
        emit ItemCreated(nextItemId, name, price, stock);
        nextItemId++;
    }

    function redeemItem(uint256 itemId) external {
        Item storage item = items[itemId];
        require(item.active, "Item not active");
        require(item.stock > 0, "Out of stock");
        require(
            token.balanceOf(msg.sender) >= item.price,
            "Insufficient balance"
        );

        // 1. Decrement Stock
        item.stock--;

        // 2. Process Stats (Burn & Treasury)
        uint256 burnAmount = (item.price * burnRate) / 100;
        uint256 treasuryAmount = item.price - burnAmount;

        // 3. Execute Transfers
        // User must have approved this contract to spend their SPC
        if (burnAmount > 0) {
            token.burnFrom(msg.sender, burnAmount);
        }
        if (treasuryAmount > 0) {
            token.transferFrom(msg.sender, treasury, treasuryAmount);
        }

        emit ItemRedeemed(msg.sender, itemId, item.name, item.price);
    }

    function setRates(
        uint256 _burnRate,
        uint256 _treasuryRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_burnRate + _treasuryRate == 100, "Must equal 100");
        burnRate = _burnRate;
        treasuryRate = _treasuryRate;
    }
}
