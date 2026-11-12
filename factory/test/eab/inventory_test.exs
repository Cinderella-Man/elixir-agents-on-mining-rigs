defmodule Eab.InventoryTest do
  use ExUnit.Case, async: false
  alias Eab.{Cache, Inventory, Release}

  # The inventory is the task folder (EAB_TASKS_DIR), not a list in the configuration
  # (factory/README.md, section 6, change 2).
  setup do
    original_root = Inventory.root()
    original_tasks = Application.fetch_env!(:eab, :tasks_dir)
    root = Path.join(System.tmp_dir!(), "eab-inventory-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "config"))
    File.mkdir_p!(Path.join(root, "tasks"))
    File.mkdir_p!(Path.join(root, "tasks_parked"))

    for relative <- ["lib", "priv", "mix.lock"] do
      File.ln_s!(Path.join(original_root, relative), Path.join(root, relative))
    end

    # A list of cases in the configuration is ignored: the folder decides.
    File.write!(
      Path.join(root, "config/factory.json"),
      Jason.encode!(%{"id" => "test", "cases" => ["listed-case"], "defaults" => %{}})
    )

    Application.put_env(:eab, :root, root)
    Application.put_env(:eab, :tasks_dir, Path.join(root, "tasks"))

    on_exit(fn ->
      Application.put_env(:eab, :root, original_root)
      Application.put_env(:eab, :tasks_dir, original_tasks)
      File.rm_rf!(root)
    end)

    %{root: root}
  end

  test "moving folders out and back restores the same release without config edits", %{root: root} do
    for id <- ["existing-case", "new-case"] do
      File.mkdir_p!(Path.join(Inventory.tasks_dir(), id))
      File.write!(Inventory.case_path(id, "case.json"), Jason.encode!(%{"id" => id}))
    end

    assert Inventory.all() == ["existing-case", "new-case"]
    protocol = Inventory.protocol(Inventory.all())
    release = %{"id" => Cache.key(protocol), "protocol" => protocol}
    config = File.read!(Inventory.path("config/factory.json"))
    assert :ok = Release.verify!(release)

    for id <- Inventory.all() do
      File.rename!(Path.join(Inventory.tasks_dir(), id), Path.join(root, "tasks_parked/#{id}"))
    end

    assert Inventory.all() == []
    assert_raise RuntimeError, ~r/cases or agent changed/, fn -> Release.verify!(release) end

    assert_raise RuntimeError, ~r/Invalid release case inventory/, fn ->
      Release.freeze(Inventory.all())
    end

    assert_raise RuntimeError, ~r/Unknown task: new-case/, fn -> Release.freeze(["new-case"]) end

    for id <- ["existing-case", "new-case"] do
      File.rename!(Path.join(root, "tasks_parked/#{id}"), Path.join(Inventory.tasks_dir(), id))
    end

    assert Inventory.all() == ["existing-case", "new-case"]
    assert Inventory.protocol(Inventory.all()) == protocol
    assert :ok = Release.verify!(release)
    assert File.read!(Inventory.path("config/factory.json")) == config
  end

  test "only direct case folders containing manifests are discovered" do
    File.mkdir_p!(Path.join(Inventory.tasks_dir(), "unfinished"))
    File.write!(Path.join(Inventory.tasks_dir(), "README.md"), "Ignored")
    File.mkdir_p!(Inventory.path("tasks_parked/parked-case"))
    File.write!(Inventory.path("tasks_parked/parked-case/case.json"), "{}")
    File.mkdir_p!(Path.join(Inventory.tasks_dir(), "nested/deeper-case"))
    File.write!(Path.join(Inventory.tasks_dir(), "nested/deeper-case/case.json"), "{}")
    assert Inventory.all() == []
    refute Inventory.member?("parked-case")
    refute Inventory.member?("deeper-case")
  end

  test "the inventory is the task folder, in the order of its ids, and nothing else" do
    for id <- ["zeta-pr-1", "alpha-pr-10", "alpha-pr-2"] do
      File.mkdir_p!(Path.join(Inventory.tasks_dir(), id))
      File.write!(Inventory.case_path(id, "case.json"), Jason.encode!(%{"id" => id}))
    end

    assert Inventory.all() == ["alpha-pr-10", "alpha-pr-2", "zeta-pr-1"]
    assert Inventory.definition()["cases"] == Inventory.all()
    refute Map.has_key?(Inventory.config(), "cases")
    assert Inventory.member?("alpha-pr-2")
    refute Inventory.member?("listed-case")
    refute Inventory.member?("../tasks_parked")
    assert Inventory.spec("zeta-pr-1") == %{"id" => "zeta-pr-1"}
    assert_raise ArgumentError, fn -> Inventory.spec("listed-case") end

    assert Inventory.case_path("zeta-pr-1", "case.json") ==
             Path.join([Inventory.tasks_dir(), "zeta-pr-1", "case.json"])

    # A protocol binds only the tasks it is given.
    protocol = Inventory.protocol(["alpha-pr-2"])
    assert protocol["inventory"]["cases"] == ["alpha-pr-2"]
    assert Map.keys(protocol["fixtures"]) == ["alpha-pr-2"]
    assert protocol["inventory"]["id"] == "test"

    # Another folder is another inventory, with no rebuild and no configuration edit.
    other = Path.join(Inventory.path("tasks_parked"), "other")
    File.mkdir_p!(Path.join(other, "beta-pr-1"))
    File.write!(Path.join(other, "beta-pr-1/case.json"), Jason.encode!(%{"id" => "beta-pr-1"}))
    Application.put_env(:eab, :tasks_dir, other)
    assert Inventory.all() == ["beta-pr-1"]
  end
end
