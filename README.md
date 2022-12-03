# Joe V2 Rewarder

This repository contains the source code for the Trader Joe Rewarder contract.
It allows to distribute rewards to users based on their share of the total liquidity provided to the Trader Joe protocol.
This share is calculated off-chain and then set on-chain using a Merkle tree.
The rewards can be any ERC20 and native tokens, they are distributed following a vesting schedule and can be claimed by the users using their Merkle proof.

## Install foundry

Foundry documentation can be found [here](https://book.getfoundry.sh/forge/index.html).

### On Linux and macOS

Open your terminal and type in the following command:

```
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. Then install Foundry by running:

```
foundryup
```

To update foundry after installation, simply run `foundryup` again, and it will update to the latest Foundry release.
You can also revert to a specific version of Foundry with `foundryup -v $VERSION`.

### On Windows

If you use Windows, you need to build from source to get Foundry.

Download and run `rustup-init` from [rustup.rs](https://rustup.rs/). It will start the installation in a console.

After this, run the following to build Foundry from source:

```
cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil --bins --locked
```

To update from source, run the same command again.

## Install dependencies

To install dependencies, run the following to install dependencies:

```
forge install
```

---

## Tests

To run tests, run the following command:

```
forge test
```
