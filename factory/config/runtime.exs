import Config

if config_env() != :test do
  data = System.get_env("EAB_DATA_DIR", ".local/app") |> Path.expand()
  File.mkdir_p!(data)
  File.chmod!(data, 0o700)

  config :eab,
    data_dir: data,
    offline: System.get_env("EAB_OFFLINE") in ["1", "true"],
    cache_reserve_bytes:
      String.to_integer(System.get_env("EAB_CACHE_MIN_FREE_GB", "5")) * 1024 * 1024 * 1024,
    docker_storage_path: System.get_env("EAB_DOCKER_STORAGE_PATH"),
    root: System.get_env("EAB_ROOT", File.cwd!()),
    # The task folder, mounted into the controller (factory/README.md, section 6, change 2).
    tasks_dir: System.get_env("EAB_TASKS_DIR", "/tasks") |> Path.expand(),
    # The installation's labels and CPU share on every container and image the engine makes
    # (factory/README.md, section 6, change 1; lib/eab/docker_settings.ex). Unset, nothing is added.
    docker_labels:
      String.split(System.get_env("EAB_DOCKER_LABELS", ""), [",", " ", "\t", "\n"], trim: true),
    # The hosts a task's release files may come from (factory/README.md, section 6, change 3; lib/eab/release_files.ex),
    # a comma or space separated list. Empty by default: no release file is fetched.
    release_file_hosts:
      System.get_env("EAB_RELEASE_FILE_HOSTS", "")
      |> String.downcase()
      |> String.split([",", " ", "\t", "\n"], trim: true),
    # A JSON file from a repository's URL to its mirror's URL (section 6, change 4; lib/eab/source.ex). Unset: no mirror.
    mirrors_file: System.get_env("EAB_MIRRORS"),
    # The BuildKit cache id for Hex packages in the workspace recipe (section 6, change 10; lib/eab/docker_settings.ex).
    # Unset: the bench's id. A machine whose Docker also builds the bench's images sets one of its own.
    hex_cache_id: System.get_env("EAB_HEX_CACHE_ID"),
    cpu_shares:
      (case String.trim(System.get_env("EAB_CPU_SHARES", "")) do
         "" -> nil
         shares -> String.to_integer(shares)
       end)

  config :eab, :pipeline,
    lookahead: String.to_integer(System.get_env("EAB_PREPARE_AHEAD", "4")),
    preparation_workers: String.to_integer(System.get_env("EAB_PREPARE_WORKERS", "2"))
end
