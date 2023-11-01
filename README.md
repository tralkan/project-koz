# Tyron SSI Protocol on EVM

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/tralkan/project-koz)

Welcome to the [Tyron SSI Protocol](https://ssiprotocol.com) repository for Ethereum Virtual Machine (EVM) powered networks. This protocol aims to provide secure, self-sovereign digital identities and enable tamper-proof transactions on blockchain networks.

## Features

- **Self-Sovereign Identities:** Empower users with complete control over their digital identities, enhancing privacy and security.
- **Tamper-Proof Transactions:** Ensure the integrity of transactions through smart contracts, fostering trust and reliability.
- **Privacy Protection:** Safeguard user data and privacy using advanced cryptographic techniques.
- **Interoperability:** Seamlessly integrate with EVM-based applications and services, enhancing accessibility and usability.

## Getting Started

These instructions will guide you through setting up and deploying a [TyronSSI account](./contracts/Account.sol) on your local machine for development and testing purposes. See the [Installation](#installation) section for detailed setup instructions.

## Prerequisites

- Node.js and npm installed
- Ethereum wallet for testing
- Foundry installed:

```
curl -L https://foundry.paradigm.xyz | bash

foundryup
```

## Installation

Follow these steps to set up the project on your local machine:

1. Clone the repository: `git clone https://github.com/tralkan/project-koz.git`
2. Change directory: `cd project-koz`
3. Install dependencies: `npm i`
4. Run Hardhat script to deploy a TyronSSI account to Polygon zkEVM: `npm run sn`
5. Run Hardhat unit tests with: `npm run th`

A [front-end interface](https://github.com/tralkan/tyron) is in development with Next.js, Web3Modal and other great tools!

## Contributing

If you'd like to contribute to the Tyron SSI Protocol, please fork this repository and create a pull request with your changes. We welcome contributions from the community!

## License

Most of this project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. The smart contract account has a GPL-3.0 license.
