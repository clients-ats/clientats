defmodule Clientats.Accounts do
  import Ecto.Query, warn: false
  alias Clientats.Repo
  alias Clientats.Accounts.User

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Get authenticated user from connection session.

  Used for API authentication in controllers.
  """
  def get_authenticated_user(conn) do
    # Try to get user from assigns (for LiveView) or session (for controllers)
    initial_user =
      conn.assigns[:current_user] ||
        conn.assigns[:user] ||
        (conn.assigns[:user_id] && get_user(conn.assigns[:user_id])) ||
        (get_session(conn, :user_id) && get_user(get_session(conn, :user_id)))

    # In test environment, also check for user in assigns (for easier testing)
    user =
      if Mix.env() == :test && conn.assigns[:user] do
        initial_user || conn.assigns[:user]
      else
        initial_user
      end

    # If we got a user ID instead of a user object, fetch the user
    final_user =
      if user && is_integer(user) do
        get_user(user)
      else
        user
      end

    final_user
  end

  defp get_session(conn, key) do
    # In tests, session data is stored in conn.assigns after put_session
    # In production, it would be in cookies after session fetch middleware
    conn.assigns[key] || conn.req_cookies[key]
  end

  def register_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.hashed_password) ->
        {:ok, user}

      user ->
        {:error, :invalid_credentials}

      true ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end
end
