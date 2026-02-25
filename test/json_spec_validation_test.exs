defmodule JSONSpecValidationTest do
  @moduledoc """
  Tests that generated JSON Schemas are valid and work correctly with JSV validator.
  """
  use ExUnit.Case, async: true

  import JSONSpec

  # Helper to validate data against a generated schema using JSV
  defp validate(schema, data) do
    root = JSV.build!(schema)
    JSV.validate(data, root)
  end

  defp valid?(schema, data) do
    case validate(schema, data) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  describe "primitive type schemas validate correctly" do
    test "String.t() accepts strings, rejects others" do
      schema = json_spec(String.t())

      assert valid?(schema, "hello")
      assert valid?(schema, "")
      refute valid?(schema, 123)
      refute valid?(schema, true)
      refute valid?(schema, nil)
      refute valid?(schema, [])
    end

    test "integer() accepts integers, rejects others" do
      schema = json_spec(integer())

      assert valid?(schema, 0)
      assert valid?(schema, 42)
      assert valid?(schema, -100)
      refute valid?(schema, 3.14)
      refute valid?(schema, "42")
      refute valid?(schema, true)
    end

    test "pos_integer() accepts positive integers only" do
      schema = json_spec(pos_integer())

      assert valid?(schema, 1)
      assert valid?(schema, 100)
      refute valid?(schema, 0)
      refute valid?(schema, -1)
      refute valid?(schema, 3.14)
    end

    test "non_neg_integer() accepts zero and positive integers" do
      schema = json_spec(non_neg_integer())

      assert valid?(schema, 0)
      assert valid?(schema, 1)
      assert valid?(schema, 100)
      refute valid?(schema, -1)
      refute valid?(schema, -100)
    end

    test "neg_integer() accepts negative integers only" do
      schema = json_spec(neg_integer())

      assert valid?(schema, -1)
      assert valid?(schema, -100)
      refute valid?(schema, 0)
      refute valid?(schema, 1)
    end

    test "float()/number() accepts numbers" do
      schema = json_spec(number())

      assert valid?(schema, 0)
      assert valid?(schema, 42)
      assert valid?(schema, 3.14)
      assert valid?(schema, -2.5)
      refute valid?(schema, "3.14")
      refute valid?(schema, true)
    end

    test "boolean() accepts booleans only" do
      schema = json_spec(boolean())

      assert valid?(schema, true)
      assert valid?(schema, false)
      refute valid?(schema, 0)
      refute valid?(schema, 1)
      refute valid?(schema, "true")
      refute valid?(schema, nil)
    end

    test "map() accepts any object" do
      schema = json_spec(map())

      assert valid?(schema, %{})
      assert valid?(schema, %{"a" => 1})
      assert valid?(schema, %{"nested" => %{"deep" => true}})
      refute valid?(schema, [])
      refute valid?(schema, "string")
      refute valid?(schema, 123)
    end

    test "any()/term() accepts everything" do
      schema = json_spec(any())

      assert valid?(schema, "string")
      assert valid?(schema, 123)
      assert valid?(schema, true)
      assert valid?(schema, nil)
      assert valid?(schema, [])
      assert valid?(schema, %{})
    end
  end

  describe "array schemas validate correctly" do
    test "[String.t()] accepts arrays of strings" do
      schema = json_spec([String.t()])

      assert valid?(schema, [])
      assert valid?(schema, ["a", "b", "c"])
      refute valid?(schema, ["a", 1, "b"])
      refute valid?(schema, "not an array")
      refute valid?(schema, [1, 2, 3])
    end

    test "[integer()] accepts arrays of integers" do
      schema = json_spec([integer()])

      assert valid?(schema, [])
      assert valid?(schema, [1, 2, 3])
      assert valid?(schema, [-1, 0, 1])
      refute valid?(schema, [1, 2.5, 3])
      refute valid?(schema, [1, "2", 3])
    end

    test "nested arrays validate correctly" do
      schema = json_spec([[integer()]])

      assert valid?(schema, [])
      assert valid?(schema, [[1, 2], [3, 4]])
      assert valid?(schema, [[]])
      refute valid?(schema, [1, 2, 3])
      refute valid?(schema, [[1, 2], "not array"])
    end
  end

  describe "enum schemas validate correctly" do
    test "atom union accepts only listed values" do
      schema = json_spec(:active | :inactive | :pending)

      assert valid?(schema, "active")
      assert valid?(schema, "inactive")
      assert valid?(schema, "pending")
      refute valid?(schema, "unknown")
      refute valid?(schema, "ACTIVE")
      refute valid?(schema, 123)
    end

    test "two-value enum" do
      schema = json_spec(:yes | :no)

      assert valid?(schema, "yes")
      assert valid?(schema, "no")
      refute valid?(schema, "maybe")
      refute valid?(schema, true)
    end
  end

  describe "object schemas validate correctly" do
    test "simple object with required fields" do
      schema = json_spec(%{name: String.t(), age: integer()})

      assert valid?(schema, %{"name" => "Alice", "age" => 30})
      refute valid?(schema, %{"name" => "Alice"})
      refute valid?(schema, %{"age" => 30})
      refute valid?(schema, %{})
      refute valid?(schema, %{"name" => 123, "age" => 30})
      refute valid?(schema, %{"name" => "Alice", "age" => "thirty"})
    end

    test "object rejects additional properties" do
      schema = json_spec(%{name: String.t()})

      assert valid?(schema, %{"name" => "Alice"})
      refute valid?(schema, %{"name" => "Alice", "extra" => "field"})
    end

    test "object with optional fields" do
      schema =
        json_spec(%{
          required(:name) => String.t(),
          optional(:email) => String.t()
        })

      assert valid?(schema, %{"name" => "Alice"})
      assert valid?(schema, %{"name" => "Alice", "email" => "alice@example.com"})
      refute valid?(schema, %{"email" => "alice@example.com"})
      refute valid?(schema, %{})
    end

    test "nullable field is optional" do
      schema = json_spec(%{name: String.t(), age: integer() | nil})

      assert valid?(schema, %{"name" => "Alice", "age" => 30})
      assert valid?(schema, %{"name" => "Alice"})
      refute valid?(schema, %{"age" => 30})
    end

    test "nested objects validate deeply" do
      schema =
        json_spec(%{
          user: %{
            name: String.t(),
            address: %{city: String.t()}
          }
        })

      assert valid?(schema, %{
               "user" => %{
                 "name" => "Alice",
                 "address" => %{"city" => "NYC"}
               }
             })

      refute valid?(schema, %{
               "user" => %{
                 "name" => "Alice",
                 "address" => %{"city" => 123}
               }
             })

      refute valid?(schema, %{
               "user" => %{
                 "name" => "Alice"
               }
             })
    end

    test "object with array field" do
      schema = json_spec(%{tags: [String.t()]})

      assert valid?(schema, %{"tags" => []})
      assert valid?(schema, %{"tags" => ["a", "b"]})
      refute valid?(schema, %{"tags" => [1, 2]})
      refute valid?(schema, %{})
    end

    test "object with enum field" do
      schema = json_spec(%{status: :active | :inactive})

      assert valid?(schema, %{"status" => "active"})
      assert valid?(schema, %{"status" => "inactive"})
      refute valid?(schema, %{"status" => "pending"})
      refute valid?(schema, %{})
    end

    test "array of objects" do
      schema = json_spec([%{id: integer(), name: String.t()}])

      assert valid?(schema, [])
      assert valid?(schema, [%{"id" => 1, "name" => "Alice"}])

      assert valid?(schema, [
               %{"id" => 1, "name" => "Alice"},
               %{"id" => 2, "name" => "Bob"}
             ])

      refute valid?(schema, [%{"id" => 1}])
      refute valid?(schema, [%{"id" => "one", "name" => "Alice"}])
    end
  end

  describe "complex real-world schemas" do
    test "LLM tool parameter schema" do
      schema =
        json_spec(
          %{
            required(:location) => String.t(),
            optional(:units) => :celsius | :fahrenheit,
            optional(:days) => pos_integer()
          },
          doc: [
            location: "City name",
            units: "Temperature units",
            days: "Forecast days"
          ]
        )

      # Valid: only required field
      assert valid?(schema, %{"location" => "San Francisco"})

      # Valid: all fields
      assert valid?(schema, %{
               "location" => "NYC",
               "units" => "celsius",
               "days" => 7
             })

      # Invalid: missing required
      refute valid?(schema, %{"units" => "celsius"})

      # Invalid: wrong enum value
      refute valid?(schema, %{"location" => "NYC", "units" => "kelvin"})

      # Invalid: days must be positive
      refute valid?(schema, %{"location" => "NYC", "days" => 0})

      # Invalid: extra field
      refute valid?(schema, %{"location" => "NYC", "extra" => true})
    end

    test "deeply nested structure" do
      schema =
        json_spec(%{
          company: %{
            name: String.t(),
            employees: [
              %{
                name: String.t(),
                role: String.t(),
                skills: [String.t()]
              }
            ]
          }
        })

      valid_data = %{
        "company" => %{
          "name" => "Acme",
          "employees" => [
            %{"name" => "Alice", "role" => "Engineer", "skills" => ["Elixir", "SQL"]},
            %{"name" => "Bob", "role" => "Designer", "skills" => []}
          ]
        }
      }

      assert valid?(schema, valid_data)

      # Missing required nested field
      invalid_data = %{
        "company" => %{
          "name" => "Acme",
          "employees" => [
            %{"name" => "Alice", "skills" => ["Elixir"]}
          ]
        }
      }

      refute valid?(schema, invalid_data)
    end

    test "nullable enum field" do
      schema = json_spec(%{status: :active | :inactive | nil})

      assert valid?(schema, %{})
      assert valid?(schema, %{"status" => "active"})
      assert valid?(schema, %{"status" => "inactive"})
      refute valid?(schema, %{"status" => "pending"})
      refute valid?(schema, %{"status" => 123})
    end
  end

  describe "schema metadata" do
    test "description is present in schema" do
      schema =
        json_spec(
          %{name: String.t()},
          doc: [name: "Full name"]
        )

      assert schema["properties"]["name"]["description"] == "Full name"
    end

    test "additionalProperties is false for objects" do
      schema = json_spec(%{name: String.t()})
      assert schema["additionalProperties"] == false
    end

    test "required array contains correct fields" do
      schema =
        json_spec(%{
          required(:a) => String.t(),
          required(:b) => String.t(),
          optional(:c) => String.t()
        })

      assert "a" in schema["required"]
      assert "b" in schema["required"]
      refute "c" in schema["required"]
    end
  end
end
