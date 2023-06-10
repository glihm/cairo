// Integration tests with external ERC721 contract.

use caironet_scarb::nft_operator::NFTOperator;

use integer::u256;
use integer::u256_from_felt252;

use starknet::ContractAddress;
use starknet::contract_address_const;

use starknet::testing::set_contract_address;
use starknet::testing::set_caller_address;

use openzeppelin::token::erc721::ERC721;

#[test]
#[available_gas(2000000)]
fn nft_operator_authorized() {

    let JOHN_ADDR: ContractAddress = contract_address_const::<0x12>();
    let DOE_ADDR: ContractAddress = contract_address_const::<0xdd>();

    let DUO_5123_TOKEN: u256 = u256_from_felt252(5123);

    // First, initialize the ERC721 collection.
    let EVERAI_DUO_COLLECTION_ADDR: ContractAddress = contract_address_const::<0x7777>();

    // Set the address to ensure we target the correct storage.
    set_contract_address(EVERAI_DUO_COLLECTION_ADDR);
    ERC721::constructor('EveraiDuo', 'EveraiDuo');

    // Let's mint. It's interesting to see that in testing, we can call private functions.
    // This is usually not something to do from the outside of the contract unit testing.
    // In the current example, it's to avoid to rewrite a ERC721 contract.
    // But in your production contract, you must customize how the mint is done,
    // who can mint, etc...
    ERC721::_mint(JOHN_ADDR, DUO_5123_TOKEN);

    // Then, let's initialize our contract.
    let OPERATOR_ADDR: ContractAddress = contract_address_const::<0x9898>();
    set_contract_address(OPERATOR_ADDR);
    NFTOperator::constructor(EVERAI_DUO_COLLECTION_ADDR);


    // You can try to uncomment the line of code with the call below
    // and see how the test fails, due to the lack of approval.
    // You should see OZ error: ('ERC721: unauthorized caller')
    //
    // NFTOperator::authorized_transfer(JOHN_ADDR, DOE_ADDR, DUO_5123_TOKEN);


    // Let's say JOHN will give the approval to the NTF operator to transfer
    // his DUO 5123.
    set_contract_address(EVERAI_DUO_COLLECTION_ADDR);

    // The caller must be JOHN as the owner of the duo.
    set_caller_address(JOHN_ADDR);
    ERC721::approve(OPERATOR_ADDR, DUO_5123_TOKEN);
    
    // Now the operator can transfer on the behalf of JOHN.
    // Remember that we've to switch the address to target the good storage.
    set_contract_address(OPERATOR_ADDR);
    NFTOperator::authorized_transfer(JOHN_ADDR, DOE_ADDR, DUO_5123_TOKEN);

    set_contract_address(EVERAI_DUO_COLLECTION_ADDR);
    assert(ERC721::owner_of(DUO_5123_TOKEN) == DOE_ADDR, 'Operator transfer failed');
}
