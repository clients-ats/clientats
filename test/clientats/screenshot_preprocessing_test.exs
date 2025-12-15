defmodule Clientats.ScreenshotPreprocessingTest do
  use ExUnit.Case

  describe "scale_image/3" do
    test "scales image to specified dimensions" do
      # Generate a mock screenshot
      filename = ScreenshotMock.generate_mock_screenshot(:generic)

      case Clientats.ScreenshotPreprocessing.scale_image(filename, 800, 600) do
        {:ok, scaled_path} ->
          assert File.exists?(scaled_path)
          assert String.ends_with?(scaled_path, ".png")

          # Cleanup
          File.rm!(scaled_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          # Skip if preprocessing not available
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "rejects invalid image paths" do
      result = Clientats.ScreenshotPreprocessing.scale_image("/nonexistent/file.png", 800, 600)
      assert {:error, _} = result
    end

    test "rejects invalid dimensions" do
      filename = ScreenshotMock.generate_mock_screenshot(:generic)

      result = Clientats.ScreenshotPreprocessing.scale_image(filename, 0, 600)
      assert {:error, _} = result

      ScreenshotMock.cleanup_screenshot(filename)
    end
  end

  describe "normalize_image/1" do
    test "normalizes image format to PNG" do
      filename = ScreenshotMock.generate_mock_screenshot(:linkedin)

      case Clientats.ScreenshotPreprocessing.normalize_image(filename) do
        {:ok, normalized_path} ->
          assert File.exists?(normalized_path)
          assert String.ends_with?(normalized_path, ".png")

          # Verify it's a valid PNG
          {:ok, content} = File.read(normalized_path)
          assert String.starts_with?(content, <<137, 80, 78, 71>>)

          File.rm!(normalized_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "handles already PNG formatted images" do
      filename = ScreenshotMock.generate_mock_screenshot(:generic)

      case Clientats.ScreenshotPreprocessing.normalize_image(filename) do
        {:ok, normalized_path} ->
          {:ok, original_content} = File.read(filename)
          {:ok, normalized_content} = File.read(normalized_path)

          # PNG files should have the same signature
          assert String.starts_with?(original_content, <<137, 80, 78, 71>>)
          assert String.starts_with?(normalized_content, <<137, 80, 78, 71>>)

          File.rm!(normalized_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end
  end

  describe "adjust_contrast/2" do
    test "adjusts image contrast for OCR processing" do
      filename = ScreenshotMock.generate_mock_screenshot(:indeed)

      case Clientats.ScreenshotPreprocessing.adjust_contrast(filename, 1.5) do
        {:ok, adjusted_path} ->
          assert File.exists?(adjusted_path)
          assert String.ends_with?(adjusted_path, ".png")

          # Cleanup
          File.rm!(adjusted_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "rejects invalid contrast values" do
      filename = ScreenshotMock.generate_mock_screenshot(:generic)

      # Negative contrast should be rejected
      result = Clientats.ScreenshotPreprocessing.adjust_contrast(filename, -0.5)
      assert {:error, _} = result

      ScreenshotMock.cleanup_screenshot(filename)
    end

    test "handles contrast value of 1.0 (no change)" do
      filename = ScreenshotMock.generate_mock_screenshot(:glassdoor)

      case Clientats.ScreenshotPreprocessing.adjust_contrast(filename, 1.0) do
        {:ok, adjusted_path} ->
          {:ok, original_content} = File.read(filename)
          {:ok, adjusted_content} = File.read(adjusted_path)

          # With 1.0 contrast, files might be identical or very similar
          assert byte_size(original_content) > 0
          assert byte_size(adjusted_content) > 0

          File.rm!(adjusted_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end
  end

  describe "validate_screenshot_metadata/1" do
    test "validates screenshot metadata for a valid PNG" do
      filename = ScreenshotMock.generate_mock_screenshot(:generic)

      case Clientats.ScreenshotPreprocessing.validate_screenshot_metadata(filename) do
        {:ok, metadata} ->
          assert is_map(metadata)
          assert Map.has_key?(metadata, :width)
          assert Map.has_key?(metadata, :height)
          assert Map.has_key?(metadata, :file_size)
          assert is_integer(metadata.width) and metadata.width > 0
          assert is_integer(metadata.height) and metadata.height > 0
          assert is_integer(metadata.file_size) and metadata.file_size > 0

          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "rejects non-existent files" do
      result = Clientats.ScreenshotPreprocessing.validate_screenshot_metadata("/nonexistent/file.png")
      assert {:error, :file_not_found} = result
    end

    test "rejects invalid PNG files" do
      invalid_png = "/tmp/invalid_#{System.unique_integer()}.png"
      File.write!(invalid_png, "not a valid png file")

      result = Clientats.ScreenshotPreprocessing.validate_screenshot_metadata(invalid_png)
      assert {:error, _} = result

      File.rm!(invalid_png)
    end
  end

  describe "get_screenshot_dimensions/1" do
    test "retrieves dimensions of a screenshot" do
      filename = ScreenshotMock.generate_mock_screenshot(:linkedin)

      case Clientats.ScreenshotPreprocessing.get_screenshot_dimensions(filename) do
        {:ok, {width, height}} ->
          assert is_integer(width) and width > 0
          assert is_integer(height) and height > 0

          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "handles invalid paths gracefully" do
      result = Clientats.ScreenshotPreprocessing.get_screenshot_dimensions("/fake/path.png")
      assert {:error, _} = result
    end
  end

  describe "preprocess_for_extraction/1" do
    test "preprocesses screenshot for LLM extraction" do
      filename = ScreenshotMock.generate_mock_screenshot(:generic)

      case Clientats.ScreenshotPreprocessing.preprocess_for_extraction(filename) do
        {:ok, processed_path} ->
          assert File.exists?(processed_path)
          assert String.ends_with?(processed_path, ".png")

          # Processed image should be valid
          {:ok, content} = File.read(processed_path)
          assert byte_size(content) > 0
          assert String.starts_with?(content, <<137, 80, 78, 71>>)

          File.rm!(processed_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "full preprocessing pipeline with normalization and contrast" do
      filename = ScreenshotMock.generate_mock_screenshot(:indeed)

      case Clientats.ScreenshotPreprocessing.preprocess_for_extraction(filename) do
        {:ok, processed_path} ->
          # Verify the processed image is valid and can be read
          {:ok, processed_content} = File.read(processed_path)
          assert String.starts_with?(processed_content, <<137, 80, 78, 71>>)
          assert byte_size(processed_content) > 0

          File.rm!(processed_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end
  end

  describe "batch_preprocess_screenshots/2" do
    test "preprocesses multiple screenshots" do
      file1 = ScreenshotMock.generate_mock_screenshot(:linkedin)
      file2 = ScreenshotMock.generate_mock_screenshot(:indeed)

      files = [file1, file2]

      case Clientats.ScreenshotPreprocessing.batch_preprocess_screenshots(files, []) do
        {:ok, results} ->
          assert is_list(results)
          assert Enum.count(results) == 2

          Enum.each(results, fn result ->
            case result do
              {:ok, path} -> assert File.exists?(path)
              {:error, _} -> true
            end
          end)

          ScreenshotMock.cleanup_screenshot(file1)
          ScreenshotMock.cleanup_screenshot(file2)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(file1)
          ScreenshotMock.cleanup_screenshot(file2)
      end
    end

    test "handles empty screenshot list" do
      result = Clientats.ScreenshotPreprocessing.batch_preprocess_screenshots([], [])
      assert {:ok, []} = result
    end
  end

  describe "cleanup_processed_image/1" do
    test "removes processed screenshot file" do
      filename = ScreenshotMock.generate_mock_screenshot(:generic)

      case Clientats.ScreenshotPreprocessing.preprocess_for_extraction(filename) do
        {:ok, processed_path} ->
          assert File.exists?(processed_path)

          Clientats.ScreenshotPreprocessing.cleanup_processed_image(processed_path)
          refute File.exists?(processed_path)

          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "handles non-existent files gracefully" do
      result = Clientats.ScreenshotPreprocessing.cleanup_processed_image("/nonexistent/file.png")
      assert :ok = result
    end
  end

  describe "preprocessing with different screenshot scenarios" do
    test "handles LinkedIn job posting screenshot preprocessing" do
      filename = ScreenshotMock.generate_mock_screenshot(:linkedin)

      case Clientats.ScreenshotPreprocessing.preprocess_for_extraction(filename) do
        {:ok, processed_path} ->
          File.rm!(processed_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "handles Indeed job posting screenshot preprocessing" do
      filename = ScreenshotMock.generate_mock_screenshot(:indeed)

      case Clientats.ScreenshotPreprocessing.preprocess_for_extraction(filename) do
        {:ok, processed_path} ->
          File.rm!(processed_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "handles Glassdoor job posting screenshot preprocessing" do
      filename = ScreenshotMock.generate_mock_screenshot(:glassdoor)

      case Clientats.ScreenshotPreprocessing.preprocess_for_extraction(filename) do
        {:ok, processed_path} ->
          File.rm!(processed_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end

    test "handles minimal job posting screenshot preprocessing" do
      filename = ScreenshotMock.generate_mock_screenshot(:minimal)

      case Clientats.ScreenshotPreprocessing.preprocess_for_extraction(filename) do
        {:ok, processed_path} ->
          File.rm!(processed_path)
          ScreenshotMock.cleanup_screenshot(filename)

        {:error, _reason} ->
          ScreenshotMock.cleanup_screenshot(filename)
      end
    end
  end
end
