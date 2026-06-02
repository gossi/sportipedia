defmodule Sportipedia.Auth.Roles do
  defguard is_guest?(user) when is_nil(user)

  defguard is_user?(user) when not is_nil(user)

  defguard is_admin?(user) when is_user?(user) and user.role == "admin"
end
