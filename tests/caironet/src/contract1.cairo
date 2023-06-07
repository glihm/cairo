// ** contract 1 **
//
// A very simple contract with few functionalities.
// We can set a name and a value with the constructor,
// and then only the value to be modified using `val_set`.
//

#[contract]
mod Contract1 {

    struct Storage {
        _name: felt252,
        _val: felt252,
    }

    #[constructor]
    fn constructor(
        name: felt252,
        val: felt252,
    ) {
        _name::write(name);
        _val::write(val);
    }

    #[view]
    fn name_get() -> felt252 {
        _name::read()
    }

    #[view]
    fn val_get() -> felt252 {
        _val::read()
    }

    #[external]
    fn val_set(v: felt252) {
        _val::write(v);
    }

}
