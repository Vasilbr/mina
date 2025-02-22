use kimchi::{
    circuits::{
        constraints::FeatureFlags,
        expr::Linearization,
        lookup::lookups::{LookupFeatures, LookupPatterns},
    },
    linearization::{constraints_expr, linearization_columns},
};

/// Converts the linearization of the kimchi circuit polynomial into a printable string.
pub fn linearization_strings<F: ark_ff::PrimeField + ark_ff::SquareRootField>(
    lookup_features: Option<LookupFeatures>,
) -> (String, Vec<(String, String)>) {
    let feature_flags = match lookup_features {
        None => None,
        Some(lookup_features) => Some(FeatureFlags {
            chacha: false,
            range_check: false,
            rot: false,
            foreign_field_add: false,
            foreign_field_mul: false,
            xor: false,
            lookup_features,
        }),
    };
    let evaluated_cols = linearization_columns::<F>(feature_flags.as_ref());
    let (linearization, _powers_of_alpha) = constraints_expr::<F>(feature_flags.as_ref(), true);

    let Linearization {
        constant_term,
        mut index_terms,
    } = linearization.linearize(evaluated_cols).unwrap();

    // HashMap deliberately uses an unstable order; here we sort to ensure that the output is
    // consistent when printing.
    index_terms.sort_by(|(x, _), (y, _)| x.cmp(y));

    let constant = constant_term.ocaml_str();
    let other_terms = index_terms
        .iter()
        .map(|(col, expr)| (format!("{:?}", col), expr.ocaml_str()))
        .collect();

    (constant, other_terms)
}

pub fn lookup_gate_config(
) -> LookupFeatures {
    LookupFeatures {
        patterns: LookupPatterns {
            xor: false,
            chacha_final: false,
            lookup: true,
            range_check: false,
            foreign_field_mul: false,
        },
        joint_lookup_used: true,
        uses_runtime_tables: true,
    }
}

#[ocaml::func]
pub fn fp_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fp>(None)
}

#[ocaml::func]
pub fn fq_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fq>(None)
}

#[ocaml::func]
pub fn fp_lookup_gate_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fp>(Some(lookup_gate_config()))
}

#[ocaml::func]
pub fn fq_lookup_gate_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fq>(Some(lookup_gate_config()))
}
