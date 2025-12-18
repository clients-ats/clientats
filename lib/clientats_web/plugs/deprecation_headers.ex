defmodule ClientatsWeb.Plugs.DeprecationHeaders do
  @moduledoc """
  Plug for adding API deprecation information to responses.

  Adds standard deprecation headers (RFC 8594) and deprecation metadata
  to API responses, informing clients about deprecated endpoints and
  migration paths.

  ## Examples

      plug ClientatsWeb.Plugs.DeprecationHeaders, version: "v1"
  """

  import Plug.Conn

  alias ClientatsWeb.Versioning.APIVersion

  def init(opts), do: opts

  def call(conn, opts) do
    version = Keyword.get(opts, :version)

    if version && APIVersion.deprecated?(version) do
      add_deprecation_headers(conn, version)
    else
      conn
    end
  end

  defp add_deprecation_headers(conn, version) do
    info = APIVersion.version_info(version)

    conn
    |> put_resp_header("deprecation", "true")
    |> put_deprecation_sunset_header(info)
    |> put_deprecation_link_header(version)
  end

  defp put_deprecation_sunset_header(conn, info) do
    if info.sunset_date do
      # Format as RFC 7231 HTTP date
      put_resp_header(conn, "sunset", format_sunset_date(info.sunset_date))
    else
      conn
    end
  end

  defp put_deprecation_link_header(conn, version) do
    next_version = get_next_version(version)

    if next_version do
      link_value = "</api/#{next_version}/scrape_job>; rel=\"successor-version\""
      put_resp_header(conn, "link", link_value)
    else
      conn
    end
  end
  defp get_next_version("v1"), do: "v2"
  defp get_next_version(_), do: nil

  defp format_sunset_date(date_string) do
    # Parse ISO 8601 date and format as RFC 7231
    case DateTime.from_iso8601(date_string <> "T00:00:00Z") do
      {:ok, datetime, _offset} ->
        Calendar.strftime(datetime, "%a, %d %b %Y 00:00:00 GMT")

      _ ->
        # Fallback to raw string if parsing fails
        date_string
    end
  end
end
