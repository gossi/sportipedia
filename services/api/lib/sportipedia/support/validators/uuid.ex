defmodule Sportipedia.Support.Validators.UuidValidator do
  use Vex.Validator

  def validate(value, _options) do
    Vex.Validators.By.validate(value,
      function: &valid_uuid?/1,
      allow_nil: false,
      allow_blank: false
    )
  end

  def valid_uuid?(maybe_id) do
    case Ecto.UUID.dump(maybe_id) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
