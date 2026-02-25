# Changelog

## v1.0.0 (2025-02-25)

Initial release.

### Features

- `schema/1,2` macro converts Elixir typespec syntax to JSON Schema at compile time
- Zero runtime cost — all conversion happens during compilation
- Supports primitive types: `String.t()`, `integer()`, `boolean()`, `number()`, etc.
- Supports constrained integers: `pos_integer()`, `non_neg_integer()`, `neg_integer()`
- Supports enums via atom unions: `:a | :b | :c`
- Supports arrays via list syntax: `[String.t()]`
- Supports objects via map syntax with `required()`/`optional()` keys
- Supports nested objects and arrays of objects
- Supports nullable types via `| nil` (marks field as optional)
- Supports field descriptions via `doc:` option
- Generated schemas include `"additionalProperties": false` for strict validation
