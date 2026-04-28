//// MySQL formula. Defaults to `mysql:8.4` with app credentials.
////
////     use db <- testcontainer.with_formula(
////       mysql.new()
////       |> mysql.with_database("app_test")
////       |> mysql.with_username("app")
////       |> mysql.with_password("secret")
////       |> mysql.formula(),
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
pub type MysqlContainer {
  MysqlContainer(
    container: container.Container,
    connection_url: String,
    host: String,
    port: Int,
    database: String,
    username: String,
  )
}

/// MySQL-specific configuration. Build with `new/0` + `with_*`.
pub opaque type MysqlConfig {
  MysqlConfig(
    image: String,
    database: String,
    username: String,
    password: cowl.Secret(String),
    root_password: cowl.Secret(String),
    extra_wait: Option(wait.WaitStrategy),
    network: Option(String),
    name: Option(String),
  )
}

/// Sensible defaults: `mysql:8.4` / `app` / `app` / `root`.
pub fn new() -> MysqlConfig {
  MysqlConfig(
    image: "mysql:8.4",
    database: "app",
    username: "app",
    password: cowl.secret("app"),
    root_password: cowl.secret("root"),
    extra_wait: None,
    network: None,
    name: None,
  )
}

/// Replaces the image entirely.
pub fn with_image(c: MysqlConfig, image: String) -> MysqlConfig {
  MysqlConfig(..c, image: image)
}

/// Shorthand: keep `mysql:` prefix, override only the tag.
pub fn with_version(c: MysqlConfig, version: String) -> MysqlConfig {
  MysqlConfig(..c, image: "mysql:" <> version)
}

pub fn with_database(c: MysqlConfig, db: String) -> MysqlConfig {
  MysqlConfig(..c, database: db)
}

pub fn with_username(c: MysqlConfig, user: String) -> MysqlConfig {
  MysqlConfig(..c, username: user)
}

pub fn with_password(c: MysqlConfig, pass: String) -> MysqlConfig {
  MysqlConfig(..c, password: cowl.secret(pass))
}

pub fn with_secret_password(
  c: MysqlConfig,
  pass: cowl.Secret(String),
) -> MysqlConfig {
  MysqlConfig(..c, password: pass)
}

/// Root password used by the MySQL image bootstrap.
pub fn with_root_password(c: MysqlConfig, pass: String) -> MysqlConfig {
  MysqlConfig(..c, root_password: cowl.secret(pass))
}

/// Same as `with_root_password/2` when the value is already a `cowl.Secret`.
pub fn with_secret_root_password(
  c: MysqlConfig,
  pass: cowl.Secret(String),
) -> MysqlConfig {
  MysqlConfig(..c, root_password: pass)
}

/// Adds an extra wait strategy on top of the default
/// `log_times("ready for connections", 2)`. The `_, 2` matches the second
/// emission, which is the final server after the temporary bootstrap
/// server has finished creating users — earlier, clients race the init
/// scripts and hit "Access denied".
pub fn with_extra_wait(c: MysqlConfig, s: wait.WaitStrategy) -> MysqlConfig {
  MysqlConfig(..c, extra_wait: Some(s))
}

pub fn on_network(c: MysqlConfig, net: network.Network) -> MysqlConfig {
  MysqlConfig(..c, network: Some(network.name(net)))
}

/// Same as `on_network/2` when you already have the Docker network name.
pub fn on_network_name(c: MysqlConfig, net: String) -> MysqlConfig {
  MysqlConfig(..c, network: Some(net))
}

pub fn with_name(c: MysqlConfig, n: String) -> MysqlConfig {
  MysqlConfig(..c, name: Some(n))
}

/// Builds the `Formula(MysqlContainer)` ready to pass to
/// `testcontainer.with_formula/2`.
pub fn formula(c: MysqlConfig) -> formula.Formula(MysqlContainer) {
  let mysql_port = port.tcp(3306)
  // The mysql image entrypoint starts a temporary server to run init
  // (database/user creation), shuts it down, then starts the final server.
  // Both phases emit "ready for connections", so matching the second
  // occurrence avoids racing client auth against not-yet-created users.
  let base_wait = wait.log_times("ready for connections", 2)
  let wait_strategy = case c.extra_wait {
    None -> base_wait
    Some(extra) -> wait.all_of([base_wait, extra])
  }

  let with_creds =
    container.new(c.image)
    |> container.expose_port(mysql_port)
    |> container.with_env("MYSQL_DATABASE", c.database)
    |> container.with_env("MYSQL_USER", c.username)
    |> container.with_secret_env("MYSQL_PASSWORD", c.password)
    |> container.with_secret_env("MYSQL_ROOT_PASSWORD", c.root_password)
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
    use mapped_port <- result.try(container.host_port(running, mysql_port))
    let host = container.host(running)
    let pass = cowl.reveal(c.password)
    Ok(MysqlContainer(
      container: running,
      connection_url: "mysql://"
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
