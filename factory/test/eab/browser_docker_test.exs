defmodule Eab.BrowserDockerTest do
  use ExUnit.Case, async: false
  @moduletag :docker
  @moduletag timeout: 300_000
  alias Eab.{Browser, Command, Grader, Sandbox, Store, TestAdapter}

  test "pinned Chromium executes a local page offline with completed Node assertions" do
    root = Store.path("scratch/browser-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    tag = "elixir-agent-benchmark:browser-check-#{System.unique_integer([:positive])}"

    spec = %{
      "runtime" => %{"browser" => true, "node_image" => "provided-by-browser-base"},
      "test_timeout" => 30
    }

    Browser.copy_bundle(spec, root)
    [stage] = Browser.stages(spec)
    base = String.replace_suffix(stage, " AS browser", " AS toolchain")

    recipe =
      [stage, base] ++
        Browser.install(spec) ++
        [
          "RUN mkdir -p /workspace/test && chown -R pwuser:pwuser /workspace",
          "USER pwuser",
          "WORKDIR /workspace",
          "CMD [\"sleep\", \"infinity\"]"
        ]

    File.write!(Path.join(root, "Dockerfile"), Enum.join(recipe, "\n"))

    on_exit(fn ->
      Sandbox.cleanup("synthetic-browser")
      Command.run("docker", ["image", "rm", tag])
      File.rm_rf!(root)
    end)

    Command.run!("docker", ["buildx", "build", "--load", "--provenance=false", "-t", tag, root],
      timeout: 240,
      limit: 100_000
    )

    image =
      Command.run!("docker", ["image", "inspect", tag, "--format", "{{.Id}}"]) |> String.trim()

    file = Path.join(root, "browser.mjs")

    File.write!(file, """
    import test, { before, after } from 'node:test';
    import assert from 'node:assert/strict';
    import { createServer } from 'node:http';
    const { chromium } = await import(process.env.EAB_BROWSER_MODULE);
    let browser, server, address;
    before(async () => {
      server = createServer((req, res) => res.end('<button onclick="this.textContent=\\'Done\\'">Run</button>'));
      await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
      address = `http://127.0.0.1:${server.address().port}`;
      browser = await chromium.launch({headless: true});
    });
    after(async () => { await browser?.close(); await new Promise(resolve => server?.close(resolve)); });
    test('local interactive page', async () => {
      const page = await browser.newPage();
      await page.goto(address);
      await page.getByRole('button').click();
      assert.equal(await page.getByRole('button').textContent(), 'Done');
      await page.close();
    });
    """)

    Sandbox.with_runtime(
      "synthetic-browser",
      spec,
      %{"image" => image, "services" => %{}},
      "synthetic-browser",
      fn box ->
        TestAdapter.install(box)
        Sandbox.copy_file(box, file, "/opt/eab-grade/browser.mjs")
        Sandbox.command!(box, "cp /opt/eab-grade/browser.mjs test/browser.mjs")

        result =
          Sandbox.command(box, TestAdapter.command("node", "node --test test/browser.mjs", []),
            timeout: 45
          )
          |> Grader.parse()

        assert result["passed"], inspect(result)
        assert result["test_results"] == %{"test/browser.mjs::local interactive page" => "passed"}

        assert Command.run!("docker", [
                 "inspect",
                 box.name,
                 "--format",
                 "{{.HostConfig.NetworkMode}}"
               ]) == "none\n"
      end
    )
  end
end
