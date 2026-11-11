defmodule EabWeb.ResultsController do
  use Phoenix.Controller, formats: [:html]

  def show(conn, %{"path" => path}) do
    if path == [] and not String.ends_with?(conn.request_path, "/") do
      redirect(conn, to: "/results/")
    else
      opts = Eab.Results.Preview.init(Path.join(Eab.Results.root(), "dist"))
      Eab.Results.Preview.call(%{conn | path_info: path}, opts)
    end
  end
end
