# Quickstart

`testcontainer_formulas` provides typed formulas on top of `testcontainer`.

## Install

```sh
gleam add testcontainer
gleam add testcontainer_formulas
```

## Postgres in one test

```gleam
import testcontainer
import testcontainer_formulas/postgres

pub fn postgres_test() {
  use pg <- testcontainer.with_formula(
    postgres.new()
    |> postgres.with_database("app_test")
    |> postgres.with_username("app")
    |> postgres.with_password("secret")
    |> postgres.formula(),
  )

  let _url = pg.connection_url
  Ok(Nil)
}
```

## Redis (with optional auth)

```gleam
import testcontainer
import testcontainer_formulas/redis

pub fn redis_test() {
  use cache <- testcontainer.with_formula(
    redis.new()
    |> redis.with_password("secret")
    |> redis.formula(),
  )

  let _url = cache.url
  Ok(Nil)
}
```

## MySQL

```gleam
import testcontainer
import testcontainer_formulas/mysql

pub fn mysql_test() {
  use db <- testcontainer.with_formula(
    mysql.new()
    |> mysql.with_database("app_test")
    |> mysql.with_username("app")
    |> mysql.with_password("secret")
    |> mysql.formula(),
  )

  let _url = db.connection_url
  Ok(Nil)
}
```

## Mongo

```gleam
import testcontainer
import testcontainer_formulas/mongo

pub fn mongo_test() {
  use db <- testcontainer.with_formula(
    mongo.new()
    |> mongo.with_database("app_test")
    |> mongo.with_username("app")
    |> mongo.with_password("secret")
    |> mongo.formula(),
  )

  let _url = db.connection_url
  Ok(Nil)
}
```

## RabbitMQ

```gleam
import testcontainer
import testcontainer_formulas/rabbitmq

pub fn rabbitmq_test() {
  use mq <- testcontainer.with_formula(
    rabbitmq.new()
    |> rabbitmq.with_username("app")
    |> rabbitmq.with_password("secret")
    |> rabbitmq.formula(),
  )

  let _amqp = mq.amqp_url
  let _ui = mq.management_url
  Ok(Nil)
}
```

## Shared network example

```gleam
import testcontainer
import testcontainer_formulas/postgres
import testcontainer_formulas/redis

pub fn stack_test() {
  use net <- testcontainer.with_stack(
    testcontainer.stack("app-test-net", fn(n) { Ok(n) }),
  )

  use pg <- testcontainer.with_formula(
    postgres.new()
    |> postgres.on_network(net)
    |> postgres.with_name("db")
    |> postgres.formula(),
  )

  use cache <- testcontainer.with_formula(
    redis.new()
    |> redis.on_network(net)
    |> redis.with_name("cache")
    |> redis.formula(),
  )

  let _ = pg.connection_url
  let _ = cache.url
  Ok(Nil)
}
```
