defmodule Sportipedia.Auth.Guardian do
  @moduledoc """
  Used by Guardian to serialize a JWT token
  """
  alias Sportipedia.Auth.User

  use Guardian, otp_app: :sportipedia

  @type token() :: %{
          # jwt fieds
          iat: non_neg_integer(),
          sub: String.t(),
          exp: non_neg_integer(),
          iss: String.t(),
          aud: String.t(),
          # better auth fields
          id: String.t(),
          createdAt: String.t(),
          updatedAt: String.t(),
          name: String.t(),
          email: String.t(),
          emailVerified: boolean(),
          image: String.t(),
          givenName: String.t(),
          familyName: String.t(),
          lang: String.t()
        }

  @spec resource_from_claims(token()) :: {:error, :reason_for_error} | {:ok, any()}
  def resource_from_claims(token) do
    user = User.from_token(token)
    {:ok, user}
  end

  # def subject_for_token(%{id: id}, _claims) do
  #   # You can use any value for the subject of your token but
  #   # it should be useful in retrieving the resource later, see
  #   # how it being used on `resource_from_claims/1` function.
  #   # A unique `id` is a good subject, a non-unique email address
  #   # is a poor subject.
  #   sub = to_string(id)
  #   {:ok, sub}
  # end

  def subject_for_token(_, _) do
    {:error, :not_implemented}
  end
end
