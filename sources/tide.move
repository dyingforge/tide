module tide::tide;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::event;
use sui::clock::{Self, Clock};

const EMarketNotActive: u64 = 1;
const EInvalidBetAmount: u64 = 2;
const EMarketNotResolved: u64 = 3;
const EInvalidMarketState: u64 = 5;
const EWrongMarket: u64 = 6;
const EBetAlreadySettled: u64 = 7;
const ENoFeeToWithdraw: u64 = 8;

const MARKET_ACTIVE: u8 = 0;
const MARKET_RESOLVED_YES: u8 = 1;
const MARKET_RESOLVED_NO: u8 = 2;
const MARKET_VOIDED: u8 = 3;

const FEE_RATE_BASIS_POINTS: u64 = 200;
const BASIS_POINTS: u64 = 10000;

public struct AdminCap has key, store {
    id: UID,
}

public struct Market has key, store {
    id: UID,
    question: std::string::String,
    yes_pool: Balance<SUI>,
    no_pool: Balance<SUI>,
    fee_pool: Balance<SUI>,
    state: u8,
    created_at: u64,
    end_time: u64,
    resolved_at: u64,
    total_yes_amount: u64,
    total_no_amount: u64,
}

public struct BetTicket has key, store {
    id: UID,
    market_id: ID,
    user: address,
    side: bool,
    amount: u64,
    settled: bool,
}

public struct MarketCreated has copy, drop {
    market_id: ID,
    question: std::string::String,
    created_at: u64,
    end_time: u64,
}

public struct BetPlaced has copy, drop {
    market_id: ID,
    user: address,
    side: bool,
    amount: u64,
    ticket_id: ID,
}

public struct MarketResolved has copy, drop {
    market_id: ID,
    result: u8,
    resolved_at: u64,
    yes_pool: u64,
    no_pool: u64,
}

public struct BetSettled has copy, drop {
    ticket_id: ID,
    market_id: ID,
    user: address,
    payout: u64,
}

public struct FeeWithdrawn has copy, drop {
    market_id: ID,
    amount: u64,
    recipient: address,
}

public struct MarketVoided has copy, drop {
    market_id: ID,
    voided_at: u64,
}

fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    transfer::transfer(admin_cap, ctx.sender());
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

public entry fun create_market(
    _: &AdminCap,
    question: std::string::String,
    end_time: u64,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let created_at = clock::timestamp_ms(clock);
    let market_id = object::new(ctx);
    
    event::emit(MarketCreated {
        market_id: object::uid_to_inner(&market_id),
        question,
        created_at,
        end_time,
    });

    let market = Market {
        id: market_id,
        question,
        yes_pool: balance::zero(),
        no_pool: balance::zero(),
        fee_pool: balance::zero(),
        state: MARKET_ACTIVE,
        created_at,
        end_time,
        resolved_at: 0,
        total_yes_amount: 0,
        total_no_amount: 0,
    };

    transfer::share_object(market);
}

public entry fun place_bet(
    market: &mut Market,
    side: bool,
    payment: Coin<SUI>,
    ctx: &mut TxContext
) {
    assert!(market.state == MARKET_ACTIVE, EMarketNotActive);
    
    let amount = coin::value(&payment);
    assert!(amount > 0, EInvalidBetAmount);

    let balance = coin::into_balance(payment);
    
    if (side) {
        balance::join(&mut market.yes_pool, balance);
        market.total_yes_amount = market.total_yes_amount + amount;
    } else {
        balance::join(&mut market.no_pool, balance);
        market.total_no_amount = market.total_no_amount + amount;
    };

    let ticket_id = object::new(ctx);
    let user = ctx.sender();

    event::emit(BetPlaced {
        market_id: object::uid_to_inner(&market.id),
        user,
        side,
        amount,
        ticket_id: object::uid_to_inner(&ticket_id),
    });

    let ticket = BetTicket {
        id: ticket_id,
        market_id: object::uid_to_inner(&market.id),
        user,
        side,
        amount,
        settled: false,
    };

    transfer::transfer(ticket, user);
}

public entry fun resolve_market(
    _: &AdminCap,
    market: &mut Market,
    result: bool,
    clock: &Clock,
) {
    assert!(market.state == MARKET_ACTIVE, EInvalidMarketState);
    
    let resolved_at = clock::timestamp_ms(clock);
    market.resolved_at = resolved_at;
    market.state = if (result) { MARKET_RESOLVED_YES } else { MARKET_RESOLVED_NO };

    event::emit(MarketResolved {
        market_id: object::uid_to_inner(&market.id),
        result: market.state,
        resolved_at,
        yes_pool: balance::value(&market.yes_pool),
        no_pool: balance::value(&market.no_pool),
    });
}

