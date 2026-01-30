#[test_only]
module tide::tide_tests {
    use tide::tide::{Self, Market, BetTicket, AdminCap};
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin;
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use std::string;

    const ADMIN: address = @0xAD;
    const USER1: address = @0xA1;
    const USER2: address = @0xA2;
    const USER3: address = @0xA3;

    fun setup_test(): (Scenario, Clock) {
        let mut scenario = ts::begin(ADMIN);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        
        tide::init_for_testing(ts::ctx(&mut scenario));
        
        (scenario, clock)
    }

    #[test]
    fun test_basic_flow_yes_wins() {
        let (mut scenario, clock) = setup_test();
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            tide::create_market(
                &admin_cap,
                string::utf8(b"Will BTC hit 100k?"),
                1000000,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER2);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(500, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, false, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut market = ts::take_shared<Market>(&scenario);
            tide::resolve_market(&admin_cap, &mut market, true, &clock);
            ts::return_shared(market);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_basic_flow_no_wins() {
        let (mut scenario, clock) = setup_test();
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            tide::create_market(
                &admin_cap,
                string::utf8(b"Will ETH flip BTC?"),
                2000000,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(800, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER2);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1200, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, false, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut market = ts::take_shared<Market>(&scenario);
            tide::resolve_market(&admin_cap, &mut market, false, &clock);
            ts::return_shared(market);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER2);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_void_market_refund() {
        let (mut scenario, clock) = setup_test();
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            tide::create_market(
                &admin_cap,
                string::utf8(b"Invalid question"),
                3000000,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(2000, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER2);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1500, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, false, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut market = ts::take_shared<Market>(&scenario);
            tide::void_market(&admin_cap, &mut market, &clock);
            ts::return_shared(market);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER2);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_fee_withdrawal() {
        let (mut scenario, clock) = setup_test();
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            tide::create_market(
                &admin_cap,
                string::utf8(b"Fee test market"),
                4000000,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(5000, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER2);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(3000, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, false, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut market = ts::take_shared<Market>(&scenario);
            tide::resolve_market(&admin_cap, &mut market, true, &clock);
            ts::return_shared(market);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut market = ts::take_shared<Market>(&scenario);
            tide::withdraw_fee(&admin_cap, &mut market, ts::ctx(&mut scenario));
            ts::return_shared(market);
            ts::return_to_sender(&scenario, admin_cap);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_multiple_bets_same_side() {
        let (mut scenario, clock) = setup_test();
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            tide::create_market(
                &admin_cap,
                string::utf8(b"Multiple bets test"),
                5000000,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER2);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1500, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER3);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(500, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, false, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut market = ts::take_shared<Market>(&scenario);
            tide::resolve_market(&admin_cap, &mut market, true, &clock);
            ts::return_shared(market);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER2);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER3);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_market_state_getters() {
        let (mut scenario, clock) = setup_test();
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            tide::create_market(
                &admin_cap,
                string::utf8(b"State test market"),
                6000000,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let market = ts::take_shared<Market>(&scenario);
            let state = tide::get_market_state(&market);
            assert!(state == 0, 0);
            let (yes_pool, no_pool) = tide::get_market_pools(&market);
            assert!(yes_pool == 0 && no_pool == 0, 1);
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(100, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let market = ts::take_shared<Market>(&scenario);
            let (yes_pool, no_pool) = tide::get_market_pools(&market);
            assert!(yes_pool == 100 && no_pool == 0, 2);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_invalid_bet_amount() {
        let (mut scenario, clock) = setup_test();
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            tide::create_market(
                &admin_cap,
                string::utf8(b"Test market"),
                7000000,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_bet_on_resolved_market() {
        let (mut scenario, clock) = setup_test();
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            tide::create_market(
                &admin_cap,
                string::utf8(b"Test market"),
                8000000,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(100, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut market = ts::take_shared<Market>(&scenario);
            tide::resolve_market(&admin_cap, &mut market, true, &clock);
            ts::return_shared(market);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER2);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(100, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, false, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_settle_before_resolve() {
        let (mut scenario, clock) = setup_test();
        ts::next_tx(&mut scenario, ADMIN);

        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            tide::create_market(
                &admin_cap,
                string::utf8(b"Test market"),
                9000000,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let payment = coin::mint_for_testing<SUI>(100, ts::ctx(&mut scenario));
            tide::place_bet(&mut market, true, payment, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };
        ts::next_tx(&mut scenario, USER1);

        {
            let mut market = ts::take_shared<Market>(&scenario);
            let ticket = ts::take_from_sender<BetTicket>(&scenario);
            tide::settle_bet(&mut market, ticket, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}
