defmodule Sportipedia.Support.Commanded.Middleware.Identity do
  @behaviour Commanded.Middleware

  alias Commanded.Middleware.Pipeline
  import Pipeline

  def before_dispatch(%Pipeline{} = pipeline) do
    user = Process.get(:user)

    if user do
      assign(pipeline, :user, user)
      assign_metadata(pipeline, :user_id, user.id)
    else
      pipeline
    end
  end

  def after_dispatch(pipeline), do: pipeline
  def after_failure(pipeline), do: pipeline
end
