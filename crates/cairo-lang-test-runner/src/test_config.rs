use std::collections::HashMap;

use cairo_felt::Felt252;
use cairo_lang_defs::plugin::PluginDiagnostic;
use cairo_lang_syntax::attribute::structured::{Attribute, AttributeArg, AttributeArgVariant};
use cairo_lang_syntax::node::ast;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_utils::OptionHelper;
use num_traits::ToPrimitive;

use crate::mock::MockConfig;

/// Expectation for a panic case.
pub enum PanicExpectation {
    /// Accept any panic value.
    Any,
    /// Accept only this specific vector of panics.
    Exact(Vec<Felt252>),
}

/// Expectation for a result of a test.
pub enum TestExpectation {
    /// Running the test should not panic.
    Success,
    /// Running the test should result in a panic.
    Panics(PanicExpectation),
}

/// The configuration for running a single test.
pub struct TestConfig {
    /// The amount of gas the test requested.
    pub available_gas: Option<usize>,
    /// The expected result of the run.
    pub expectation: TestExpectation,
    /// Should the test be ignored.
    pub ignored: bool,
    /// Caironet addresses mapping.
    /// Only simple mocked address is supported for now.
    pub caironet: HashMap<String, MockConfig>,
}

/// Extracts the configuration of a tests from attributes, or returns the diagnostics if the
/// attributes are set illegally.
pub fn try_extract_test_config(
    db: &dyn SyntaxGroup,
    attrs: Vec<Attribute>,
) -> Result<Option<TestConfig>, Vec<PluginDiagnostic>> {
    let test_attr = attrs.iter().find(|attr| attr.id.as_str() == "test");
    let ignore_attr = attrs.iter().find(|attr| attr.id.as_str() == "ignore");
    let available_gas_attr = attrs.iter().find(|attr| attr.id.as_str() == "available_gas");
    let should_panic_attr = attrs.iter().find(|attr| attr.id.as_str() == "should_panic");
    let caironet_attr = attrs.iter().find(|attr| attr.id.as_str() == "caironet");

    let mut diagnostics = vec![];
    if let Some(attr) = test_attr {
        if !attr.args.is_empty() {
            diagnostics.push(PluginDiagnostic {
                stable_ptr: attr.id_stable_ptr.untyped(),
                message: "Attribute should not have arguments.".into(),
            });
        }
    } else {
        for attr in [ignore_attr, available_gas_attr, should_panic_attr].into_iter().flatten() {
            diagnostics.push(PluginDiagnostic {
                stable_ptr: attr.id_stable_ptr.untyped(),
                message: "Attribute should only appear on tests.".into(),
            });
        }
    }
    let ignored = if let Some(attr) = ignore_attr {
        if !attr.args.is_empty() {
            diagnostics.push(PluginDiagnostic {
                stable_ptr: attr.id_stable_ptr.untyped(),
                message: "Attribute should not have arguments.".into(),
            });
        }
        true
    } else {
        false
    };

    let available_gas = if let Some(attr) = available_gas_attr {
        if let [
            AttributeArg {
                variant: AttributeArgVariant::Unnamed { value: ast::Expr::Literal(literal), .. },
                ..
            },
        ] = &attr.args[..]
        {
            literal.numeric_value(db).unwrap_or_default().to_usize()
        } else {
            diagnostics.push(PluginDiagnostic {
                stable_ptr: attr.id_stable_ptr.untyped(),
                message: "Attribute should have a single value argument.".into(),
            });
            None
        }
    } else {
        None
    };

    let (should_panic, expected_panic_value) = if let Some(attr) = should_panic_attr {
        if attr.args.is_empty() {
            (true, None)
        } else {
            (
                true,
                extract_panic_values(db, attr).on_none(|| {
                    diagnostics.push(PluginDiagnostic {
                        stable_ptr: attr.args_stable_ptr.untyped(),
                        message: "Expected panic must be of the form `expected: <tuple of \
                                  felt252s>`."
                            .into(),
                    });
                }),
            )
        }
    } else {
        (false, None)
    };

    let caironet = if let Some(attr) = caironet_attr {
        extract_caironet_mocks(db, attr)
    } else {
        HashMap::new()
    };

    if !diagnostics.is_empty() {
        return Err(diagnostics);
    }
    Ok(if test_attr.is_none() {
        None
    } else {
        Some(TestConfig {
            available_gas,
            expectation: if should_panic {
                TestExpectation::Panics(if let Some(values) = expected_panic_value {
                    PanicExpectation::Exact(values)
                } else {
                    PanicExpectation::Any
                })
            } else {
                TestExpectation::Success
            },
            ignored,
            caironet,
        })
    })
}

