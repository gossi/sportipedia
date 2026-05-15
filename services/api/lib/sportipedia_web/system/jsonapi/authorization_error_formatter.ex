defmodule SportipediaWeb.System.JSONAPI.AuthorizationErrorFormatter do
  def format(:unauthorized),
    do: %{
      title: "Forbidden",
      detail: "You do not have permission to perform this action",
      status: "403"
    }
end
