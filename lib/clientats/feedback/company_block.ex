defmodule Clientats.Feedback.CompanyBlock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "company_blocks" do
    field :company_name, :string
    field :reason, :string

    belongs_to :user, Clientats.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [:user_id, :company_name, :reason])
    |> validate_required([:user_id, :company_name])
    |> update_change(:company_name, &String.trim/1)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :company_name])
  end
end
