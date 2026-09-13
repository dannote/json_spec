defmodule JSONSpec.Generator do
  @moduledoc false

  def generate(type, options) do
    options = Keyword.validate!(options, [:resolve, :nullable])
    resolver = Keyword.get(options, :resolve, &unresolved!/1)
    nullable = Keyword.get(options, :nullable, :json_schema)

    unless is_function(resolver, 1) and nullable in [:json_schema, :legacy] do
      raise ArgumentError,
            "expected a unary :resolve function and :nullable to be :json_schema or :legacy"
    end

    schema(type, %{resolve: resolver, nullable: nullable, seen: %{}}, [])
  end

  defp schema(:string, _state, _path), do: %{"type" => "string"}
  defp schema(:integer, _state, _path), do: %{"type" => "integer"}
  defp schema(:non_neg_integer, _state, _path), do: %{"type" => "integer", "minimum" => 0}
  defp schema(:pos_integer, _state, _path), do: %{"type" => "integer", "minimum" => 1}
  defp schema(:neg_integer, _state, _path), do: %{"type" => "integer", "maximum" => -1}
  defp schema(:float, _state, _path), do: %{"type" => "number"}
  defp schema(:number, _state, _path), do: %{"type" => "number"}
  defp schema(:boolean, _state, _path), do: %{"type" => "boolean"}
  defp schema(:atom, _state, _path), do: %{"type" => "string"}
  defp schema(:map, _state, _path), do: %{"type" => "object"}
  defp schema(:any, _state, _path), do: %{}
  defp schema(:term, _state, _path), do: %{}
  defp schema(nil, _state, _path), do: %{"type" => "null"}
  defp schema({:literal, value}, _state, _path), do: %{"const" => value}
  defp schema({:schema, value}, _state, _path) when is_map(value) or is_boolean(value), do: value

  defp schema({:enum, values}, _state, _path),
    do: %{"type" => "string", "enum" => Enum.map(values, &to_string/1)}

  defp schema({:nullable, type}, %{nullable: :legacy} = state, path),
    do: Map.put(schema(type, state, path), "nullable", true)

  defp schema({:nullable, type}, state, path),
    do: schema({:one_of, [type, nil]}, state, path)

  defp schema({:one_of, types}, state, path) do
    variants =
      types
      |> Enum.with_index()
      |> Enum.map(fn {type, index} ->
        schema(type, state, [Integer.to_string(index), "anyOf" | path])
      end)

    %{"anyOf" => variants}
  end

  defp schema({:list, type}, state, path),
    do: %{"type" => "array", "items" => schema(type, state, ["items" | path])}

  defp schema({:map, :string, type}, state, path),
    do: %{
      "type" => "object",
      "additionalProperties" => schema(type, state, ["additionalProperties" | path])
    }

  defp schema({:object, fields}, state, path) when is_list(fields) do
    properties =
      Map.new(fields, fn field ->
        validate_field!(field)
        %{name: name, type: type} = field
        {name, schema(type, state, [name, "properties" | path])}
      end)

    if map_size(properties) != length(fields),
      do: raise(ArgumentError, "duplicate JSON property names")

    required = for %{name: name, required: true} <- fields, do: name
    object = %{"type" => "object", "properties" => properties, "additionalProperties" => false}
    if required == [], do: object, else: Map.put(object, "required", required)
  end

  defp schema({:ref, id}, state, path) do
    case Map.fetch(state.seen, id) do
      {:ok, target} -> %{"$ref" => pointer(target)}
      :error -> schema(state.resolve.(id), %{state | seen: Map.put(state.seen, id, path)}, path)
    end
  end

  defp schema(module, state, path) when is_atom(module), do: schema({:ref, module}, state, path)

  defp schema(type, _state, _path),
    do: raise(ArgumentError, "unsupported JSON schema type: #{inspect(type)}")

  @spec unresolved!(term()) :: no_return()
  defp unresolved!(id),
    do: raise(ArgumentError, "unresolved JSON schema reference: #{inspect(id)}")

  defp validate_field!(%{name: name, type: _} = field) when is_binary(name) do
    unless is_boolean(Map.get(field, :required, false)) do
      raise ArgumentError, "JSON field :required must be a boolean"
    end
  end

  defp validate_field!(field) do
    raise ArgumentError,
          "expected a JSON field with a string :name and a :type, got: #{inspect(field)}"
  end

  # Paths are cheap reversed token lists; escape only when emitting a reference.
  defp pointer([]), do: "#"
  defp pointer(path), do: "#/" <> (path |> Enum.reverse() |> Enum.map_join("/", &pointer_token/1))

  defp pointer_token(key) do
    key
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
    |> URI.encode(&URI.char_unreserved?/1)
  end
end
