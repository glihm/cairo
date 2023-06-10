// ** NFT operator **
//
// A contract that moves NFTs on the
// behalfs of user, with a previous approval.
//

#[contract]
mod NFTOperator {

    use starknet::ContractAddress;
    use starknet::contract_address::ContractAddressZeroable;

    use openzeppelin::token::erc721::ERC721;
    use openzeppelin::token::erc721::interface::IERC721Dispatcher;
    use openzeppelin::token::erc721::interface::IERC721DispatcherTrait;

    struct Storage {
        // Address of the NFT collection to work with.
        _erc721_addr: ContractAddress,
    }

    #[constructor]
    fn constructor(erc721_addr: ContractAddress) {
        assert(erc721_addr != ContractAddressZeroable::zero(), 'Ctor ERC721 address');
        _erc721_addr::write(erc721_addr);
    }

    // This transfer requires a previous approval to be authorized by the ERC721 contract.
    // If no approval was given for the corresponding token (or the whole collection), this call
    // will revert.
    #[view]
    fn authorized_transfer(from: ContractAddress, to: ContractAddress, token_id: u256) {
        assert(from != ContractAddressZeroable::zero(), 'From address');
        assert(to != ContractAddressZeroable::zero(), 'to address');
        IERC721Dispatcher { contract_address: _erc721_addr::read() }.transfer_from(from, to, token_id);
    }

}
