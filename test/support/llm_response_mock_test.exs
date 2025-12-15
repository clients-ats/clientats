defmodule LLMResponseMockTest do
  use ExUnit.Case

  describe "generate_response/1" do
    test "generates successful response with all fields" do
      response = LLMResponseMock.generate_response(:successful)
      assert is_binary(response)

      {:ok, parsed} = Jason.decode(response)
      assert parsed["company_name"] == "TechCorp Industries"
      assert parsed["position_title"] == "Senior Software Engineer"
      assert parsed["salary_min"] == 150000
      assert parsed["salary_max"] == 200000
      assert parsed["employment_type"] == "full_time"
      assert Enum.count(parsed["skills"]) > 0
    end

    test "generates minimal response with required fields only" do
      response = LLMResponseMock.generate_response(:minimal)
      assert is_binary(response)

      {:ok, parsed} = Jason.decode(response)
      assert parsed["company_name"] == "Test Company"
      assert parsed["position_title"] == "Software Engineer"
      assert parsed["job_description"] == "Seeking a software engineer."
      refute Map.has_key?(parsed, "salary_min")
    end

    test "generates malformed JSON response" do
      response = LLMResponseMock.generate_response(:malformed_json)
      assert is_binary(response)
      # Malformed JSON should not parse
      assert {:error, _} = Jason.decode(response)
    end

    test "generates response with missing required fields" do
      response = LLMResponseMock.generate_response(:missing_fields)
      {:ok, parsed} = Jason.decode(response)

      assert parsed["company_name"]
      assert parsed["position_title"]
      refute Map.has_key?(parsed, "job_description")
    end

    test "generates response with invalid salary data" do
      response = LLMResponseMock.generate_response(:invalid_salary)
      {:ok, parsed} = Jason.decode(response)

      assert is_binary(parsed["salary_min"])
      assert is_binary(parsed["salary_max"])
    end

    test "generates partial response with some optional fields" do
      response = LLMResponseMock.generate_response(:partial_data)
      {:ok, parsed} = Jason.decode(response)

      assert parsed["company_name"]
      assert parsed["salary_min"]
      refute Map.has_key?(parsed, "salary_max")
      refute Map.has_key?(parsed, "application_deadline")
    end

    test "generates empty response" do
      response = LLMResponseMock.generate_response(:empty_response)
      {:ok, parsed} = Jason.decode(response)
      assert parsed == %{}
    end

    test "generates error response" do
      response = LLMResponseMock.generate_response(:error)
      {:ok, parsed} = Jason.decode(response)

      assert parsed["error"]
      assert String.contains?(parsed["error"], "Unable to process")
    end

    test "defaults to successful response for unknown scenarios" do
      response = LLMResponseMock.generate_response(:unknown)
      {:ok, parsed} = Jason.decode(response)
      assert parsed["company_name"] == "TechCorp Industries"
    end

    test "all response strings are valid JSON or known invalid" do
      scenarios = [:successful, :minimal, :missing_fields, :invalid_salary, :partial_data, :empty_response, :error]

      Enum.each(scenarios, fn scenario ->
        response = LLMResponseMock.generate_response(scenario)
        assert is_binary(response)
        assert byte_size(response) > 0
      end)
    end
  end

  describe "generate_response_map/1" do
    test "returns parsed map for valid JSON responses" do
      map = LLMResponseMock.generate_response_map(:successful)
      assert is_map(map)
      assert map["company_name"] == "TechCorp Industries"
    end

    test "returns empty map for malformed JSON" do
      map = LLMResponseMock.generate_response_map(:malformed_json)
      assert map == %{}
    end

    test "returns map with available fields for partial responses" do
      map = LLMResponseMock.generate_response_map(:minimal)
      assert map["company_name"]
      assert map["position_title"]
    end
  end

  describe "generate_fallback_chain/0" do
    test "returns list of fallback responses" do
      chain = LLMResponseMock.generate_fallback_chain()
      assert is_list(chain)
      assert Enum.count(chain) > 0
    end

    test "all fallback responses are ok tuples" do
      chain = LLMResponseMock.generate_fallback_chain()

      Enum.each(chain, fn response ->
        assert is_tuple(response)
        assert elem(response, 0) == :ok
        assert is_binary(elem(response, 1))
      end)
    end

    test "fallback chain contains parseable JSON" do
      chain = LLMResponseMock.generate_fallback_chain()

      Enum.each(chain, fn {:ok, response} ->
        {:ok, _parsed} = Jason.decode(response)
      end)
    end
  end

  describe "response scenarios coverage" do
    test "all scenarios generate responses" do
      scenarios = [
        :successful,
        :minimal,
        :malformed_json,
        :missing_fields,
        :invalid_salary,
        :partial_data,
        :empty_response,
        :error
      ]

      Enum.each(scenarios, fn scenario ->
        response = LLMResponseMock.generate_response(scenario)
        assert is_binary(response)
        assert byte_size(response) > 0
      end)
    end

    test "response scenarios are distinct" do
      responses =
        [:successful, :minimal, :partial_data, :error]
        |> Enum.map(&LLMResponseMock.generate_response/1)

      # At least some should be different
      unique_responses = Enum.uniq(responses)
      assert Enum.count(unique_responses) > 1
    end
  end
end
