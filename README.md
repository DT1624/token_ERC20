# Token ERC-20

## Overview



## Features



## Getting Started

### Prerequisites

- Movement CLI or [Aptos CLI 3.5.0](https://github.com/aptos-labs/aptos-core/releases/tag/aptos-cli-v3.5.0)

### Installation

1. Clone the repository:

```bash
git clone https://github.com/DT1624/token_ERC20.git
```

2. Create a new Move project:

```bash
aptos/movement move init --name NAME_PROJECT
```

3. Initialize your development account

```bash
aptos/movement init --profile NAME_ACCOUNT
# Network: custom
# REST endpoint: https://testnet.bardock.movementnetwork.xyz/v1
# Faucet: (skip)  
# Private key: (press Enter to generate)
```

### Configuration

To support multiple named signers, define them under [addresses] in the Move.toml file to configure the application:

```toml
[addresses]
owner = '0x456' # The OBJECT_ADDRESS after deployment
user = '0xabc'  # Using for testing
admin = '0x123' # Using for testing
```

Replace the [dependencies.AptosFramework] section with the following:
```toml
[dependencies.AptosFramework]
git = "https://github.com/movementlabsxyz/aptos-core.git"
rev = "movement"
subdir = "aptos-move/framework/aptos-framework"
```

## Usage

### Publish Contract

- A faucet is needed for the account created by '_aptos/movement init_' at https://faucet.movementnetwork.xyz/
- Update OBJECT_ADDRESS = '_'

```bash
aptos/movement move create-object-and-publish-package --address-name <OBJECT_ADDRESS> --url https://testnet.bardock.movementnetwork.xyz/v1 --private-key <PRIVATE_KEY> [OPTIONS]
# You can configure the artifact property
# PRIVATE_KEY is the account's private key will manage this object.
```

### Upgrade Contract

- Update OBJECT_ADDRESS with the object address created during the publish process
```toml
OBJECT_ADDRESS = '0x...'
```

```bash
aptos/movement move upgrade-object-package --object-address <OBJECT_ADDRESS> --url https://testnet.bardock.movementnetwork.xyz/v1 --private-key <PRIVATE_KEY> [OPTIONS]
```