public entry fun settle_bet(
    market: &mut Market,
    ticket: BetTicket,
    ctx: &mut TxContext
) {
    assert!(market.state != MARKET_ACTIVE, EMarketNotResolved);
    assert!(ticket.market_id == object::uid_to_inner(&market.id), EWrongMarket);
    assert!(!ticket.settled, EBetAlreadySettled);

    let BetTicket { id, market_id: _, user, side, amount, settled: _ } = ticket;
    let ticket_id = object::uid_to_inner(&id);
    object::delete(id);

    let payout_balance = if (market.state == MARKET_VOIDED) {
        if (side) {
            balance::split(&mut market.yes_pool, amount)
        } else {
            balance::split(&mut market.no_pool, amount)
        }
    } else {
        let user_won = (market.state == MARKET_RESOLVED_YES && side) || 
                       (market.state == MARKET_RESOLVED_NO && !side);
        
        if (user_won) {
            let winning_pool_total = if (side) { market.total_yes_amount } else { market.total_no_amount };
            let losing_pool_total = if (side) { market.total_no_amount } else { market.total_yes_amount };

            if (losing_pool_total == 0 || winning_pool_total == 0) {
                if (side) {
                    balance::split(&mut market.yes_pool, amount)
                } else {
                    balance::split(&mut market.no_pool, amount)
                }
            } else {
                let raw_profit = (amount * losing_pool_total) / winning_pool_total;
                let fee = (raw_profit * FEE_RATE_BASIS_POINTS) / BASIS_POINTS;
                let net_profit = raw_profit - fee;
                
                let mut principal = if (side) {
                    balance::split(&mut market.yes_pool, amount)
                } else {
                    balance::split(&mut market.no_pool, amount)
                };

                let profit_balance = if (side) {
                    balance::split(&mut market.no_pool, net_profit)
                } else {
                    balance::split(&mut market.yes_pool, net_profit)
                };

                let fee_balance = if (side) {
                    balance::split(&mut market.no_pool, fee)
                } else {
                    balance::split(&mut market.yes_pool, fee)
                };
                balance::join(&mut market.fee_pool, fee_balance);

                balance::join(&mut principal, profit_balance);
                principal
            }
        } else {
            balance::zero()
        }
    };

    let payout = balance::value(&payout_balance);

    event::emit(BetSettled {
        ticket_id,
        market_id: object::uid_to_inner(&market.id),
        user,
        payout,
    });

    if (payout > 0) {
        let payout_coin = coin::from_balance(payout_balance, ctx);
        transfer::public_transfer(payout_coin, user);
    } else {
        balance::destroy_zero(payout_balance);
    };
}

public entry fun withdraw_fee(
    _: &AdminCap,
    market: &mut Market,
    ctx: &mut TxContext
) {
    let fee_amount = balance::value(&market.fee_pool);
    assert!(fee_amount > 0, ENoFeeToWithdraw);

    let fee_balance = balance::split(&mut market.fee_pool, fee_amount);
    let fee_coin = coin::from_balance(fee_balance, ctx);
    let recipient = ctx.sender();

    event::emit(FeeWithdrawn {
        market_id: object::uid_to_inner(&market.id),
        amount: fee_amount,
        recipient,
    });

    transfer::public_transfer(fee_coin, recipient);
}

public entry fun void_market(
    _: &AdminCap,
    market: &mut Market,
    clock: &Clock,
) {
    assert!(market.state == MARKET_ACTIVE, EInvalidMarketState);
    
    market.state = MARKET_VOIDED;
    let voided_at = clock::timestamp_ms(clock);

    event::emit(MarketVoided {
        market_id: object::uid_to_inner(&market.id),
        voided_at,
    });
}

public fun get_market_state(market: &Market): u8 {
    market.state
}

public fun get_market_pools(market: &Market): (u64, u64) {
    (balance::value(&market.yes_pool), balance::value(&market.no_pool))
}

public fun get_ticket_info(ticket: &BetTicket): (ID, bool, u64, bool) {
    (ticket.market_id, ticket.side, ticket.amount, ticket.settled)
}
