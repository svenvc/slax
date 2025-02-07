defmodule Slax.Chat.Reply do
  use Ecto.Schema
  import Ecto.Changeset

  alias Slax.Chat.Message
  alias Slax.Accounts.User

  schema "replies" do
    field :body, :string
    belongs_to :message, Message
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reply, attrs) do
    reply
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end
end
