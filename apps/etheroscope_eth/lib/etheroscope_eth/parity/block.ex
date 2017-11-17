defmodule EtheroscopeEth.Parity.Block do
  @moduledoc """
    EtheroscopeEth.Parity.History is the module containing functions to handle retrieval
  of block times and other block related functions.
  """
  use Etheroscope.Util, :parity
  alias EtheroscopeEth.Parity

  @batch_size 1_000

  @behaviour EtheroscopeEth.Parity.Resource

  def start_block_number do
    blocks_ago(100_000)
  end

  def start_block_hex do
    Hex.to_hex start_block_number()
  end

  def blocks_ago(number) do
    case current_block_number() do
      {:ok, num} ->
        Cache.add_or_update_global_var(:current_block, num - number)
        num - number
      {:error, err} -> Error.build_error(err, "[ETH] Fetch failed: current_block_number")
    end
  end

  def fetch_time(block_number) when is_integer(block_number) do
    fetch_time(Hex.to_hex(block_number))
  end
  def fetch_time(block_number) when is_binary(block_number) do
    Logger.info "[ETH] Fetching: block #{block_number}"
    case EtheroscopeEth.Client.eth_get_block_by_number(block_number, false) do
      {:ok, %{"timestamp" => timestamp}} -> {:ok, timestamp}
      {:error, err} ->
        Error.build_error(err, "[ETH] Unable to fetch block time")
    end
  end

  @spec current_block_number() :: non_neg_integer()
  def current_block_number do
    Hex.from_hex(EtheroscopeEth.Client.eth_block_number())
  end

  @spec current_block_number_ch() :: non_neg_integer()
  def current_block_number_ch do
    Cache.fetch_global_var(:current_block)
  end

  @spec fetch({String.t(), {atom(), integer()}}) :: {:ok, MapSet.t()} | Error.t()
  def fetch({address, {:ok, block_num}}), do: fetch_batch(address, block_num, [])
  def fetch({_a, {:error, err}}),         do: Error.build_error(err, "[ETH] Not Fetched: Error passed in")

  @spec fetch_full_history(String.t()) :: {:ok, MapSet.t()} | Error.t()
  def fetch_full_history(address), do: fetch_batch(address, start_block_number(), [])

  @spec fetch_batch(String.t(), integer(), list()) :: {:ok, MapSet.t()} | Error.t()
  def fetch_batch(address, block_num, list) do
    if block_num >= current_block_number_ch() do
      Logger.info "[ETH] Fetched: block numbers for #{address}"
      list
    else
      Logger.info "[ETH] Fetching: blocks #{block_num} to #{block_num + @batch_size} for #{address}"
      case address |> batched_filter_params(block_num) |> Parity.trace_filter do
        {:ok, ts} ->
          Logger.info "[ETH] Fetched: blocks #{block_num} to #{block_num + @batch_size} for #{address}"
          fetch_batch(address, block_num + @batch_size, [ts | list])
        {:error, _err} ->
          Logger.error "[ETH] Not Fetched: blocks #{block_num} to #{block_num + @batch_size} for #{address}"
          fetch_batch(address, block_num + @batch_size, list)
      end
    end
  end

  defp batched_filter_params(address, block_num) do
    %{
      "toAddress" => [address],
      "fromBlock" => Hex.to_hex(block_num),
      "toBlock"   => Hex.to_hex(block_num + @batch_size)
    }
  end
end
