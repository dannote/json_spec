defmodule JSONSpecTest do
  use ExUnit.Case, async: true

  import JSONSpec

  describe "primitive types" do
    test "String.t()" do
      assert schema(String.t()) == %{"type" => "string"}
    end

    test "binary()" do
      assert schema(binary()) == %{"type" => "string"}
    end

    test "integer()" do
      assert schema(integer()) == %{"type" => "integer"}
    end

    test "pos_integer()" do
      assert schema(pos_integer()) == %{"type" => "integer", "minimum" => 1}
    end

    test "non_neg_integer()" do
      assert schema(non_neg_integer()) == %{"type" => "integer", "minimum" => 0}
    end

    test "neg_integer()" do
      assert schema(neg_integer()) == %{"type" => "integer", "maximum" => -1}
    end

    test "float()" do
      assert schema(float()) == %{"type" => "number"}
    end

    test "number()" do
      assert schema(number()) == %{"type" => "number"}
    end

    test "boolean()" do
      assert schema(boolean()) == %{"type" => "boolean"}
    end

    test "map()" do
      assert schema(map()) == %{"type" => "object"}
    end

    test "atom()" do
      assert schema(atom()) == %{"type" => "string"}
    end

    test "any()" do
      assert schema(any()) == %{}
    end

    test "term()" do
      assert schema(term()) == %{}
    end
  end

  describe "arrays" do
    test "list literal [String.t()]" do
      assert schema([String.t()]) == %{
               "type" => "array",
               "items" => %{"type" => "string"}
             }
    end

    test "list literal [integer()]" do
      assert schema([integer()]) == %{
               "type" => "array",
               "items" => %{"type" => "integer"}
             }
    end

    test "nested list [[integer()]]" do
      assert schema([[integer()]]) == %{
               "type" => "array",
               "items" => %{
                 "type" => "array",
                 "items" => %{"type" => "integer"}
               }
             }
    end

    test "list of objects" do
      assert schema([%{id: integer(), name: String.t()}]) == %{
               "type" => "array",
               "items" => %{
                 "type" => "object",
                 "properties" => %{
                   "id" => %{"type" => "integer"},
                   "name" => %{"type" => "string"}
                 },
                 "required" => ["id", "name"],
                 "additionalProperties" => false
               }
             }
    end
  end

  describe "enums (atom unions)" do
    test "two atoms" do
      assert schema(:celsius | :fahrenheit) == %{
               "type" => "string",
               "enum" => ["celsius", "fahrenheit"]
             }
    end

    test "three atoms" do
      assert schema(:active | :inactive | :pending) == %{
               "type" => "string",
               "enum" => ["active", "inactive", "pending"]
             }
    end

    test "four atoms" do
      assert schema(:a | :b | :c | :d) == %{
               "type" => "string",
               "enum" => ["a", "b", "c", "d"]
             }
    end
  end

  describe "objects" do
    test "simple object" do
      result = schema(%{name: String.t(), age: integer()})

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"},
                 "age" => %{"type" => "integer"}
               },
               "required" => ["name", "age"],
               "additionalProperties" => false
             }
    end

    test "object with optional fields via optional()" do
      result =
        schema(%{
          optional(:name) => String.t(),
          optional(:email) => String.t()
        })

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"},
                 "email" => %{"type" => "string"}
               },
               "additionalProperties" => false
             }
    end

    test "object with explicit required() and optional()" do
      result =
        schema(%{
          required(:name) => String.t(),
          optional(:email) => String.t()
        })

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"},
                 "email" => %{"type" => "string"}
               },
               "required" => ["name"],
               "additionalProperties" => false
             }
    end

    test "keyword-style fields are required by default" do
      result = schema(%{name: String.t(), age: integer()})

      assert result["required"] == ["name", "age"]
    end

    test "nullable field is treated as optional" do
      result = schema(%{name: String.t(), age: integer() | nil})

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"},
                 "age" => %{"type" => "integer"}
               },
               "required" => ["name"],
               "additionalProperties" => false
             }
    end

    test "nested objects" do
      result =
        schema(%{
          user: %{
            name: String.t(),
            address: %{
              city: String.t(),
              zip: String.t()
            }
          }
        })

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "user" => %{
                   "type" => "object",
                   "properties" => %{
                     "name" => %{"type" => "string"},
                     "address" => %{
                       "type" => "object",
                       "properties" => %{
                         "city" => %{"type" => "string"},
                         "zip" => %{"type" => "string"}
                       },
                       "required" => ["city", "zip"],
                       "additionalProperties" => false
                     }
                   },
                   "required" => ["name", "address"],
                   "additionalProperties" => false
                 }
               },
               "required" => ["user"],
               "additionalProperties" => false
             }
    end

    test "object with enum field" do
      result =
        schema(%{
          color: :red | :green | :blue
        })

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "color" => %{"type" => "string", "enum" => ["red", "green", "blue"]}
               },
               "required" => ["color"],
               "additionalProperties" => false
             }
    end

    test "object with list field" do
      result = schema(%{tags: [String.t()], scores: [integer()]})

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
                 "scores" => %{"type" => "array", "items" => %{"type" => "integer"}}
               },
               "required" => ["tags", "scores"],
               "additionalProperties" => false
             }
    end
  end

  describe "mixed keyword and arrow syntax" do
    test "keyword-style required + arrow-style optional" do
      result =
        schema(%{
          required(:name) => String.t(),
          optional(:email) => String.t(),
          optional(:age) => integer()
        })

      assert result["required"] == ["name"]
      assert map_size(result["properties"]) == 3
    end
  end

  describe "descriptions via :doc option" do
    test "adds descriptions to fields" do
      result =
        schema(
          %{
            required(:location) => String.t(),
            optional(:units) => String.t()
          },
          doc: [location: "City name", units: "Temperature units"]
        )

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "location" => %{"type" => "string", "description" => "City name"},
                 "units" => %{"type" => "string", "description" => "Temperature units"}
               },
               "required" => ["location"],
               "additionalProperties" => false
             }
    end

    test "partial descriptions — only described fields get description" do
      result =
        schema(
          %{name: String.t(), age: integer()},
          doc: [name: "Full name"]
        )

      assert result["properties"]["name"]["description"] == "Full name"
      refute Map.has_key?(result["properties"]["age"], "description")
    end

    test "descriptions on enum fields" do
      result =
        schema(
          %{status: :active | :inactive},
          doc: [status: "Account status"]
        )

      assert result["properties"]["status"] == %{
               "type" => "string",
               "enum" => ["active", "inactive"],
               "description" => "Account status"
             }
    end
  end

  describe "atomize/2" do
    test "converts string keys to atoms" do
      s = schema(%{required(:name) => String.t(), optional(:age) => integer()})
      assert JSONSpec.atomize(s, %{"name" => "Alice", "age" => 30}) == %{name: "Alice", age: 30}
    end

    test "leaves unknown keys as strings" do
      s = schema(%{name: String.t()})
      result = JSONSpec.atomize(s, %{"name" => "Alice", "extra" => "x"})
      assert result[:name] == "Alice"
      assert result["extra"] == "x"
    end

    test "atomizes nested objects" do
      s = schema(%{user: %{name: String.t(), email: String.t()}})
      input = %{"user" => %{"name" => "Alice", "email" => "a@b.c"}}
      assert JSONSpec.atomize(s, input) == %{user: %{name: "Alice", email: "a@b.c"}}
    end

    test "atomizes enum values" do
      s = schema(%{required(:status) => :active | :inactive})
      assert JSONSpec.atomize(s, %{"status" => "active"}) == %{status: :active}
    end

    test "atomizes arrays of objects" do
      s = schema(%{items: [%{id: integer(), name: String.t()}]})
      input = %{"items" => [%{"id" => 1, "name" => "A"}, %{"id" => 2, "name" => "B"}]}
      assert JSONSpec.atomize(s, input) == %{items: [%{id: 1, name: "A"}, %{id: 2, name: "B"}]}
    end

    test "handles already atom-keyed maps" do
      s = schema(%{name: String.t()})
      assert JSONSpec.atomize(s, %{name: "Alice"}) == %{name: "Alice"}
    end

    test "returns data as-is when schema has no properties" do
      assert JSONSpec.atomize(%{}, %{"a" => 1}) == %{"a" => 1}
    end
  end

  describe "complex schemas" do
    test "LLM tool-like schema" do
      result =
        schema(
          %{
            required(:location) => String.t(),
            optional(:units) => :celsius | :fahrenheit,
            optional(:days) => pos_integer()
          },
          doc: [
            location: "City name or ZIP code",
            units: "Temperature units",
            days: "Number of forecast days"
          ]
        )

      assert result == %{
               "type" => "object",
               "properties" => %{
                 "location" => %{
                   "type" => "string",
                   "description" => "City name or ZIP code"
                 },
                 "units" => %{
                   "type" => "string",
                   "enum" => ["celsius", "fahrenheit"],
                   "description" => "Temperature units"
                 },
                 "days" => %{
                   "type" => "integer",
                   "minimum" => 1,
                   "description" => "Number of forecast days"
                 }
               },
               "required" => ["location"],
               "additionalProperties" => false
             }
    end

    test "deeply nested with arrays of objects" do
      result =
        schema(%{
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

      employees_schema = result["properties"]["company"]["properties"]["employees"]
      assert employees_schema["type"] == "array"

      employee = employees_schema["items"]
      assert employee["type"] == "object"
      assert employee["properties"]["name"] == %{"type" => "string"}

      assert employee["properties"]["skills"] == %{
               "type" => "array",
               "items" => %{"type" => "string"}
             }

      assert employee["required"] == ["name", "role", "skills"]
    end

    test "nullable enum is optional but still enum" do
      result = schema(%{status: :active | :inactive | nil})

      assert result["properties"]["status"] == %{
               "type" => "string",
               "enum" => ["active", "inactive"]
             }

      refute Map.has_key?(result, "required")
    end
  end
end
