# Changelog

## v1.1.1 (2026-02-27)

### Improved

- Added JSV validation examples to README (runtime validation, API contract testing, webhook payloads)
- Trimmed `@moduledoc` to avoid duplication with README
- Enriched `atomize/2` docs with enum, nested object, and array examples
- Added output examples to `schema/2` docs
- Enabled doctests

## v1.1.0 (2025-02-25)

### Added

- `atomize/2` function to convert string-keyed JSON data back to atom keys
  - Uses the schema's `"properties"` as the source of allowed keys
  - Converts enum string values to atoms (e.g., `"active"` → `:active`)
  - Recursively atomizes nested objects and arrays of objects
  - Unknown keys are left as strings (safe for untrusted input)

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
