defmodule SpGen.PlaceholdersTest do
  @moduledoc """
  Table-driven against the "Substitution Samples" of
  docs/architecture/naming-substitution.md.
  """
  use ExUnit.Case, async: true

  alias SpGen.Placeholders

  # | Variable | Value |
  @sample_values %{
    "subdomain" => "catalog",
    "composite" => "equipment",
    "domain_object" => "apparatus",
    "command" => "catalog-apparatus",
    "event" => "apparatus-cataloged",
    "operation" => "catalog-apparatus",
    "query" => "list-apparatuses",
    "public_api" => "apparatus",
    "field" => "title"
  }

  defp render(template, slots \\ %{}) do
    Placeholders.render(template, %{vars: @sample_values, slots: slots})
  end

  describe "casing, one word" do
    test "kebap / snake / camel of a single word value" do
      assert render("<-subdomain>") == "catalog"
      assert render("<_subdomain>") == "catalog"
      assert render("<subdomain>") == "catalog"
    end

    test "PascalCase" do
      assert render("<Subdomain>") == "Catalog"
    end
  end

  describe "casing, two words" do
    test "each notation renders the documented sample" do
      assert render("<-command>") == "catalog-apparatus"
      assert render("<_command>") == "catalog_apparatus"
      assert render("<Command>") == "CatalogApparatus"
      assert render("<command>") == "catalogApparatus"
    end

    test "Event and DomainObject" do
      assert render("<Event>") == "ApparatusCataloged"
      assert render("<DomainObject>") == "Apparatus"
      assert render("<domain-object>") == "apparatus"
      assert render("<domain_object>") == "apparatus"
    end
  end

  describe "module names" do
    test "public api module" do
      assert render("Sportipedia.<Subdomain>.<Composite>.<DomainObject>") ==
               "Sportipedia.Catalog.Equipment.Apparatus"
    end

    test "aggregate module" do
      assert render("Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate") ==
               "Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate"
    end

    test "command module" do
      assert render("Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>") ==
               "Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus"
    end

    test "event module" do
      assert render("Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>") ==
               "Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged"
    end

    test "controller module" do
      assert render("SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>Controller") ==
               "SportipediaWeb.Catalog.Equipment.ApparatusController"
    end

    test "view module" do
      assert render("SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View") ==
               "SportipediaWeb.Catalog.Equipment.ApparatusView"
    end

    test "response schema module" do
      assert render("SportipediaWeb.<Subdomain>.<Composite>.Schemas.<DomainObject>Response") ==
               "SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse"
    end
  end

  describe "file paths" do
    test "public api" do
      assert render(
               "/services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/public_api.ex"
             ) == "/services/api/lib/sportipedia/catalog/equipment/apparatus/public_api.ex"
    end

    test "operation dir can be kebap or snake — both render" do
      assert render(
               "/services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<-command>/handler.ex"
             ) ==
               "/services/api/lib/sportipedia/catalog/equipment/apparatus/operation/catalog-apparatus/handler.ex"

      assert render(
               "/services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_command>/handler.ex"
             ) ==
               "/services/api/lib/sportipedia/catalog/equipment/apparatus/operation/catalog_apparatus/handler.ex"
    end

    test "controller" do
      assert render(
               "/services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>_controller.ex"
             ) == "/services/api/lib/sportipedia_web/catalog/equipment/apparatus_controller.ex"
    end

    test "response schema" do
      assert render(
               "/services/api/lib/sportipedia_web/<_subdomain>/<composite>/schemas/<domain_object>_response.ex"
             ) ==
               "/services/api/lib/sportipedia_web/catalog/equipment/schemas/apparatus_response.ex"
    end

    test "operation test" do
      assert render(
               "/services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_command>_test.exs"
             ) ==
               "/services/api/test/sportipedia/catalog/equipment/apparatus/operation/catalog_apparatus_test.exs"
    end

    test "request test" do
      assert render(
               "/services/api/test/sportipedia_web/<_subdomain>/<composite>/<_command>_request_test.exs"
             ) ==
               "/services/api/test/sportipedia_web/catalog/equipment/catalog_apparatus_request_test.exs"
    end
  end

  describe "function names" do
    test "controller action" do
      assert render("def <_command>(conn, params)") == "def catalog_apparatus(conn, params)"
    end

    test "authorize clause" do
      assert render("def authorize(:<_command>, user, params)") ==
               "def authorize(:catalog_apparatus, user, params)"
    end

    test "public api call" do
      assert render("<PublicAPI>.<_command>(params)") == "Apparatus.catalog_apparatus(params)"
    end

    test "operation macro" do
      assert render("operation :<_command>") == "operation :catalog_apparatus"
    end
  end

  describe "routes" do
    test "command route" do
      assert render("post \"/<-command>\", <DomainObject>Controller, :<_command>") ==
               "post \"/catalog-apparatus\", ApparatusController, :catalog_apparatus"
    end

    test "read route keeps the literal path param" do
      # "<id>" is a slot, not a variable — templates must fill it.
      assert render("get \"/:<id>\", <DomainObject>Controller, :read_<domain_object>", %{
               "id" => "id"
             }) == "get \"/:id\", ApparatusController, :read_apparatus"
    end

    test "scopes" do
      assert render("scope \"/<-subdomain>\", SportipediaWeb.<Subdomain>") ==
               "scope \"/catalog\", SportipediaWeb.Catalog"

      assert render("scope \"/<composite>\", <Composite>") == "scope \"/equipment\", Equipment"
      assert render("scope \"/<domain-object>s\"") == "scope \"/apparatuses\""
    end
  end

  describe "json:api and openapi" do
    test "plural type" do
      assert render("type: \"<domain-object>s\"") == "type: \"apparatuses\""
    end

    test "path" do
      assert render("path: \"<-subdomain>/<composite>/<domain-object>s\"") ==
               "path: \"catalog/equipment/apparatuses\""
    end

    test "schema titles" do
      assert render("title: \"<composite>.<DomainObject>\"") == "title: \"equipment.Apparatus\""

      assert render("title: \"<composite>.<DomainObject>s\"") ==
               "title: \"equipment.Apparatuses\""
    end

    test "tags" do
      assert render("tags [\"<composite>\"]") == "tags [\"equipment\"]"
    end
  end

  describe "test module names" do
    test "operation test module" do
      assert render("Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test") ==
               "Sportipedia.Catalog.Equipment.Apparatus.Operation.CatalogApparatusTest"
    end

    test "request test module" do
      assert render("SportipediaWeb.<Subdomain>.<Composite>.<Command>RequestTest") ==
               "SportipediaWeb.Catalog.Equipment.CatalogApparatusRequestTest"
    end
  end

  describe "slots" do
    test "two-word prose slot is filled verbatim" do
      assert render("<field type>", %{"field type" => "String.t()"}) == "String.t()"
    end

    test "long documentation prose slot is filled verbatim" do
      slot = "Describe what the command does to the aggregate, derived from the domain model."

      assert render("<#{slot}>", %{slot => "Catalogs a new apparatus."}) ==
               "Catalogs a new apparatus."
    end

    test "underscored slot keys work" do
      assert render("<param_type>", %{"param_type" => "map()"}) == "map()"
    end
  end

  describe "totality" do
    test "unknown variables raise with a helpful list" do
      assert_raise ArgumentError, ~r/unresolved placeholder\(s\).*<Entity>.*<jsonapi-type>/, fn ->
        render("Sportipedia.<Subdomain>.<Entity>.<jsonapi-type>")
      end
    end

    test "unknown slots raise too" do
      assert_raise ArgumentError, ~r/<describe the operation>/, fn ->
        render("summary: \"<describe the operation>\"")
      end
    end

    test "fill/2 reports without raising" do
      assert {:error, ["Entity", "field type"]} =
               Placeholders.fill("x<Entity> <field type>", %{vars: %{}, slots: %{}})
    end

    test "no placeholders at all is the identity" do
      assert render("# hello") == "# hello"
    end
  end

  test "variables/0 covers the naming-substitution variable table" do
    assert Placeholders.variables() == [
             "command",
             "event",
             "subdomain",
             "operation",
             "entity",
             "value_object",
             "composite",
             "constituent",
             "domain_object",
             "query",
             "public_api",
             "action",
             "jsonapi_type",
             "field",
             "validator",
             "object"
           ]
  end

  test "words/1 splits casings and acronym runs" do
    assert Placeholders.words("PublicAPI") == ["public", "api"]
    assert Placeholders.words("domainObject") == ["domain", "object"]
    assert Placeholders.words("DomainObject") == ["domain", "object"]
    assert Placeholders.words("domain-object") == ["domain", "object"]
    assert Placeholders.words("domain_object") == ["domain", "object"]
    assert Placeholders.words("value-object") == ["value", "object"]
  end
end
