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
    cpu_shares:
      (case String.trim(System.get_env("EAB_CPU_SHARES", "")) do
         "" -> nil
         shares -> String.to_integer(shares)
       end)

  config :eab, :pipeline,
    lookahead: String.to_integer(System.get_env("EAB_PREPARE_AHEAD", "4")),
    preparation_workers: String.to_integer(System.get_env("EAB_PREPARE_WORKERS", "2"))
end
