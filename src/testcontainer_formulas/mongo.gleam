//// Mongo formula. Defaults to `mongo:7` with root auth.
////
////     use db <- testcontainer.with_formula(
////       mongo.new()
////       |> mongo.with_database("app_test")
////       |> mongo.with_username("app")
////       |> mongo.with_password("secret")
////       |> mongo.formula(),
////     )
////
////     // db.connection_url, db.host, db.port, db.database, db.username

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
pub type MongoContainer {
  MongoContainer(
    container: container.Container,
    connection_url: String,
    host: String,
    port: Int,
    database: String,
    username: String,
  )
}

/// Mongo-specific configuration. Build with `new/0` + `with_*`.
pub opaque type MongoConfig {
  MongoConfig(
    image: String,
    database: String,
    username: String,
    password: cowl.Secret(String),
    auth_database: String,
    extra_wait: Option(wait.WaitStrategy),
    network: Option(String),
    name: Option(String),
  )
}

/// Sensible defaults: `mongo:7` / db `app` / user `root` / pass `root`.
pub fn new() -> MongoConfig {
  MongoConfig(
    image: "mongo:7",
    database: "app",
    username: "root",
    password: cowl.secret("root"),
    auth_database: "admin",
    extra_wait: None,
    network: None,
    name: None,
  )
}

/// Replaces the image entirely.
pub fn with_image(c: MongoConfig, image: String) -> MongoConfig {
  MongoConfig(..c, image: image)
}

/// Shorthand: keep `mongo:` prefix, override only the tag.
pub fn with_version(c: MongoConfig, version: String) -> MongoConfig {
  MongoConfig(..c, image: "mongo:" <> version)
}

/// Sets `MONGO_INITDB_DATABASE`. The image creates this database during
/// bootstrap, but `mongosh` will still connect through `auth_database`
/// (default `"admin"`).
pub fn with_database(c: MongoConfig, db: String) -> MongoConfig {
  MongoConfig(..c, database: db)
}

/// Sets `MONGO_INITDB_ROOT_USERNAME`. This is the **root** user the image
/// creates at startup, used by the returned `connection_url`.
pub fn with_username(c: MongoConfig, user: String) -> MongoConfig {
  MongoConfig(..c, username: user)
}

/// Sets `MONGO_INITDB_ROOT_PASSWORD` for the root user.
pub fn with_password(c: MongoConfig, pass: String) -> MongoConfig {
  MongoConfig(..c, password: cowl.secret(pass))
}

/// Same as `with_password/2` when the value is already a `cowl.Secret`.
pub fn with_secret_password(
  c: MongoConfig,
  pass: cowl.Secret(String),
) -> MongoConfig {
  MongoConfig(..c, password: pass)
}

/// Authentication database used in the returned Mongo URI.
pub fn with_auth_database(c: MongoConfig, db: String) -> MongoConfig {
  MongoConfig(..c, auth_database: db)
}

/// Adds an extra wait strategy on top of the default
/// `all_of([port(27017), log("Waiting for connections")])`. Both signals
/// are emitted by the official `mongo` images and stay image-agnostic
/// (no dependency on `mongosh` being present).
pub fn with_extra_wait(c: MongoConfig, s: wait.WaitStrategy) -> MongoConfig {
  MongoConfig(..c, extra_wait: Some(s))
}

pub fn on_network(c: MongoConfig, net: network.Network) -> MongoConfig {
  MongoConfig(..c, network: Some(network.name(net)))
}

/// Same as `on_network/2` when you already have the Docker network name.
pub fn on_network_name(c: MongoConfig, net: String) -> MongoConfig {
  MongoConfig(..c, network: Some(net))
}

pub fn with_name(c: MongoConfig, n: String) -> MongoConfig {
  MongoConfig(..c, name: Some(n))
}

/// Builds the `Formula(MongoContainer)` ready to pass to
/// `testcontainer.with_formula/2`.
pub fn formula(c: MongoConfig) -> formula.Formula(MongoContainer) {
  let mongo_port = port.tcp(27_017)
  // Port-open alone can race the auth bootstrap; the log line confirms
  // mongod is actually accepting client connections.
  let base_wait =
    wait.all_of([wait.port(27_017), wait.log("Waiting for connections")])
  let wait_strategy = case c.extra_wait {
    None -> base_wait
    Some(extra) -> wait.all_of([base_wait, extra])
  }

  let with_auth =
    container.new(c.image)
    |> container.expose_port(mongo_port)
    |> container.with_env("MONGO_INITDB_DATABASE", c.database)
    |> container.with_env("MONGO_INITDB_ROOT_USERNAME", c.username)
    |> container.with_secret_env("MONGO_INITDB_ROOT_PASSWORD", c.password)
    |> container.wait_for(wait_strategy)

  let with_net = case c.network {
    None -> with_auth
    Some(n) -> with_auth |> container.on_network(n)
  }

  let final_spec = case c.name {
    None -> with_net
    Some(n) -> with_net |> container.with_name(n)
  }

  formula.new(final_spec, fn(running) {
    use mapped_port <- result.try(container.host_port(running, mongo_port))
    let host = container.host(running)
    let pass = cowl.reveal(c.password)
    Ok(MongoContainer(
      container: running,
      connection_url: "mongodb://"
        <> uri.percent_encode(c.username)
        <> ":"
        <> uri.percent_encode(pass)
        <> "@"
        <> host
        <> ":"
        <> int.to_string(mapped_port)
        <> "/"
        <> uri.percent_encode(c.database)
        <> "?authSource="
        <> uri.percent_encode(c.auth_database),
      host: host,
      port: mapped_port,
      database: c.database,
      username: c.username,
    ))
  })
}
