import cowl
import gleam/dict
import gleam/string
import gleeunit
import gleeunit/should

import testcontainer/container
import testcontainer/formula

import formula_contract
import testcontainer_formulas/mongo
import testcontainer_formulas/mysql
import testcontainer_formulas/postgres
import testcontainer_formulas/rabbitmq
import testcontainer_formulas/redis

pub fn main() -> Nil {
  gleeunit.main()
}

// Constructors don't crash and the builders return the expected opaque type.
pub fn postgres_builder_smoke_test() {
  formula_contract.run_builder_contract(fn() {
    postgres.new()
    |> postgres.with_version("15-alpine")
    |> postgres.with_database("myapp")
    |> postgres.with_username("app")
    |> postgres.with_password("hunter2")
    |> postgres.on_network_name("test-net")
    |> postgres.with_name("db")
    |> postgres.formula()
  })
}

pub fn redis_builder_smoke_test() {
  formula_contract.run_builder_contract(fn() {
    redis.new()
    |> redis.with_version("7-alpine")
    |> redis.on_network_name("test-net")
    |> redis.with_name("cache")
    |> redis.formula()
  })
}

pub fn redis_builder_with_password_smoke_test() {
  formula_contract.run_builder_contract(fn() {
    redis.new()
    |> redis.with_password("hunter2")
    |> redis.without_password()
    |> redis.with_secret_password(cowl.secret("hunter2"))
    |> redis.formula()
  })
}

pub fn mysql_builder_smoke_test() {
  formula_contract.run_builder_contract(fn() {
    mysql.new()
    |> mysql.with_version("8.4")
    |> mysql.with_database("myapp")
    |> mysql.with_username("app")
    |> mysql.with_password("hunter2")
    |> mysql.with_root_password("root-secret")
    |> mysql.on_network_name("test-net")
    |> mysql.with_name("db")
    |> mysql.formula()
  })
}

pub fn rabbitmq_builder_smoke_test() {
  formula_contract.run_builder_contract(fn() {
    rabbitmq.new()
    |> rabbitmq.with_version("3.13-management")
    |> rabbitmq.with_username("app")
    |> rabbitmq.with_password("hunter2")
    |> rabbitmq.with_vhost("/")
    |> rabbitmq.on_network_name("test-net")
    |> rabbitmq.with_name("mq")
    |> rabbitmq.formula()
  })
}

pub fn mongo_builder_smoke_test() {
  formula_contract.run_builder_contract(fn() {
    mongo.new()
    |> mongo.with_version("7")
    |> mongo.with_database("myapp")
    |> mongo.with_username("app")
    |> mongo.with_password("hunter2")
    |> mongo.with_auth_database("admin")
    |> mongo.on_network_name("test-net")
    |> mongo.with_name("mongo")
    |> mongo.formula()
  })
}

// Password value must never appear in `string.inspect` of the config -
// cowl.Secret is responsible for redaction.
pub fn postgres_password_not_in_inspect_test() {
  let cfg = postgres.new() |> postgres.with_password("supersecret-leak-canary")
  let inspected = string.inspect(cfg)
  string.contains(inspected, "supersecret-leak-canary") |> should.be_false()
}

pub fn redis_password_not_in_inspect_test() {
  let cfg = redis.new() |> redis.with_password("supersecret-leak-canary")
  let inspected = string.inspect(cfg)
  string.contains(inspected, "supersecret-leak-canary") |> should.be_false()
}

pub fn mysql_password_not_in_inspect_test() {
  let cfg = mysql.new() |> mysql.with_password("supersecret-leak-canary")
  let inspected = string.inspect(cfg)
  string.contains(inspected, "supersecret-leak-canary") |> should.be_false()
}

pub fn rabbitmq_password_not_in_inspect_test() {
  let cfg = rabbitmq.new() |> rabbitmq.with_password("supersecret-leak-canary")
  let inspected = string.inspect(cfg)
  string.contains(inspected, "supersecret-leak-canary") |> should.be_false()
}

pub fn mongo_password_not_in_inspect_test() {
  let cfg = mongo.new() |> mongo.with_password("supersecret-leak-canary")
  let inspected = string.inspect(cfg)
  string.contains(inspected, "supersecret-leak-canary") |> should.be_false()
}

