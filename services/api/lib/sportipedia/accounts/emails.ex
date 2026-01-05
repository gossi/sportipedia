defmodule Sportipedia.Accounts.Emails do
  import Swoosh.Email

  defp with_from do
    new()
    |> from({"Sportipedia", "no-reply@sportipedia.net"})
  end

  def welcome(to, name) do
    with_from()
    |> to(to)
    |> subject("Welcome to Sportipedia")
    |> text_body("""

    ==============================

    Hi #{name},

    Welcome to Sportipedia

    ==============================
    """)
  end

  def email_confirmation(to, name, url) do
    with_from()
    |> to(to)
    |> subject("Confirm your Email-Address")
    |> text_body("""

    ==============================

    Hi #{name},

    You can confirm your email-address by visiting the URL below:

    #{url}

    ==============================
    """)
  end

  def password_reset(to, name, url) do
    with_from()
    |> to(to)
    |> subject("Reset your Password")
    |> text_body("""

    ==============================

    Hi #{name},

    You can reset your password by visiting the URL below:

    #{url}

    ==============================
    """)
  end
end
