defmodule Clientats.Documents.CoverLetterTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cover_letter_templates" do
    field :name, :string
    field :description, :string
    field :content, :string
    field :is_default, :boolean, default: false

    belongs_to :user, Clientats.Accounts.User

    timestamps()
  end

  def changeset(cover_letter_template, attrs) do
    cover_letter_template
    |> cast(attrs, [:user_id, :name, :description, :content, :is_default])
    |> validate_required([:user_id, :name, :content])
    |> foreign_key_constraint(:user_id)
  end
end
