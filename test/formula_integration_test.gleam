import gleam/string
import gleeunit/should

import testcontainer

import formula_contract
import testcontainer_formulas/mongo
import testcontainer_formulas/mysql
import testcontainer_formulas/postgres
import testcontainer_formulas/rabbitmq
import testcontainer_formulas/redis

pub fn postgres_formula_integration_contract_test() {
  case formula_contract.integration_enabled() {
    False -> Nil
    True -> {
      testcontainer.with_formula(
        postgres.new()
          |> postgres.with_database("app_test")
          |> postgres.with_username("app")
          |> postgres.with_password("secret")
          |> postgres.formula(),
        fn(pg) {
          formula_contract.assert_endpoint_contract(
            pg.connection_url,
            "postgresql://",
            pg.host,
            pg.port,
          )
          formula_contract.assert_non_empty(pg.database)
          formula_contract.assert_non_empty(pg.username)

          let ready =
            testcontainer.exec(pg.container, ["pg_isready", "-U", pg.username])
            |> should.be_ok()
          ready.exit_code |> should.equal(0)
          Ok(Nil)
        },
      )
      |> should.be_ok()
    }
  }
}

pub fn redis_formula_integration_contract_test() {
  case formula_contract.integration_enabled() {
    False -> Nil
    True -> {
      testcontainer.with_formula(redis.new() |> redis.formula(), fn(cache) {
        formula_contract.assert_endpoint_contract(
          cache.url,
          "redis://",
          cache.host,
          cache.port,
        )

        let ping =
          testcontainer.exec(cache.container, ["redis-cli", "PING"])
          |> should.be_ok()
        ping.exit_code |> should.equal(0)
        string.contains(ping.stdout, "PONG") |> should.be_true()
        Ok(Nil)
      })
      |> should.be_ok()
    }
  }
}

pub fn redis_formula_with_password_integration_contract_test() {
  case formula_contract.integration_enabled() {
    False -> Nil
    True -> {
      testcontainer.with_formula(
        redis.new()
          |> redis.with_password("secret")
          |> redis.formula(),
        fn(cache) {
          formula_contract.assert_endpoint_contract(
            cache.url,
            "redis://:secret@",
            cache.host,
            cache.port,
          )

          let ping =
            testcontainer.exec(cache.container, [
              "redis-cli",
              "-a",
              "secret",
              "PING",
            ])
            |> should.be_ok()
          ping.exit_code |> should.equal(0)
          string.contains(ping.stdout, "PONG") |> should.be_true()
          Ok(Nil)
        },
      )
      |> should.be_ok()
    }
  }
}

pub fn mysql_formula_integration_contract_test() {
  case formula_contract.integration_enabled() {
    False -> Nil
    True -> {
      testcontainer.with_formula(
        mysql.new()
          |> mysql.with_database("app_test")
          |> mysql.with_username("app")
          |> mysql.with_password("secret")
          |> mysql.formula(),
        fn(db) {
          formula_contract.assert_endpoint_contract(
            db.connection_url,
            "mysql://",
            db.host,
            db.port,
          )
          formula_contract.assert_non_empty(db.database)
          formula_contract.assert_non_empty(db.username)

          // mysql:8.4 default auth plugin is `caching_sha2_password`. Over
          // plain TCP (no TLS, not a unix socket) the client must either
          // already hold the server's RSA public key or fetch it on demand.
          // `--get-server-public-key` does the latter — without it, the
          // first connection fails with
          // "Authentication requires secure connection".
          let ping =
            testcontainer.exec(db.container, [
              "mysqladmin",
              "ping",
              "-h",
              "127.0.0.1",
              "-u",
              db.username,
              "-psecret",
              "--get-server-public-key",
            ])
            |> should.be_ok()
          ping.exit_code |> should.equal(0)
          Ok(Nil)
        },
      )
      |> should.be_ok()
    }
  }
}

pub fn rabbitmq_formula_integration_contract_test() {
  case formula_contract.integration_enabled() {
    False -> Nil
    True -> {
      testcontainer.with_formula(
        rabbitmq.new()
          |> rabbitmq.with_username("app")
          |> rabbitmq.with_password("secret")
          |> rabbitmq.formula(),
        fn(mq) {
          formula_contract.assert_endpoint_contract(
            mq.amqp_url,
            "amqp://",
            mq.host,
            mq.amqp_port,
          )
          formula_contract.assert_endpoint_contract(
            mq.management_url,
            "http://",
            mq.host,
            mq.management_port,
          )

          let ping =
            testcontainer.exec(mq.container, [
              "rabbitmq-diagnostics",
              "-q",
              "ping",
            ])
            |> should.be_ok()
          ping.exit_code |> should.equal(0)
          Ok(Nil)
        },
      )
      |> should.be_ok()
    }
  }
}

pub fn mongo_formula_integration_contract_test() {
  case formula_contract.integration_enabled() {
    False -> Nil
    True -> {
      testcontainer.with_formula(
        mongo.new()
          |> mongo.with_database("app_test")
          |> mongo.with_username("app")
          |> mongo.with_password("secret")
          |> mongo.with_auth_database("admin")
          |> mongo.formula(),
        fn(db) {
          formula_contract.assert_endpoint_contract(
            db.connection_url,
            "mongodb://",
            db.host,
            db.port,
          )
          formula_contract.assert_non_empty(db.database)
          formula_contract.assert_non_empty(db.username)

          let ping =
            testcontainer.exec(db.container, [
              "mongosh",
              "--quiet",
              "--username",
              db.username,
              "--password",
              "secret",
              "--authenticationDatabase",
              "admin",
              "--eval",
              "db.runCommand({ ping: 1 }).ok",
            ])
            |> should.be_ok()
          ping.exit_code |> should.equal(0)
          string.contains(ping.stdout, "1") |> should.be_true()
          Ok(Nil)
        },
      )
      |> should.be_ok()
    }
  }
}
