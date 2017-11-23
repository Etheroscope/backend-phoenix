defmodule EtheroscopeEcto.Parity.Contract do
  use Ecto.Schema
  use Etheroscope.Util, :parity
  import Ecto.Changeset
  require EtheroscopeEcto
  alias EtheroscopeEcto.Repo
  alias EtheroscopeEcto.Parity.{Contract, VariableState}

  schema "contracts" do
    field :address,   :string
    field :abi,       {:array, :map}
    field :most_recent_block, :integer, default: -1
    field :variables, {:array, :string}, default: []
    field :blocks,    {:array, :integer}, default: []

    has_many :variable_states, VariableState

    timestamps()
  end

  @doc false
  defp changeset(%Contract{} = contract, attrs) do
    contract
    |> cast(attrs, [:address, :abi, :variables, :blocks])
    |> validate_required([:address, :abi])
  end

  @spec create_contract(map()) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  defp create_contract(attrs) do
    %Contract{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @spec update_contract(struct(), map()) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  defp update_contract(contract, attrs) do
    contract
    |> changeset(attrs)
    |> Repo.update()
  end

  def next_storage_module, do: EtheroscopeEth.Parity.Contract

  def get(opts = [address: address]) do
    case load_contract(address) do
      resp = {:ok, _c}    -> resp
      {:not_found, _addr} ->
        abi = apply(next_storage_module(), :get, opts)
        store_contract(address, abi)
    end
  end

  defp store_contract(addr, abi) do
    case create_contract(%{address: addr, abi: abi}) do
      resp = {:ok, _c} -> resp
      {:error, chgset}  ->
        Error.build_error_db(chgset.errors, "Store Failed: contract #{addr}.")
    end
  end

  defp load_contract(addr) do
    case Repo.get_by(Contract, address: addr) do
      nil -> {:not_found, addr}
      contract -> {:ok, contract}
    end
  end

  ################################### BLOCKS ###################################

  def get_block_numbers(addr) do
    case load_block_numbers(addr) do
      resp = {:ok, _b}  -> resp
      {:stale, ctr}     -> update_block_numbers(ctr)
      {:not_found, ctr} -> get_full_block_history(ctr)
      {:error, err}     -> Error.build_error(err, "Not Loaded: unable to load blocks for #{addr}")
    end
  end

  defp load_block_numbers(addr) do
    Cache.update_task_status(self(), "loading", {})
    case get(addr) do
      {:ok, contract = %Contract{blocks: []}} -> {:not_found, contract}
      {:ok, contract}                         -> {:stale, contract} # assume it's always stale for now
      resp = {:error, _err}                   -> resp
    end
  end

  defp update_block_numbers(contract) do
    handle_new_blocks(contract, :fetch_latest_blocks, [contract.addr, contract.most_recent_blocks])
  end

  defp get_full_block_history(contract) do
    handle_new_blocks(contract, :fetch_early_blocks, [contract.addr])
  end

  defp handle_new_blocks(contract, fun, args) do
    case apply(next_storage_module(), fun, args) do
      {:ok, blocks} ->
        new_blocks = MapSet.to_list(block_numbers(blocks))
        store_block_numbers(contract, new_blocks)
      {:error, err, new_blocks} ->
        if new_blocks != [], do: store_block_numbers(contract, new_blocks)
        Error.build_error(err)
    end
  end

  defp store_block_numbers(contract, new_blocks) do
    case contract |> update_contract(%{blocks: contract.blocks ++ new_blocks, most_recent_block: Enum.max(new_blocks)}) do
      resp = {:ok, _contract} -> resp
      {:error, err}           -> Error.build_error_db(err, "Not Stored: contract blocks for #{contract.address}")
    end
  end

  ################################### ABI ###################################

  @spec get_contract_abi(String.t()) :: EtheroscopeEcto.db_status()
  def get_contract_abi(addr) do
    case get(addr) do
      {:error, chgset} -> Error.build_error_db(chgset.errors, "Fetch Failed: contractABI for #{addr}.")
      {:ok, contract}  -> {:ok, contract.abi}
    end
  end

  ################################### VARIABLES ###################################

  @spec get_contract_variables(String.t()) :: EtheroscopeEcto.db_status()
  def get_contract_variables(addr) do
    case get(addr) do
      {:ok, ctr = %Contract{variables: [], abi: abi}} -> abi |> parse_contract_abi |> store_contract_variables(ctr)
      {:ok, %Contract{variables: vars}}               -> {:ok, vars}
      {:error, err}                                   -> Error.build_error_db(err, "Fetch Failed: contract variables for #{addr}.")
    end
  end

  defp store_contract_variables(vars, contract) do
    case update_contract(contract, %{variables: vars}) do
      resp = {:ok, _contract} -> resp
      {:error, err}           -> Error.build_error_db(err, "Not Stored: contract variables for #{contract.address}")
    end
  end
end
