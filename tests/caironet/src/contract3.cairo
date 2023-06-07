// ** contract 3 **
//
// A very simple contract which can only be called
// from a specific instance of contract 1.
//

#[contract]
mod Contract3 {

    use starknet::ContractAddress;
    use starknet::get_caller_address;

    struct Storage {
        _c1_addr: ContractAddress,
    }

    #[constructor]
    fn constructor(c1_addr: ContractAddress) {
        _c1_addr::write(c1_addr);
    }

    #[view]
    fn call_me() {
        assert(get_caller_address() == _c1_addr::read(), 'Unauthorized call');
    }
}
