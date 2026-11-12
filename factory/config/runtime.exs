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
    tasks_dir: System.get_env("EAB_TASKS_DIR", "/tasks") |> Path.expand()

  present = fn name -> System.get_env(name) |> then(&if(&1 not in [nil, ""], do: &1)) end

  # Memory collection is on unless EAB_MEMORY=off. Without a target it reaches root on the
  # model endpoint's own host; without a host list it samples only that host.
  if System.get_env("EAB_MEMORY") not in ["off", "0", "false"] do
    config :eab, :memory_monitor,
      target: present.("EAB_MEMORY_SSH_TARGET"),
      hosts:
        if(hosts = present.("EAB_MEMORY_HOSTS"),
          do: hosts |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
        ),
      known_hosts:
        System.get_env("EAB_MEMORY_KNOWN_HOSTS", Path.join(data, "memory/known_hosts")),
      ssh_key: System.get_env("EAB_MEMORY_SSH_KEY") |> then(&if(&1 not in [nil, ""], do: &1)),
      collector:
        System.get_env(
          "EAB_MEMORY_REMOTE_COLLECTOR",
          "/srv/elixir-agent-benchmark/memory-collector/bin/eab_memory_collector"
        ),
      key_file: System.get_env("EAB_MEMORY_REMOTE_KEY_FILE")
  end

  config :eab, :pipeline,
    lookahead: String.to_integer(System.get_env("EAB_PREPARE_AHEAD", "4")),
    preparation_workers: String.to_integer(System.get_env("EAB_PREPARE_WORKERS", "2"))
end
