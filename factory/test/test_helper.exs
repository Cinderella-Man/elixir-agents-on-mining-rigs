ExUnit.start(exclude: if(System.get_env("EAB_DOCKER_TESTS") == "1", do: [], else: [:docker]))

# Functional tests use synthetic time; individual timing tests advance this clock explicitly.
Application.put_env(:eab, :measurement_clock, fn -> 0 end)
Code.require_file("support/made_up_tasks.exs", __DIR__)

# The tooling image the Docker tests build from (the Dockerfile's target "tooling"): the bench's tag unless
# EAB_TOOLING_IMAGE names another, for a machine whose Docker also holds the bench's images (factory/README.md,
# section 6, change 10).
defmodule Eab.TestTooling do
  def image, do: System.get_env("EAB_TOOLING_IMAGE", "eab-tooling:dev")
end
