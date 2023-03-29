defmodule Forms.Todos do
  @moduledoc """
  The Todos context.
  """

  import Ecto.Query, warn: false
  alias Forms.{Repo, Scope, Events}

  alias Forms.Todos.{List, Todo}

  @max_todos 1000

  def subscribe(%Scope{} = scope) do
    Phoenix.PubSub.subscribe(Forms.PubSub, topic(scope))
  end

  def update_list_position(%Scope{} = scope, %List{} = list, new_index) do
    Ecto.Multi.new()
    |> multi_reposition(:new, list, list, new_index, user_id: scope.current_user.id)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        new_list = %List{list | position: new_index}
        broadcast(scope, %Events.ListRepositioned{list: new_list})
        :ok

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  def multi_reposition(%Ecto.Multi{} = multi, name, %type{} = struct, lock, new_idx, where_query)
      when is_integer(new_idx) or new_idx == :end do
    old_index = struct.position

    multi
    |> Repo.multi_transaction_lock(name, lock)
    |> Ecto.Multi.run({:index, name}, fn repo, _changes ->
      case repo.one(from(t in type, where: ^where_query, select: count(t.id))) do
        count when new_idx == :end -> {:ok, count - 1}
        count when new_idx < count -> {:ok, new_idx}
        count -> {:ok, count - 1}
      end
    end)
    |> multi_update_all({:dec_positions, name}, fn %{{:index, ^name} => computed_index} ->
      from(t in type,
        where: ^where_query,
        where: t.id != ^struct.id,
        where: t.position > ^old_index and t.position <= ^computed_index,
        update: [inc: [position: -1]]
      )
    end)
    |> multi_update_all({:inc_positions, name}, fn %{{:index, ^name} => computed_index} ->
      from(t in type,
        where: ^where_query,
        where: t.id != ^struct.id,
        where: t.position < ^old_index and t.position >= ^computed_index,
        update: [inc: [position: 1]]
      )
    end)
    |> multi_update_all({:position, name}, fn %{{:index, ^name} => computed_index} ->
      from(t in type,
        where: t.id == ^struct.id,
        update: [set: [position: ^computed_index]]
      )
    end)
  end

  def update_todo_position(%Scope{} = scope, %Todo{} = todo, new_index) do
    Ecto.Multi.new()
    |> multi_reposition(:new, todo, {List, todo.list_id}, new_index, list_id: todo.list_id)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        new_todo = %Todo{todo | position: new_index}
        broadcast(scope, %Events.TodoRepositioned{todo: new_todo})
        :ok

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  def change_todo(todo_or_changeset, attrs \\ %{}) do
    Todo.changeset(todo_or_changeset, attrs)
  end

  def move_todo_to_list(%Scope{} = scope, %Todo{} = todo, %List{} = list, at_index) do
    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:move_lock, scope.current_user)
    |> multi_reposition(:old, todo, {List, todo.list_id}, :end, list_id: todo.list_id)
    |> multi_reposition(:new, todo, list, at_index, list_id: list.id)
    |> multi_update_all(:move_to_list, fn _changes ->
      from(t in Todo,
        where: t.id == ^todo.id,
        update: [set: [list_id: ^list.id]]
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        broadcast(scope, %Events.TodoDeleted{todo: todo})
        new_todo = %Todo{todo | list_id: list.id, position: at_index}
        broadcast(scope, %Events.TodoRepositioned{todo: new_todo})
        :ok

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  def delete_todo(%Scope{} = scope, %Todo{} = todo) do
    case Repo.delete(todo) do
      {:ok, todo} ->
        broadcast(scope, %Events.TodoDeleted{todo: todo})
        {:ok, todo}

      other ->
        other
    end
  end

  def list_todos(%Scope{} = scope, limit) do
    Repo.all(
      from(t in Todo,
        where: t.user_id == ^scope.current_user.id,
        limit: ^limit,
        order_by: [asc: :position]
      )
    )
  end

  def toggle_complete(%Scope{} = scope, %Todo{} = todo) do
    new_status =
      case todo.status do
        :completed -> :started
        :started -> :completed
      end

    query = from(t in Todo, where: t.id == ^todo.id and t.user_id == ^scope.current_user.id)
    {1, _} = Repo.update_all(query, set: [status: new_status])
    todo = %Todo{todo | status: new_status}
    broadcast(scope, %Events.TodoToggled{todo: todo})

    {:ok, todo}
  end

  def get_todo!(%Scope{} = scope, id) do
    from(t in Todo, where: t.id == ^id and t.user_id == ^scope.current_user.id)
    |> Repo.one!()
    |> Repo.preload(:list)
  end

  def update_todo(%Scope{} = scope, %Todo{} = todo, params) do
    todo
    |> Todo.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, todo} ->
        broadcast(scope, %Events.TodoUpdated{todo: todo})
        {:ok, todo}

      other ->
        other
    end
  end

  def create_todo(%Scope{} = scope, %List{} = list, params) do
    position = Repo.one(from t in Todo, where: t.list_id == ^list.id, select: count(t.id))

    todo = %Todo{
      user_id: scope.current_user.id,
      status: :started,
      position: position,
      list_id: list.id
    }

    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:list, list)
    |> Ecto.Multi.insert(:todo, Todo.changeset(todo, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{todo: todo}} ->
        broadcast(scope, %Events.TodoAdded{todo: todo})
        {:ok, todo}

      {:error, :todo, changeset, _changes_so_far} ->
        {:error, changeset}
    end
  end

  @doc """
  Returns the active lists.

  ## Examples

      iex> active_lists()
      [%List{}, ...]

  """
  def active_lists(%Scope{} = scope, limit) do
    from(l in List,
      where: l.user_id == ^scope.current_user.id,
      limit: ^limit,
      order_by: [asc: :position]
    )
    |> Repo.all()
    |> Repo.preload(
      todos:
        from(t in Todo,
          where: t.user_id == ^scope.current_user.id,
          limit: @max_todos,
          order_by: [asc: t.position]
        )
    )
  end

  @doc """
  Gets a single list.

  Raises `Ecto.NoResultsError` if the List does not exist.

  ## Examples

      iex> get_list!(123)
      %List{}

      iex> get_list!(456)
      ** (Ecto.NoResultsError)

  """
  def get_list!(%Scope{} = scope, id) do
    Repo.one!(from(l in List, where: l.user_id == ^scope.current_user.id, where: l.id == ^id))
    |> preload()
  end

  defp preload(resource), do: Repo.preload(resource, [:todos])

  @doc """
  Creates a list.

  ## Examples

      iex> create_list(%{field: value})
      {:ok, %List{}}

      iex> create_list(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_list(%Scope{} = scope, attrs \\ %{}) do
    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:user, scope.current_user)
    |> Ecto.Multi.run(:position, fn repo, _changes ->
      position =
        repo.one(from l in List, where: l.user_id == ^scope.current_user.id, select: count(l.id))

      {:ok, position}
    end)
    |> Ecto.Multi.insert(:list, fn %{position: position} ->
      List.changeset(%List{user_id: scope.current_user.id, position: position}, attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{list: list}} ->
        list = Repo.preload(list, :todos)
        broadcast(scope, %Events.ListAdded{list: list})
        {:ok, list}

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  @doc """
  Updates a list.

  ## Examples

      iex> update_list(list, %{field: new_value})
      {:ok, %List{}}

      iex> update_list(list, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_list(%Scope{} = scope, %List{} = list, attrs) do
    list
    |> List.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, list} ->
        broadcast(scope, %Events.ListUpdated{list: list})
        {:ok, list}

      other ->
        other
    end
  end

  @doc """
  Deletes a list.

  ## Examples

      iex> delete_list(list)
      {:ok, %List{}}

      iex> delete_list(list)
      {:error, %Ecto.Changeset{}}

  """
  def delete_list(%Scope{} = _scope, %List{} = list) do
    Repo.delete(list)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking list changes.

  ## Examples

      iex> change_list(list)
      %Ecto.Changeset{data: %List{}}

  """
  def change_list(%List{} = list, attrs \\ %{}) do
    List.changeset(list, attrs)
  end

  defp multi_update_all(multi, name, func, opts \\ []) do
    Ecto.Multi.update_all(multi, name, func, opts)
  end

  defp broadcast(%Scope{} = scope, event) do
    Phoenix.PubSub.broadcast(Forms.PubSub, topic(scope), {__MODULE__, event})
  end

  defp topic(%Scope{} = scope), do: "todos:#{scope.current_user.id}"
end
