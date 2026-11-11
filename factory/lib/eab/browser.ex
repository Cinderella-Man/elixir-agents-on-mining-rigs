defmodule Eab.Browser do
  @moduledoc "Pinned, offline Chromium tools installed only for cases that request a browser."
  alias Eab.Inventory

  @image "mcr.microsoft.com/playwright@sha256:dcc5531e97840b9b5e794f2814476b21571c5124a3fca2267d73041f56e7580e"

  def enabled?(spec), do: spec["runtime"]["browser"] == true

  def copy_bundle(spec, dest) do
    if enabled?(spec),
      do: File.cp_r!(Inventory.path("priv/fixtures/browser"), Path.join(dest, "browser"))
  end

  def stages(spec), do: if(enabled?(spec), do: ["FROM #{@image} AS browser"], else: [])

  def install(spec) do
    if enabled?(spec) do
      unless spec["runtime"]["node_image"],
        do: raise("Browser cases require an explicit Node runtime")

      lock = Inventory.hash_file(Inventory.path("priv/fixtures/browser/package-lock.json"))

      [
        "# Pinned browser bundle #{lock}",
        "RUN test -f /etc/os-release && . /etc/os-release && test \"$ID:$VERSION_ID\" = ubuntu:24.04",
        "COPY --from=browser /ms-playwright/ /ms-playwright/",
        "COPY browser/package.json browser/package-lock.json /opt/eab-browser/",
        "RUN npm ci --prefix /opt/eab-browser --ignore-scripts --no-audit --no-fund && /opt/eab-browser/node_modules/.bin/playwright install-deps chromium && rm -rf /var/lib/apt/lists/*",
        "ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright",
        "ENV EAB_BROWSER_MODULE=/opt/eab-browser/node_modules/playwright-core/index.mjs"
      ]
    else
      []
    end
  end
end
