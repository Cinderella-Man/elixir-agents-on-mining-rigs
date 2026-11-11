defmodule Eab.Baseline do
  @moduledoc "Pristine initialized service snapshots shared by attempts and grading."
  alias Eab.{Cache, DatabaseSeed, Inventory, Sandbox, ServiceImages}

  def policy(spec) do
    policy =
      spec["baseline"] ||
        if spec["runtime"]["profile"] == "plausible_ce" do
          %{"mode" => "prepared", "commands" => ["mix ecto.create --quiet", "mix ecto.migrate"]}
        else
          %{"mode" => "prepared", "commands" => []}
        end

    unless policy["mode"] in ["prepared", "fresh"] and
             is_list(policy["commands"] || []) and
             Enum.all?(policy["commands"] || [], &is_binary/1),
           do: raise("Invalid baseline policy")

    Map.put_new(policy, "commands", [])
  end

  def ensure(id, spec, runtime, run_id, emit, opts \\ []) do
    policy = policy(spec)
    engines = runtime["services"]

    if policy["mode"] == "fresh" or map_size(engines) == 0 do
      if policy["commands"] != [],
        do: raise("Service-free/fresh cases cannot cache bootstrap commands")

      Map.put(runtime, "baseline", %{
        "mode" => policy["mode"],
        "id" => Cache.key([runtime["image"], engines, policy])
      })
    else
      inputs = inputs(runtime, policy)

      {artifact, status} =
        Cache.fetch(
          "databases",
          inputs,
          fn reason ->
            emit.("Preparing pristine database baseline for #{id}: #{reason}")
            prepare(id, spec, runtime, run_id, inputs, emit, opts)
          end,
          opts
        )

      if status == :reused,
        do: emit.("Reusing pristine database baseline for #{id}; no migrations to apply")

      runtime
      |> Map.put("services", artifact["services"])
      |> Map.put("service_engines", engines)
      |> Map.put("baseline", %{
        "mode" => "prepared",
        "id" => Cache.key([runtime["image"], inputs]),
        "database" => Cache.key(inputs)
      })
    end
  end

  def inputs(runtime, policy) do
    %{
      "version" => 1,
      "engines" => runtime["services"],
      "layout" => ServiceImages.layout_identity(),
      "capture" => Inventory.hash_file(Inventory.path("lib/eab/service_images.ex")),
      "toolchain" => runtime["toolchain_image"],
      "policy" => policy,
      "database" => runtime["database_inputs"] || %{"project" => runtime["image"]}
    }
  end

  def seed(inputs, opts \\ []) do
    Cache.records("databases")
    |> Enum.filter(fn record ->
      candidate = record["inputs"]

      Map.drop(candidate, ["database"]) == Map.drop(inputs, ["database"]) and
        DatabaseSeed.compatible?(candidate["database"], inputs["database"])
    end)
    |> Enum.sort_by(&DatabaseSeed.migration_count(&1["inputs"]["database"]), :desc)
    |> Enum.find(fn record -> match?({:ok, _}, Cache.lookup("databases", record["id"], opts)) end)
  end

  defp prepare(id, spec, runtime, run_id, inputs, emit, opts) do
    seed = seed(inputs, opts)

    {services, depth} =
      if seed do
        emit.(
          "Seeding #{id} from database baseline #{seed["id"]}; applying only missing migrations"
        )

        artifact = seed["artifact"]

        if artifact["depth"] >= 8 do
          emit.("Sealing a shallow database checkpoint before extending its migration history")

          {Map.new(artifact["services"], fn {name, image} ->
             {name, ServiceImages.rebase(name, image, inputs["engines"][name])}
           end), 1}
        else
          {artifact["services"], artifact["depth"] + 1}
        end
      else
        emit.("No compatible database seed; initializing this database family once")

        {Map.new(inputs["engines"], fn {name, engine} ->
           {name, ServiceImages.ensure(name, engine)}
         end), 1}
      end

    runtime = Map.put(runtime, "services", services)

    Sandbox.with_runtime(
      id,
      spec,
      runtime,
      run_id,
      fn box ->
        for command <- inputs["policy"]["commands"],
            do: Sandbox.command!(box, command, timeout: 1200, limit: 2_000_000)

        ServiceImages.validate!(box)

        # Publish only after successful bootstrap, validation and both captures.
        captured =
          Map.new(services, fn {name, _} ->
            suffix = if name == "postgres", do: "-db", else: "-ch"
            {name, ServiceImages.capture(name, box.name <> suffix, Cache.key(inputs))}
          end)

        %{
          "services" => captured,
          "images" => Map.values(captured),
          "depth" => depth,
          "seed" => seed && seed["id"],
          "case" => id
        }
      end,
      before_test: false
    )
  end
end
