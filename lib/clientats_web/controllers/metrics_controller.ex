defmodule ClientatsWeb.MetricsController do
  @moduledoc """
  Metrics endpoint for monitoring LLM performance.

  Exposes metrics at GET /metrics in JSON format.
  """

  use ClientatsWeb, :controller
  require Logger

  @metrics_token System.get_env("METRICS_TOKEN", "")

  @doc """
  Expose metrics in JSON format.

  Requires METRICS_TOKEN header if configured.
  """
  def index(conn, _params) do
    # Authentication check
    if @metrics_token != "" do
      case get_req_header(conn, "authorization") do
        [bearer_token] ->
          token =
            bearer_token
            |> String.replace("Bearer ", "")
            |> String.trim()

          if token != @metrics_token do
            send_resp(conn, 401, "Unauthorized")
          else
            serve_metrics(conn)
          end

        [] ->
          send_resp(conn, 401, "Missing authorization header")
      end
    else
      serve_metrics(conn)
    end
  end

  defp serve_metrics(conn) do
    try do
      metrics = Clientats.LLM.Metrics.get_metrics()

      conn
      |> put_resp_header("content-type", "application/json; charset=utf-8")
      |> json(metrics)
    rescue
      e ->
        Logger.error("Failed to generate metrics: #{inspect(e)}")

        conn
        |> put_status(500)
        |> json(%{error: "Failed to generate metrics"})
    end
  end
end
