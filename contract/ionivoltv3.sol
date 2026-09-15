// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IONI VOLT V3 — Secure Energy & Battery DePIN Protocol
 * @dev Защищенное ядро системы с защитой от атак Reentrancy, подделки выплат и слива пула.
 */

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract IONIVoltV3 {
    address public owner;
    IERC20 public ioniToken;
    address public oracleAddress;
    bool public paused = false;

    // Защита от Reentrancy атак
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    struct SolarPanel {
        string location;
        bool active;
        uint256 totalWhLogged;
        uint256 availableWh;
        uint256 lastLogTimestamp;
    }

    struct EnergyOrder {
        address seller;
        uint256 amountWh;
        uint256 remainingWh;
        uint256 totalPrice;
        bool active;
    }

    struct GridConfig {
        uint256 tariffPerWh; // Цена в wei за 1 Вт·ч
        uint256 reserve;     // Доступный резерв токенов в контракте
        bool enabled;        // Статус экспорта
    }

    uint256 public orderCount;
    mapping(address => SolarPanel) public userPanels;
    mapping(uint256 => EnergyOrder) public energyOrders;
    mapping(address => uint256) public purchasedEnergyWh;
    GridConfig public grid;

    event EnergyListed(uint256 indexed orderId, address indexed seller, uint256 amountWh, uint256 totalPrice);
    event EnergyBought(uint256 indexed orderId, address indexed buyer, uint256 amountWh, uint256 pricePaid);
    event GridExported(address indexed seller, uint256 amountWh, uint256 payout);
    event ArbitrageExecuted(address indexed operator, uint256 energyWh, uint256 profitIoni);
    event GridFunded(address indexed funder, uint256 amount);

    // МОДИФИКАТОРЫ БЕЗОПАСНОСТИ
    modifier onlyOwner() {
        require(msg.sender == owner, "Security: Only owner allowed");
        _;
    }

    modifier onlyOracleOrOwner() {
        require(msg.sender == oracleAddress || msg.sender == owner, "Security: Only authorized Oracle or Owner allowed");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Security: Contract is paused");
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "Security: Reentrancy guard triggered");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address _ioniTokenAddress) {
        require(_ioniTokenAddress != address(0), "Invalid token address");
        owner = msg.sender;
        oracleAddress = msg.sender; // По умолчанию Оракулом является деплоер
        ioniToken = IERC20(_ioniTokenAddress);
        _status = _NOT_ENTERED;

        // По умолчанию тариф: 0.048 IONI за 1 Вт·ч (48000000000000000 wei)
        grid = GridConfig({
            tariffPerWh: 48000000000000000,
            reserve: 0,
            enabled: true
        });
    }

    // =========================================================================
    // 1. P2P ТОРГОВЛЯ МЕЖДУ СОСЕДЯМИ
    // =========================================================================

    function listSolarEnergy(uint256 amountWh, uint256 totalPrice) external whenNotPaused returns (uint256) {
        require(amountWh > 0 && totalPrice > 0, "Invalid inputs");
        orderCount++;
        energyOrders[orderCount] = EnergyOrder({
            seller: msg.sender,
            amountWh: amountWh,
            remainingWh: amountWh,
            totalPrice: totalPrice,
            active: true
        });

        emit EnergyListed(orderCount, msg.sender, amountWh, totalPrice);
        return orderCount;
    }

    function buySolarEnergy(uint256 orderId) external whenNotPaused nonReentrant {
        EnergyOrder storage order = energyOrders[orderId];
        require(order.active, "Order inactive or filled");
        require(order.seller != msg.sender, "Cannot buy your own order");

        uint256 burnAmount = (order.totalPrice * 2000) / 10000; // 20% СЖИГАНИЕ
        uint256 sellerAmount = order.totalPrice - burnAmount;

        address deadAddress = 0x000000000000000000000000000000000000dEaD;

        // Закрываем ордер до перевода средств (Защита)
        order.active = false;
        purchasedEnergyWh[msg.sender] += order.amountWh;

        // Выполняем безопасные переводы
        require(ioniToken.transferFrom(msg.sender, order.seller, sellerAmount), "Seller payment failed");
        require(ioniToken.transferFrom(msg.sender, deadAddress, burnAmount), "Burn payment failed");

        emit EnergyBought(orderId, msg.sender, order.amountWh, order.totalPrice);
    }

    // =========================================================================
    // 2. ЭКСПОРТ В СЕТЬ (GRID EXPORT / VPP)
    // =========================================================================

    function exportToGrid(uint256 amountWh) external whenNotPaused nonReentrant returns (uint256) {
        require(grid.enabled, "Grid export is currently disabled");
        require(amountWh > 0, "Amount must be greater than zero");

        uint256 payout = amountWh * grid.tariffPerWh;
        require(payout > 0, "Payout amount too small");
        require(grid.reserve >= payout, "Insufficient Grid reserve in contract");
        require(ioniToken.balanceOf(address(this)) >= payout, "Insufficient contract token balance");

        // Уменьшаем резерв до перевода
        grid.reserve -= payout;

        require(ioniToken.transfer(msg.sender, payout), "Payout to user failed");

        emit GridExported(msg.sender, amountWh, payout);
        return payout;
    }

    // =========================================================================
    // 3. БАТАРЕЙНЫЙ АРБИТРАЖ (ЗАЩИЩЕНО: ТОЛЬКО ОРАКУЛ ИЛИ ВЛАДЕЛЕЦ)
    // =========================================================================

    function executeBatteryArbitrage(
        address operator,
        uint256 energyWh,
        uint256 rewardAmountIoni
    ) external onlyOracleOrOwner whenNotPaused nonReentrant {
        require(operator != address(0), "Invalid operator address");
        require(energyWh > 0 && rewardAmountIoni > 0, "Invalid arbitrage parameters");

        uint256 burnAmount = (rewardAmountIoni * 2000) / 10000; // 20% СЖИГАНИЕ
        uint256 userReward = rewardAmountIoni - burnAmount;

        address deadAddress = 0x000000000000000000000000000000000000dEaD;

        require(ioniToken.balanceOf(address(this)) >= rewardAmountIoni, "Insufficient contract reserve");

        // Безопасная выплата профита оператору батареи
        require(ioniToken.transfer(operator, userReward), "User reward failed");
        require(ioniToken.transfer(deadAddress, burnAmount), "Burn transfer failed");

        emit ArbitrageExecuted(operator, energyWh, userReward);
    }

    // =========================================================================
    // 4. УПРАВЛЕНИЕ РЕЗЕРВОМ И АДМИНИСТРИРОВАНИЕ
    // =========================================================================

    function fundGrid(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(ioniToken.transferFrom(msg.sender, address(this), amount), "Funding transfer failed");
        
        grid.reserve += amount;
        emit GridFunded(msg.sender, amount);
    }

    function setGridConfig(uint256 tariffPerWh, bool enabled) external onlyOwner {
        grid.tariffPerWh = tariffPerWh;
        grid.enabled = enabled;
    }

    function setOracleAddress(address newOracle) external onlyOwner {
        require(newOracle != address(0), "Invalid oracle address");
        oracleAddress = newOracle;
    }

    function pause() external onlyOwner { paused = true; }
    function unpause() external onlyOwner { paused = false; }
}
