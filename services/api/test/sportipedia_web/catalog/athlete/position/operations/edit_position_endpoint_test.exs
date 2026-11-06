defmodule SportipediaWeb.Catalog.Athlete.Position.EditPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Instrument

  describe "POST /catalog/athlete/positions/edit-position" do
    test "edit-position returns 200 with the position", %{conn: conn} do
      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})
          )
        )

      catalog_body = json_response(catalog_conn, 200)
      id = jsonapi_id(catalog_body)

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{}, id))
        )

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
    end

    test "returns 200 with only the patched field changed", %{conn: conn} do
      slug = "old-title-#{UUID.uuid4()}"

      {:ok, created} =
        Position.catalog_position(%{
          title: "Old Title",
          slug: slug,
          description: "Stays as it is"
        })

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "New Title"}, created.id))
        )

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "title") == "New Title"
      assert jsonapi_attr(body, "slug") == slug
      assert jsonapi_attr(body, "description") == "Stays as it is"
    end

    test "a field sent as null keeps its stored value: an edit patches, it never clears", %{
      conn: conn
    } do
      {:ok, created} =
        Position.catalog_position(%{
          title: "Support",
          slug: "support-#{UUID.uuid4()}",
          description: "Stands, because null is not a clear"
        })

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "Renamed", description: nil}, created.id)
          )
        )

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "title") == "Renamed"
      assert jsonapi_attr(body, "description") == "Stands, because null is not a clear"
    end

    test "returns 404 for a position that is not there", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "Nobody"}, UUID.uuid4()))
        )

      assert json_response(conn, 404)
    end

    test "returns 404 for an id that is not an id", %{conn: conn} do
      # A string that cannot denote a position addresses nothing, so the answer
      # is the same as for an unknown one. It used to be a 500: the existence
      # check handed the value straight to `Repo.get/2`, which raises on it.
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "Nobody"}, "not-a-uuid"))
        )

      assert json_response(conn, 404)
    end

    test "returns 422 for a request without an id", %{conn: conn} do
      # An absent address is not an unknown position: `presence` is what rejects
      # it, and the existence check must not look an id up that was never sent.
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "Nobody"}))
        )

      assert %{"errors" => [error]} = json_response(conn, 422)
      assert error["status"] == "422"
      assert error["detail"] == "must be present"
      assert error["title"] == "id"
    end

    test "returns 422 for a request with a blank id", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "Nobody"}, ""))
        )

      assert %{"errors" => [error]} = json_response(conn, 422)
      assert error["status"] == "422"
      assert error["detail"] == "must be present"
    end

    test "returns 422 for a slug another position owns", %{conn: conn} do
      {:ok, taken} = Position.catalog_position(%{title: "Taken", slug: "taken-#{UUID.uuid4()}"})

      {:ok, other} =
        Position.catalog_position(%{title: "Other", slug: "other-#{UUID.uuid4()}"})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{slug: taken.slug}, other.id))
        )

      assert %{"errors" => [error]} = json_response(conn, 422)
      assert error["detail"] == "slug_exists"
      assert error["source"] == %{"pointer" => "/data/attributes/slug"}
    end

    test "returns 422 when the patch and the stored position fill both equipment slots", %{
      conn: conn
    } do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Parallel Bars", slug: "pb"})
      {:ok, instrument} = Instrument.catalog_instrument(%{title: "Drum", slug: "drum"})

      {:ok, created} =
        Position.catalog_position(%{
          title: "Support",
          slug: "support-#{UUID.uuid4()}",
          apparatusId: apparatus.id
        })

      # The request itself is unambiguous: it names one instrument. Only the
      # merged state shows the violation, and the handler is what rejects it.
      # A bare handler error must still reach the client as 422, not as 500.
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{instrumentId: instrument.id}, created.id))
        )

      assert %{"errors" => [error]} = json_response(conn, 422)
      assert error["status"] == "422"
      assert error["detail"] == "at_most_one_equipment"
      assert error["source"] == %{"pointer" => "/data/attributes/instrumentId"}

      # Nothing was changed: the stored position keeps its apparatus.
      assert {:ok, unchanged} = Position.read_position(created.id)
      assert unchanged.apparatusId == apparatus.id
      assert unchanged.instrumentId == nil
    end

    test "returns 422 for an equipment reference the patch re-supplies and that is gone", %{
      conn: conn
    } do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vt"})

      {:ok, created} =
        Position.catalog_position(%{
          title: "Vault Approach",
          slug: "vault-approach-#{UUID.uuid4()}",
          apparatusId: apparatus.id
        })

      :ok = Apparatus.archive_apparatus(apparatus.id)

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(
            jsonapi_body("position", %{apparatusId: apparatus.id, title: "Renamed"}, created.id)
          )
        )

      assert %{"errors" => [error]} = json_response(conn, 422)
      assert error["detail"] == "equipment_not_found"
      assert error["source"] == %{"pointer" => "/data/attributes/apparatusId"}
    end

    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{}))
        )

      assert json_response(conn, 403)
    end
  end
end
