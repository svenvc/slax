defmodule SlaxWeb.ChatComponents do
  use SlaxWeb, :html

  alias Slax.Accounts.User

  import SlaxWeb.UserComponents

  attr :current_user, User, required: true
  attr :dom_id, :string, required: true
  attr :message, :any, required: true
  attr :in_thread?, :boolean, default: false
  attr :timezone, :string, required: true

  def message(assigns) do
    ~H"""
    <div id={@dom_id} class="group relative flex px-4 py-3">
      <div
        :if={!@in_thread? || @current_user.id == @message.user_id}
        class="absolute top-4 right-4 hidden group-hover:block bg-white shadow-sm px-2 pb-1 rounded border border-px border-slate-300 gap-1"
      >
        <button
          :if={!@in_thread?}
          phx-click="show-thread"
          phx-value-id={@message.id}
          class="text-slate-500 hover:text-slate-600 cursor-pointer"
        >
          <.icon name="hero-chat-bubble-bottom-center-text" class="h-4 w-4" />
        </button>

        <button
          :if={@current_user.id == @message.user_id}
          class="text-red-500 hover:text-red-800 cursor-pointer"
          data-confirm="Are you sure?"
          phx-click="delete-message"
          phx-value-id={@message.id}
          phx-value-type={@message.__struct__ |> Module.split() |> List.last()}
        >
          <.icon name="hero-trash" class="h-4 w-4" />
        </button>
      </div>

      <.user_avatar
        user={@message.user}
        class="h-10 w-10 rounded cursor-pointer"
        phx-click="show-profile"
        phx-value-user-id={@message.user.id}
      />

      <div class="ml-2">
        <div class="-mt-1">
          <.link
            phx-click="show-profile"
            phx-value-user-id={@message.user.id}
            class="text-sm font-semibold hover:underline"
          >
            {@message.user.username}
          </.link>
          <span :if={@timezone} class="ml-1 text-xs text-gray-500">
            {message_timestamp(@message, @timezone)}
          </span>
          <p class="text-sm">{@message.body}</p>
          <div
            :if={!@in_thread? && Enum.any?(@message.replies)}
            class="inline-flex items-center mt-2 rounded border border-transparent hover:border-slate-200 hover:bg-slate-50 py-1 pr-2 box-border cursor-pointer"
            phx-click="show-thread"
            phx-value-id={@message.id}
          >
            <.thread_avatars replies={@message.replies} />
            <a class="inline-block text-blue-600 text-xs font-medium ml-1" href="#">
              {length(@message.replies)}
              <%= if length(@message.replies) == 1 do %>
                reply
              <% else %>
                replies
              <% end %>
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp thread_avatars(assigns) do
    users =
      assigns.replies
      |> Enum.map(fn x -> x.user end)
      |> Enum.uniq_by(fn x -> x.id end)

    assigns = assign(assigns, :users, users)

    ~H"""
    <.user_avatar :for={user <- @users} class="h-6 w-6 rounded shrink-0 ml-1" user={user} />
    """
  end

  defp message_timestamp(message, timezone) do
    message.inserted_at
    |> Timex.Timezone.convert(timezone)
    |> Timex.format!("%-l:%M %p", :strftime)
  end
end
