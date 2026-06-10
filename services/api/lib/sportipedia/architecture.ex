defmodule Sportipedia.Architecture do
  # @type vex_validator() :: atom()
  # @type vex_error() :: {:error, atom(), vex_validator()} | {:error, atom(), vex_validator(), String.t()}

  @type validaton_failure :: %{String.t() => [String.t()]}
  @type validaton_failures :: {:validation_failure, validaton_failure()}

  @type result :: term()

  @type public_api_with_result :: {:ok, result()} | {:error, validaton_failures()}
  @type public_api :: :ok | {:error, validaton_failures()}
end
