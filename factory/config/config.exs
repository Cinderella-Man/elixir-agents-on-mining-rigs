import Config

config :eab,
  data_dir: System.get_env("EAB_DATA_DIR", ".local/app"),
  root: File.cwd!(),
  tasks_dir: System.get_env("EAB_TASKS_DIR", "/tasks")

config :logger, :console, format: "$level $message\n"
config :logger, level: :info

if config_env() == :test do
  config :eab,
    cache_reserve_bytes: 0,
    data_dir: Path.join(System.tmp_dir!(), "eab-tests-#{System.pid()}"),
    # Empty unless a test mounts a task folder of made-up tasks (test/support/made_up_tasks.exs).
    tasks_dir: Path.join(System.tmp_dir!(), "eab-tests-tasks-#{System.pid()}")

  config :logger, level: :warning
end
