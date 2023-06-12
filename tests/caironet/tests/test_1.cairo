use caironet::contract1::Contract1;
use caironet::contract2::Contract2;
use caironet::contract3::Contract3;
use caironet::contract4::Contract4;

use starknet::ContractAddress;
use starknet::contract_address_const;

use starknet::testing::set_contract_address;
use starknet::testing::set_caller_address;

// Integration tests, where we use the mocked addresses.

// Our testing function. Everything is in the same test
// for demo purposes only.
#[test]
#[available_gas(2000000)]
fn test_c1_c2_interaction() {

    // JOHN and DOE addresses here must be placed into the .caironet.json located at the root of your project
    // file to be considered as "deployed", as to be able to call the corresponding
    // dispatchers.
    let JOHN_ADDR: ContractAddress = contract_address_const::<1010>();
    let DOE_ADDR: ContractAddress = contract_address_const::<0x1234>();
    let C2_ADDR: ContractAddress = contract_address_const::<99>();

    // Go to the contract1 JOHN addr, construct to init the storage.
    set_contract_address(JOHN_ADDR);
    Contract1::constructor('JOHN', 200);
    assert(Contract1::name_get() == 'JOHN', 'JOHN ctor name');
    assert(Contract1::val_get() == 200, 'JOHN ctor val');

    // Let's switch to the contract1 DOE address to init it's storage.
    set_contract_address(DOE_ADDR);
    Contract1::constructor('DOE', 10);
    assert(Contract1::name_get() == 'DOE', 'DOE ctor name');
    assert(Contract1::val_get() == 10, 'DOE ctor val');

    // So here, using `set_contract_address` we can control which
    // instance of contract we want to manipulate.
    // Let's see an example below:

    // We still use the DOE addr, set few lines above.
    assert(Contract1::name_get() == 'DOE', 'DOE name');

    // Explicit change to JOHN addr.
    set_contract_address(JOHN_ADDR);
    assert(Contract1::name_get() == 'JOHN', 'JOHN name');

    // Now, let's use a contract 2 instance to actually call
    // contract 1 ones.

    // Setup our new instance with it's own storage.
    set_contract_address(C2_ADDR);
    Contract2::constructor();

    // Modify some contract 1 values.
    Contract2::contract1_val_set(JOHN_ADDR, 111);
    Contract2::contract1_val_set(DOE_ADDR, 222);

    // Note here as we didn't need to use `set_contract_address` to actually
    // call them, because they are already registered in the StarknetState mapping,
    // so the runner will automatically map the address to the class hash to execute
    // the correct code, and the address also redirects to the respective storage of
    // each contracts (JOHN and DOE) correctly.
    
    // Let's verify the values. Note the use of `set_contract_address` to
    // newly target the storage we want based on the address.
    set_contract_address(JOHN_ADDR);
    assert(Contract1::val_get() == 111, 'JOHN val');

    set_contract_address(DOE_ADDR);
    assert(Contract1::val_get() == 222, 'DOE val');

    // Ensure that we registered correctly the 2 contract1_val_set calls
    // into the C2 storage.
    set_contract_address(C2_ADDR);
    assert(Contract2::counter_get() == 2, 'C2 counter');
}

// Let's see an example where `set_contract_address` is not used
// where it should be.
#[test]
#[available_gas(2000000)]
fn test_bad_set_address() {

    // Those addresses here must be placed into the .caironet.json located at the root of your project
    // file to be considered as deployed.
    let JOHN_ADDR: ContractAddress = contract_address_const::<1010>();
    let DOE_ADDR: ContractAddress = contract_address_const::<0x1234>();

    // Go to the contract1 JOHN addr, construct to init the storage.
    set_contract_address(JOHN_ADDR);
    Contract1::constructor('JOHN', 200);
    assert(Contract1::name_get() == 'JOHN', 'JOHN ctor name');
    assert(Contract1::val_get() == 200, 'JOHN ctor val');

    // We forget here to set the address to DOE...!
    // So we are using the SAME storage as we used at the address of JOHN.
    // Note that the assert works fine, as we actually update the storage correctly,
    // but we are overwritting the storage of JOHN.
    Contract1::constructor('DOE', 10);
    assert(Contract1::name_get() == 'DOE', 'DOE ctor name');
    assert(Contract1::val_get() == 10, 'DOE ctor val');

    // Let's check the mistake, re-set explicitely to JOHN, and we will see
    // DOE name and value.
    set_contract_address(JOHN_ADDR);
    assert(Contract1::name_get() == 'DOE', 'DOE mistake name');
    assert(Contract1::val_get() == 10, 'DOE mistake val');
}

// Test how set_caller_address must be used to simulate the contract
// address that is calling.
// In the case of `set_caller_address` we are only indicating to the runner
// which address we want to mock for the caller.
// THIS IS NOT changing the executing contract address, and then has no effect
// on which storage we are using.
#[test]
#[should_panic()]
#[available_gas(2000000)]
fn test_set_caller_address() {

    // Those addresses here must be placed into the .caironet.json located at the root of your project
    // file to be considered as deployed.
    let JOHN_ADDR: ContractAddress = contract_address_const::<1010>();
    let DOE_ADDR: ContractAddress = contract_address_const::<0x1234>();
    let C3_ADDR: ContractAddress = contract_address_const::<33>();

    // We don't need to actually contruct or deploy JOHN and DOE, as we
    // are not using their storage / dispatchers.

    // Let's now initialize the instance of contract 3 to only be callable from
    // JOHN. Remember, each time we want to deal with a contract instance
    // with storage, we must set the address accordingly.
    set_contract_address(C3_ADDR);
    Contract3::constructor(JOHN_ADDR);

    // Simulate that it's JOHN calling.
    set_caller_address(JOHN_ADDR);
    Contract3::call_me();

    // This one will cause a panic, which is expected by the test.
    set_caller_address(DOE_ADDR);
    Contract3::call_me();
}

// Test the use of call_contract_syscall to
// use some fallback in case that a selector does not exist.
#[test]
#[available_gas(2000000)]
fn test_call_contract_syscall() {

    let JOHN_ADDR: ContractAddress = contract_address_const::<1010>();
    let DOE_ADDR: ContractAddress = contract_address_const::<0x1234>();
    let C4_ADDR: ContractAddress = contract_address_const::<44>();

    set_contract_address(JOHN_ADDR);
    Contract1::constructor('JOHN', 200);
    assert(Contract1::name_get() == 'JOHN', 'JOHN ctor name');
    assert(Contract1::val_get() == 200, 'JOHN ctor val');

    set_contract_address(DOE_ADDR);
    Contract1::constructor('DOE', 10);
    assert(Contract1::name_get() == 'DOE', 'DOE ctor name');
    assert(Contract1::val_get() == 10, 'DOE ctor val');

    set_contract_address(C4_ADDR);
    // Contract4 has no custom constructor, so we don't need to call it.

    // Modify some contract 1 values.
    Contract4::val_set_syscall(JOHN_ADDR, 111);
    Contract4::val_set_syscall(DOE_ADDR, 222);

    set_contract_address(JOHN_ADDR);
    assert(Contract1::val_get() == 111, 'JOHN val');

    set_contract_address(DOE_ADDR);
    assert(Contract1::val_get() == 222, 'DOE val');
}
