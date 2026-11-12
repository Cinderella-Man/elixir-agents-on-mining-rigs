# t0_formatter.exs: an ExUnit formatter that writes one tab-separated line per test to the file named by T0_RESULTS:
# the test file, the module, the test's name, its state (passed, failed, skipped, excluded, invalid) and the first
# 400 characters of the reason. A module whose setup_all fails gets one line with the state module_failed. Loaded
# with `elixir -r t0_formatter.exs -S mix test ... --formatter ExUnit.CLIFormatter --formatter T0Formatter`, so the
# engine's own output stays as it is.
defmodule T0Formatter do
  use GenServer

  @impl true
  def init(_opts) do
    path = System.fetch_env!("T0_RESULTS")
    {:ok, io} = File.open(path, [:write, :utf8])
    {:ok, io}
  end

  @impl true
  def handle_cast({:test_finished, %ExUnit.Test{} = test}, io) do
    {state, reason} = describe(test.state)
    write(io, [file(test.tags[:file]), inspect(test.module), to_string(test.name), state, reason])
    {:noreply, io}
  end

  def handle_cast({:module_finished, %ExUnit.TestModule{state: {:failed, failures}} = module}, io) do
    write(io, [file(Map.get(module, :file)), inspect(module.name), "(setup_all)", "module_failed", reason(failures)])
    {:noreply, io}
  end

  def handle_cast(_event, io), do: {:noreply, io}

  defp describe(nil), do: {"passed", ""}
  defp describe({:failed, failures}), do: {"failed", reason(failures)}
  defp describe({:skipped, why}), do: {"skipped", to_string(why)}
  defp describe({:excluded, why}), do: {"excluded", to_string(why)}
  defp describe({:invalid, _module}), do: {"invalid", "setup_all failed"}

  defp reason(failures) do
    failures
    |> Enum.map_join(" || ", fn {kind, reason, stack} -> Exception.format_banner(kind, reason, stack) end)
    |> String.slice(0, 400)
  end

  defp file(nil), do: ""
  defp file(path), do: Path.relative_to(path, File.cwd!())

  defp write(io, fields) do
    line = Enum.map_join(fields, "\t", &(&1 |> to_string() |> String.replace(~r/\s+/u, " ")))
    IO.write(io, line <> "\n")
  end
end