/// Tries to extract the relevant expected panic values.
fn extract_panic_values(db: &dyn SyntaxGroup, attr: &Attribute) -> Option<Vec<Felt252>> {
    let [
        AttributeArg {
            variant: AttributeArgVariant::Named { name, value: panics, .. },
            ..
        }
    ] = &attr.args[..] else {
        return None;
    };
    if name != "expected" {
        return None;
    }
    let ast::Expr::Tuple(panics) = panics else { return None };
    panics
        .expressions(db)
        .elements(db)
        .into_iter()
        .map(|value| match value {
            ast::Expr::Literal(literal) => {
                Some(literal.numeric_value(db).unwrap_or_default().into())
            }
            ast::Expr::ShortString(literal) => {
                Some(literal.numeric_value(db).unwrap_or_default().into())
            }
            _ => None,
        })
        .collect::<Option<Vec<_>>>()
}

/// Tries to extract mocks mappings for caironet.
/// Mappings are expected to be named attributes: #[caironet(contract1: 0x1234, contract2: 1888)].
/// Only literal are supported at it's an address.
fn extract_caironet_mocks(
    db: &dyn SyntaxGroup,
    attr: &Attribute
) -> HashMap<String, MockConfig> {

    let mut mocks: HashMap<String, MockConfig> = HashMap::new();

    let mut mappings_instances: HashMap<String, HashMap<String, String>> = HashMap::new();

    attr.args.iter().for_each(|a| {
        match &a.variant {
            AttributeArgVariant::Named { name, value, .. } => {
                let contract_name = name.to_string();
                let mut contract_instance: Option<String> = None;
                let mut contract_address: Option<String> = None;

                match value {
                    ast::Expr::Literal(literal) => {
                        contract_address = Some(literal
                            .numeric_value(db)
                            .unwrap_or_default()
                            .to_string());
                    },
                    ast::Expr::Tuple(vals) => {
                        vals.expressions(db)
                            .elements(db)
                            .into_iter()
                            .for_each(|value| match value {
                                ast::Expr::Literal(literal) => {
                                    contract_address = Some(
                                        literal.numeric_value(db).unwrap_or_default().to_string());
                                }
                                ast::Expr::ShortString(literal) => {
                                    contract_instance = Some(
                                        literal.numeric_value(db).unwrap_or_default().to_string());
                                }
                                _ => (),
                            });
                    }
                    _ => return ()
                };

                // Literal or Tuple, an address is expected in any cases.
                // The contract address is always a literal.
                let contract_address = match contract_address {
                    Some(addr) => addr,
                    None => {
                        // println!("No address found for contract {:?}", contract_name);
                        return ();
                    }
                };

                match contract_instance {
                    Some(i) => {
                        // Keep the mapping to later construct the InstancesAddress.
                        if mappings_instances.contains_key(&contract_name) {
                            mappings_instances
                                .get_mut(&contract_name)
                                .expect("HashMap of instance mappings not init")
                                .insert(i, contract_address);
                        } else {
                            let mut h = HashMap::new();
                            h.insert(i, contract_address);
                            mappings_instances.insert(contract_name, h);
                        }
                    },
                    None => {
                        // Directly register the singleton.
                        mocks.insert(contract_name, MockConfig::SingletonAddress(contract_address));
                        return ();
                    }
                };
            },
            _ => ()
        }
    });

    for (contract_name, instances) in mappings_instances {
        let mock = MockConfig::InstanceAddresses(instances);
        mocks.insert(contract_name, mock);
    }

    //println!("MOCKS FROM ATTR {:?}", mocks);
    mocks
}
