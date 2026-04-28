//// Postgres formula. Defaults to `postgres:16-alpine`, database `postgres`,
//// user `postgres`, password `postgres`.
////
////     use pg <- testcontainer.with_formula(
////       postgres.new()
////       |> postgres.with_database("myapp_test")
////       |> postgres.with_password("secret")
////       |> postgres.formula(),
////     )
////
////     // pg.connection_url, pg.host, pg.port, pg.database, pg.username

import cowl
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri

import testcontainer/container
import testcontainer/formula
import testcontainer/network
import testcontainer/port
import testcontainer/wait

/// Typed output handed to the body of `testcontainer.with_formula/2`.
pub type PostgresContainer {
  PostgresContainer(
    container: container.Container,
    connection_url: String,
    host: String,
    port: Int,
    database: String,
    username: String,
  )
}

/// Postgres-specific configuration. Build with `new/0` + `with_*`.
pub opaque type PostgresConfig {
  PostgresConfig(
    image: String,
    database: String,
    username: String,
    password: cowl.Secret(String),
    extra_wait: Option(wait.WaitStrategy),
    network: Option(String),
    name: Option(String),
  )
}

/// Sensible defaults: `postgres:16-alpine` / `postgres` / `postgres` / `postgres`.
pub fn new() -> PostgresConfig {
  PostgresConfig(
    image: "postgres:16-alpine",
    database: "postgres",
    username: "postgres",
    password: cowl.secret("postgres"),
    extra_wait: None,
    network: None,
    name: None,
  )
}

/// Replaces the image entirely (e.g. for hardened images or different bases).
pub fn with_image(c: PostgresConfig, image: String) -> PostgresConfig {
  PostgresConfig(..c, image: image)
}

/// Shorthand: keep `postgres:` prefix, override only the tag.
pub fn with_version(c: PostgresConfig, version: String) -> PostgresConfig {
  PostgresConfig(..c, image: "postgres:" <> version)
}

pub fn with_database(c: PostgresConfig, db: String) -> PostgresConfig {
  PostgresConfig(..c, database: db)
}

pub fn with_username(c: PostgresConfig, user: String) -> PostgresConfig {
  PostgresConfig(..c, username: user)
}

pub fn with_password(c: PostgresConfig, pass: String) -> PostgresConfig {
  PostgresConfig(..c, password: cowl.secret(pass))
}

pub fn with_secret_password(
  c: PostgresConfig,
  pass: cowl.Secret(String),
) -> PostgresConfig {
  PostgresConfig(..c, password: pass)
}

/// Adds an extra wait strategy on top of the default
/// `log("database system is ready to accept connections")`.
pub fn with_extra_wait(
  c: PostgresConfig,
  s: wait.WaitStrategy,
) -> PostgresConfig {
  PostgresConfig(..c, extra_wait: Some(s))
}

/// Attaches the container to the given network (typically built by
/// `testcontainer.with_network/2` or `testcontainer.with_stack/2`).
pub fn on_network(c: PostgresConfig, net: network.Network) -> PostgresConfig {
  PostgresConfig(..c, network: Some(network.name(net)))
}

/// Same as `on_network/2` when you already have the Docker network name.
pub fn on_network_name(c: PostgresConfig, net: String) -> PostgresConfig {
  PostgresConfig(..c, network: Some(net))
}

/// Names the container so other containers on the same network can reach
/// it (e.g. `"db"` → `db:5432`).
pub fn with_name(c: PostgresConfig, n: String) -> PostgresConfig {
  PostgresConfig(..c, name: Some(n))
}

/// Builds the `Formula(PostgresContainer)` ready to pass to
/// `testcontainer.with_formula/2`.
pub fn formula(c: PostgresConfig) -> formula.Formula(PostgresContainer) {
  let pg_port = port.tcp(5432)
  let base_wait = wait.log("database system is ready to accept connections")
  let wait_strategy = case c.extra_wait {
    None -> base_wait
    Some(extra) -> wait.all_of([base_wait, extra])
  }

  let with_creds =
    container.new(c.image)
    |> container.expose_port(pg_port)
    |> container.with_env("POSTGRES_DB", c.database)
    |> container.with_env("POSTGRES_USER", c.username)
    |> container.with_secret_env("POSTGRES_PASSWORD", c.password)
    |> container.wait_for(wait_strategy)

  let with_net = case c.network {
    None -> with_creds
    Some(n) -> with_creds |> container.on_network(n)
  }

  let final_spec = case c.name {
    None -> with_net
    Some(n) -> with_net |> container.with_name(n)
  }

  formula.new(final_spec, fn(running) {
    use mapped_port <- result.try(container.host_port(running, pg_port))
    let host = container.host(running)
    let pass = cowl.reveal(c.password)
    Ok(PostgresContainer(
      container: running,
      connection_url: "postgresql://"
        <> uri.percent_encode(c.username)
        <> ":"
        <> uri.percent_encode(pass)
        <> "@"
        <> host
        <> ":"
        <> int.to_string(mapped_port)
        <> "/"
        <> uri.percent_encode(c.database),
      host: host,
      port: mapped_port,
      database: c.database,
      username: c.username,
    ))
  })
}
