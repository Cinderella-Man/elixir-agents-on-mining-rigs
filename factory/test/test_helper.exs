ExUnit.start(exclude: if(System.get_env("EAB_DOCKER_TESTS") == "1", do: [], else: [:docker]))

# Functional tests use synthetic time; individual timing tests advance this clock explicitly.
Application.put_env(:eab, :measurement_clock, fn -> 0 end)
Code.require_file("support/made_up_tasks.exs", __DIR__)
