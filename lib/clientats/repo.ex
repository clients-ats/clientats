defmodule Clientats.Repo do
  use Ecto.Repo,
    otp_app: :clientats,
    adapter: Ecto.Adapters.Postgres
end
