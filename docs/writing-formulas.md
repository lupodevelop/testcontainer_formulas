# Writing Formulas

A formula module should be additive, typed, and easy to override.

## Minimal shape

```gleam
import gleam/int
import gleam/result
import testcontainer/container
import testcontainer/formula
import testcontainer/port
import testcontainer/wait

pub type FooContainer {
  FooContainer(container: container.Container, url: String, host: String, port: Int)
}

pub opaque type FooConfig {
  FooConfig(image: String)
}

pub fn new() -> FooConfig {
  FooConfig(image: "foo:latest")
}

pub fn with_image(c: FooConfig, image: String) -> FooConfig {
  FooConfig(..c, image: image)
}

pub fn formula(c: FooConfig) -> formula.Formula(FooContainer) {
  let p = port.tcp(1234)
  let spec =
    container.new(c.image)
    |> container.expose_port(p)
    |> container.wait_for(wait.log("ready"))

  formula.new(spec, fn(running) {
    use hp <- result.try(container.host_port(running, p))
    let host = container.host(running)
    Ok(FooContainer(
      container: running,
      url: "foo://" <> host <> ":" <> int.to_string(hp),
      host: host,
      port: hp,
    ))
  })
}
```

## Design guidelines

1. Keep `new()` runnable with sensible defaults.
2. Add only `with_*` builders; avoid breaking signature changes.
3. Expose a typed output with `container` as escape hatch.
4. Support network composition (`on_network`, `with_name`) for stacks.
5. Keep waits explicit and stable (log, port, http, health, command).
6. Use `cowl.Secret` for sensitive config and avoid leaks in inspect/logs.

## Suggested builders

- `with_image/2`
- `with_version/2`
- `with_extra_wait/2`
- `on_network/2` and `on_network_name/2`
- `with_name/2`
- `with_password/2` and `with_secret_password/2` when auth is supported

## What to avoid

1. Hidden side effects in `formula/1`.
2. Hardcoded host ports.
3. Returning generic `Container` as the only output.
4. Formula-specific behavior that cannot be overridden.
