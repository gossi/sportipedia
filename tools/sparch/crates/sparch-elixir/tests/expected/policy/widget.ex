defmodule Sportipedia.Catalog.Equipment.Widget.Policy do
@moduledoc """
Authorizes widget operations based on user roles.
"""
import Sportipedia.Auth.Roles
@behaviour Bodyguard.Policy
def authorize(:create_widget, user, _params) when is_guest?(user), do: :error
def authorize(:create_widget, user, _params) when is_user?(user), do: :ok
def authorize(:archive_widget, user, _params) when is_guest?(user), do: :error
def authorize(:archive_widget, user, _params) when is_user?(user), do: :ok
def authorize(:edit_widget, user, _params) when is_guest?(user), do: :error
def authorize(:edit_widget, user, _params) when is_user?(user), do: :ok
def authorize(:note_widget, user, _params) when is_guest?(user), do: :error
def authorize(:note_widget, user, _params) when is_user?(user), do: :ok
def authorize(:relabel_widget, user, _params) when is_guest?(user), do: :error
def authorize(:relabel_widget, user, _params) when is_user?(user), do: :ok
def authorize(:list_widgets, _user, _params), do: :ok
def authorize(:read_widget, _user, _params), do: :ok
end
