defmodule SportipediaWeb.Router do
  use SportipediaWeb, :router

  scope "/catalog", SportipediaWeb.Catalog do
    pipe_through [:api, :catalog]

    scope "/equipment", Equipment do
      scope "/gadgets", Gadget do
        post "/create-gadget", GadgetController, :create_gadget
      end
    end
  end
end
