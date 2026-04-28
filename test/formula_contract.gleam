import envie
import gleam/string
import gleeunit/should

pub fn integration_enabled() -> Bool {
  envie.get_bool("TESTCONTAINER_FORMULAS_INTEGRATION", False)
}

pub fn run_builder_contract(build: fn() -> a) -> Nil {
  let _ = build()
  Nil
}

pub fn assert_non_empty(value: String) -> Nil {
  value |> should.not_equal("")
}

pub fn assert_positive_port(value: Int) -> Nil {
  { value > 0 } |> should.be_true()
}

pub fn assert_endpoint_contract(
  url: String,
  scheme_prefix: String,
  host: String,
  port: Int,
) -> Nil {
  assert_non_empty(url)
  assert_non_empty(host)
  assert_positive_port(port)
  string.starts_with(url, scheme_prefix) |> should.be_true()
}
