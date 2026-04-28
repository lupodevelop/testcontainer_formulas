//// RabbitMQ formula. Defaults to `rabbitmq:3-management` with guest creds.
////
////     use mq <- testcontainer.with_formula(
////       rabbitmq.new()
////       |> rabbitmq.with_username("app")
////       |> rabbitmq.with_password("secret")
////       |> rabbitmq.formula(),
////     )
////
////     // mq.amqp_url, mq.management_url, mq.host, mq.amqp_port

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
pub type RabbitMqContainer {
  RabbitMqContainer(
    container: container.Container,
    amqp_url: String,
    management_url: String,
    host: String,
    amqp_port: Int,
    management_port: Int,
    username: String,
    vhost: String,
  )
}

/// RabbitMQ-specific configuration. Build with `new/0` + `with_*`.
pub opaque type RabbitMqConfig {
  RabbitMqConfig(
    image: String,
    username: String,
    password: cowl.Secret(String),
    vhost: String,
    extra_wait: Option(wait.WaitStrategy),
    network: Option(String),
    name: Option(String),
  )
}

/// Sensible defaults: `rabbitmq:3-management` / `guest` / `guest` / `/`.
pub fn new() -> RabbitMqConfig {
  RabbitMqConfig(
    image: "rabbitmq:3-management",
    username: "guest",
    password: cowl.secret("guest"),
    vhost: "/",
    extra_wait: None,
    network: None,
    name: None,
  )
}

/// Replaces the image entirely.
pub fn with_image(c: RabbitMqConfig, image: String) -> RabbitMqConfig {
  RabbitMqConfig(..c, image: image)
}

/// Shorthand for `rabbitmq:<version>` (for example `3.13-management`).
pub fn with_version(c: RabbitMqConfig, version: String) -> RabbitMqConfig {
  RabbitMqConfig(..c, image: "rabbitmq:" <> version)
}

pub fn with_username(c: RabbitMqConfig, user: String) -> RabbitMqConfig {
  RabbitMqConfig(..c, username: user)
}

pub fn with_password(c: RabbitMqConfig, pass: String) -> RabbitMqConfig {
  RabbitMqConfig(..c, password: cowl.secret(pass))
}

pub fn with_secret_password(
  c: RabbitMqConfig,
  pass: cowl.Secret(String),
) -> RabbitMqConfig {
  RabbitMqConfig(..c, password: pass)
}

/// Sets the default vhost used by RabbitMQ bootstrap.
pub fn with_vhost(c: RabbitMqConfig, vhost: String) -> RabbitMqConfig {
  RabbitMqConfig(..c, vhost: vhost)
}

/// Adds an extra wait strategy on top of the default
/// `all_of([port(5672), log("Server startup complete")])`.
pub fn with_extra_wait(c: RabbitMqConfig, s: wait.WaitStrategy) -> RabbitMqConfig {
  RabbitMqConfig(..c, extra_wait: Some(s))
}

pub fn on_network(c: RabbitMqConfig, net: network.Network) -> RabbitMqConfig {
  RabbitMqConfig(..c, network: Some(network.name(net)))
}

/// Same as `on_network/2` when you already have the Docker network name.
pub fn on_network_name(c: RabbitMqConfig, net: String) -> RabbitMqConfig {
  RabbitMqConfig(..c, network: Some(net))
}

pub fn with_name(c: RabbitMqConfig, n: String) -> RabbitMqConfig {
  RabbitMqConfig(..c, name: Some(n))
}

/// Builds the `Formula(RabbitMqContainer)` ready to pass to
/// `testcontainer.with_formula/2`.
pub fn formula(c: RabbitMqConfig) -> formula.Formula(RabbitMqContainer) {
  let amqp_port = port.tcp(5672)
  let management_port = port.tcp(15672)
  let base_wait = wait.all_of([wait.port(5672), wait.log("Server startup complete")])
  let wait_strategy = case c.extra_wait {
    None -> base_wait
    Some(extra) -> wait.all_of([base_wait, extra])
  }

  let with_creds =
    container.new(c.image)
    |> container.expose_port(amqp_port)
    |> container.expose_port(management_port)
    |> container.with_env("RABBITMQ_DEFAULT_USER", c.username)
    |> container.with_secret_env("RABBITMQ_DEFAULT_PASS", c.password)
    |> container.with_env("RABBITMQ_DEFAULT_VHOST", c.vhost)
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
    use mapped_amqp <- result.try(container.host_port(running, amqp_port))
    use mapped_management <- result.try(container.host_port(running, management_port))
    let host = container.host(running)
    let pass = cowl.reveal(c.password)
    Ok(RabbitMqContainer(
      container: running,
      amqp_url: "amqp://"
        <> uri.percent_encode(c.username)
        <> ":"
        <> uri.percent_encode(pass)
        <> "@"
        <> host
        <> ":"
        <> int.to_string(mapped_amqp)
        <> "/"
        <> uri.percent_encode(c.vhost),
      management_url: "http://" <> host <> ":" <> int.to_string(mapped_management),
      host: host,
      amqp_port: mapped_amqp,
      management_port: mapped_management,
      username: c.username,
      vhost: c.vhost,
    ))
  })
}
