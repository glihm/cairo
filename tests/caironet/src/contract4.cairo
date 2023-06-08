// ** contract 4 **
//
// Testing a way to call contracts using the call_contract_syscall
// instead of the dispatcher.
//

#[contract]
mod Contract4 {

    use array::ArrayTrait;

    use starknet::ContractAddress;
    use starknet::SyscallResult;

    #[view]
    fn val_set_syscall(c1_addr: ContractAddress, v: felt252) {

        // Selector for `val_set` method.
        let val_set_selector: felt252 = 0x016eaa2574b6ad33938e95bc4d56ddccaf585ae40e968a822b79e429bc4b4cc6;

        // Selector for `valSet` method.
        let val_set_selector_camel: felt252 = 0x02890a111e55b1fc328cf28a61d1ab334b1904f2a0f6808e3fc2c2330a57f82f;

        let mut calldata = ArrayTrait::new();
        calldata.append(v);

        let r = starknet::call_contract_syscall(c1_addr, val_set_selector_camel, calldata.span());
        match r {
            // Here we can use a Span<felt252> if needed, in this case we discard the output.
            Result::Ok(_) => {},
            Result::Err(revert_reason) => {
                match starknet::call_contract_syscall(c1_addr, val_set_selector, calldata.span()) {
                    Result::Ok(_) => {},
                    Result::Err(revert_reason) => panic(revert_reason)
                }
            }
        };
    }

}
