# caironet
Cairo test runner with contract address mocking.

## Motivation

Testing cairo contract must be simple, including contract interactions
when a contract can `call` an other contract. This is crucial for
effective development of starknet contracts written in cairo.

`caironet` aims at being very simple and so thin, that it's easy
and quick to get started with cairo contracts testing mocking the deployment.

## What caironet is

It's a fork from [Starkware cairo repo](https://github.com/starkware-libs/cairo),
having a little modification on the test runner to have the `cairo-test`
being able to honor a `call_contract syscall`.

It's different from protostar, which is a more featured tool that also proposes integration testing.
The difference is that, with caironet you can easily choose the addresses, and you only use built-ins from
the compiler. Protostar has more advanced tooling with specific methods to managed `declare/deploy/etc...`.

It's not a devnet.  
It's not a testnet.  

`caironet` was developped in my journey of Starknet exploration and understanding.
Amazing devs in the ecosystem (for example Software mansion with protostar and SpaceShard with the starknet-devnet) are proposing more advanced tooling.

But as the time of this writting, those tools are still under active development and I was looking
for a way to easily do integration testing with only built-in features of the compiler.

## TLDR;

```rust
// A minimum contract implementation with a view to be called.
#[contract]
mod Cmin {
    struct Storage {
        val_: felt252,
    }

    // Init the contract with a value inside the storage.
    #[constructor]
    fn constructor(val: felt252) {
        val_::write(val);
    }

    // Queries the value inside the storage.
    #[view]
    fn get_val() -> felt252 {
        val_::read()
    }
}

// Defines an ABI to generate a Dispatcher
// which encapsulate a call_contract syscall.
#[abi]
trait ICmin {
    #[view]
    fn get_val() -> felt252;
}

#[test]
#[available_gas(2000000)]
#[caironet(Cmin: 1122)]
fn test_call() {

    // The #[caironet..] attribute ensure that the class hash of Cmin
    // contract is mapped to the address 1122.

    // To "deploy", we need an address and call the constructor.
    // we set the contract address to ensure the storage we use
    // is the one corresponding to the address 1122.
    let cmin_addr = starknet::contract_address_const::<1122>();
    starknet::testing::set_contract_address(cmin_addr);
    Cmin::constructor(123456789);

    // Use the call_contract syscall encapsulated into the dispatcher.
    let dispatcher = ICminDispatcher { contract_address: cmin_addr };
    let res = dispatcher.get_val();

    assert(res == 123456789, 'get_val failed');
}
```

In the example above, you can see caironet in action.
In this example, the `call_contract` is done in the test function.
But you can imagine a contract calling an other contract. Refer to the following
sections for more examples.

## Configuration

To mock addresses, you have two choices:

### Local mocking

In the `cairo-test` runner, every test runs in a new state. Which means that
any contract storage for instance is reset (even if you use the same address).

To only mock an address for a test, you can do the following:

```rust
#[test]                                                                                                                                                                                       
#[available_gas(2000000)]
#[caironet(Contract1: 0x123, Contract2: 7788)]
fn test_1() {
    ...
}
```

With this syntax, the mocking will only be effective for the scope of `test_1` function.

### Global mocking

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

Any mapping here is global, an injected in all your tests.

The most important requirement is that, the first level keys are always the
exact name of your contracts. The case **MUST** be respected.

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

## Examples

You can find a complete working example in the `tests/caironet` directory [here](https://github.com/glihm/cairo/blob/1.1.0/tests/caironet/tests/test_1.cairo).  
The examples are commented with detailed explanations.

To test run the tests of this repo:

```bash
cd tests/caironet
scarb run test-caironet

// To show the mocking output, add the argument --show-mock.
scarb run test-caironet --show-mock

// If you only want to run tests with specific names, use the --filter option.
scarb run test-caironet --filter test_erc721_call
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
test-caironet = "sudo docker run --rm -v $(pwd):/project -t --entrypoint cairo-test glihm/caironet:1.1.0-d --starknet /project/"
```
The docker tag is always the cairo-compile version (`1.1.0` in this example), with an incremental version of `caironet` (`d` in this example).
Consider to always run `cairo-test` with `--starknet` plugin.

To compile locally, use `cargo build --package cairo-lang-test-runner --release`

```toml
[scripts]
test-caironet = "/path/caironet/target/release/cairo-test --starknet ."
```

## Testing contracts that are outside your package

(**Before any testing, do not forget to run `scarb build` to ensure that all dependencies are fecthed by Scarb**)

You can run integration testing, using contracts outside of your package.
An example is given testing [here](https://github.com/glihm/cairo/blob/1.1.0/tests/caironet_scarb/tests/test_erc20_call.cairo)
the contract [balance_checker.cairo](https://github.com/glihm/cairo/blob/1.1.0/tests/caironet_scarb/src/balance_checker.cairo)
which depends on the OpenZeppelin standard.

In this example, the dependency is managed with Scarb, and the test runner is using
the dependency pulled by scarb to run the test.

When doing so, the imported contracts may also have tests to run. In order to
only run the test you want, you can use the `--filter` option from the `cairo-test` command.

First, check the [Scarb.toml file](https://github.com/glihm/caironet/blob/1.1.0/tests/caironet_scarb/Scarb.toml) of this example and you will see that the docker as two volumes,
to ensure that all dependencies pulled by scarb can be located correctly.
Do not forget to adapt to your location. I have tried to use `$(echo $HOME)` instead
but it looks like the variable is not set in the environment of the execution in `scarb run`.

To run this example you have to do:
```bash
cd tests/caironet_scarb/
scarb run test-caironet --filter test_erc20_call
```

Try to run without this filter, and you will see all OpenZeppellin tests running too.

**Important note**, Scarb is planning to totally integrate the `cairo_project.toml`,
which will make the built-in test runner not able to find dependencies.
Caironet will adapt to that in order to keep being compatible to scarb, or native contract testing.

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

Also, scarb is planning to integrate the `cairo_project.toml` which is used by the
compiler to locate crates. Caironet will adapt to thoses changes.

## Disclaimer

Caironet is provided **as is**, and it still experimental.
It is not subject to grow neither to match all the features that the tools like protostar are providing.
