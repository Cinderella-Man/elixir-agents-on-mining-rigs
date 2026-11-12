defmodule Eab.DockerSettings do
  @moduledoc """
  The installation's own labels and CPU share (factory/README.md, section 6, change 1).

  `EAB_DOCKER_LABELS` is a list of `key=value` separated by commas or white space; each label goes on every container
  the engine starts and on every image it builds. `EAB_CPU_SHARES` is a number, the weight of every container the
  engine starts when the machine's CPUs are busy; it does not change any container's `--cpus` limit. Both are read
  in `config/runtime.exs`. Unset, they add no argument, so the engine's `docker run` and build arguments are the
  bench's.
  """

  @doc "The labels, as `key=value` texts."
  def labels do
    labels = Application.get_env(:eab, :docker_labels) || []

    for label <- labels do
      unless is_binary(label) and Regex.match?(~r/\A[^=\s,]+=[^\s,]*\z/, label),
        do:
          raise(
            ArgumentError,
            "EAB_DOCKER_LABELS holds an entry that is not key=value: #{inspect(label)}"
          )

      label
    end
  end

  @doc "The CPU share, or nil when unset."
  def cpu_shares do
    case Application.get_env(:eab, :cpu_shares) do
      nil ->
        nil

      shares when is_integer(shares) and shares >= 2 ->
        shares

      other ->
        raise ArgumentError,
              "EAB_CPU_SHARES must be a whole number of at least 2: #{inspect(other)}"
    end
  end

  @doc "The arguments added to each `docker run`: the labels, then the CPU share."
  def run_args do
    Enum.flat_map(labels(), &["--label", &1]) ++
      case cpu_shares() do
        nil -> []
        shares -> ["--cpu-shares", Integer.to_string(shares)]
      end
  end

  @doc "The arguments added to each image build: the labels."
  def build_args, do: Enum.flat_map(labels(), &["--label", &1])

  @bench_hex_cache_id "eab-hex-packages-v1"

  @doc """
  The id of the BuildKit cache that keeps Hex packages between workspace builds (`EAB_HEX_CACHE_ID`, section 6,
  change 10). Unset or empty, the bench's own id, so the workspace recipe is the bench's byte for byte. A machine whose
  Docker also builds the bench's images sets an id of its own, so the two installations never share that cache.
  """
  def hex_cache_id do
    case Application.get_env(:eab, :hex_cache_id) do
      blank when blank in [nil, ""] ->
        @bench_hex_cache_id

      id when is_binary(id) ->
        unless Regex.match?(~r/\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/, id),
          do:
            raise(
              ArgumentError,
              "EAB_HEX_CACHE_ID must be letters, digits, '.', '_' or '-' (at most 128): #{inspect(id)}"
            )

        id

      other ->
        raise ArgumentError, "EAB_HEX_CACHE_ID must be a text: #{inspect(other)}"
    end
  end
end
