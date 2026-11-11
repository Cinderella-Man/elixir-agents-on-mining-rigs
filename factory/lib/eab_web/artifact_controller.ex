defmodule EabWeb.ArtifactController do
  use Phoenix.Controller, formats: [:html]

  def show(conn, %{"id" => id, "path" => parts}) do
    case Eab.Store.artifact(id, Enum.join(parts, "/")) do
      {:ok, file} ->
        conn
        |> put_resp_content_type("application/octet-stream")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"#{Path.basename(file)}\""
        )
        |> send_file(200, file)

      :error ->
        send_resp(conn, 404, "Artifact not found")
    end
  end
end
