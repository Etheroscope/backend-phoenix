defmodule EtheroscopeDB do
  @moduledoc """
  Documentation for EtheroscopeDB.
  """

  @doc """
  Hello world.

  ## Examples

      iex> EtheroscopeDB.hello
      :world

  """
  def db_props do
    %{
      protocol: Application.get_env(:etheroscope_db, :protocol),
      hostname: Application.get_env(:etheroscope_db, :hostname),
      database: Application.get_env(:etheroscope_db, :database),
      port:     Application.get_env(:etheroscope_db, :port),
      user:     Application.get_env(:etheroscope_db, :user),
      password: Application.get_env(:etheroscope_db, :password)
    }
  end

  def fetch_filter(id), do: fetch("filter/#{id}")
  def write_filter(id, params), do: write("filter/#{id}", params)

  # HELPERS
  defp fetch(id), do: Couchdb.Connector.get(db_props(), id)
  defp write(id, params) do
    with {:error, err} <- Couchdb.Connector.create(db_props(), params, id),
         %{payload: %{"error" => err_msg}} <- err
    do
      {:error, err_msg}
    else
      {:ok, _resp} -> {:ok, id}
    end
  end
end
