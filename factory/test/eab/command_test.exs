defmodule Eab.CommandTest do
  use ExUnit.Case, async: true

  test "bounded output preserves head and tail and drains a command" do
    result = Eab.Command.run("sh", ["-c", "printf 'abcdefghijklmnopqrst'"], limit: 10)
    assert result["returncode"] == 0
    assert result["output"] == "abcde\n[output elided]\npqrst"
    assert result["output_truncated"]
  end

  test "nonzero exit status remains explicit" do
    assert Eab.Command.run("sh", ["-c", "exit 7"])["returncode"] == 7
  end

  test "a JSON exchange without a watchdog completes normally" do
    result =
      Eab.Command.exchange(
        "sh",
        ["-c", ~s(printf '{"ready":true}\\n'; read reply)],
        false,
        fn %{"ready" => true}, false -> {%{"continue" => true}, true} end,
        timeout: :infinity
      )

    assert result == %{"returncode" => 0, "state" => true}
  end

  test "owner cancellation terminates its subprocess tree" do
    path = Path.join(System.tmp_dir!(), "eab-child-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)

    worker =
      spawn(fn ->
        Eab.Command.run("sh", ["-c", "echo $$ > #{Eab.Command.quote(path)}; sleep 30"],
          timeout: 40
        )
      end)

    wait_for_file(path, 200)
    pid = File.read!(path) |> String.trim()
    Process.exit(worker, :kill)
    Eab.Command.await_owner(worker)
    {_, status} = System.cmd("kill", ["-0", pid], stderr_to_stdout: true)
    assert status != 0
  end

  test "cancelling a JSON exchange without a watchdog interrupts a blocked callback" do
    parent = self()

    owner =
      spawn(fn ->
        handler = fn frame, state ->
          send(parent, {:callback, self(), frame["pid"]})

          receive do
            :never -> {nil, state}
          end
        end

        Eab.Command.exchange(
          "sh",
          ["-c", ~s(printf '{"pid":%s}\\n' "$$"; read reply)],
          nil,
          handler,
          timeout: :infinity
        )
      end)

    assert_receive {:callback, callback, os_pid}, 3000
    monitor = Process.monitor(callback)
    Process.exit(owner, :kill)
    Eab.Command.await_owner(owner)
    assert_receive {:DOWN, ^monitor, :process, ^callback, :killed}
    {_, status} = System.cmd("kill", ["-0", to_string(os_pid)], stderr_to_stdout: true)
    assert status != 0
  end

  test "a command scope drains nested commands started inside callbacks" do
    parent = self()
    scope = make_ref()

    nested_handler = fn frame, nested ->
      send(parent, {:nested, self(), frame["pid"]})

      receive do
        :never -> {nil, nested}
      end
    end

    handler = fn _, state ->
      Eab.Command.exchange(
        "sh",
        ["-c", ~s(printf '{"pid":%s}\\n' "$$"; read reply)],
        nil,
        nested_handler,
        timeout: 15
      )

      {nil, state}
    end

    owner =
      spawn(fn ->
        Eab.Command.with_scope(scope, fn ->
          Eab.Command.exchange(
            "sh",
            ["-c", ~s(printf '{"ready":true}\\n'; read reply)],
            nil,
            handler,
            timeout: 15
          )
        end)
      end)

    assert_receive {:nested, callback, os_pid}, 3000
    monitor = Process.monitor(callback)
    Process.exit(owner, :kill)
    Eab.Command.await_owner(owner)
    Eab.Command.await_scope(scope)
    assert_receive {:DOWN, ^monitor, :process, ^callback, _}, 3000
    {_, status} = System.cmd("kill", ["-0", to_string(os_pid)], stderr_to_stdout: true)
    assert status != 0
  end

  defp wait_for_file(path, tries) do
    cond do
      File.exists?(path) and File.stat!(path).size > 0 ->
        :ok

      tries == 0 ->
        flunk("Subprocess did not start")

      true ->
        Process.sleep(5)
        wait_for_file(path, tries - 1)
    end
  end
end
