# Evaluated inside the controller (controller.sh rpc), in a process of its own. Runs the project's own tests at the
# prepared starting commit through the engine's own runner (Eab.Grader.run_tests/3, the reporter installed by
# Eab.TestAdapter.install/1), ROUNDS times, each in a fresh workspace container and a fresh copy of the database.
# P3_DIR: the folder with probe/<id>/; P3_COMMAND: the test command (default "mix test"); P3_TAG: a name for the
# output files; P3_STUB_FWUP=1: the diagnostic stand-in for fwup below. Writes P3_DIR/<tag>_round<n>.json (one row per test) and .txt (the raw output), then
# P3_DIR/<tag>.done.
dir = System.get_env("P3_DIR", "/data/p3")
id = System.get_env("P3_ID", "flick-probe-pr-341")
command = System.get_env("P3_COMMAND", "mix test")
tag = System.get_env("P3_TAG", "tests")
rounds = String.to_integer(System.get_env("P3_ROUNDS", "2"))
run_id = "p3-" <> id
{:ok, log} = File.open(Path.join(dir, "#{tag}.log"), [:append, :utf8])
emit = fn msg -> IO.puts(log, "#{DateTime.utc_now() |> DateTime.to_iso8601()} #{msg}") end

status =
  try do
    Eab.Inventory.with_case(id, Path.join([dir, "probe", id]), fn ->
      for round <- 1..rounds do
        Eab.Sandbox.with_box(id, run_id, fn box ->
          Eab.TestAdapter.install(box)

          # Diagnostic only (P3_STUB_FWUP=1): a stand-in `fwup` in the agent's ~/.local/bin, which a login shell puts
          # on PATH. It answers `fwup --version` (the application refuses to start without it) and fails every other
          # call, so the suite can boot and the tests that need the real fwup fail visibly. Never part of a recipe.
          if System.get_env("P3_STUB_FWUP") == "1" do
            stub =
              "mkdir -p ~/.local/bin && printf '%s\\n' '#!/bin/sh' " <>
                "'if [ \"$1\" = --version ]; then echo 0.0.0-stub; exit 0; fi' " <>
                "'echo \"fwup stub: not installed\" >&2; exit 1' > ~/.local/bin/fwup && " <>
                "chmod +x ~/.local/bin/fwup && bash -lc 'command -v fwup && fwup --version'"

            emit.("stub fwup: " <> inspect(Eab.Sandbox.command(box, stub)))
          end

          t0 = System.monotonic_time(:millisecond)
          result = Eab.Grader.run_tests(box, command)
          ms = System.monotonic_time(:millisecond) - t0
          counts = result["test_results"] |> Map.values() |> Enum.frequencies()

          emit.(
            "round #{round}: #{ms} ms, returncode #{result["returncode"]}, completed #{result["completed"]}, " <>
              "passed #{result["passed"]}, #{inspect(counts)}"
          )

          File.write!(Path.join(dir, "#{tag}_round#{round}.txt"), result["output"])

          File.write!(
            Path.join(dir, "#{tag}_round#{round}.json"),
            Jason.encode!(
              %{
                "command" => command,
                "ms" => ms,
                "returncode" => result["returncode"],
                "completed" => result["completed"],
                "passed" => result["passed"],
                "counts" => counts,
                "tests" => result["test_results"],
                "failure_phases" => result["failure_phases"],
                "exclusion_tags" => result["exclusion_tags"]
              },
              pretty: true
            )
          )
        end)
      end
    end)

    "ok"
  rescue
    error ->
      emit.("ERROR " <> Exception.format(:error, error, __STACKTRACE__))
      "error"
  after
    Eab.Sandbox.cleanup(run_id)
  end

File.close(log)
File.write!(Path.join(dir, "#{tag}.done"), status <> "\n")
