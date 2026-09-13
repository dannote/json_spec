defmodule JSONSpec do
  @moduledoc """
  Elixir typespec syntax → JSON Schema, at compile time.

  Write familiar Elixir types and get a JSON Schema map with zero runtime cost.
  See the [overview](readme.html) for a full guide with examples.

  ## Type mapping

  | Elixir type | JSON Schema |
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
  | `:a \\| :b \\| :c` | `{"type": "string", "enum": ["a", "b", "c"]}` |
  | `[String.t()]` | `{"type": "array", "items": {"type": "string"}}` |
  | `%{key: type}` | nested object |
  | `optional(:key) => type` | omitted from `required` |
  | `type \\| nil` | omitted from `required` |
  """

  @doc """
  Converts a string-keyed map to an atom-keyed map using the schema's
  `"properties"` as the source of allowed keys.

  Unknown keys are left as strings. Enum values are converted to atoms.
  Nested objects and arrays of objects are atomized recursively.

  ## Examples

      iex> import JSONSpec
      iex> my_schema = schema(%{required(:name) => String.t(), optional(:age) => integer()})
      iex> JSONSpec.atomize(my_schema, %{"name" => "Alice", "age" => 30})
      %{name: "Alice", age: 30}

  Enum string values become atoms:

      iex> import JSONSpec
      iex> my_schema = schema(%{status: :active | :inactive})
      iex> JSONSpec.atomize(my_schema, %{"status" => "active"})
      %{status: :active}

  Nested objects are atomized recursively:

      iex> import JSONSpec
      iex> my_schema = schema(%{user: %{name: String.t(), role: :admin | :member}})
      iex> JSONSpec.atomize(my_schema, %{"user" => %{"name" => "Alice", "role" => "admin"}})
      %{user: %{name: "Alice", role: :admin}}

  Arrays of objects too:

      iex> import JSONSpec
      iex> my_schema = schema(%{items: [%{id: integer(), status: :on | :off}]})
      iex> JSONSpec.atomize(my_schema, %{"items" => [%{"id" => 1, "status" => "on"}]})
      %{items: [%{id: 1, status: :on}]}
  """
  @spec atomize(map(), map()) :: map()
  def atomize(%{"properties" => properties}, data) when is_map(data) do
    Map.new(data, fn {k, v} ->
      str_key = to_string(k)

      case Map.fetch(properties, str_key) do
        {:ok, prop_schema} ->
          {String.to_atom(str_key), atomize_value(prop_schema, v)}

        :error ->
          {k, v}
      end
    end)
  end

  def atomize(_schema, data), do: data

  defp atomize_value(%{"type" => "object", "properties" => _} = schema, value)
       when is_map(value),
       do: atomize(schema, value)

  defp atomize_value(%{"type" => "array", "items" => items}, values)
       when is_list(values),
       do: Enum.map(values, &atomize_value(items, &1))

  defp atomize_value(%{"enum" => _}, value) when is_binary(value),
    do: String.to_atom(value)

  defp atomize_value(_schema, value), do: value

  @doc """
  Converts an Elixir typespec AST to a JSON Schema map at compile time.

  The macro captures the quoted form of the type expression and converts it
  to a JSON Schema map. The result is a plain map embedded in your compiled code.

  ## Options

    * `:doc` - Keyword list mapping field names to description strings

  ## Examples

      iex> import JSONSpec
      iex> schema(%{name: String.t(), age: integer()})
      %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name", "age"],
        "additionalProperties" => false
      }

      iex> import JSONSpec
      iex> schema([String.t()])
      %{"type" => "array", "items" => %{"type" => "string"}}

      iex> import JSONSpec
      iex> schema(:active | :inactive | :pending)
      %{"type" => "string", "enum" => ["active", "inactive", "pending"]}

  With descriptions:

      iex> import JSONSpec
      iex> schema(
      ...>   %{required(:name) => String.t(), optional(:age) => integer()},
      ...>   doc: [name: "Full name", age: "Age in years"]
      ...> )
      %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string", "description" => "Full name"},
          "age" => %{"type" => "integer", "description" => "Age in years"}
        },
        "required" => ["name"],
        "additionalProperties" => false
      }
  """
  defmacro schema(type_ast, opts \\ []) do
    docs = extract_docs(opts)
    schema = convert(type_ast, docs)
    Macro.escape(schema)
  end

  @typedoc "A normalized type description for schema generation."
  @type schema_type ::
          atom()
          | {:literal, term()}
          | {:enum, [atom()]}
          | {:nullable, schema_type()}
          | {:one_of, [schema_type()]}
          | {:list, schema_type()}
          | {:map, :string, schema_type()}
          | {:object, [schema_field()]}
          | {:ref, term()}
          | {:schema, map() | boolean()}

  @type schema_field :: %{
          required(:name) => String.t(),
          required(:type) => schema_type(),
          optional(:required) => boolean()
        }

  @doc """
  Generates JSON Schema from normalized field/type metadata.

  Unlike `schema/2`, this function accepts data rather than quoted Elixir syntax.
  Fields use their JSON names and explicit requiredness; omitted `:required`
  means optional. This lets codec libraries apply aliases and defaults without
  duplicating JSON Schema generation.

      JSONSpec.from_type({:object, [
        %{name: "name", type: :string, required: true},
        %{name: "age", type: {:nullable, :non_neg_integer}}
      ]})

  `:resolve` accepts a unary function returning a type description for a
  `{:ref, id}`. Unrecognized atom types also resolve through this callback,
  allowing consumers to resolve remote modules without JSONSpec depending on
  those modules. Cycles become local `$ref` pointers; acyclic objects stay inline.

  `{:one_of, types}` describes an Elixir union and emits `anyOf`, since its
  alternatives may overlap. Nullable values use `anyOf` with a null branch by
  default. Field optionality
  is independent of nullability. `nullable: :legacy` emits the nonstandard
  `"nullable": true` form for adapters that must preserve an existing contract.
  The `schema/2` macro's existing optional-field semantics are unchanged.

  `{:schema, value}` passes through an already-built object or boolean schema
  without rebasing its references. No cache is retained between calls.
  """
  @spec from_type(schema_type(), keyword()) :: map() | boolean()
  def from_type(type, options \\ []), do: JSONSpec.Generator.generate(type, options)

  @spec extract_docs(keyword()) :: %{String.t() => String.t()}
  defp extract_docs(opts) do
    case Keyword.get(opts, :doc) do
      nil ->
        %{}

      docs when is_list(docs) ->
        Map.new(docs, fn {k, v} -> {Atom.to_string(k), v} end)

      other ->
        raise ArgumentError,
              "json_spec :doc option must be a keyword list, got: #{inspect(other)}"
    end
  end

  @doc false
  @spec convert(Macro.t(), %{String.t() => String.t()}) :: map()
  def convert(ast, docs \\ %{})

  # %{key: type, ...} — map literal with keyword pairs
  def convert({:%{}, _, fields}, docs) when is_list(fields) do
    {properties, required} =
      Enum.reduce(fields, {%{}, []}, &convert_field(&1, &2, docs))

    schema = %{
      "type" => "object",
      "properties" => properties,
      "additionalProperties" => false
    }

    case Enum.reverse(required) do
      [] -> schema
      req -> Map.put(schema, "required", req)
    end
  end

  # [type] — list literal (shorthand for list(type))
  def convert([inner_ast], docs) do
    %{"type" => "array", "items" => convert(inner_ast, docs)}
  end

  # list(type)
  def convert({:list, _, [inner_ast]}, docs) do
    %{"type" => "array", "items" => convert(inner_ast, docs)}
  end

  # Union of atoms — :a | :b | :c → enum
  def convert({:|, _, _} = union_ast, _docs) do
    case collect_union(union_ast) do
      {:enum, values} ->
        %{"type" => "string", "enum" => Enum.map(values, &Atom.to_string/1)}

      {:nullable, inner} ->
        convert(inner)

      :mixed ->
        raise ArgumentError,
              "json_spec: unsupported union type. " <>
                "Unions must be all atoms (enum) or `type | nil` (nullable). " <>
                "Got: #{Macro.to_string(union_ast)}"
    end
  end

  # String.t()
  def convert({{:., _, [{:__aliases__, _, [:String]}, :t]}, _, []}, _docs) do
    from_type(:string)
  end

  # Built-in types share the normalized generator's mappings.
  def convert({:binary, _, []}, _docs), do: from_type(:string)
  def convert({:integer, _, []}, _docs), do: from_type(:integer)
  def convert({:pos_integer, _, []}, _docs), do: from_type(:pos_integer)
  def convert({:non_neg_integer, _, []}, _docs), do: from_type(:non_neg_integer)
  def convert({:neg_integer, _, []}, _docs), do: from_type(:neg_integer)
  def convert({:float, _, []}, _docs), do: from_type(:float)
  def convert({:number, _, []}, _docs), do: from_type(:number)
  def convert({:boolean, _, []}, _docs), do: from_type(:boolean)
  def convert({:map, _, []}, _docs), do: from_type(:map)
  def convert({:atom, _, []}, _docs), do: from_type(:atom)
  def convert({:any, _, []}, _docs), do: from_type(:any)
  def convert({:term, _, []}, _docs), do: from_type(:term)

  def convert(other, _docs) do
    raise ArgumentError,
          "json_spec: unsupported type expression: #{Macro.to_string(other)}"
  end

  # Convert a single field from a map spec
  @spec convert_field(tuple(), {map(), [String.t()]}, %{String.t() => String.t()}) ::
          {map(), [String.t()]}
  defp convert_field(field, {props, req}, docs) do
    case field do
      # optional(:key) => type
      {{:optional, _, [key]}, type_ast} when is_atom(key) ->
        name = Atom.to_string(key)
        prop = type_ast |> convert() |> maybe_add_description(name, docs)
        {Map.put(props, name, prop), req}

      # required(:key) => type (explicit required)
      {{:required, _, [key]}, type_ast} when is_atom(key) ->
        name = Atom.to_string(key)
        prop = type_ast |> convert() |> maybe_add_description(name, docs)
        {Map.put(props, name, prop), [name | req]}

      # key: type (default = required)
      {key, type_ast} when is_atom(key) ->
        convert_keyword_field(key, type_ast, props, req, docs)
    end
  end

  @spec convert_keyword_field(atom(), Macro.t(), map(), [String.t()], %{String.t() => String.t()}) ::
          {map(), [String.t()]}
  defp convert_keyword_field(key, type_ast, props, req, docs) do
    name = Atom.to_string(key)
    {prop, nullable} = convert_maybe_nullable(type_ast)
    prop = maybe_add_description(prop, name, docs)

    if nullable do
      {Map.put(props, name, prop), req}
    else
      {Map.put(props, name, prop), [name | req]}
    end
  end

  # Check if a type is `type | nil` (nullable), returning {schema, true} if so
  @spec convert_maybe_nullable(Macro.t()) :: {map(), boolean()}
  defp convert_maybe_nullable({:|, _, _} = union_ast) do
    members = flatten_union(union_ast)
    has_nil = nil in members
    non_nil = Enum.reject(members, &is_nil/1)
    all_atoms = Enum.all?(non_nil, &is_atom/1)

    if all_atoms and has_nil and length(non_nil) >= 2 do
      schema = %{"type" => "string", "enum" => Enum.map(non_nil, &Atom.to_string/1)}
      {schema, true}
    else
      convert_union_type(union_ast)
    end
  end

  defp convert_maybe_nullable(ast), do: {convert(ast), false}

  @spec convert_union_type(Macro.t()) :: {map(), boolean()}
  defp convert_union_type(union_ast) do
    case collect_union(union_ast) do
      {:nullable, inner} ->
        {convert(inner), true}

      {:enum, values} ->
        {%{"type" => "string", "enum" => Enum.map(values, &Atom.to_string/1)}, false}

      :mixed ->
        raise ArgumentError,
              "json_spec: unsupported union: #{Macro.to_string(union_ast)}"
    end
  end

  # Collect all members of a `|` union into a flat list and classify it
  @spec collect_union(Macro.t()) :: {:enum, [atom()]} | {:nullable, Macro.t()} | :mixed
  defp collect_union(ast) do
    members = flatten_union(ast)
    classify_union_members(members)
  end

  @spec classify_union_members([Macro.t()]) :: {:enum, [atom()]} | {:nullable, Macro.t()} | :mixed
  defp classify_union_members(members) do
    has_nil = nil in members
    non_nil = Enum.reject(members, &is_nil/1)
    all_atoms = Enum.all?(non_nil, &is_atom/1)

    classify_union(all_atoms, has_nil, non_nil)
  end

  @spec classify_union(boolean(), boolean(), [Macro.t()]) ::
          {:enum, [atom()]} | {:nullable, Macro.t()} | :mixed
  defp classify_union(true, true, [_single_atom]) do
    # Single atom | nil — treat as nullable string
    {:nullable, {:atom, [], []}}
  end

  defp classify_union(true, _has_nil, non_nil) do
    # All atoms (with or without nil) — enum
    {:enum, non_nil}
  end

  defp classify_union(false, true, [single]) do
    # type | nil — nullable
    {:nullable, single}
  end

  defp classify_union(_all_atoms, _has_nil, _non_nil), do: :mixed

  @spec flatten_union(Macro.t()) :: [Macro.t()]
  defp flatten_union({:|, _, [left, right]}) do
    flatten_union(left) ++ flatten_union(right)
  end

  defp flatten_union(other), do: [other]

  @spec maybe_add_description(map(), String.t(), %{String.t() => String.t()}) :: map()
  defp maybe_add_description(schema, name, docs) do
    case Map.get(docs, name) do
      nil -> schema
      desc -> Map.put(schema, "description", desc)
    end
  end
end
