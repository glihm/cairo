// Integration tests with external ERC20 contract use to check balances.

use caironet::balance_checker::BalanceChecker;

use integer::u256;
use integer::u256_from_felt252;

use starknet::ContractAddress;
use starknet::contract_address_const;

use starknet::testing::set_contract_address;
use starknet::testing::set_caller_address;

use openzeppelin::token::erc20::ERC20;

#[test]
#[available_gas(2000000)]
fn test_balance_checker() {

    // First, initialize the ERC20 with initial supply and to which
    // account we use to mint the inital supply.
    let ERC20_ADDR: ContractAddress = contract_address_const::<20>();
    let ACCOUNT_WITH_ERC20_ADDR: ContractAddress = contract_address_const::<0x12345678>();
    let initial_supply: u256 = u256_from_felt252(9999);

    // Remember to set the contract address to the balance checker before
    // constructor to use the correct storage location.
    set_contract_address(ERC20_ADDR);
    ERC20::constructor('Ether', 'ETH', initial_supply, ACCOUNT_WITH_ERC20_ADDR);

    // Switch to balance checker init.
    let BALANCE_CHECKER_ADDR: ContractAddress = contract_address_const::<0xbac>();
    let MIN_BALANCE: u256 = u256_from_felt252(10);

    // Remember to set the contract address to the balance checker before
    // constructor to use the correct storage location.
    set_contract_address(BALANCE_CHECKER_ADDR);
    BalanceChecker::constructor(ERC20_ADDR, MIN_BALANCE);

    let EVE_ADDR: ContractAddress = contract_address_const::<0x9877>();
    // Let's verify that the EVE has not enough balance yet.
    assert(BalanceChecker::ensure_minimum_balance_of(EVE_ADDR) == false,
           'EVE balance not enough');

    // Transfer some funds to EVE as if it was the account with initial supply
    // making the call.
    set_caller_address(ACCOUNT_WITH_ERC20_ADDR);
    set_contract_address(ERC20_ADDR);
    let amount: u256 = u256_from_felt252(10);
    let success: bool = ERC20::transfer(EVE_ADDR, amount);

    assert(success == true, 'EVE transfert funds');

    set_contract_address(BALANCE_CHECKER_ADDR);
    assert(BalanceChecker::ensure_minimum_balance_of(EVE_ADDR) == true,
           'EVE balance not enough');

}
