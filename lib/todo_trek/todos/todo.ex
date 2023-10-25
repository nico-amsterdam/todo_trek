defmodule TodoTrek.Todos.Todo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "todos" do
    field :status, Ecto.Enum, values: [:started, :completed], default: :started
    field :title, :string
    field :position, :integer
    field :country, :string, virtual: true
    field :capital, :string, virtual: true

    belongs_to :list, TodoTrek.Todos.List
    belongs_to :user, TodoTrek.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(todo, attrs) do
    todo
    |> cast(attrs, [:id, :title, :status])
    |> validate_required([:title])
  end
end
