defmodule Sportipedia.Catalog.Equipment.Instrument.Policy do
  @behaviour Bodyguard.Policy

  # create instrument

  def authorize(:catalog_instrument, user, _params) when is_nil(user) do
    :error
  end

  def authorize(:catalog_instrument, user, _params) when not is_nil(user) do
    :ok
  end

  # edit instrument

  def authorize(:edit_instrument, user, _params) when is_nil(user) do
    :error
  end

  def authorize(:edit_instrument, user, _params) when not is_nil(user) do
    :ok
  end

  # read instrument

  def authorize(:read_instrument, _user, _params) do
    :ok
  end

  def authorize(:list_instruments, _user, _params) do
    :ok
  end

  # delete instrument

  def authorize(:archive_instrument, user, _params) when is_nil(user) do
    :error
  end

  def authorize(:archive_instrument, user, _params) when not is_nil(user) do
    :ok
  end
end
