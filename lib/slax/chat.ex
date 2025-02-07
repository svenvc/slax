defmodule Slax.Chat do
  alias Slax.Accounts.User
  alias Slax.Chat.{Message, Reply, Room, RoomMembership}
  alias Slax.Repo

  import Ecto.{Query, Changeset}

  @pubsub Slax.PubSub

  def list_rooms do
    Repo.all(from Room, order_by: [asc: :name])
  end

  def list_joined_rooms_with_unread_counts(%User{} = user) do
    from(room in Room,
      join: membership in assoc(room, :memberships),
      where: membership.user_id == ^user.id,
      left_join: message in assoc(room, :messages),
      on: message.id > membership.last_read_id,
      group_by: room.id,
      select: {room, count(message.id)},
      order_by: [asc: room.name]
    )
    |> Repo.all()
  end

  def list_rooms_with_joined(%User{} = user) do
    query =
      from r in Room,
        left_join: m in RoomMembership,
        on: r.id == m.room_id and m.user_id == ^user.id,
        select: {r, not is_nil(m.id)},
        order_by: [asc: :name]

    Repo.all(query)
  end

  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  def get_room!(id) do
    Repo.get!(Room, id)
  end

  def get_first_room! do
    Repo.one!(from r in Room, limit: 1, order_by: [asc: :name])
  end

  def change_room(room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  def list_messages_in_room(%Room{id: room_id}) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], asc: :inserted_at, asc: :id)
    |> preload_message_user_and_replies()
    |> Repo.all()
  end

  defp preload_message_user_and_replies(message_query) do
    replies_query = from r in Reply, order_by: [asc: :inserted_at, asc: :id]

    preload(message_query, [:user, replies: ^{replies_query, [:user]}])
  end

  def change_message(message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  def create_message(room, attrs, user) do
    with {:ok, message} <-
           %Message{room: room, user: user, replies: []}
           |> Message.changeset(attrs)
           |> Repo.insert() do
      Phoenix.PubSub.broadcast!(@pubsub, topic(room.id), {:new_message, message})
      {:ok, message}
    end
  end

  def delete_message_by_id(id, %User{id: user_id}) do
    message = %Message{user_id: ^user_id} = Repo.get(Message, id)

    Repo.delete(message)

    Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:message_deleted, message})
  end

  def delete_reply_by_id(id, %User{id: user_id}) do
    with %Reply{} = reply <-
           from(r in Reply, where: r.id == ^id and r.user_id == ^user_id)
           |> Repo.one() do
      Repo.delete(reply)

      message = get_message!(reply.message_id)

      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:deleted_reply, message})
    end
  end

  def get_message!(id) do
    Message
    |> where([m], m.id == ^id)
    |> preload_message_user_and_replies()
    |> Repo.one!()
  end

  def subscribe_to_room(room) do
    Phoenix.PubSub.subscribe(@pubsub, topic(room.id))
  end

  def unsubscribe_from_room(room) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(room.id))
  end

  defp topic(room_id), do: "chat_room:#{room_id}"

  def join_room!(room, user) do
    Repo.insert!(%RoomMembership{room: room, user: user})
  end

  def joined?(%Room{} = room, %User{} = user) do
    Repo.exists?(
      from rm in RoomMembership, where: rm.room_id == ^room.id and rm.user_id == ^user.id
    )
  end

  def toggle_room_membership(room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        Repo.delete(membership)
        {room, false}

      nil ->
        join_room!(room, user)
        {room, true}
    end
  end

  defp get_membership(room, user) do
    Repo.get_by(RoomMembership, room_id: room.id, user_id: user.id)
  end

  def update_last_read_id(room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        id =
          from(m in Message, where: m.room_id == ^room.id, select: max(m.id))
          |> Repo.one()

        membership
        |> change(%{last_read_id: id})
        |> Repo.update()

      nil ->
        nil
    end
  end

  def get_last_read_id(%Room{} = room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        membership.last_read_id

      nil ->
        nil
    end
  end

  def change_reply(reply, attrs \\ %{}) do
    Reply.changeset(reply, attrs)
  end

  def create_reply(%Message{} = message, attrs, user) do
    with {:ok, reply} <-
           %Reply{message: message, user: user}
           |> Reply.changeset(attrs)
           |> Repo.insert() do
      message = get_message!(reply.message_id)

      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:new_reply, message})

      {:ok, reply}
    end
  end
end
