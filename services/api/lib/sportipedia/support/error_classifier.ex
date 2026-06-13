defmodule Sportipedia.Support.ErrorClassifier do
  def classify_error({:validation_failure, failures} = validation_failures) do
    case find_not_found_error(failures) do
      nil -> {:error, validation_failures}
      _element -> {:error, :not_found}
    end
  end

  def classify_error(reason), do: {:error, reason}

  defp find_not_found_error(failures) do
    Enum.find(failures, fn {_k, val} -> Enum.find(val, fn e -> e == :not_found end) end)
  end
end
