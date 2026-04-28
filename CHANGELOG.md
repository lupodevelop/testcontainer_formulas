<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

## 1.0.0 - 2026-04-29

### Added

- `docs/quickstart.md` with usage examples for every formula plus a
  shared-network composition example.
- `docs/writing-formulas.md` covering the recommended formula structure,
  builder conventions, and a design checklist.
- `docs/testing-model.md` describing the two-layer test model
  (unit contracts + optional Docker integration contracts).
- New formulas:
  - `testcontainer_formulas/mongo`
  - `testcontainer_formulas/mysql`
  - `testcontainer_formulas/rabbitmq`
- Mongo builders:
  - `mongo.with_image/2`, `mongo.with_version/2`
  - `mongo.with_database/2`, `mongo.with_username/2`
  - `mongo.with_password/2`, `mongo.with_secret_password/2`
  - `mongo.with_auth_database/2`, `mongo.with_extra_wait/2`
  - `mongo.on_network/2`, `mongo.on_network_name/2`,
    `mongo.with_name/2`
- MySQL builders:
  - `mysql.with_image/2`, `mysql.with_version/2`
  - `mysql.with_database/2`, `mysql.with_username/2`
  - `mysql.with_password/2`, `mysql.with_secret_password/2`
  - `mysql.with_root_password/2`, `mysql.with_secret_root_password/2`
  - `mysql.with_extra_wait/2`, `mysql.on_network/2`,
    `mysql.on_network_name/2`, `mysql.with_name/2`
- RabbitMQ builders:
  - `rabbitmq.with_image/2`, `rabbitmq.with_version/2`
  - `rabbitmq.with_username/2`, `rabbitmq.with_password/2`,
    `rabbitmq.with_secret_password/2`
  - `rabbitmq.with_vhost/2`, `rabbitmq.with_extra_wait/2`
  - `rabbitmq.on_network/2`, `rabbitmq.on_network_name/2`,
    `rabbitmq.with_name/2`
- Redis auth builders:
  - `redis.with_password/2`
  - `redis.with_secret_password/2`
  - `redis.without_password/1`
  When auth is enabled, the formula starts Redis with
  `redis-server --requirepass ...` and returns an auth-aware URL.
- Network-name builders for easier composition when only a string name is
  available:
  - `postgres.on_network_name/2`
  - `redis.on_network_name/2`

### Changed

- All formulas now percent-encode credentials and path segments in the
  generated connection URLs via `gleam/uri.percent_encode`. Passwords or
  database names containing reserved characters (`@`, `/`, `:`, `?`,
  `#`, `&`, `=`, space) no longer break the DSN.
- Mongo wait strategy default is now
  `all_of([port(27017), log("Waiting for connections")])`. The port
  alone could open before mongod was ready to accept clients; the log
  signal closes that gap and stays image-agnostic (no dependency on
  `mongosh`).
- README trimmed to a short overview that links out to the dedicated
  docs pages.
- Formula tests now follow a reusable contract-oriented model
  (`test/formula_contract.gleam`).
- Contract tests (unit + optional integration) added for Mongo, MySQL,
  and RabbitMQ.

### Removed

- The custom `encode_vhost_segment` helper inside the RabbitMQ formula.
  The `gleam/uri.percent_encode` standard helper covers the same cases
  (default vhost `/` becomes `%2F`) plus arbitrary reserved characters
  in custom vhost names.

## [0.1.0] - 2026-03-11

First private release.

### Added

- `testcontainer_formulas/postgres` - `new/0`, `with_image/2`,
  `with_version/2`, `with_database/2`, `with_username/2`, `with_password/2`,
  `with_secret_password/2`, `with_extra_wait/2`, `on_network/2`,
  `with_name/2`, `formula/1` returning `Formula(PostgresContainer)`
- `testcontainer_formulas/redis` - `new/0`, `with_image/2`,
  `with_version/2`, `with_extra_wait/2`, `on_network/2`, `with_name/2`,
  `formula/1` returning `Formula(RedisContainer)`
- MIT license

### Notes

- Depends on `testcontainer` core for lifecycle, network and formula
  primitives.
