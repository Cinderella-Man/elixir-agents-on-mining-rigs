defmodule Eab.BaselineTest do
  use ExUnit.Case, async: false
  alias Eab.{Baseline, Cache, Store}

  setup do
    previous = Store.root()
    root = Path.join(System.tmp_dir!(), "eab-baseline-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)

    on_exit(fn ->
      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
    end)

    runtime = %{
      "image" => "project",
      "toolchain_image" => "tools",
      "services" => %{"postgres" => "pg-engine", "clickhouse" => "ch-engine"},
      "database_inputs" => %{
        "version" => 1,
        "migrations" => %{"postgres" => [], "clickhouse" => []}
      }
    }

    %{runtime: runtime, opts: [image_exists?: fn _ -> true end]}
  end

  test "exact database hits serve different projects without bootstrap or service startup", %{
    runtime: runtime,
    opts: opts
  } do
    spec = %{"runtime" => %{"profile" => "plausible_ce"}}
    inputs = Baseline.inputs(runtime, Baseline.policy(spec))
    services = %{"postgres" => "pg-snapshot", "clickhouse" => "ch-snapshot"}

    Cache.fetch(
      "databases",
      inputs,
      fn _ ->
        %{"services" => services, "images" => Map.values(services), "depth" => 1}
      end,
      opts
    )

    parent = self()

    for project <- ["project", "different-project"] do
      result =
        Baseline.ensure(
          "case",
          spec,
          Map.put(runtime, "image", project),
          "run",
          &send(parent, &1),
          opts
        )

      assert result["image"] == project
      assert result["services"] == services
      assert result["baseline"]["database"] == Cache.key(inputs)
      assert_receive "Reusing pristine database baseline for case; no migrations to apply"
    end

    refute File.exists?(Store.path("build"))
  end

  test "seed selection respects engine, toolchain, history and physical availability", %{
    runtime: runtime,
    opts: opts
  } do
    inputs = Baseline.inputs(runtime, %{"mode" => "prepared", "commands" => []})

    Cache.fetch(
      "databases",
      inputs,
      fn _ ->
        %{"services" => %{"postgres" => "saved"}, "images" => ["saved"], "depth" => 1}
      end,
      opts
    )

    assert Baseline.seed(inputs, opts)["id"] == Cache.key(inputs)
    assert Baseline.seed(Map.put(inputs, "engines", %{"postgres" => "new"}), opts) == nil
    assert Baseline.seed(Map.put(inputs, "toolchain", "new"), opts) == nil
    assert Baseline.seed(inputs, image_exists?: fn _ -> false end) == nil
  end

  test "migration tasks explicitly retain fresh setup and service-free cases skip database records",
       %{runtime: runtime} do
    spec = %{"runtime" => %{}, "baseline" => %{"mode" => "fresh"}}

    result =
      Baseline.ensure("case", spec, runtime, "run", fn _ -> flunk("unexpected preparation") end)

    assert result["services"] == runtime["services"]
    assert result["baseline"]["mode"] == "fresh"
    assert Cache.records("databases") == []

    result =
      Baseline.ensure(
        "case",
        %{"runtime" => %{}},
        Map.put(runtime, "services", %{}),
        "run",
        fn _ -> :ok end
      )

    assert result["baseline"]["mode"] == "prepared"
    assert Cache.records("databases") == []
  end
end
