defmodule Clientats.AccountsTest do
  use Clientats.DataCase

  alias Clientats.Accounts
  alias Clientats.Accounts.User

  describe "get_user/1" do
    test "returns user when id exists" do
      user = user_fixture()
      assert Accounts.get_user(user.id).id == user.id
    end

    test "returns nil when id does not exist" do
      assert Accounts.get_user(999_999) == nil
    end
  end

  describe "get_user!/1" do
    test "returns user when id exists" do
      user = user_fixture()
      assert Accounts.get_user!(user.id).id == user.id
    end

    test "raises error when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(999_999)
      end
    end
  end

  describe "get_user_by_email/1" do
    test "returns user when email exists" do
      user = user_fixture()
      assert Accounts.get_user_by_email(user.email).id == user.id
    end

    test "returns nil when email does not exist" do
      assert Accounts.get_user_by_email("nonexistent@example.com") == nil
    end

    test "is case-sensitive" do
      user = user_fixture(email: "test@example.com")
      assert Accounts.get_user_by_email("TEST@EXAMPLE.COM") == nil
      assert Accounts.get_user_by_email("test@example.com").id == user.id
    end
  end

  describe "register_user/1" do
    test "creates user with valid attributes" do
      valid_attrs = %{
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:ok, %User{} = user} = Accounts.register_user(valid_attrs)
      assert user.email == "test@example.com"
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.hashed_password != nil
      assert user.hashed_password != "password123"
    end

    test "hashes password on registration" do
      valid_attrs = %{
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:ok, user} = Accounts.register_user(valid_attrs)
      assert Bcrypt.verify_pass("password123", user.hashed_password)
    end

    test "requires email" do
      invalid_attrs = %{
        password: "password123",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires valid email format" do
      invalid_attrs = %{
        email: "invalid-email",
        password: "password123",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "requires unique email" do
      _user = user_fixture(email: "test@example.com")

      attrs = %{
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Jane",
        last_name: "Doe"
      }

      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "requires password" do
      invalid_attrs = %{
        email: "test@example.com",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires password to be at least 8 characters" do
      invalid_attrs = %{
        email: "test@example.com",
        password: "short",
        password_confirmation: "short",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert %{password: ["should be at least 8 character(s)"]} = errors_on(changeset)
    end

    test "requires password confirmation to match" do
      invalid_attrs = %{
        email: "test@example.com",
        password: "password123",
        password_confirmation: "different",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end

    test "requires first name" do
      invalid_attrs = %{
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        last_name: "Doe"
      }

      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert %{first_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires last name" do
      invalid_attrs = %{
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "John"
      }

      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert %{last_name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "authenticate_user/2" do
    test "authenticates user with valid credentials" do
      user = user_fixture(email: "test@example.com", password: "password123")

      assert {:ok, authenticated_user} = Accounts.authenticate_user("test@example.com", "password123")
      assert authenticated_user.id == user.id
    end

    test "returns error with invalid password" do
      user_fixture(email: "test@example.com", password: "password123")

      assert {:error, :invalid_credentials} = Accounts.authenticate_user("test@example.com", "wrongpassword")
    end

    test "returns error with non-existent email" do
      assert {:error, :invalid_credentials} = Accounts.authenticate_user("nonexistent@example.com", "password123")
    end

    test "prevents timing attacks on non-existent users" do
      user_fixture(email: "exists@example.com", password: "password123")

      time_existing = :timer.tc(fn ->
        Accounts.authenticate_user("exists@example.com", "wrongpassword")
      end) |> elem(0)

      time_nonexistent = :timer.tc(fn ->
        Accounts.authenticate_user("nonexistent@example.com", "password123")
      end) |> elem(0)

      ratio = time_nonexistent / time_existing
      assert ratio > 0.5 and ratio < 2.0, "Timing difference too large, potential timing attack vulnerability"
    end
  end

  describe "change_user_registration/2" do
    test "returns changeset for new user" do
      changeset = Accounts.change_user_registration(%User{})
      assert %Ecto.Changeset{} = changeset
    end

    test "returns changeset with changes" do
      changeset = Accounts.change_user_registration(%User{}, %{email: "test@example.com"})
      assert changeset.changes.email == "test@example.com"
    end

    test "validates but does not persist password" do
      changeset = Accounts.change_user_registration(%User{}, %{password: "password123"})
      assert changeset.changes[:password] == "password123"
      assert changeset.changes[:hashed_password] == nil
    end
  end

  defp user_fixture(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }

    attrs = Enum.into(attrs, default_attrs)

    {:ok, user} = Accounts.register_user(attrs)
    user
  end
end
