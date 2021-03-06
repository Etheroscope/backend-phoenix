defmodule EtheroscopeWeb.Router do
  use EtheroscopeWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EtheroscopeWeb do
    pipe_through :api

    get "/contracts/:contract_address/",                                            ContractController, :contract
    get "/contracts/:contract_address/history/:variable",                           ContractController, :get_history
    post "/contracts/:contract_address/history/:variable",                          ContractController, :post_history
    post "/contracts/:contract_address/history/:variable/subscribe/:email_address", NotificationController, :subscribe

  end
end
