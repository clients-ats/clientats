defmodule Clientats.Logging.Timestamp do
  @moduledoc """
  Timestamp formatting utilities for logging.
  """

  @doc """
  Generate current timestamp as ISO8601 string.
  """
  def iso8601_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  @doc """
  Generate current timestamp in Unix milliseconds.
  """
  def unix_ms_now do
    DateTime.utc_now() |> DateTime.to_unix(:millisecond)
  end

  @doc """
  Generate filename-safe timestamp (YYYY-MM-DD_HH-mm-ss).
  """
  def filename_safe_now do
    now = DateTime.utc_now()
    "#{format_date(now)}_#{format_time(now)}"
  end

  @doc """
  Generate filename-safe timestamp with custom precision.
  Adds microseconds as a suffix if precision is set.
  """
  def filename_safe_now(:microsecond) do
    now = DateTime.utc_now()
    "#{format_date(now)}_#{format_time(now)}_#{now.microsecond |> elem(0) |> Integer.to_string() |> String.pad_leading(6, "0")}"
  end

  defp format_date(datetime) do
    "#{datetime.year |> Integer.to_string() |> String.pad_leading(4, "0")}-#{datetime.month |> Integer.to_string() |> String.pad_leading(2, "0")}-#{datetime.day |> Integer.to_string() |> String.pad_leading(2, "0")}"
  end

  defp format_time(datetime) do
    "#{datetime.hour |> Integer.to_string() |> String.pad_leading(2, "0")}-#{datetime.minute |> Integer.to_string() |> String.pad_leading(2, "0")}-#{datetime.second |> Integer.to_string() |> String.pad_leading(2, "0")}"
  end
end
