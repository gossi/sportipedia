defmodule SportipediaWeb.Catalog.Equipment.EditInstrumentRequestTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

  @moduletag :integration

  describe "POST edit-instrument" do
    test "updates an instrument when authenticated" do
      instrument = insert_instrument()

      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/edit-instrument",
          Jason.encode!(jsonapi_body("instruments", %{title: "Updated"}, instrument.id))
        )

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "title") == "Updated"
      assert Repo.get!(InstrumentReadModel, instrument.id).title == "Updated"
    end

    test "partially updates leaving other fields intact" do
      instrument = insert_instrument()

      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/edit-instrument",
          Jason.encode!(jsonapi_body("instruments", %{description: "new desc"}, instrument.id))
        )

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "description") == "new desc"
      assert jsonapi_attr(body, "title") == "Original"

      updated = Repo.get!(InstrumentReadModel, instrument.id)
      assert updated.title == "Original"
      assert updated.slug == instrument.slug
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/edit-instrument",
          Jason.encode!(jsonapi_body("instruments", %{title: "Updated"}, UUID.uuid4()))
        )

      assert json_response(conn, 403)
    end

    test "returns 200 when instrument not found (no existence check)" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/edit-instrument",
          Jason.encode!(jsonapi_body("instruments", %{title: "Updated"}, UUID.uuid4()))
        )

      assert json_response(conn, 200)
    end

    test "returns 404 on validation failure (error mapped to notfound)" do
      insert_instrument(%{slug: "taken"})
      instrument = insert_instrument()

      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/edit-instrument",
          Jason.encode!(jsonapi_body("instruments", %{slug: "taken"}, instrument.id))
        )

      assert json_response(conn, 404)
    end
  end

  defp insert_instrument(attrs \\ %{}) do
    defaults = %{
      id: UUID.uuid4(),
      title: "Original",
      slug: "original-#{System.unique_integer()}",
      description: "desc"
    }

    InstrumentReadModel.insert_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
