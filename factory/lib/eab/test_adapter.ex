defmodule Eab.TestAdapter do
  @moduledoc "Controller-owned test reporters for ExUnit and Node's test runner."
  alias Eab.{Command, Grader, Inventory, Sandbox}

  def install(box) do
    Sandbox.formatter(box)

    Sandbox.copy_file(
      box,
      Inventory.path("priv/fixtures/node_runner.mjs"),
      "/opt/eab-grade/node_runner.mjs"
    )
  end

  def command("exunit", command, extra), do: Grader.test_command(command, extra)

  def command("node", command, extra) do
    case OptionParser.split(command) do
      ["node", "--test" | files] when files != [] ->
        files = Enum.uniq(files ++ extra)

        unless Enum.all?(files, fn path ->
                 not String.starts_with?(path, ["-", "/"]) and
                   not Enum.any?(Path.split(path), &(&1 in ["..", ".git"])) and
                   Path.extname(path) in [".js", ".mjs", ".cjs"] and
                   not String.contains?(path, ["*", "?", "["])
               end),
               do:
                 raise(
                   "Node grading requires explicit JavaScript test files, without flags or globs"
                 )

        "node /opt/eab-grade/node_runner.mjs " <> Enum.map_join(files, " ", &Command.quote/1)

      _ ->
        raise "Node grading requires an explicit node --test command"
    end
  end

  def selected("exunit", files), do: "mix test " <> Enum.map_join(files, " ", &Command.quote/1)
  def selected("node", files), do: "node --test " <> Enum.map_join(files, " ", &Command.quote/1)
end
