# caironet
Cairo test runner with contract address mocking.

## Motivation

Testing cairo contract must be simple, including contract interactions
when a contract can `call` an other contract.

`caironet` aims at being very simple and so thin, that it's easy
and quick get started with cairo contracts testing mocking the deployment.

A simple, flexible `.caironet.json` file to mock the addresses.

## What caironet is

It's a fork from [Starkware cairo repo](https://github.com/starkware-libs/cairo),
having a little modification on the test runner to have the `cairo-test`
being able to honor a `call` between contrats.

Running caironet produces the same testing feature as `cairo-test`, and the
modified code is only altering the `StarknetState` to mock deployed contracts.

Indeed, in the test running, "deploying" a contract can be seen as "registering
a mapping between a contract address and it's class hash".

It's not a devnet.  
It's not a testnet.  

Caironet was developped in my journey of Starknet exploration and understanding.
Amazing devs in the ecosystem (for example Software mansion with protostar) are proposing more advanced tooling.

Finally, `caironet` makes sense only if `cairo-test` is used
with `--starknet` plugin, as it's for testing Starknet contracts.

## How to use and examples

You can find a complete working example in the `tests/caironet` directory.
The examples are commented with detailed explanations.

For the `.caironet.json` file, it must be placed at the root of the `cairo project`.
The configuration is a simple `JSON` with only strings.

The most important requirement is that, the first level keys are always the
exact name of your contracts. The case MUST be respected.

For example, in the `test/caironet` directory, you can find `Contract1` and `Contract2`
contracts (which are cairo modules).

If you need several addresses for the same contract (which is usually the case
for instance when using ERC721 and ERC20), you can use the same structure as
shown below for `Contract1`. Here, `JOHN` and `DOE` are label for the instances
of the contracts, which does not correspond to anything in the code, so the text
is totally up to you.

The `JSON` specification is not supporting trailing commas, so be careful
to not forget them, the configuration file will not be parseable.

The addresses are strings, and both decimal and hexadecimal strings are supported.
Hexadecimal string **MUST BE PREFIXED** with `0x`.

```json
{
    "Contract1": {
        "JOHN": "1010",
        "DOE": "0x1234"
    },
    "Contract2": "99",
    "ContractName": {
        "Instance1": "0x1111"
    }
}

```

## Starknet contracts dichotomy

Starknet divides contract data in two:
* Contract class: which is the code associated with a contract and related ABI.
* Contract instance: a mapping of contract address, to a class hash identifying the contract class and a "state" (including the storage among other).

In this context, the contract class can be seen as a static piece of code, ready to be executed.
The contract instance can be seen as a dedicated space with a storage. So anytime we call a contract:

1. The address is used to know which underlying storage the runner should use.
2. The class hash is used to know which code to execute. In the case of testing,
we never user the class hash explicitely, we call the corresponding module explicitely.

## Caironet considerations

This tool depends on the cairo compiler at https://github.com/starkware-libs/cairo.
It will follow the stable releases of the starkware repo.

Under the hood, caironet is using the exact same code as `cairo-test` command,
modified to support a populated `StarknetState` before the execution.

It's important to note that, every test runs in a different instance of the test runner.
Which means any storage value is reseted at each test.

Finally, `caironet` was designed this way because populating the `StarknetState` by calling
`deploy_syscall` is more complex from the cairo code.

The focus of `caironet` is to keep testing simple, with no changes compared
to the original `cairo-lang` testing features for the `starknet` plugin found [here](https://github.com/starkware-libs/cairo/blob/c4dcdf689840313e27f6305ba89d489169a68348/corelib/src/starknet/testing.cairo).

## Disclaimer

Caironet is provided **as is**, and it still experimental. Use at your own risks.
