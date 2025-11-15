defmodule ClientatsWeb.CoreComponentsTest do
  use ClientatsWeb.ConnCase

  import ClientatsWeb.CoreComponents

  describe "translate_error/1" do
    test "translates simple error message" do
      assert translate_error({"must be at least %{count} character(s)", count: 5}) ==
               "must be at least 5 character(s)"
    end

    test "translates error with multiple interpolations" do
      assert translate_error({"should be between %{min} and %{max}", min: 1, max: 10}) ==
               "should be between 1 and 10"
    end

    test "handles error without interpolations" do
      assert translate_error({"is invalid", []}) == "is invalid"
    end
  end

  describe "translate_errors/2" do
    test "translates multiple errors for a field" do
      errors = [
        {:name, {"can't be blank", [validation: :required]}},
        {:name, {"must be at least %{count} character(s)", count: 3}}
      ]

      result = translate_errors(errors, :name)

      assert result == ["can't be blank", "must be at least 3 character(s)"]
    end

    test "returns empty list when no errors for field" do
      errors = [
        {:email, {"is invalid", [validation: :format]}}
      ]

      result = translate_errors(errors, :name)

      assert result == []
    end

    test "filters errors for specific field only" do
      errors = [
        {:name, {"can't be blank", [validation: :required]}},
        {:email, {"is invalid", [validation: :format]}}
      ]

      result = translate_errors(errors, :name)

      assert result == ["can't be blank"]
    end
  end
end
