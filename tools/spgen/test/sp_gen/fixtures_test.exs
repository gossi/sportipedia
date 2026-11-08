defmodule SpGen.FixturesTest do
  use ExUnit.Case, async: true

  alias SpGen.{Esdm, Fixtures}
  alias SpGen.Esdm.Element

  @source "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml"

  describe "fixture_key?/1 and parse_key/1" do
    test "three kebab-case segments form a key" do
      assert Fixtures.fixture_key?("equipment:widget:classic-widget")
      assert Fixtures.fixture_key?("athlete:position:handstand-2")

      assert {:ok, {"equipment", "widget", "classic-widget"}} =
               Fixtures.parse_key("equipment:widget:classic-widget")
    end

    test "anything else is not a key — and says what a key is" do
      for not_a_key <- [
            "classic-widget",
            "equipment:widget",
            "equipment:widget:extra:segments",
            "equipment:widget:Classic-Widget",
            "equipment:widget:-leading",
            "equipment: widget:no-space",
            "1equipment:widget:digits-first",
            ""
          ] do
        refute Fixtures.fixture_key?(not_a_key), not_a_key
        assert {:error, message} = Fixtures.parse_key(not_a_key)
        assert message =~ "<composite>:<read-model>:<mnemonic>"
      end
    end

    test "a non-string is not a key either" do
      refute Fixtures.fixture_key?(nil)
      refute Fixtures.fixture_key?(:widget)
      assert {:error, message} = Fixtures.parse_key(42)
      assert message =~ "must be a string"
    end
  end

  describe "function_name/1" do
    test "the mnemonic, snake-cased" do
      assert Fixtures.function_name("equipment:apparatus:parallel-bars") == "parallel_bars"
      assert Fixtures.function_name("equipment:widget:gadget-2000") == "gadget_2000"
    end
  end

  describe "materialize/2 — the wrap decision" do
    test "a fixture key in any field materializes as the uuid5 expression" do
      assert Fixtures.materialize("id", "equipment:widget:classic-widget") ==
               ~s|UUID.uuid5(:dns, "equipment:widget:classic-widget")|

      assert Fixtures.materialize("coachId", "equipment:coach:head-coach") ==
               ~s|UUID.uuid5(:dns, "equipment:coach:head-coach")|
    end

    test "a real UUID stays a literal — never re-derived" do
      id = "d290f1ee-6c54-4b01-90e6-d701748f0851"
      assert Fixtures.materialize("id", id) == inspect(id)
      assert Fixtures.materialize("coachId", id) == inspect(id)
    end

    test "a bare mnemonic in a reference field is wrapped fail-safe" do
      # the value cannot denote a UUID, so it is a key spelled without its
      # home — wrapped as one; the closed-world check catches the mismatch
      assert Fixtures.materialize("coachId", "head-coach") ==
               ~s|UUID.uuid5(:dns, "head-coach")|
    end

    test "plain values stay literals, whatever the field" do
      assert Fixtures.materialize("title", "Classic Widget") == inspect("Classic Widget")
      assert Fixtures.materialize("description", nil) == "nil"
    end

    test "reference_field?/1 reads the *Id convention, case-sensitively" do
      assert Fixtures.reference_field?("coachId")
      assert Fixtures.reference_field?("apparatusId")
      refute Fixtures.reference_field?("id")
      refute Fixtures.reference_field?("coach_id")
    end
  end

  describe "validate/3 — the model contract" do
    test "a clean read model yields specs in canonical field order" do
      element =
        read_model(%{
          "schema" => %{
            "properties" => schema_properties(),
            "required" => ["id", "title", "slug"],
            "examples" => [
              %{
                "id" => "equipment:widget:classic-widget",
                "title" => "Classic Widget",
                "slug" => "classic-widget",
                "coachId" => "equipment:coach:head-coach"
              },
              %{
                "id" => "equipment:widget:gadget-2000",
                "title" => "Gadget 2000",
                "slug" => "gadget-2000"
              }
            ]
          }
        })

      assert {:ok, specs} = Fixtures.validate(element, "equipment", "widgets")

      assert Enum.map(specs, & &1.fname) == ["classic_widget", "gadget_2000"]

      assert specs
             |> hd()
             |> Map.fetch!(:attrs)
             |> Enum.map(&elem(&1, 0)) == ["id", "title", "slug", "coachId"]
    end

    test "every violation is reported, not just the first" do
      element =
        read_model(%{
          "schema" => %{
            "properties" => schema_properties(),
            "required" => ["id", "title", "slug"],
            "examples" => [
              # unknown field, missing slug, foreign key home, bad reference
              %{
                "id" => "catalog:widget:else",
                "title" => "Très mal",
                "ghost" => "here",
                "coachId" => "just-a-word-without-colons"
              }
            ]
          }
        })

      assert {:error, messages} = Fixtures.validate(element, "equipment", "widgets")
      text = Enum.join(messages, "\n")

      assert text =~ "carries \"ghost\""
      assert text =~ "missing required property \"slug\""

      assert text =~
               "names \"catalog\"/\"widget\", but this read model lives in \"equipment\"/\"widget\""

      assert text =~ "neither a fixture key nor a UUID"
    end

    test "an example with no id cannot name itself" do
      element =
        read_model(%{
          "schema" => %{
            "properties" => schema_properties(),
            "required" => ["id"],
            "examples" => [%{"title" => "Homeless"}]
          }
        })

      assert {:error, messages} = Fixtures.validate(element, "equipment", "widgets")
      assert Enum.any?(messages, &(&1 =~ "carries no id"))
    end

    test "a mnemonic that shadows an Elixir keyword is refused" do
      element = keyword_example()
      assert {:error, [message | _]} = Fixtures.validate(element, "equipment", "widgets")
      assert message =~ "would shadow an Elixir keyword"
    end

    test "a mnemonic naming the aggregate function collides" do
      element =
        read_model(%{
          "schema" => %{
            "properties" => schema_properties(),
            "required" => ["id"],
            "examples" => [%{"id" => "equipment:widget:widgets"}]
          }
        })

      assert {:error, [message | _]} = Fixtures.validate(element, "equipment", "widgets")
      assert message =~ "colliding with the aggregate function of the same file"
    end

    test "the same example declared twice is refused" do
      element =
        read_model(%{
          "schema" => %{
            "properties" => schema_properties(),
            "required" => ["id"],
            "examples" => [
              %{"id" => "equipment:widget:gadget-2000"},
              %{"id" => "equipment:widget:gadget-2000"}
            ]
          }
        })

      assert {:error, [message | _]} = Fixtures.validate(element, "equipment", "widgets")
      assert message =~ "gadget_2000/0"
    end

    test "a read model without examples validates to an empty spec list" do
      element = read_model(%{"schema" => %{"properties" => schema_properties()}})
      assert {:ok, []} = Fixtures.validate(element, "equipment", "widgets")
    end

    test "defined_keys/1 and referenced_keys/1 read the example graph" do
      element =
        read_model(%{
          "schema" => %{
            "properties" => schema_properties(),
            "required" => ["id"],
            "examples" => [
              %{
                "id" => "equipment:widget:classic-widget",
                "coachId" => "equipment:coach:head-coach"
              },
              %{"id" => "equipment:widget:gadget-2000"}
            ]
          }
        })

      assert Fixtures.defined_keys(element) == [
               "equipment:widget:classic-widget",
               "equipment:widget:gadget-2000"
             ]

      assert Fixtures.referenced_keys(element) == ["equipment:coach:head-coach"]
    end
  end

  # -- builders ----------------------------------------------------------------

  defp read_model(doc) do
    %Element{
      kind: :"read-model",
      name: "widget",
      scope: [{"domain", "sport"}, {"bounded-context", "sport"}],
      doc:
        Map.merge(
          %{"apiVersion" => "schema.esdm.io/core/v1", "kind" => "read-model", "name" => "widget"},
          doc
        ),
      source: @source,
      address: "esdm:domain=sport/bounded-context=sport/read-model=widget"
    }
  end

  defp schema_properties do
    %{
      "id" => %{"type" => "string", "format" => "uuid"},
      "title" => %{"type" => "string"},
      "slug" => %{"type" => "string"},
      "coachId" => %{"type" => "string", "format" => "uuid"}
    }
  end

  defp keyword_example do
    # `equipment:widget:else` — mnemonic "else" is an Elixir noname; the key
    # must be otherwise well-formed and name its home for that to be THE finding
    read_model(%{
      "schema" => %{
        "properties" => schema_properties(),
        "required" => [],
        "examples" => [%{"id" => "equipment:widget:else"}]
      }
    })
  end

  # Esdm.fields canonicalization is part of what validate/3 promises —
  # exercise it through the real loader, not a hand-rolled order
  test "field order follows Esdm.fields: id, required in order, optional alphabetical" do
    element =
      read_model(%{
        "schema" => %{
          "properties" => %{
            "title" => %{"type" => "string"},
            "coachId" => %{"type" => "string", "format" => "uuid"},
            "id" => %{"type" => "string", "format" => "uuid"},
            "slug" => %{"type" => "string"}
          },
          "required" => ["id", "title", "slug"],
          "examples" => [
            %{
              "slug" => "x",
              "coachId" => "equipment:coach:head-coach",
              "title" => "T",
              "id" => "equipment:widget:x"
            }
          ]
        }
      })

    assert {:ok, [spec]} = Fixtures.validate(element, "equipment", "widgets")
    assert Enum.map(spec.attrs, &elem(&1, 0)) == ["id", "title", "slug", "coachId"]
    assert Enum.all?(Esdm.fields(element), &is_map(&1))
  end
end
