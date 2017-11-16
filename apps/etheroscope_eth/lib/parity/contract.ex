defmodule EtheroscopeEth.Parity.Contract do
  use Etheroscope.Util, :parity

  @behaviour EtheroscopeEth.Parity.Resource

  @api_base_url "https://api.etherscan.io"

  defp handle_etherscan_error(do: block) do
    Error.handle_error "There seems to be an issue with Etherscan", do: block
  end

  @spec fetch(binary()) :: {:ok, map()} | Error.t
  def fetch(contract_address) do
    handle_etherscan_error do
      api_key = Application.get_env(:etheroscope, :etherscan_api_key)
      url = "#{@api_base_url}/api?module=contract&action=getabi&address=#{contract_address}&apikey=#{api_key}"

      with {:ok, resp}                             <- HTTPoison.get(url),
          %{"message" => "OK", "result" => result} <-  Poison.decode!(resp.body),
          abi                                       = result |> Poison.decode!
      do
        {:ok, abi}
      else
        body = %{"message" => "NOTOK"} -> {:error, %{msg: "Error with Etherscan", body: body}}
      end
    end
  end
end
