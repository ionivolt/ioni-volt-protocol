import time
import json
import random
from web3 import Web3

# 1. Настройка подключения к блокчейну (BSC / Testnet / Local)
RPC_URL = "https://data-seed-prebsc-1-s1.binance.org:8545/"  # BSC Testnet
web3 = Web3(Web3.HTTPProvider(RPC_URL))

# Настройки ключей (В реальном проекте берутся из .env)
PRIVATE_KEY = "0xYOUR_PRIVATE_KEY_HERE"
ACCOUNT_ADDRESS = web3.eth.account.from_key(PRIVATE_KEY).address
CONTRACT_ADDRESS = "0xYOUR_DEPLOYED_CONTRACT_ADDRESS"

# Минимальный ABI смарт-контракта
CONTRACT_ABI = json.loads('''[
    {"inputs":[{"internalType":"bytes32","name":"_nodeId","type":"bytes32"},{"internalType":"uint256","name":"_capacityWh","type":"uint256"}],"name":"registerBatteryNode","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[{"internalType":"bytes32","name":"_nodeId","type":"bytes32"},{"internalType":"uint256","name":"_energyWh","type":"uint256"},{"internalType":"uint256","name":"_buyTariffWei","type":"uint256"},{"internalType":"uint256","name":"_sellTariffWei","type":"uint256"}],"name":"executeArbitrage","outputs":[],"stateMutability":"nonpayable","type":"function"}
]''')

contract = web3.eth.contract(address=CONTRACT_ADDRESS, abi=CONTRACT_ABI)

# 2. Симулятор Hardware-BMS (Аккумулятора)
class SmartBatteryBMS:
    def __init__(self, capacity_wh=10000): # 10 кВт·ч батарея
        self.capacity_wh = capacity_wh
        self.soc = 50.0  # State of Charge (Заряд в %)
        self.voltage = 51.2  # Номинальное напряжение LiFePO4
        self.is_charging = False
        self.is_discharging = False

    def read_telemetry(self):
        """Эмуляция чтения данных по протоколу RS485/Modbus от батареи"""
        return {
            "soc": self.soc,
            "voltage": self.voltage,
            "available_wh": (self.soc / 100.0) * self.capacity_wh
        }

    def set_mode(self, mode):
        if mode == "CHARGE":
            self.is_charging = True
            self.is_discharging = False
            self.soc = min(100.0, self.soc + 25.0) # Симуляция заряда
            print("⚡ [HARDWARE] BMS: Включен режим ЗАРЯДА аккумулятора от сети.")
        elif mode == "DISCHARGE":
            self.is_charging = False
            self.is_discharging = True
            self.soc = max(10.0, self.soc - 25.0) # Симуляция разряда в сеть
            print("🔋 [HARDWARE] BMS: Включен режим РАЗРЯДА (Экспорт энергии в сеть).")
        else:
            self.is_charging = False
            self.is_discharging = False
            print("⏸️ [HARDWARE] BMS: Режим ожидания (Standby).")

# 3. Симулятор цен городской электросети (Tariff Oracle)
def get_grid_tariff_spot_price():
    """
    В продакшене тут запрос к API биржи электроэнергии (Nord Pool / EPEX SPOT / ТНС Энерго).
    Возвращает цену за 1 Вт·ч в wei.
    """
    hour = time.localtime().tm_hour
    
    # Ночной тариф (00:00 - 06:00) — Очень дешево
    if 0 <= hour < 6:
        price_per_wh = Web3.to_wei(0.00001, 'ether') # Низкая цена
        zone = "NIGHT_CHEAP"
    # Пиковый тариф (18:00 - 22:00) — Очень дорого
    elif 18 <= hour < 22:
        price_per_wh = Web3.to_wei(0.00008, 'ether') # Высокая цена
        zone = "PEAK_EXPENSIVE"
    else:
        price_per_wh = Web3.to_wei(0.00003, 'ether') # Обычная цена
        zone = "STANDARD"

    return price_per_wh, zone

# 4. Главный алгоритм арбитража и Web3-фиксации
def main_arbitrage_loop():
    print("🚀 Запуск контроллера IONI Smart-Grid Arbitrage...")
    battery = SmartBatteryBMS(capacity_wh=10000)
    node_id = web3.keccak(text="BATTERY_NODE_001")

    last_buy_price = 0

    while True:
        telemetry = battery.read_telemetry()
        tariff_price, zone = get_grid_tariff_spot_price()

        print(f"\n📊 [STATUS] SoC: {telemetry['soc']}% | Зона сети: {zone} | Цена: {web3.from_wei(tariff_price, 'ether')} ETH/Wh")

        # АЛГОРИТМ ПРИНЯТИЯ РЕШЕНИЙ (ARBITRAGE LOGIC)
        
        # 1. Ночь: Покупаем и заряжаем, если SoC < 90%
        if zone == "NIGHT_CHEAP" and telemetry['soc'] < 90:
            battery.set_mode("CHARGE")
            last_buy_price = tariff_price
            print(f"💰 Заряжено по дешевой цене: {web3.from_wei(tariff_price, 'ether')} ETH/Wh")

        # 2. Пик: Продаем в сеть, если есть заряд и профит > 300%
        elif zone == "PEAK_EXPENSIVE" and telemetry['soc'] > 30 and last_buy_price > 0:
            energy_to_sell_wh = 2500 # Продаем 2.5 кВт·ч
            battery.set_mode("DISCHARGE")

            print("📝 Отправка арбитражной транзакции в смарт-контракт IONI...")
            try:
                # Формирование Web3 транзакции
                tx = contract.functions.executeArbitrage(
                    node_id,
                    energy_to_sell_wh,
                    last_buy_price,
                    tariff_price
                ).build_transaction({
                    'from': ACCOUNT_ADDRESS,
                    'nonce': web3.eth.get_transaction_count(ACCOUNT_ADDRESS),
                    'gas': 300000,
                    'gasPrice': web3.eth.gas_price
                })

                signed_tx = web3.eth.account.sign_transaction(tx, PRIVATE_KEY)
                tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
                print(f"✅ [SUCCESS] Арбитраж зафиксирован в блокчейне! TX: {web3.to_hex(tx_hash)}")
                last_buy_price = 0 # Сброс цикла

            except Exception as e:
                print(f"❌ Ошибка отправки транзакции: {e}")

        else:
            battery.set_mode("STANDBY")

        time.sleep(10) # Задержка между циклами контроля

if __name__ == "__main__":
    main_arbitrage_loop()