// ---------------------------------------------------------------------------
// URL encoding: special characters in credentials and path segments must be
// percent-encoded. Built using the @internal `formula.extract/2` against a
// synthetic running Container - no Docker needed.
// ---------------------------------------------------------------------------

fn synthetic_container(
  port_pairs: List(#(#(Int, String), Int)),
) -> container.Container {
  container.build("id-x", "127.0.0.1", dict.from_list(port_pairs), False, 10)
}

pub fn postgres_connection_url_encodes_credentials_test() {
  let cont = synthetic_container([#(#(5432, "tcp"), 32_768)])
  let f =
    postgres.new()
    |> postgres.with_username("us:er")
    |> postgres.with_password("p@ss/word#1")
    |> postgres.with_database("my db?")
    |> postgres.formula()
  let assert Ok(pg) = formula.extract(f, cont)
  string.contains(pg.connection_url, "us%3Aer") |> should.be_true()
  string.contains(pg.connection_url, "p%40ss%2Fword%231") |> should.be_true()
  string.contains(pg.connection_url, "my%20db%3F") |> should.be_true()
  string.contains(pg.connection_url, "p@ss/word") |> should.be_false()
}

pub fn mysql_connection_url_encodes_credentials_test() {
  let cont = synthetic_container([#(#(3306, "tcp"), 32_769)])
  let f =
    mysql.new()
    |> mysql.with_username("us@er")
    |> mysql.with_password("p:ass/w#")
    |> mysql.with_database("db/1")
    |> mysql.formula()
  let assert Ok(db) = formula.extract(f, cont)
  string.contains(db.connection_url, "us%40er") |> should.be_true()
  string.contains(db.connection_url, "p%3Aass%2Fw%23") |> should.be_true()
  string.contains(db.connection_url, "db%2F1") |> should.be_true()
}

pub fn mongo_connection_url_encodes_credentials_and_auth_db_test() {
  let cont = synthetic_container([#(#(27_017, "tcp"), 32_770)])
  let f =
    mongo.new()
    |> mongo.with_username("ad min")
    |> mongo.with_password("p&w=q")
    |> mongo.with_database("db?1")
    |> mongo.with_auth_database("auth/db")
    |> mongo.formula()
  let assert Ok(m) = formula.extract(f, cont)
  string.contains(m.connection_url, "ad%20min") |> should.be_true()
  string.contains(m.connection_url, "p%26w%3Dq") |> should.be_true()
  string.contains(m.connection_url, "db%3F1") |> should.be_true()
  string.contains(m.connection_url, "authSource=auth%2Fdb") |> should.be_true()
}

pub fn rabbitmq_amqp_url_encodes_default_vhost_test() {
  let cont =
    synthetic_container([
      #(#(5672, "tcp"), 32_771),
      #(#(15_672, "tcp"), 32_772),
    ])
  let f = rabbitmq.new() |> rabbitmq.formula()
  let assert Ok(mq) = formula.extract(f, cont)
  // Default vhost "/" must be encoded as "%2F" per AMQP URL spec.
  string.contains(mq.amqp_url, "/%2F") |> should.be_true()
}

pub fn rabbitmq_amqp_url_encodes_custom_vhost_and_credentials_test() {
  let cont =
    synthetic_container([
      #(#(5672, "tcp"), 32_771),
      #(#(15_672, "tcp"), 32_772),
    ])
  let f =
    rabbitmq.new()
    |> rabbitmq.with_username("u@x")
    |> rabbitmq.with_password("p/w&q")
    |> rabbitmq.with_vhost("my/vhost")
    |> rabbitmq.formula()
  let assert Ok(mq) = formula.extract(f, cont)
  string.contains(mq.amqp_url, "u%40x") |> should.be_true()
  string.contains(mq.amqp_url, "p%2Fw%26q") |> should.be_true()
  string.contains(mq.amqp_url, "my%2Fvhost") |> should.be_true()
}

pub fn redis_url_encodes_password_test() {
  let cont = synthetic_container([#(#(6379, "tcp"), 32_773)])
  let f =
    redis.new()
    |> redis.with_password("p@ss/word")
    |> redis.formula()
  let assert Ok(r) = formula.extract(f, cont)
  // Redis URL: "redis://:<password>@host:port" - password segment must be
  // percent-encoded so `@` does not break the userinfo split.
  string.contains(r.url, "p@ss/word") |> should.be_false()
}
