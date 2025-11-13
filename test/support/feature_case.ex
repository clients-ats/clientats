defmodule ClientatsWeb.FeatureCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.DSL

      alias ClientatsWeb.Endpoint
      alias Clientats.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ClientatsWeb.FeatureCase

      @moduletag :feature
    end
  end

  setup tags do
    Clientats.DataCase.setup_sandbox(tags)
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Clientats.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
