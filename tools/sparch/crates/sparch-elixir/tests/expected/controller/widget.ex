defmodule SportipediaWeb.Catalog.Equipment.Widget.WidgetController do
@moduledoc """
Handles HTTP requests for widget operations.
"""
use SportipediaWeb, :controller
use OpenApiSpex.ControllerSpecs
alias OpenApiSpex.Reference
alias Sportipedia.Catalog.Equipment.Widget
alias SportipediaWeb.System.FallbackController
  plug Bodyguard.Plug.Authorize,
    policy: Sportipedia.Catalog.Equipment.Widget.Policy,
    action: {Phoenix.Controller, :action_name},
    user: {Sportipedia.Auth, :get_user_from_assigns},
    fallback: FallbackController
tags ["equipment"]
end
