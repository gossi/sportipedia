defmodule Sportipedia.Architecture do
  # @type vex_validator() :: atom()
  # @type vex_error() :: {:error, atom(), vex_validator()} | {:error, atom(), vex_validator(), String.t()}

  @type validation_failure :: %{String.t() => [String.t()]}
  @type validation_failures :: {:validation_failure, validation_failure()}

  @type result :: term()

  @type public_api(t) :: {:ok, t} | {:error, validation_failures()} | {:error, :not_found}
  @type public_api() :: :ok | {:error, validation_failures()} | {:error, :not_found}
end
