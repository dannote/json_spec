# JSONSpec

[![Hex.pm](https://img.shields.io/hexpm/v/json_spec.svg)](https://hex.pm/packages/json_spec)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/json_spec)

Elixir typespec syntax → JSON Schema, at compile time.

Write familiar Elixir types, get a JSON Schema map with zero runtime cost.

```elixir
import JSONSpec

schema(%{
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
  [{:json_spec, "~> 1.1"}]
end
```

## Usage

### Objects

Keyword-style keys are required by default:

```elixir
schema(%{name: String.t(), age: integer()})
# Both "name" and "age" in "required"
```

Use `optional()` / `required()` with arrow syntax for explicit control:

```elixir
schema(%{
  required(:name) => String.t(),
  optional(:email) => String.t()
})
```

Or use `| nil` to mark a field as optional:

```elixir
schema(%{name: String.t(), email: String.t() | nil})
# Only "name" in "required"
```

### Descriptions

```elixir
schema(
  %{required(:location) => String.t(), optional(:units) => :celsius | :fahrenheit},
  doc: [location: "City name", units: "Temperature units"]
)
```

### Enums

Unions of atoms become `"enum"`:

```elixir
schema(:active | :inactive | :pending)
# => %{"type" => "string", "enum" => ["active", "inactive", "pending"]}
```

### Arrays

```elixir
schema([String.t()])
# => %{"type" => "array", "items" => %{"type" => "string"}}

schema([%{id: integer(), name: String.t()}])
# Array of objects
```

### Nesting

```elixir
schema(%{
  user: %{
    name: String.t(),
    address: %{city: String.t(), zip: String.t()}
  }
})
```

### Atomizing

JSON data uses string keys. `atomize/2` converts them back to atoms using
the schema as the source of truth:

```elixir
my_schema = schema(%{
  required(:name) => String.t(),
  required(:status) => :active | :inactive,
  optional(:age) => integer()
})

JSONSpec.atomize(my_schema, %{"name" => "Alice", "status" => "active", "age" => 30})
# => %{name: "Alice", status: :active, age: 30}
```

Enum string values are converted to atoms. Nested objects and arrays of
objects are atomized recursively.

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

## Validate with JSV

Pair with [JSV](https://hexdocs.pm/jsv) to validate incoming data against
your schemas at runtime:

```elixir
import JSONSpec

@user_schema schema(%{
  required(:name) => String.t(),
  required(:email) => String.t(),
  optional(:role) => :admin | :editor | :viewer
})

root = JSV.build!(@user_schema)

case JSV.validate(params, root) do
  {:ok, data} -> create_user(data)
  {:error, error} -> {:error, JSV.normalize_error(error)}
end
```

### API contract testing

Use schemas in ExUnit tests to verify your API responses match the contract:

```elixir
@user_response schema(%{
  required(:id) => integer(),
  required(:name) => String.t(),
  required(:email) => String.t(),
  optional(:avatar_url) => String.t()
})

test "GET /api/users/:id returns a valid user" do
  root = JSV.build!(@user_response)
  conn = get(conn, ~p"/api/users/1")
  assert {:ok, _} = JSV.validate(json_response(conn, 200), root)
end
```

### Webhook payload validation

Document and validate outgoing webhook payloads:

```elixir
@webhook_schema schema(%{
  required(:event) => :order_created | :order_updated | :order_cancelled,
  required(:timestamp) => String.t(),
  required(:data) => %{
    required(:order_id) => integer(),
    required(:total) => number(),
    optional(:items) => [%{name: String.t(), quantity: pos_integer()}]
  }
})

root = JSV.build!(@webhook_schema)

def deliver_webhook(payload) do
  {:ok, _} = JSV.validate(payload, root)
  WebhookClient.post(payload)
end
```

## Use with ReqLLM

JSONSpec works with [ReqLLM](https://hexdocs.pm/req_llm) tool calling.
Define the schema, then atomize the args the LLM sends back:

```elixir
import JSONSpec

@weather_schema schema(
  %{
    required(:location) => String.t(),
    optional(:units) => :celsius | :fahrenheit
  },
  doc: [location: "City name", units: "Temperature units"]
)

ReqLLM.tool(
  name: "get_weather",
  description: "Get current weather for a location",
  parameter_schema: @weather_schema,
  callback: fn args ->
    %{location: location, units: units} = JSONSpec.atomize(@weather_schema, args)
    WeatherService.get(location, units || :celsius)
  end
)
```

## License

MIT
