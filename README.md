# testcontainer_formulas

[![Hex Package](https://img.shields.io/hexpm/v/testcontainer_formulas?color=ffaff3)](https://hex.pm/packages/testcontainer_formulas)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/testcontainer_formulas/)
[![CI](https://github.com/lupodevelop/testcontainer_formulas/actions/workflows/test.yml/badge.svg)](https://github.com/lupodevelop/testcontainer_formulas/actions/workflows/test.yml)
[![License](https://img.shields.io/hexpm/l/testcontainer_formulas?color=blue)](LICENSE)

Ready-to-use formulas for `testcontainer` with typed outputs.

Each formula gives you sensible defaults plus a rich record (for example
`PostgresContainer` with `connection_url`, `host`, `port`) so tests do not
rebuild connection strings manually.

## Install

```sh
gleam add testcontainer
gleam add testcontainer_formulas
```

## Quick example

```gleam
import testcontainer
import testcontainer_formulas/postgres

pub fn user_repository_test() {
  use pg <- testcontainer.with_formula(
    postgres.new()
    |> postgres.with_database("myapp_test")
    |> postgres.with_password("secret")
    |> postgres.formula(),
  )

  let _ = pg.connection_url
  Ok(Nil)
}
```

## Available formulas

- `testcontainer_formulas/mongo`
- `testcontainer_formulas/mysql`
- `testcontainer_formulas/postgres`
- `testcontainer_formulas/rabbitmq`
- `testcontainer_formulas/redis`

## Documentation

- [Quickstart](docs/quickstart.md)
- [Writing formulas](docs/writing-formulas.md)
- [Testing model](docs/testing-model.md)

## License

[MIT](LICENSE).
