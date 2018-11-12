defmodule MapQueueTest do
  use ExUnit.Case
  doctest MapQueue

  test "new/0 returns an empty queue" do
    assert %MapQueue{map: map, first: 0, last: 0} = MapQueue.new()
    assert map_size(map) == 0
  end

  describe "new/1" do
    test "can handle lists" do
      assert %MapQueue{
               map: %{
                 0 => "1",
                 1 => "2",
                 2 => "3"
               },
               first: 0,
               last: 2
             } = MapQueue.new(["1", "2", "3"])
    end

    test "can handle maps, but order is not guaranteed" do
      assert %MapQueue{map: map, first: 0, last: 1} = MapQueue.new(%{one: "one", two: "two"})
      values = Map.values(map)
      assert {:one, "one"} in values
      assert {:two, "two"} in values
    end
  end

  describe "pop/1" do
    test "pops in order" do
      queue = "one two three four five" |> String.split(" ") |> MapQueue.new()
      assert {"one", queue} = MapQueue.pop(queue)
      assert {"two", queue} = MapQueue.pop(queue)
      assert {"three", queue} = MapQueue.pop(queue)
      assert {"four", queue} = MapQueue.pop(queue)
    end
  end

  describe "pop/2" do
    test "returns a list and MapQueue struct" do
      assert {popped, queue} = MapQueue.new() |> MapQueue.pop(10)
      assert is_list(popped)
      assert %MapQueue{} = queue
    end

    test "pops the correct count" do
      queue = Enum.into(1001..1100, MapQueue.new())
      assert MapQueue.size(queue) == 100
      assert queue.first == 0
      assert queue.last == 99
      assert {popped, queue} = MapQueue.pop(queue, 50)
      assert length(popped) == 50
      assert MapQueue.size(queue) == 50
    end

    test "pops an empty list when empty" do
      queue = MapQueue.new()
      assert MapQueue.size(queue) == 0
      assert {[], _} = MapQueue.pop(queue, 10)
    end
  end

  describe "defimpl Collectable, for: QueueMap" do
    test "increases in size correctly" do
      assert %MapQueue{} = queue = Enum.into(1..5, MapQueue.new())
      assert MapQueue.size(queue) == 5
      assert %MapQueue{} = queue = Enum.into(11..15, queue)
      assert MapQueue.size(queue) == 10
    end

    test "keeps order correctly" do
      assert %MapQueue{} = queue = Enum.into(1..5, MapQueue.new())
      assert Enum.into(queue, []) == [1, 2, 3, 4, 5]
      assert %MapQueue{} = queue = Enum.into(11..15, queue)
      assert Enum.into(queue, []) == [1, 2, 3, 4, 5, 11, 12, 13, 14, 15]
    end

    test "collecting pushes new entries to the rear of the queue" do
      assert %MapQueue{} = queue = Enum.into(1..5, MapQueue.new())
      assert %MapQueue{} = queue = Enum.into(11..15, queue)
      assert {1, queue} = MapQueue.pop(queue)
      assert {15, queue} = MapQueue.pop_rear(queue)
    end
  end

  test "QueueMap implements Enumerable" do
    assert [1, 2, 3, 4, 5] == 1..5 |> MapQueue.new() |> Enum.into([])
    assert [3, 4, 5, 6] == 1..6 |> MapQueue.new() |> Enum.drop(2)
    assert [1, 2, 3] == 1..50 |> MapQueue.new() |> Enum.slice(0, 3)
    assert [11, 12, 13] == 1..50 |> MapQueue.new() |> Enum.slice(10, 3)
    assert 15 == Enum.reduce(MapQueue.new(1..5), 0, fn n, acc -> n + acc end)
    assert 1..5 |> MapQueue.new() |> Enum.count() == 5
    assert 1..5 |> MapQueue.new() |> Enum.sum() == 15
  end
end
