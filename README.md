# JSONSpec

Elixir typespec syntax → JSON Schema, at compile time.

Write familiar Elixir types, get a JSON Schema map with zero runtime cost.

```elixir
import JSONSpec

json_spec(%{
  required(:location) => String.t(),
  optional(:units) => :celsius | :fahrenheit
})

# => %{
#   "type" => "object",
#   "properties" => %{
#     "location" => %{"type" => "string"},
#     "units" => %{"type" => "string", "enum" => ["celsius", "fahrenheit"]}
#   },
#   "required" => ["location"],
#   "additionalProperties" => false
# }
```

## Installation

```elixir
def deps do
  [{:json_spec, "~> 0.1.0"}]
end
```

## Usage

### Objects

Keyword-style keys are required by default:

```elixir
json_spec(%{name: String.t(), age: integer()})
# Both "name" and "age" in "required"
```

Use `optional()` / `required()` with arrow syntax for explicit control:

```elixir
json_spec(%{
  required(:name) => String.t(),
  optional(:email) => String.t()
})
```

Or use `| nil` to mark a field as optional:

```elixir
json_spec(%{name: String.t(), email: String.t() | nil})
# Only "name" in "required"
```

### Descriptions

```elixir
json_spec(
  %{required(:location) => String.t(), optional(:units) => :celsius | :fahrenheit},
  doc: [location: "City name", units: "Temperature units"]
)
```

### Enums

Unions of atoms become `"enum"`:

```elixir
json_spec(:active | :inactive | :pending)
# => %{"type" => "string", "enum" => ["active", "inactive", "pending"]}
```

### Arrays

```elixir
json_spec([String.t()])
# => %{"type" => "array", "items" => %{"type" => "string"}}

json_spec([%{id: integer(), name: String.t()}])
# Array of objects
```

### Nesting

```elixir
json_spec(%{
  user: %{
    name: String.t(),
    address: %{city: String.t(), zip: String.t()}
  }
})
```

## Type mapping

| Elixir | JSON Schema |
|---|---|
| `String.t()` | `{"type": "string"}` |
| `binary()` | `{"type": "string"}` |
| `integer()` | `{"type": "integer"}` |
| `pos_integer()` | `{"type": "integer", "minimum": 1}` |
| `non_neg_integer()` | `{"type": "integer", "minimum": 0}` |
| `neg_integer()` | `{"type": "integer", "maximum": -1}` |
| `float()` | `{"type": "number"}` |
| `number()` | `{"type": "number"}` |
| `boolean()` | `{"type": "boolean"}` |
| `map()` | `{"type": "object"}` |
| `atom()` | `{"type": "string"}` |
| `term()` / `any()` | `{}` (no constraints) |
| `:a \| :b \| :c` | `{"enum": ["a", "b", "c"]}` |
| `[type]` | `{"type": "array", "items": ...}` |
| `%{k: type}` | nested object |
| `type \| nil` | optional (not in `required`) |

## Use with LLM tools

JSONSpec pairs well with [ReqLLM](https://github.com/agentjido/req_llm):

```elixir
import JSONSpec

Tool.new!(
  name: "get_weather",
  description: "Get current weather for a location",
  parameter_schema: json_spec(
    %{
      required(:location) => String.t(),
      optional(:units) => :celsius | :fahrenheit
    },
    doc: [location: "City name", units: "Temperature units"]
  ),
  callback: {WeatherService, :get_current_weather}
)
```

## License

MIT
