//// Redis formula. Defaults to `redis:7-alpine` with no auth.
////
////     use cache <- testcontainer.with_formula(
////       redis.new() |> redis.formula(),
////     )
////
////     // cache.url, cache.host, cache.port

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
pub type RedisContainer {
  RedisContainer(
    container: container.Container,
    url: String,
    host: String,
    port: Int,
  )
}

/// Redis-specific configuration. Build with `new/0` + `with_*`.
pub opaque type RedisConfig {
  RedisConfig(
    image: String,
    password: Option(cowl.Secret(String)),
    extra_wait: Option(wait.WaitStrategy),
    network: Option(String),
    name: Option(String),
  )
}

/// Sensible default: `redis:7-alpine`, no auth, no persistence.
pub fn new() -> RedisConfig {
  RedisConfig(
    image: "redis:7-alpine",
    password: None,
    extra_wait: None,
    network: None,
    name: None,
  )
}

/// Replaces the image entirely.
pub fn with_image(c: RedisConfig, image: String) -> RedisConfig {
  RedisConfig(..c, image: image)
}

/// Shorthand for `redis:<version>`.
pub fn with_version(c: RedisConfig, version: String) -> RedisConfig {
  RedisConfig(..c, image: "redis:" <> version)
}

/// Enables Redis auth by starting `redis-server --requirepass <password>`.
pub fn with_password(c: RedisConfig, pass: String) -> RedisConfig {
  RedisConfig(..c, password: Some(cowl.secret(pass)))
}

/// Same as `with_password/2` when the value is already a `cowl.Secret`.
pub fn with_secret_password(
  c: RedisConfig,
  pass: cowl.Secret(String),
) -> RedisConfig {
  RedisConfig(..c, password: Some(pass))
}

/// Disables Redis auth (default behaviour).
pub fn without_password(c: RedisConfig) -> RedisConfig {
  RedisConfig(..c, password: None)
}

/// Adds an extra wait strategy on top of the default
/// `log("Ready to accept connections")`.
pub fn with_extra_wait(c: RedisConfig, s: wait.WaitStrategy) -> RedisConfig {
  RedisConfig(..c, extra_wait: Some(s))
}

pub fn on_network(c: RedisConfig, net: network.Network) -> RedisConfig {
  RedisConfig(..c, network: Some(network.name(net)))
}

/// Same as `on_network/2` when you already have the Docker network name.
pub fn on_network_name(c: RedisConfig, net: String) -> RedisConfig {
  RedisConfig(..c, network: Some(net))
}

pub fn with_name(c: RedisConfig, n: String) -> RedisConfig {
  RedisConfig(..c, name: Some(n))
}

/// Builds the `Formula(RedisContainer)` ready to pass to
/// `testcontainer.with_formula/2`.
pub fn formula(c: RedisConfig) -> formula.Formula(RedisContainer) {
  let redis_port = port.tcp(6379)
  let base_wait = wait.log("Ready to accept connections")
  let wait_strategy = case c.extra_wait {
    None -> base_wait
    Some(extra) -> wait.all_of([base_wait, extra])
  }

  let with_basic =
    container.new(c.image)
    |> container.expose_port(redis_port)
    |> container.wait_for(wait_strategy)

  let with_auth = case c.password {
    None -> with_basic
    Some(pass) ->
      with_basic
      |> container.with_command([
        "redis-server",
        "--requirepass",
        cowl.reveal(pass),
      ])
  }

  let with_net = case c.network {
    None -> with_auth
    Some(n) -> with_auth |> container.on_network(n)
  }

  let final_spec = case c.name {
    None -> with_net
    Some(n) -> with_net |> container.with_name(n)
  }

  formula.new(final_spec, fn(running) {
    use mapped_port <- result.try(container.host_port(running, redis_port))
    let host = container.host(running)
    let url = case c.password {
      None -> "redis://" <> host <> ":" <> int.to_string(mapped_port)
      Some(pass) ->
        "redis://:"
        <> uri.percent_encode(cowl.reveal(pass))
        <> "@"
        <> host
        <> ":"
        <> int.to_string(mapped_port)
    }
    Ok(RedisContainer(
      container: running,
      url: url,
      host: host,
      port: mapped_port,
    ))
  })
}
