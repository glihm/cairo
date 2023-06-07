// ** contract 2 **
//
// A very simple contract which needs an instance of
// Contract1 to work.
//

// This will generate IContract1Dispatcher
// and IContract1DispatcherTrait.
// See: https://cairo-book.github.io/ch99-02-02-contract-dispatcher-library-dispatcher-and-system-calls.html
#[abi]
trait IContract1 {
    #[external]
    fn val_set(v: felt252);
}

#[contract]
mod Contract2 {

    use starknet::ContractAddress;
    use super::IContract1Dispatcher;
    use super::IContract1DispatcherTrait;

    struct Storage {
        _counter: felt252,
    }

    #[constructor]
    fn constructor() {
        _counter::write(0);
    }

    #[view]
    fn contract1_val_set(c1_addr: ContractAddress, v: felt252) {
        _increment_counter();
        IContract1Dispatcher { contract_address: c1_addr }.val_set(v);
    }

    #[view]
    fn counter_get() -> felt252 {
        _counter::read()
    }

    #[internal]
    fn _increment_counter() {
        _counter::write(_counter::read() + 1);
    }
}
