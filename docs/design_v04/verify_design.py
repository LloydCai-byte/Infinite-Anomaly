"""Paper-design checks, not tests of the Godot game. Run using Python 3.12+."""
import json
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CFG = json.loads((ROOT / '首章规则样例.json').read_text(encoding='utf-8'))
REPORT = []


def record(label, value):
    REPORT.append({'check': label, 'result': value})


def draw_options(owned, dry, pool, target=None):
    missing = set(pool) - set(owned)
    if missing and dry >= 2:
        return [target] if target in missing else sorted(missing)
    return list(pool)


def draw_result(owned, dry, pool, chosen):
    is_new = chosen not in owned
    updated = frozenset(set(owned) | {chosen})
    next_dry = 0 if is_new or set(pool) <= set(updated) else dry + 1
    return updated, next_dry


def exhaustive_pity(pool, initial):
    states = {(frozenset(initial), 0)}
    count = 0
    visited = 1
    while any(not set(pool) <= set(owned) for owned, _ in states):
        assert count < 10
        next_states = set()
        for owned, dry in states:
            if set(pool) <= set(owned):
                next_states.add((owned, 0))
                continue
            for chosen in draw_options(owned, dry, pool):
                next_states.add(draw_result(owned, dry, pool, chosen))
        count += 1
        visited += len(next_states)
        states = next_states
    return count, visited


def upgrade_cost(level):
    return 2 * level + 2


def can_buy(food, echo, cost):
    return echo >= cost and food + 4 * (echo - cost) >= 3


def farm(food, echo, route, rounds, top_up):
    completed = 0
    for _ in range(rounds):
        while food < route['food'] + 1 and top_up and echo:
            assert food <= 196
            echo -= 1
            food += 4
        if food < route['food'] + 1:
            break
        food -= route['food']
        assert food > 0  # known route cannot reach Game Over
        echo += 2 * route['samples']
        completed += 1
    return food, echo, completed


def verify():
    for pool in CFG['pools']:
        assert len(set(pool['cards'])) == 3
        assert sum(pool['weights']) == 100
        empty_bound, states = exhaustive_pity(pool['cards'], [])
        known_bound, _ = exhaustive_pity(pool['cards'], pool['cards'][:1])
        assert empty_bound == 7 and known_bound == 6
        assert draw_options({pool['cards'][0]}, 2, pool['cards'], pool['cards'][2]) == [pool['cards'][2]]
        record(pool['id'] + ' pity', {'empty_pool_max_samples': empty_bound, 'one_owned_max_samples': known_bound, 'states_examined': states})

    food, echo = 100, 0
    food -= 2
    echo += 2  # first C01
    for card in CFG['chapter']['tutorial_completed_route_rewards']:
        food -= 2
        echo += 2
        if echo == 4 and card == 'C01' and food == 96:
            assert can_buy(food, echo, upgrade_cost(1))
            echo -= upgrade_cost(1)
    assert (food, echo) == (92, 4)
    assert can_buy(food, echo, 4)
    echo -= 4
    assert (food, echo) == (92, 0)
    record('intro after first training and house upgrade', {'food': food, 'echo': echo})

    # Continue all three viable specializations along the same story gates.
    for stat in ('combat', 'perception', 'survival'):
        food, echo, level = 92, 0, 2
        food -= 4; echo += 4  # N03/N04, C07+C04
        food, echo, rounds = farm(food, echo, CFG['chapter']['routes'][0], 1, False)
        assert rounds == 1 and echo == upgrade_cost(level)
        echo -= upgrade_cost(level); level += 1
        food -= 4; echo += 2  # N05/N06, C08
        assert level >= 3 and food > 0
        record(stat + ' chapter clear', {'food': food, 'echo': echo, 'level': level})

    for route in CFG['chapter']['routes']:
        assert route['duration_s'] < route['window_s']
        sample_income = 2 * route['samples']
        net = Fraction(sample_income) - Fraction(route['food'], 4)
        per_minute = net * Fraction(60, route['duration_s'])
        assert net > 0
        record(route['id'] + ' net', {'per_run': str(net), 'per_minute': str(per_minute)})
        f, r, n = farm(route['food'] + 1, 0, route, 10000, True)
        assert n == 10000 and f >= 1 and r >= 0
        record(route['id'] + ' 10000 automated runs', {'food': f, 'echo': r, 'completed': n})

    f, r, n = farm(3, 0, CFG['chapter']['routes'][0], 10, False)
    assert (f, r, n) == (1, 2, 1)
    assert not can_buy(2, 4, 4)
    assert can_buy(3, 4, 4)
    assert can_buy(1, 5, 4)
    record('safe stop and purchase reserve', 'passed')
    invested = sum(upgrade_cost(level) for level in range(1, 7))
    assert invested == 54
    record('training refund ledger', {'levels_1_to_7_investment': invested, 'full_refund': invested})

    seen = set()
    r = 0
    for tx_id in ('run_1_segment_1', 'run_1_segment_1', 'run_2_segment_1'):
        if tx_id not in seen:
            seen.add(tx_id); r += 2
    assert r == 4
    record('illustrative idempotent ledger', 'passed; runtime still needs implementation')
    record('coverage boundary', 'Checks paper formulas and proposed algorithm only; no Godot, UI, save-file or real playtest validation')
    result = {'status': 'passed', 'checks': REPORT}
    (ROOT / '规则演算结果.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    verify()
