defmodule MapQueue do
  @type t :: %__MODULE__{
          first: integer(),
          last: integer(),
          map: %{required(integer()) => any()}
        }

  defstruct first: 0,
            last: 0,
            map: %{}

  @spec new() :: MapQueue.t()
  def new() do
    %MapQueue{}
  end

  @spec new(any()) :: MapQueue.t()
  def new(enumerable) do
    append(%MapQueue{}, enumerable)
  end

  @spec size(MapQueue.t()) :: non_neg_integer()
  def size(%MapQueue{map: map}) do
    map_size(map)
  end

  @spec append(MapQueue.t(), any()) :: MapQueue.t()
  def append(%MapQueue{} = queue, enumerable) do
    Enum.into(enumerable, queue)
  end

  @spec prepend(MapQueue.t(), any()) :: MapQueue.t()
  def prepend(%MapQueue{} = queue, enumerable) do
    enumerable
    |> Enum.reverse()
    |> Enum.reduce(queue, fn item, acc ->
      push_front(acc, item)
    end)
  end

  @spec pop(MapQueue.t()) :: :empty | {any(), MapQueue.t()}
  def pop(%MapQueue{} = queue) do
    do_pop(queue, :first)
  end

  @spec pop(MapQueue.t(), non_neg_integer()) :: {list(), MapQueue.t()}
  def pop(%MapQueue{} = queue, 0) do
    {[], queue}
  end

  def pop(%MapQueue{map: map} = queue, _) when map_size(map) == 0 do
    {[], queue}
  end

  def pop(%MapQueue{first: first, last: last} = queue, count) when count >= 0 do
    last_popped = min(first + count - 1, last)
    do_pop_indexes(queue, first..last_popped, :first, min(last_popped, last))
  end

  @spec pop_rear(MapQueue.t()) :: :empty | {any(), MapQueue.t()}
  def pop_rear(%MapQueue{} = queue) do
    do_pop(queue, :last)
  end

  @spec pop_rear(MapQueue.t(), non_neg_integer()) :: {list(), MapQueue.t()}

  def pop_rear(%MapQueue{} = queue, 0) do
    {[], queue}
  end

  def pop_rear(%MapQueue{map: map} = queue, _) when map_size(map) == 0 do
    {[], queue}
  end

  def pop_rear(%MapQueue{first: first, last: last} = queue, count) when count > 0 do
    first_popped = max(last - count, first)
    do_pop_indexes(queue, last..first_popped, :last, max(first_popped - 1, first))
  end

  @spec push(MapQueue.t(), any()) :: MapQueue.t()
  def push(%MapQueue{last: last} = queue, value) do
    add_value(queue, :last, last + 1, value)
  end

  @spec push_front(MapQueue.t(), any()) :: MapQueue.t()
  def push_front(%MapQueue{first: first} = queue, value) do
    add_value(queue, :first, first - 1, value)
  end

  @spec slice(MapQueue.t(), any(), any()) :: MapQueue.t()
  def slice(%MapQueue{last: last}, index, _) when index > last do
    MapQueue.new()
  end

  def slice(%MapQueue{first: first, map: map}, index, amount) do
    rel_start = first + index

    rel_start..(rel_start + amount - 1)
    |> Enum.reduce(%MapQueue{}, fn index, acc ->
      push(acc, Map.get(map, index))
    end)
  end

  defp add_value(%MapQueue{map: map} = queue, _spot, _, value) when map_size(map) == 0 do
    %MapQueue{queue | map: Map.put(map, 0, value)}
  end

  defp add_value(%MapQueue{map: map} = queue, spot, index, value) do
    queue
    |> Map.put(spot, index)
    |> Map.put(:map, Map.put(map, index, value))
  end

  defp diff_by_index_type(:last), do: -1
  defp diff_by_index_type(:first), do: 1

  defp do_pop(%MapQueue{map: map}, _) when map_size(map) == 0 do
    :empty
  end

  defp do_pop(%MapQueue{map: map} = queue, index_type) do
    index = Map.get(queue, index_type)
    {value, new_map} = Map.pop(map, index)

    queue =
      queue
      |> Map.put(:map, new_map)
      |> Map.put(index_type, index + diff_by_index_type(index_type))

    {value, queue}
  end

  def do_pop_indexes(%MapQueue{map: map} = queue, a..b, first_or_last, boundary_value) do
    indexes = Enum.into(a..b, [])
    popped_items = Enum.map(indexes, fn index -> Map.get(map, index) end)
    updated_map = Map.drop(map, indexes)

    updated_queue =
      queue
      |> Map.put(first_or_last, boundary_value)
      |> Map.put(:map, updated_map)

    {popped_items, updated_queue}
  end

  defimpl Enumerable do
    @spec count(MapQueue.t()) :: {:ok, non_neg_integer()}
    def count(%MapQueue{map: map}) do
      {:ok, map_size(map)}
    end

    def member?(%MapQueue{map: map}, item) do
      map
      |> Enum.find(fn {_, i} -> i == item end)
      |> case do
        nil ->
          {:ok, false}

        {_, _} ->
          {:ok, true}
      end
    end

    @type suspended_function ::
            ({:cont, any()} | {:halt, any()} | {:suspend, any()} ->
               {:done, any()} | {:halted, any()} | {:suspended, any(), any()})
    @spec reduce(any(), {:cont, any()} | {:halt, any()} | {:suspend, any()}, any()) ::
            {:done, any()}
            | {:halted, any()}
            | {:suspended, any(), suspended_function()}
    def reduce(_, {:halt, acc}, _) do
      {:halted, acc}
    end

    def reduce(queue, {:suspend, acc}, fun) do
      {:suspended, acc, fn acc_2 -> reduce(queue, acc_2, fun) end}
    end

    def reduce(%MapQueue{map: map}, {:cont, acc}, _fun) when map_size(map) == 0 do
      {:done, acc}
    end

    def reduce(%MapQueue{} = queue, {:cont, acc}, fun) do
      {popped, queue} = MapQueue.pop(queue)
      reduce(queue, fun.(popped, acc), fun)
    end

    @spec slice(MapQueue.t()) ::
            {:ok, non_neg_integer(), (non_neg_integer(), pos_integer() -> list(any()))}
    def slice(%MapQueue{map: map} = queue) do
      func = fn start, count ->
        queue
        |> MapQueue.slice(start, count)
        |> Enum.into([])
      end

      {:ok, map_size(map), func}
    end
  end

  defimpl Inspect do
    def inspect(%MapQueue{map: map, first: first, last: last}, _opts) do
      items =
        [items: render_values(map, first, last), size: map_size(map)]
        |> Enum.reduce([], fn {k, v}, acc ->
          [Enum.join([to_string(k), ": ", to_string(v)]) | acc]
        end)
        |> List.flatten()
        |> Enum.join(", ")

      :erlang.iolist_to_binary(["#MapQueue<[", items, "]>"])
    end

    defp render_values(map, _, _) when map_size(map) == 0 do
      wrap_brackets("")
    end

    defp render_values(map, first, _) when map_size(map) == 1 do
      map
      |> render_value(first)
      |> wrap_brackets
    end

    defp render_values(map, first, last) do
      [render_value(map, first), ", ..., ", render_value(map, last)]
      |> Enum.join("")
      |> wrap_brackets()
    end

    def render_value(map, key) do
      map
      |> Map.get(key)
      |> inspect()
    end

    defp wrap_brackets(item) do
      "[" <> item <> "]"
    end
  end

  defimpl Collectable, for: MapQueue do
    def into(original) do
      collector_fun = fn
        queue, {:cont, item} -> MapQueue.push(queue, item)
        queue, :done -> queue
        _queue, :halt -> :ok
      end

      {original, collector_fun}
    end
  end
end
