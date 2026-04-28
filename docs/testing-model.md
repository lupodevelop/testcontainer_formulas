# Testing Model For Formulas

Tests come in two layers. Unit tests run on every commit. Integration
tests are opt-in because they need a running Docker daemon.

## Layer 1: unit contracts (always on)

These run without Docker and check what a formula promises on paper:

1. The builder accepts the documented defaults and overrides without
   crashing.
2. Secrets passed to `with_password` (and friends) never appear in
   `string.inspect` of the config.
3. The shape of the typed output is what callers expect (URL scheme,
   non-empty fields).

They finish in milliseconds, so CI keeps them on.

## Layer 2: integration contracts (opt-in)

These actually start a container and verify the formula behaves the
same way against a real service:

1. `testcontainer.with_formula/2` brings the container up and the
   typed output is populated.
2. `host`, `port`, and the formatted URL are coherent.
3. A liveness probe inside the container succeeds: `pg_isready`,
   `redis-cli PING`, `mysqladmin ping`, `rabbitmq-diagnostics ping`,
   or `mongosh ... db.runCommand({ ping: 1 })`.

Run them with:

```sh
TESTCONTAINER_FORMULAS_INTEGRATION=true gleam test
```

## Reusable contract helper

`test/formula_contract.gleam` keeps the shared assertions in one place:

- `integration_enabled/0`
- `run_builder_contract/1`
- `assert_endpoint_contract/4`
- `assert_non_empty/1`
- `assert_positive_port/1`

When you add a new formula, follow the same shape used by the existing
ones:

1. Builder smoke + secret-redaction unit tests.
2. One integration test that calls `assert_endpoint_contract` and
   issues a service-specific liveness probe.
3. Gate the integration test on `TESTCONTAINER_FORMULAS_INTEGRATION`
   so contributors without Docker still get a green build.
