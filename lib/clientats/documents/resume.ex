defmodule Clientats.Documents.Resume do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resumes" do
    field :name, :string
    field :description, :string
    field :file_path, :string
    field :original_filename, :string
    field :file_size, :integer
    field :is_default, :boolean, default: false

    belongs_to :user, Clientats.Accounts.User

    timestamps()
  end

  def changeset(resume, attrs) do
    resume
    |> cast(attrs, [:user_id, :name, :description, :file_path, :original_filename, :file_size, :is_default])
    |> validate_required([:user_id, :name, :file_path, :original_filename])
    |> foreign_key_constraint(:user_id)
  end
end
