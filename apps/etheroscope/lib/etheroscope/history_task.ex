defmodule Etheroscope.HistoryTask do
  use Etheroscope.Util, :parity
  alias Etheroscope.Cache.History

  def notifier do
    Etheroscope.Notifier.Email
  end

  def start_task(start_value, address, variable) do
    Task.Supervisor.start_child(Etheroscope.TaskSupervisor, fn -> run(start_value, address, variable) end)
  end

  def start(address, variable) do
    case History.get(address: address, variable: variable) do
      nil             ->
        start_task([], address, variable)
      {:error, _data} ->
        History.delete_history(address, variable)
        start_task([], address, variable)
      {:stale, data}  ->
        History.delete_history(address, variable)
        start_task(data, address, variable)
      _other          -> {:found, nil}
    end
  end

  def run(start_value, address, variable) do
    History.start(self(), start_value, address, variable)
    case :timer.tc(fn -> get_blocks(address, variable) end) do
      {_time, {:error, err}} ->
        History.set_fetch_error(self(), err)
        Error.put_error_message(err)
      {time, blocks} ->
        Logger.info("TIME IS #{time}")
        History.finish(self(), blocks)
        notifier().notify(address, variable)
      :not_found ->
        History.not_found_error(self())
    end
  end

  defp get_blocks(address, variable) do
    EtheroscopeEcto.History.get(address: address, variable: variable)
  end

  def status(address, variable) do
    History.get(address: address, variable: variable)
  end
end
