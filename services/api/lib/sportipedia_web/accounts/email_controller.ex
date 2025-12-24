# lib/my_app_web/controllers/email_controller.ex
defmodule SportipediaWeb.Accounts.EmailController do
  use SportipediaWeb, :controller

  alias Sportipedia.Mailer
  alias Sportipedia.Accounts.Emails

  def confirm_email(conn, %{"to" => to, "url" => url, "name" => name}) do
    Emails.email_confirmation(to, name, url)
    |> Mailer.deliver()

    send_resp(conn, 204, "")
  end

  def password_reset(conn, %{"data" => %{"email" => email, "url" => url, "name" => name}}) do
    Emails.password_reset(email, name, url)
    |> Mailer.deliver()

    # with {:ok, _metadata} <- Mailer.deliver(email) do
    #   {:ok, email}
    # end

    send_resp(conn, 204, "")
  end
end
