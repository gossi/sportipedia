defmodule Sportipedia.Catalog do
use Commanded.Application, otp_app: :sportipedia
router Sportipedia.Catalog.Equipment.Router
end
