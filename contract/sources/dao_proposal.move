module fibre::dao_proposal {
    use std::string::{Self, String};
    use std::vector;

    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::dynamic_field as field;

    use fibre::dao::{Self, Dao};
    use fibre::dao_member::{Self, Member};
    use fibre::number::{Self, Number};
    use fibre::error;

    struct CoinTransferProposal<phantom T> has key, store {
        id: UID,
        amount: u64,
        recipient: address
    }

    struct PollProposal has key, store {
        id: UID,
        options: vector<String>
    }

    struct Proposal has key, store {
        id: UID,
        type: u8,
        status: u8,
        title: String,
        text: String,
        proposer: address,
        pointer: u64,
        member_votes: Table<address, u8>,
        votes_count: Table<u8, Number>,
    }

    const DYNAMIC_FIELD_KEY: u8 = 0;

    const PROPOSAL_TYPE: u8 = 0;
    const POLL_PROPOSAL_TYPE: u8 = 1;
    const COIN_TRANSFER_PROPOSAL_TYPE: u8 = 2;

    const ACTIVE_STATUS: u8 = 0;
    const APPROVED_STATUS: u8 = 1;
    const REJECTED_STATUS: u8 = 2;

    const VOTE_YES: u8 = 0;
    const VOTE_NO: u8 = 1;

    fun new(type: u8, title: vector<u8>, text: vector<u8>, pointer: u64, ctx: &mut TxContext): Proposal {
        let id = object::new(ctx);

        Proposal {
            id,
            type,
            pointer,
            status: ACTIVE_STATUS,
            title: string::utf8(title),
            text: string::utf8(text),
            proposer: tx_context::sender(ctx),
            member_votes: table::new(ctx),
            votes_count: table::new(ctx)
        }
    }

    fun record_proposal(dao: &mut Dao, proposal: Proposal) {
        let dao_proposals = dao::proposals_mut(dao);

        vector::push_back(dao_proposals, object::id(&proposal));
        dao::increment_proposals_count(dao);

        transfer::share_object(proposal);
    }

    public entry fun create_proposal<T>(dao: &mut Dao, title: vector<u8>, text: vector<u8>, ctx: &mut TxContext) {
        let proposal = new(PROPOSAL_TYPE, title, text, dao::proposals_count(dao), ctx);
        record_proposal(dao, proposal);
    }

    public entry fun create_poll_proposal(dao: &mut Dao, text: vector<u8>, options: vector<vector<u8>>, ctx: &mut TxContext) {
        assert!(!vector::is_empty(&options), error::empty_poll_option());

        let proposal = new(POLL_PROPOSAL_TYPE, b"Poll Proposal", text, dao::proposals_count(dao), ctx);

        let string_options = vector::empty<String>();
        let i = 0;

        while(vector::length(&string_options) < vector::length(&options)) {
            let option = vector::borrow(&options, i);
            vector::push_back(&mut string_options, string::utf8(*option));

            i = i + 1;
        };

        let value = PollProposal {
            id: object::new(ctx),
            options: string_options
        };

        field::add<u8, PollProposal>(&mut proposal.id, DYNAMIC_FIELD_KEY, value);
        record_proposal(dao, proposal);
    }

    public entry fun create_coin_transfer_proposal<T>(dao: &mut Dao, text: vector<u8>, amount: u64, recipient: address, ctx: &mut TxContext) {
        let proposal = new(COIN_TRANSFER_PROPOSAL_TYPE, b"Coin Transfer Proposal", text, dao::proposals_count(dao), ctx);

        let value = CoinTransferProposal<T> {
            id: object::new(ctx),
            amount,
            recipient
        };

        field::add<u8, CoinTransferProposal<T>>(&mut proposal.id, DYNAMIC_FIELD_KEY, value);
        record_proposal(dao, proposal);
    }

    public entry fun vote_proposal(dao: &mut Dao, proposal: &mut Proposal, member: &mut Member, vote: u8, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        dao_member::assert_member(dao, sender);
        dao_member::assert_member_id(dao, member, ctx);

        assert_not_voted(proposal, sender);


        // let prop = vector::borrow(dao::proposals(dao), proposal.pointer);


        if(table::contains(&proposal.votes_count, vote)) {
            let votes_count = table::borrow_mut(&mut proposal.votes_count, vote);
            number::add(votes_count, 1);
        } else {
            table::add(&mut proposal.votes_count, vote, number::new(1));
        };
        
        table::add(&mut proposal.member_votes, sender, vote);
    }

    fun has_voted(proposal: &Proposal, address: address): bool {
        table::contains(&proposal.member_votes, address)
    }

    fun votes_count(proposal: &Proposal, vote: u8): &Number {
        table::borrow(&proposal.votes_count, vote)
    }

    fun assert_not_voted(proposal: &Proposal, address: address) {
        assert!(!has_voted(proposal, address), error::already_voted_proposal())
    }
}