defmodule Sportipedia.Auth do
  def get_user_from_assigns(%{assigns: %{user: user}} = _), do: user
  def get_user_from_assigns(%{user: user}), do: user
  def get_user_from_assigns(_), do: nil

  # identify the role from a user
  def is_guest?(user), do: user == nil
  def is_user?(user), do: user != nil
  def is_admin?(user), do: is_user?(user) && user.role == "admin"
end
