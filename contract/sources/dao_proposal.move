module fibre::dao_proposal {
    use std::string::{Self, String};
    use std::vector;
    use std::type_name::{Self, TypeName};

    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use fibre::dao::{Self, Dao};

    struct Proposal has key, store {
        id: UID,
        type: TypeName,
        status: TypeName,
        text: String,
        proposer: address
    }

    entry fun new<T: store, S: store>(dao: &mut Dao,text: vector<u8>, ctx: &mut TxContext) {
        let proposal = create_proposal<T, S>(text, ctx);
        let proposal_ids = dao::get_proposal_ids(dao);

        vector::push_back(&mut proposal_ids, object::id(&proposal));
        transfer::share_object(proposal);
    }

    public fun create_proposal<T: store, S: store>(text: vector<u8>, ctx: &mut TxContext): Proposal {
        Proposal {
            id: object::new(ctx),
            type: type_name::get<T>(),
            status: type_name::get<S>(),
            text: string::utf8(text),
            proposer: tx_context::sender(ctx)
        }
    }
}