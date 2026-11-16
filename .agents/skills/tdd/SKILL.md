---
name: tdd
description: Test-driven development for this repo. Builds a ticket or fix as red → green cycles, starting with the invariant tests the spec or ticket names. Use when building a ticket, fixing a bug test-first, or when the developer mentions TDD or red-green.
---

# TDD

Build in red → green cycles. Each cycle: one failing test, then only the code that makes it pass.

## Where the tests come from

1. **The ticket's invariant tests come first.** For a red ticket, write each listed invariant as a failing test before any production code. Name the test after the invariant ("same txId twice credits once").
2. **Then the acceptance criteria**, one cycle each.
3. **Test at the agreed seams.** Use the seams in the spec (`<home>/specs/<slug>/spec.md`). When there is no spec, propose the seams to the developer before writing tests, with one line on what each catches and misses.

## What a good test is

It checks behaviour through a public interface, so a refactor that keeps the behaviour keeps the test green. Examples: [tests.md](tests.md). When to mock: [mocking.md](mocking.md).

- **Expected values are independent literals** from the spec or a worked example, never recomputed the way the code computes them.
- **Mock only system boundaries:** provider HTTP clients, queues, time. Not our own services.
- **Money tests use exact values** and the repo's rounding (`roundToTwoDecimalPlaces`).

## Tests this repo needs for money paths

| Invariant | Test shape |
|---|---|
| Bad input never reaches the wallet | negative, zero, NaN and string amounts are rejected before `WalletService.updateBalance` |
| Idempotency | the same request twice → one balance change |
| Concurrency | N identical requests at once → exactly one wins. Needs a real Postgres: the database decides. When no test database is available, write the test, mark it `it.todo`, and report it as missing |
| Callback trust | bad signature → rejected; missing key → rejected (fail closed); confirmed amount ≠ recorded amount → rejected |
| Reversal | rollback or refund restores exactly the debit, including wager |
| Access | player A cannot act on player B's ids; a player cannot set `kycVerified` or `isTest` |

## Running tests

Pass the full spec path and one worker: `yarn test <path/to/file.spec.ts> -w 1`. Never run the full suite. Run one heavy command at a time on the machine.

## Rules of the loop

- **Red before green.** See the test fail for the right reason before writing the code.
- **One slice at a time.** One test, the minimum code, repeat.
- **No speculative code.** Nothing the current test doesn't need.
- **Refactor after green**, in a separate step, keeping the tests green. Larger cleanups belong to review, not the loop.
