# caironet
Cairo test runner with contract address mocking.

## Motivation

Testing cairo contract must be simple, including contract interactions
when a contract can `call` an other contract. This is crucial for
effective development of starknet contracts written in cairo.

`caironet` aims at being very simple and so thin, that it's easy
and quick to get started with cairo contracts testing mocking the deployment.

Only add the configuration file and use regular cairo testing features.

## What caironet is

It's a fork from [Starkware cairo repo](https://github.com/starkware-libs/cairo),
having a little modification on the test runner to have the `cairo-test`
being able to honor a `call` between contracts mocking their addresses.

It's not a devnet.  
It's not a testnet.  

`caironet` was developped in my journey of Starknet exploration and understanding.
Amazing devs in the ecosystem (for example Software mansion with protostar) are proposing more advanced tooling.

But as the time of this writting, those tools are still under active development and I was looking
for a way to easily do integration testing with only `cairo-test` features.

## Configuration

The configuration is a simple `JSON` file named `.caironet.json`.  
This file contains the mocked addresses and must be placed at the root of the `cairo/scarb project`.

Example:
```json
{
    "Contract1": {
        "JOHN": "1010",
        "DOE": "0x1234"
    },
    "Contract2": "99"
}

```

The most important requirement is that, the first level keys are always the
exact name of your contracts. The case **MUST** be respected.

For example, in the `test/caironet/src` directory, you can find `Contract1` and `Contract2`
contracts with this exact case.

If you need several addresses for the same contract class (which is usually the case
for instance when using ERC721 and ERC20), you can use the same structure as
shown in the example for `Contract1`. Here, `JOHN` and `DOE` are labels for the instances
of the contract, which does not correspond to anything in the code, so the text
is totally free and up to you.

The `JSON` specification is not supporting trailing commas, so be careful
to not forget them, the configuration file will not be parseable.

The addresses are strings, and both decimal and hexadecimal strings are supported.
Hexadecimal string **MUST BE PREFIXED** with `0x`.

When the runner starts, it will output the mocked addresses and corresponding class hashes:

```
Mocked address: 0x1234 for Contract1 [DOE] (class_hash: 1674043218147484320489166460321444344881925232388472483217999049795709544553)
Mocked address: 1010 for Contract1 [JOHN] (class_hash: 1674043218147484320489166460321444344881925232388472483217999049795709544553)
```

## Examples

You can find a complete working example in the `tests/caironet` directory [here](https://github.com/glihm/cairo/blob/1.1.0/tests/caironet/tests/test_1.cairo).  
The examples are commented with detailed explanations.

To test run the tests of this repo:

```bash
cd tests/caironet
scarb build test-caironet
```

One of two most important functions when testing a contract are:
1. [set_caller_address](https://github.com/starkware-libs/cairo/blob/c4dcdf689840313e27f6305ba89d489169a68348/corelib/src/starknet/testing.cairo#L3), which mocks the
address returned by `get_caller_address` in our contracts.
2. [set_contract_address](https://github.com/starkware-libs/cairo/blob/c4dcdf689840313e27f6305ba89d489169a68348/corelib/src/starknet/testing.cairo#L4), which mocks the
contract address used during the execution to lookup the storage (among other).

So, using `set_contract_address` in a test will indicate to the test runner at which address it must lookup for storage values.

This is a very important part to understand to ensure you fully control the storage values associated with the contracts you want to test.

Walkthrough detailed [here](https://github.com/glihm/cairo/blob/1.1.0/tests/caironet/tests/test_1.cairo#L22).

## Test with caironet inside your Scarb project

[Scarb](https://github.com/software-mansion/scarb) supports scripting.
You can use the pre-built docker image or clone and compile the repository depending your need.

Example of `Scarb.toml` file using the [docker image from docker hub](https://hub.docker.com/r/glihm/caironet/tags):

```toml
[scripts]
test-caironet = "sudo docker run --rm -v $(pwd):/project -t --entrypoint cairo-test glihm/caironet:1.1.0-a --starknet /project/"
```
The docker tag is always the cairo-compile version (`1.1.0` in this example), with an incremental version of `caironet` (`a` in this example).
Consider to always run `cairo-test` with `--starknet` plugin.

To compile locally, use `cargo build --package cairo-lang-test-runner --release`

```toml
[scripts]
test-caironet = "/path/caironet/target/release/cairo-test --starknet ."
```

## Starknet contracts dichotomy

Starknet divides contract data in two:
* Contract class: which is the code associated with a contract and related ABI.
* Contract instance: a mapping of contract address, to a class hash identifying the contract class and a "state" (including the storage among other).

In this context, the contract class can be seen as a static piece of code, ready to be executed.
The contract instance can be seen as a dedicated space with a storage. So anytime we call a contract:

1. The address is used to know which underlying storage the runner should use.
2. The class hash is used to know which code to execute. In the case of testing,
we never user the class hash explicitely, we call the corresponding cairo module explicitely (`Contract1::` for instance).

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

Caironet is provided **as is**, and it still experimental.
It is not subject to grow neither to match all the features that the tools like protostar are providing.
