defmodule ClientatsWeb.E2E.UserFixtures do
  @moduledoc """
  Shared user fixtures for E2E tests.
  """

  import Wallaby.Query

  @doc """
  Generate a unique user map with credentials.
  """
  def user_attrs do
    %{
      email: "test#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }
  end

  @doc """
  Create a user in the database and return the user struct.
  """
  def create_user(attrs \\ %{}) do
    attrs = Map.merge(user_attrs(), attrs)
    {:ok, user} = Clientats.Accounts.register_user(attrs)
    Map.put(attrs, :id, user.id)
  end

  @doc """
  Create a user and log them in via the Wallaby session.
  Returns the user map with :id added.
  """
  def create_user_and_login(session, attrs \\ %{}) do
    user = user_attrs() |> Map.merge(attrs)
    {:ok, db_user} = Clientats.Accounts.register_user(user)

    session
    |> Wallaby.Browser.visit("/login")
    |> Wallaby.Browser.fill_in(css("input[name='user[email]']"), with: user.email)
    |> Wallaby.Browser.fill_in(css("input[name='user[password]']"), with: user.password)
    |> Wallaby.Browser.click(button("Sign in"))

    Map.put(user, :id, db_user.id)
  end
end
