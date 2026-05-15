defmodule Sportipedia.Auth.User do
  alias Sportipedia.Auth.Guardian
  use TypedStruct

  typedstruct do
    field :id, String.t()
    field :name, String.t()
    field :email, String.t()
    field :image, String.t()
    field :given_name, String.t()
    field :family_name, String.t()
    field :lang, String.t()
  end

  @spec from_token(Guardian.token()) :: Sportipedia.Auth.User.t()
  def from_token(token) do
    %Sportipedia.Auth.User{
      id: token["id"],
      name: token["name"],
      email: token["email"],
      image: token["image"],
      given_name: token["givenName"],
      family_name: token["familyName"],
      lang: token["lang"]
    }
  end
end
