defmodule Sportipedia.Auth do
  def get_user_from_assigns(%{assigns: %{user: user}} = _), do: user
  def get_user_from_assigns(%{user: user}), do: user
  def get_user_from_assigns(_), do: nil
end
