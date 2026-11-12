import Config
config :eab, data_dir: System.get_env("EAB_DATA_DIR", ".local/app"), root: File.cwd!()

config :logger, :console, format: "$level $message\n"
config :logger, level: :info

if config_env() == :test do
  config :eab,
    cache_reserve_bytes: 0,
    data_dir: Path.join(System.tmp_dir!(), "eab-tests-#{System.pid()}")

  config :logger, level: :warning
end
