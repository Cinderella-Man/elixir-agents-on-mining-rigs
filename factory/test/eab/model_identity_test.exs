defmodule Eab.ModelIdentityTest do
  # Written for the factory with made-up values: no model folder, host or address here names a real one.
  use ExUnit.Case, async: false
  alias Eab.ModelIdentity

  @weights "/opt/example-weights"

  test "discovery names the served weight file and its size, and keeps the server's alias for requests" do
    Application.put_env(:eab, :http_request, fn opts ->
      body =
        case URI.parse(opts[:url]).path do
          "/health" ->
            %{"status" => "ok"}

          "/v1/models" ->
            %{
              "data" => [
                %{
                  "id" => "widget-alias",
                  "meta" => %{"size" => 5_368_709_120, "n_params" => 7_241_732_096}
                }
              ]
            }

          "/props" ->
            %{
              "model_alias" => "widget-alias",
              "model_path" => "#{@weights}/Widget-7B-Instruct-Q5_K_M.gguf",
              "default_generation_settings" => %{"n_ctx" => 32_768}
            }
        end

      {:ok, %{status: 200, body: body}}
    end)

    on_exit(fn -> Application.delete_env(:eab, :http_request) end)
    endpoint = Eab.Model.discover("http://model.invalid:8080/v1/")

    assert endpoint["url"] == "http://model.invalid:8080"
    assert endpoint["backend"] == "llama_cpp"
    assert endpoint["model"] == "widget-alias"
    assert endpoint["context"] == 32_768

    assert endpoint["identity"] == %{
             "version" => 1,
             "name" => "Widget-7B-Instruct",
             "quantization" => "Q5_K_M",
             "artifact" => "Widget-7B-Instruct-Q5_K_M.gguf",
             "source" => "reported_artifact",
             "size_bytes" => 5_368_709_120,
             "parameter_count" => 7_241_732_096
           }

    assert ModelIdentity.label(endpoint) == "Widget-7B-Instruct · Q5_K_M"
    assert ModelIdentity.size_label(endpoint) == "5.4 GB"
  end

  test "a shard suffix is not part of the name, and a size nobody reported stays unknown" do
    endpoint = %{
      "backend" => "llama_cpp",
      "model" => "widget-moe",
      "profile" => %{"model_path" => "#{@weights}/Widget-30B-A3B-UD-IQ2_XXS-00002-of-00003.gguf"}
    }

    identity = ModelIdentity.details(endpoint)
    assert identity["name"] == "Widget-30B-A3B"
    assert identity["quantization"] == "UD-IQ2_XXS"
    assert identity["artifact"] == "Widget-30B-A3B-UD-IQ2_XXS-00002-of-00003.gguf"
    assert identity["size_bytes"] == nil
    assert identity["parameter_count"] == nil
    assert ModelIdentity.label(endpoint) == "Widget-30B-A3B · UD-IQ2_XXS"
    assert ModelIdentity.size_label(endpoint) == "Not reported"
  end

  test "without a weight file the name falls back to reported metadata, then to the alias" do
    assert %{"name" => "plain-widget", "quantization" => nil, "artifact" => nil} =
             ModelIdentity.details(%{"model" => "plain-widget"})

    assert ModelIdentity.details(%{"model" => "plain-widget"})["source"] == "reported_name"
    assert ModelIdentity.label(%{"model" => "plain-widget"}) == "plain-widget"

    generic = %{
      "model" => "widget-alias",
      "profile" => %{"model_path" => "#{@weights}/model.gguf", "model_ftype" => "Q4_K - Medium"},
      "metadata" => %{
        "props" => %{"model_name" => "Widget Small", "model_size_bytes" => 2_100_000_000}
      }
    }

    identity = ModelIdentity.details(generic)
    assert identity["name"] == "Widget Small"
    assert identity["quantization"] == "Q4_K_M"
    assert identity["artifact"] == "model.gguf"
    assert identity["size_bytes"] == 2_100_000_000

    named =
      generic
      |> put_in(["metadata", "model"], %{"meta" => %{"name" => "Widget Small Instruct"}})

    assert ModelIdentity.details(named)["name"] == "Widget Small Instruct"
    assert ModelIdentity.details(%{})["name"] == "Unknown model"
    assert ModelIdentity.details("not an endpoint")["name"] == "Unknown model"
  end

  test "a reported file type is normalized only when the file name carries none" do
    for {ftype, quant} <- [
          {"Q4_K - Medium", "Q4_K_M"},
          {"q3_k - small", "Q3_K_S"},
          {"Q3_K - Large", "Q3_K_L"},
          {"BF16", "BF16"},
          {"  ", nil},
          {nil, nil}
        ] do
      assert ModelIdentity.details(%{"model" => "w", "profile" => %{"model_ftype" => ftype}})[
               "quantization"
             ] == quant
    end

    endpoint = %{
      "model" => "w",
      "profile" => %{"model_path" => "#{@weights}/Widget-3B-f16.gguf", "model_ftype" => "Q8_0"}
    }

    assert ModelIdentity.details(endpoint)["quantization"] == "F16"
    assert ModelIdentity.details(endpoint)["name"] == "Widget-3B"
  end

  test "sizes and parameter counts are recorded only when they are positive integers" do
    for value <- [0, -1, 1.5, "2000"] do
      endpoint = %{
        "model" => "w",
        "metadata" => %{"model" => %{"meta" => %{"size" => value, "n_params" => value}}}
      }

      assert ModelIdentity.details(endpoint)["size_bytes"] == nil
      assert ModelIdentity.details(endpoint)["parameter_count"] == nil
    end
  end

  test "a Strata pack folder is not a model name; the alias stands until a weight file names it" do
    endpoint = %{
      "backend" => "strata",
      "model" => "widget-pack-alias",
      "profile" => %{"model_path" => "#{@weights}/widget-pack"}
    }

    assert ModelIdentity.served_artifact(endpoint) == "widget-pack"
    assert ModelIdentity.folder?("widget-pack")
    refute ModelIdentity.folder?("widget.gguf")
    refute ModelIdentity.folder?(nil)

    identity = ModelIdentity.details(endpoint)
    assert identity["name"] == "widget-pack-alias"
    assert identity["artifact"] == nil
    assert identity["source"] == "reported_name"

    # An identity saved before pack folders were recognised named the model after the folder.
    stale = %{"version" => 1, "name" => "widget-pack", "artifact" => "widget-pack"}
    assert ModelIdentity.label(Map.put(endpoint, "identity", stale)) == "widget-pack-alias"

    # A saved identity that names a weight file, or one from another back end, is kept as saved.
    saved = %{"version" => 1, "name" => "Saved Widget", "artifact" => "Widget-7B-Q8_0.gguf"}
    assert ModelIdentity.details(Map.put(endpoint, "identity", saved)) == saved

    assert ModelIdentity.details(%{"backend" => "other", "identity" => stale}) == stale

    props = %{"metadata" => %{"props" => %{"model_path" => "#{@weights}/Widget-1B-Q6_K.gguf"}}}
    assert ModelIdentity.served_artifact(props) == "Widget-1B-Q6_K.gguf"
    assert ModelIdentity.served_artifact(%{"profile" => %{"model_path" => " "}}) == nil
  end

  test "the weight files found on the model host name the model" do
    files = %{
      "files" => [%{"name" => "Widget-7B-Q8_0.gguf"}, %{"name" => "Widget-7B-mmproj.gguf"}]
    }

    assert ModelIdentity.from_files(files) == %{
             "version" => 1,
             "name" => "Widget-7B",
             "quantization" => "Q8_0",
             "artifact" => "Widget-7B-Q8_0.gguf",
             "source" => "host_files",
             "size_bytes" => nil,
             "parameter_count" => nil
           }

    assert ModelIdentity.from_files(nil) == nil
    assert ModelIdentity.from_files(%{"files" => []}) == nil
  end

  test "attach stores the identity beside the endpoint it describes" do
    endpoint = %{
      "model" => "w",
      "profile" => %{"model_path" => "#{@weights}/Widget-1B-Q6_K.gguf"}
    }

    attached = ModelIdentity.attach(endpoint)

    assert Map.delete(attached, "identity") == endpoint
    assert attached["identity"] == ModelIdentity.details(endpoint)
    assert ModelIdentity.attach(nil)["identity"]["name"] == "Unknown model"
  end
end
