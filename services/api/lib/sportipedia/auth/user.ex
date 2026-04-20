defmodule Sportipedia.Auth.User do
  alias Sportipedia.Auth.Guardian
  use TypedStruct

  typedstruct do
    field :id, String.t()
    field :name, String.t()
    field :email, String.t()
    field :image, String.t()
    field :givenName, String.t()
    field :familyName, String.t()
    field :lang, String.t()
  end

  @spec from_token(Guardian.token()) :: Sportipedia.Auth.User.t()
  def from_token(token) do
    %Sportipedia.Auth.User{
      id: token["id"],
      name: token["name"],
      email: token["email"],
      image: token["image"],
      givenName: token["givenName"],
      familyName: token["familyName"],
      lang: token["lang"]
    }
  end
end
