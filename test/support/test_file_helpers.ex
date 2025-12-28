defmodule ClientatsWeb.TestFileHelpers do
  @moduledoc """
  Helper functions for generating test files of specific sizes.
  """

  @doc """
  Generate a test PDF file of the specified size in bytes.
  Returns the path to the temporary file.

  ## Examples

      iex> path = generate_test_pdf(5_000_000)
      iex> File.exists?(path)
      true
      iex> File.stat!(path).size
      5_000_000

  """
  def generate_test_pdf(size_in_bytes) when size_in_bytes > 0 do
    # Create a minimal PDF header
    pdf_header = "%PDF-1.4\n"
    pdf_footer = "\n%%EOF\n"

    # Calculate how much random data we need
    header_size = byte_size(pdf_header)
    footer_size = byte_size(pdf_footer)
    random_data_size = size_in_bytes - header_size - footer_size

    if random_data_size < 0 do
      raise ArgumentError, "File size too small to create a valid PDF (minimum ~20 bytes)"
    end

    # Generate random data to fill the file
    random_data = :crypto.strong_rand_bytes(random_data_size)

    # Create temporary file
    temp_path =
      Path.join(System.tmp_dir!(), "test_resume_#{System.unique_integer([:positive])}.pdf")

    # Write PDF content
    content = pdf_header <> random_data <> pdf_footer
    File.write!(temp_path, content)

    temp_path
  end

  @doc """
  Generate a test file with a specific extension and size.
  Returns the path to the temporary file.
  """
  def generate_test_file(extension, size_in_bytes) when size_in_bytes > 0 do
    random_data = :crypto.strong_rand_bytes(size_in_bytes)

    temp_path =
      Path.join(System.tmp_dir!(), "test_file_#{System.unique_integer([:positive])}.#{extension}")

    File.write!(temp_path, random_data)

    temp_path
  end

  @doc """
  Clean up a temporary test file.
  """
  def cleanup_test_file(path) do
    if File.exists?(path) do
      File.rm!(path)
    end
  end
end
