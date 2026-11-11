defmodule Eab.Source do
  @moduledoc "Pristine source snapshots cached by repository and exact revision."
  alias Eab.{Cache, Command, Inventory, Store}

  def snapshot(repo, source, emit, opts \\ []) do
    key = Inventory.hash(Jason.encode!([repo["url"], repo["revision"]]))
    Cache.locked({:source, key}, fn -> export(repo, source, emit, key, opts) end)
  end

  defp export(repo, source, emit, key, opts) do
    archive = Store.path("sources/#{key}.tar")
    receipt_path = "sources/#{key}.json"
    receipt = Store.read(receipt_path)

    if File.regular?(archive) and receipt do
      unless receipt["version"] == 1 and receipt["repository"] == repo and
               receipt["archive_hash"] == Inventory.hash_file(archive),
             do: raise("Cached source archive failed its integrity check")

      verify_tree!(receipt["tree"], opts[:expected_tree])
      emit.("Reusing source snapshot at #{repo["revision"]}")
      Command.run!("tar", ["-xf", archive, "-C", source])
      receipt
    else
      Command.run!("git", ["init", "--quiet", source])

      Command.run!("git", ["fetch", "--quiet", "--depth=1", repo["url"], repo["revision"]],
        cd: source
      )

      Command.run!("git", ["checkout", "--quiet", "--detach", "FETCH_HEAD"], cd: source)

      unless String.trim(Command.run!("git", ["rev-parse", "HEAD"], cd: source)) ==
               repo["revision"],
             do: raise("Fetched source revision does not match the case")

      tree = String.trim(Command.run!("git", ["rev-parse", "HEAD^{tree}"], cd: source))
      verify_tree!(tree, opts[:expected_tree])
      listing = Command.run("git", ["ls-files", "--stage"], cd: source, limit: 4_000_000)

      unless listing["returncode"] == 0 and not listing["output_truncated"],
        do: raise("Source file inventory could not be verified")

      files = listing["output"]

      if Regex.match?(~r/^160000 /m, files),
        do: raise("Submodule sources require an explicit export contract")

      File.mkdir_p!(Path.dirname(archive))
      File.chmod!(Path.dirname(archive), 0o700)
      temp = archive <> ".#{System.unique_integer([:positive])}.tmp"

      try do
        File.rm_rf!(Path.join(source, ".git"))
        Command.run!("tar", ["-cf", temp, "-C", source, "."])
        File.chmod!(temp, 0o600)
        File.rename!(temp, archive)

        receipt = %{
          "version" => 1,
          "repository" => repo,
          "tree" => tree,
          "archive_hash" => Inventory.hash_file(archive)
        }

        Store.write(receipt_path, receipt)
        receipt
      after
        File.rm(temp)
      end
    end
  end

  defp verify_tree!(tree, expected) do
    unless is_binary(tree) and Regex.match?(~r/^[a-f0-9]{40}$/, tree) and
             (is_nil(expected) or tree == expected),
           do: raise("Exported source tree does not match recorded provenance")
  end
end
