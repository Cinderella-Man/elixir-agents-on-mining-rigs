defmodule EabWeb.ChatGPTController do
  use Phoenix.Controller, formats: [:html]
  import Plug.Conn

  def start(conn, params) do
    # Establish the browser session on exactly the loopback host used by the callback.
    if conn.host != "127.0.0.1" do
      redirect(conn,
        external:
          base_url() <> "/auth/chatgpt?" <> URI.encode_query(Map.take(params, ["account"]))
      )
    else
      case Eab.ChatGPTAuth.begin(params["account"], base_url() <> "/auth/chatgpt/callback") do
        {:ok, url, state} -> conn |> put_session(:chatgpt_state, state) |> redirect(external: url)
        {:error, message} -> failure(conn, message)
      end
    end
  end

  def callback(conn, params) do
    state = get_session(conn, :chatgpt_state)
    conn = conn |> delete_session(:chatgpt_state) |> put_resp_header("cache-control", "no-store")

    case Eab.ChatGPTAuth.complete(params, state) do
      {:ok, id} ->
        redirect(conn, to: "/?" <> URI.encode_query(%{"chatgpt" => id}))

      {:error, :reauthorize} ->
        failure(
          conn,
          "ChatGPT authorization expired. Select the saved registration and sign in again."
        )

      {:error, message} ->
        failure(conn, message)
    end
  end

  defp failure(conn, message), do: conn |> put_flash(:error, message) |> redirect(to: "/")

  def base_url do
    port = EabWeb.Endpoint.config(:http)[:port]
    "http://127.0.0.1:#{port}"
  end
end
