defmodule ClientatsWeb.DataImportLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  defp user_fixture(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, user} = Clientats.Accounts.register_user(attrs)
    user
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end

  describe "Data Import Live" do
    test "renders import page", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/import")

      assert html =~ "Import Data"
      assert html =~ "Drag and drop your JSON file here"
    end

    test "validates file upload triggers change", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/import")

            import_data = %{
              "version" => "1.0",
              "job_interests" => []
            }
      
            file_input = file_input(lv, "#import-form", :import_file, [
              %{
                last_modified: 1_594,
                name: "data.json",
                content: Jason.encode!(import_data),
                type: "application/json"
              }
            ])
      render_upload(file_input, "data.json")

      assert has_element?(lv, "p", "data.json")
    end

    test "successfully imports data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/import")

      import_data = %{
        "version" => "1.0",
        "job_interests" => [
          %{ 
            "company_name" => "Tech Corp",
            "position_title" => "Elixir Developer",
            "status" => "interested"
          }
        ]
      }

      file_input = file_input(lv, "#import-form", :import_file, [
        %{ 
          last_modified: 1_594,
          name: "data.json",
          content: Jason.encode!(import_data),
          type: "application/json"
        }
      ])

      render_upload(file_input, "data.json")

      lv
      |> form("#import-form")
      |> render_submit()

      html = render(lv)
      assert html =~ "Import Successful!"
      assert html =~ "Job Interests: 1"
    end

    test "handles invalid JSON", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/import")

      file_input = file_input(lv, "#import-form", :import_file, [
        %{ 
          last_modified: 1_594,
          name: "data.json",
          content: "invalid json",
          type: "application/json"
        }
      ])

      render_upload(file_input, "data.json")

      lv
      |> form("#import-form")
      |> render_submit()

      assert render(lv) =~ "Invalid JSON file"
    end

    test "handles missing file", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/import")

      lv
      |> form("#import-form")
      |> render_submit()

      assert render(lv) =~ "Please select a file to import"
    end
  end
end
