defmodule Eab.ReleaseFiles do
  @moduledoc """
  Release files a task's workspace image installs (factory/README.md, section 6, change 3): a file named by its URL,
  its SHA-256 and its kind, such as a program's own `.deb` that a project's CI installs instead of a distribution
  package.

  Only `https` URLs on the installation's list of allowed hosts (`EAB_RELEASE_FILE_HOSTS`, empty by default) are
  fetched, and every redirect must stay on that list, so a task cannot make the engine fetch from anywhere. The engine
  fetches a file once, checks its SHA-256, keeps it under `release-files/` in its data folder and puts it into the
  build folder under its SHA-256; the recipe checks the SHA-256 again inside the image build, which fails on a
  mismatch, and installs the file. The URL never enters the recipe.
  """
  alias Eab.Store

  @max_bytes 512 * 1024 * 1024
  @max_redirects 5

  def allowed_hosts, do: Application.get_env(:eab, :release_file_hosts) || []

  def https_url?(url) do
    with true <- is_binary(url) and not String.match?(url, ~r/[\s"'\\`$]/),
         %URI{scheme: "https", host: host, userinfo: nil} when is_binary(host) and host != "" <-
           URI.parse(url) do
      true
    else
      _ -> false
    end
  end

  def allowed?(url),
    do: https_url?(url) and String.downcase(URI.parse(url).host) in allowed_hosts()

  @doc "The file name a release file has in the build folder and in the recipe."
  def file_name(%{"sha256" => sha, "kind" => "deb"}), do: "#{sha}.deb"

  @doc """
  Fetches (or reuses) each release file, checks its SHA-256 and copies it to `dest/release-files/`. Does nothing for
  an empty list.
  """
  def stage!([], _dest, _emit), do: :ok

  def stage!(entries, dest, emit) do
    folder = Path.join(dest, "release-files")
    File.rm_rf!(folder)
    File.mkdir_p!(folder)

    for entry <- entries do
      name = file_name(entry)
      kept = Store.path("release-files/#{name}")

      if File.regular?(kept) and sha256_file(kept) == entry["sha256"] do
        emit.("Reusing release file #{name}")
      else
        emit.("Fetching release file #{entry["url"]}")
        body = fetch!(entry["url"])

        unless sha256(body) == entry["sha256"],
          do: raise("Release file checksum mismatch: #{entry["url"]}")

        File.mkdir_p!(Path.dirname(kept))
        temp = kept <> ".#{System.unique_integer([:positive])}.tmp"
        File.write!(temp, body)
        File.rename!(temp, kept)
      end

      File.cp!(kept, Path.join(folder, name))
    end

    :ok
  end

  defp fetch!(url, redirects \\ 0) do
    unless allowed?(url),
      do: raise("Release file host is not allowed by this installation: #{url}")

    request = Application.get_env(:eab, :release_file_request, &Req.request/1)

    case request.(
           method: :get,
           url: url,
           redirect: false,
           retry: false,
           decode_body: false,
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: body}} when is_binary(body) and byte_size(body) <= @max_bytes ->
        body

      {:ok, %{status: status} = response} when status in [301, 302, 303, 307, 308] ->
        if redirects >= @max_redirects, do: raise("Release file has too many redirects: #{url}")

        case Req.Response.get_header(response, "location") do
          [location | _] -> fetch!(URI.merge(url, location) |> URI.to_string(), redirects + 1)
          [] -> raise "Release file redirect without a location: #{url}"
        end

      {:ok, %{status: status}} ->
        raise "Release file could not be fetched (HTTP #{status}): #{url}"

      {:error, error} ->
        raise "Release file could not be fetched (#{if is_exception(error), do: Exception.message(error), else: inspect(error)}): #{url}"
    end
  end

  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

  defp sha256_file(path), do: sha256(File.read!(path))
end
