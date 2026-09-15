# ioni-volt-protocol
Official smart contracts, AI Oracle PoSG telemetry, and battery arbitrage node for IONI VOLT V3 DePIN Network.
# ⚡ IONI VOLT V3 — Decentralized Solar & Battery DePIN Protocol

![DePIN](https://img.shields.io/badge/Sector-DePIN-00e676?style=for-the-badge)
![Network](https://img.shields.io/badge/Network-Binance_Smart_Chain-ffd200?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Solidity](https://img.shields.io/badge/Solidity-v0.8.20-brightgreen?style=for-the-badge)
![Security](https://img.shields.io/badge/Security-ReentrancyGuard_Active-green?style=for-the-badge)

Official open-source repository for **IONI VOLT V3**, an AI-powered Decentralized Physical Infrastructure Network (DePIN) bridging residential solar generation, energy storage batteries (BMS), and Web3 liquidity on the Binance Smart Chain.

---

## 🌐 Official Links

- **Website & dApp:** [https://ioni.network](https://ioni.network)
- **Technical Whitepaper:** [Read Whitepaper V3](https://ioni.network/ioni_volt_whitepaper_v3_full_26_pages.pdf)
- **Telegram Channel:** [t.me/ioni_volt_official](https://t.me/ioni_volt_official)
- **DEX Trading (PancakeSwap):** [Buy $IONI Token](https://pancakeswap.finance)

---

## 📐 Protocol Architecture

┌──────────────────────────────┐

                               │     AI Oracle & Weather      │

                               │   EIP-712 Signature Proofs   │

                               └──────────────┬───────────────┘

                                              │

                                              ▼

┌─────────────────────────────┐   EIP-712     ┌──────────────────────────────┐

│  Residential Solar Panel    │ ────────────> │  IONIVoltV3 Smart Contract   │

│   (Shelly IoT Telemetry)    │   Verified    │  (Binance Smart Chain)       │

└─────────────────────────────┘               └──────────────┬───────────────┘

                                                             │

┌─────────────────────────────┐  Automated                   │ 80% Payout

│  Battery Storage Arbitrage  │ <────────────────────────────┤ 20% Deflation Burn 🔥

│   (RS485 Modbus Daemon)     │   Execution                  ▼

└─────────────────────────────┘               ┌──────────────────────────────┐

                                              │  P2P Marketplace & Grid Pool │

                                              └──────────────────────────────┘


ChatGPT | Nano Banana, [15 сен. 2026 в 10:32]
---

## 🔑 Key Features

- **Proof-of-Solar-Generation (PoSG):** Cryptographic validation of solar power output cross-referenced with weather telemetry.
- **Deflationary P2P Marketplace:** Peer-to-peer energy trade with an automatic **20% permanent token burn** on settlement.
- **Smart Battery Arbitrage:** Automated IoT daemon (`scripts/ioni_battery_daemon.py`) executing charge/discharge cycles based on grid tariff spreads.
- **Zero Transfer Tax:** 0% buy/sell transaction tax for maximum DEX liquidity integration.
- **Reentrancy Protection:** Industrial-grade security pattern preventing contract state manipulation.

---

## ⚙️ Smart Contract Specifications

| Contract | Network | Compiler | License |
| :--- | :--- | :--- | :--- |
| **`IONIVoltV3.sol`** | Binance Smart Chain (BEP-20) | v0.8.20 | MIT |
| **`IONIToken.sol`** | Binance Smart Chain (BEP-20) | v0.8.20 | MIT |

### Verified Contract Addresses

bash

$IONI Utility Token Address:

0x513EE676783737Cdf0562a824322aE082c52B8C1

IONI VOLT V3 Core Protocol Address:

0xA3C49DD653D1B46F7daDff355CB1540310Ce97CA

---

## 🛠 Quick Start for Hardware Battery Nodes

To run an autonomous Battery Node on a Raspberry Pi or Home Server:

1. Clone the repository:
   

bash

   git clone https://github.com/YOUR-USERNAME/ioni-volt-protocol.git

   cd ioni-volt-protocol/scripts

2. Install dependencies:
   

bash

   pip install web3 pymodbus

3. Configure your node settings in `ioni_battery_daemon.py`:
   

python

   PRIVATE_KEY = "0xYOUR_WALLET_PRIVATE_KEY"

   CONTRACT_ADDRESS = "0xYOUR_VOLT_CONTRACT_ADDRESS"

4. Execute the daemon:
   

bash

   python3 ioni_battery_daemon.py

---

## 🛡️ Security & Audits

- **Reentrancy Guard:** Built-in mutex locks on all state-changing transfer functions.
- **Access Control:** Critical parameters (`setOracleAddress`, `pause`, `setGridConfig`) are restricted to multi-sig owner access.
- **Circuit Breakers:** Emergency pause capability to halt protocol execution in case of network anomalies.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

*Disclaimer: $IONI is a utility token designed for node authentication, telemetry settlement, and P2P energy trading within the IONI VOLT ecosystem. Nothing in this repository constitutes financial advice.*
