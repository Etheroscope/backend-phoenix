defmodule EtheroscopeEth.Parity do
  @moduledoc """
    EtheroscopeEth.Parity serves as a wrapper for the Ethereumex library. It allows us
  to be responsible for error handling as well as adding new functionality to it.
  """
  use Etheroscope.Util, :parity
  alias EtheroscopeEth.Client

  @type keccak_var :: {atom, <<_ ::80>>}

  @method_id_size 10

  @spec trace_filter(map()) :: {:ok, String.t} | Error.t
  def trace_filter(params) do
    with true          <- validate_filter_params(params),
         {:ok, result} <- Client.request("trace_filter", [params], [])
    do
      {:ok, result}
    else
      false ->
        {:error, "Invalid parameters"}
      {:error, %{"code" => -32602, "message" => msg}} ->
        {:error, "Invalid parameters: #{msg}"}
    end
  end

  @spec keccak_value(String.t()) :: {:ok, String.t()} | Error.t
  def keccak_value(var) do
    # create hash for variable name with empty parenthises
    hash = Base.encode16(var <> "()")
    case Client.web3_sha3("0x" <> hash) do
      {:ok, hex}    -> {:ok, String.slice(hex, 0, @method_id_size)}
      {:error, err} -> Error.build_error_eth(err, "Bad Argument or Parity Failiure")
    end
  end

  @spec variable_value(keccak_var, String.t(), String.t()) :: {:ok, String.t()} | Error.t
  def variable_value({:ok, variable}, address, block_number) do
    Client.eth_call(%{ "to" => address, "data" => variable}, block_number)
  end
  def variable_value({:error, error}, address, block_number) do
    # head of error list should be the variable
    Error.build_error_eth(error, "Fetch Failed: contract #{address} at block #{block_number}.")
  end

  @spec current_block_number :: {:ok, integer()} | Error.t()
  def current_block_number do
    case Client.eth_block_number do
      {:ok, hex}    -> {:ok, hex |> Hex.from_hex}
      {:error, err} -> Error.build_error_eth(err, "Fetch Failed: current block number.")
    end
  end
end
