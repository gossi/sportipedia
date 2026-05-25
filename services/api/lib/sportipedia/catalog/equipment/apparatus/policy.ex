defmodule Sportipedia.Catalog.Equipment.Apparatus.Policy do
  def authorize(:catalog_apparatus, user, _params) when is_nil(user) do
    :error
  end

  def authorize(:catalog_apparatus, user, _params) when not is_nil(user) do
    :ok
  end
end
