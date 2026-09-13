defmodule JSONSpec.GeneratorTest do
  use ExUnit.Case, async: true
  import JSONSpec

  defp node_type(:node) do
    {:object,
     [
       %{name: "name", type: :string, required: true},
       %{name: "children", type: {:list, {:ref, :node}}},
       %{name: "parent", type: {:nullable, {:ref, :node}}}
     ]}
  end

  test "recursive descriptors generate finite schemas that validate recursive data" do
    schema = JSONSpec.from_type({:ref, :node}, resolve: &node_type/1)
    assert schema["properties"]["children"]["items"] == %{"$ref" => "#"}
    assert schema["properties"]["parent"] == %{"anyOf" => [%{"$ref" => "#"}, %{"type" => "null"}]}
    root = JSV.build!(schema)

    assert {:ok, _} =
             JSV.validate(
               %{"name" => "root", "children" => [%{"name" => "leaf", "parent" => nil}]},
               root
             )

    assert {:error, _} = JSV.validate(%{"name" => "root", "children" => [%{"name" => 123}]}, root)
  end

  test "nullable recursive objects refer to the non-null branch" do
    schema = JSONSpec.from_type({:nullable, {:ref, :node}}, resolve: &node_type/1)
    assert hd(schema["anyOf"])["properties"]["children"]["items"] == %{"$ref" => "#/anyOf/0"}
    root = JSV.build!(schema)
    assert {:ok, nil} = JSV.validate(nil, root)
    assert {:error, _} = JSV.validate(%{"name" => "root", "children" => [nil]}, root)
  end

  test "mutual references resolve through caller metadata" do
    resolve = fn
      :left -> {:object, [%{name: "right", type: {:ref, :right}}]}
      :right -> {:object, [%{name: "left", type: {:ref, :left}}]}
    end

    schema = JSONSpec.from_type({:ref, :left}, resolve: resolve)
    assert schema["properties"]["right"]["properties"]["left"] == %{"$ref" => "#"}
    assert {:ok, _} = JSV.validate(%{"right" => %{"left" => %{}}}, JSV.build!(schema))
  end

  test "array and map paths escape aliased names" do
    type = {:object, [%{name: "a/b~ #%🦆", type: {:map, :string, {:list, {:ref, :node}}}}]}
    schema = JSONSpec.from_type(type, resolve: &node_type/1)
    items = schema["properties"]["a/b~ #%🦆"]["additionalProperties"]["items"]

    assert items["properties"]["children"]["items"]["$ref"] ==
             "#/properties/a~1b~0%20%23%25%F0%9F%A6%86/additionalProperties/items"

    assert {:ok, _} =
             JSV.validate(
               %{"a/b~ #%🦆" => %{"x" => [%{"name" => "a", "children" => [%{"name" => "b"}]}]}},
               JSV.build!(schema)
             )
  end

  test "optional fields and nullable values are independent" do
    schema =
      JSONSpec.from_type(
        {:object,
         [
           %{name: "optional", type: :string},
           %{name: "required_nullable", type: {:nullable, :string}, required: true}
         ]}
      )

    root = JSV.build!(schema)
    assert {:ok, _} = JSV.validate(%{"required_nullable" => nil}, root)
    assert {:error, _} = JSV.validate(%{}, root)
    assert {:error, _} = JSV.validate(%{"required_nullable" => nil, "optional" => nil}, root)

    assert JSONSpec.from_type({:nullable, :string}, nullable: :legacy) == %{
             "type" => "string",
             "nullable" => true
           }

    assert schema(%{name: String.t() | nil}) == %{
             "type" => "object",
             "properties" => %{"name" => %{"type" => "string"}},
             "additionalProperties" => false
           }
  end

  test "mixed unions and repeated acyclic references remain valid" do
    assert JSONSpec.from_type({:one_of, [:string, :integer]}) == %{
             "anyOf" => [%{"type" => "string"}, %{"type" => "integer"}]
           }

    resolve = fn :leaf -> {:object, [%{name: "value", type: :string, required: true}]} end

    schema =
      JSONSpec.from_type(
        {:object,
         [%{name: "first", type: {:ref, :leaf}}, %{name: "second", type: {:ref, :leaf}}]},
        resolve: resolve
      )

    assert schema["properties"]["first"] == schema["properties"]["second"]
    refute Map.has_key?(schema["properties"]["first"], "$ref")
  end

  test "prebuilt schemas are preserved, including boolean schemas" do
    assert JSONSpec.from_type({:schema, true}) == true
    assert JSONSpec.from_type({:schema, false}) == false

    assert JSONSpec.from_type({:schema, %{"type" => "string", "format" => "uuid"}}) == %{
             "type" => "string",
             "format" => "uuid"
           }
  end

  test "references do not leak resolver state between calls" do
    assert JSONSpec.from_type({:ref, :value}, resolve: fn :value -> :string end) == %{
             "type" => "string"
           }

    assert JSONSpec.from_type({:ref, :value}, resolve: fn :value -> :integer end) == %{
             "type" => "integer"
           }
  end

  test "invalid options and unresolved types fail explicitly" do
    assert_raise ArgumentError, fn -> JSONSpec.from_type({:ref, :missing}) end
    assert_raise ArgumentError, fn -> JSONSpec.from_type(:string, nullable: :unknown) end
    assert_raise ArgumentError, fn -> JSONSpec.from_type(:string, resolve: nil) end
    assert_raise ArgumentError, fn -> JSONSpec.from_type(:string, typo: true) end

    assert_raise ArgumentError, fn ->
      JSONSpec.from_type({:object, [%{name: :atom, type: :string}]})
    end

    assert_raise ArgumentError, fn ->
      JSONSpec.from_type({:object, [%{name: "x", type: :string, required: nil}]})
    end

    assert_raise ArgumentError, fn ->
      JSONSpec.from_type({:object, [%{name: "x", type: :string}, %{name: "x", type: :integer}]})
    end
  end
end
