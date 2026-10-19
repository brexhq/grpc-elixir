defmodule GRPC.Codec.ErlpackTest do
  use ExUnit.Case, async: true

  alias GRPC.Codec.Erlpack

  defmodule Message do
    defstruct [:value]
  end

  test "rejects new atoms without adding them to the atom table" do
    name = "erlpack_untrusted_atom_#{System.unique_integer([:positive])}"
    binary = <<131, 119, byte_size(name)::8, name::binary>>

    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    assert_raise ArgumentError, fn -> Erlpack.decode(binary, nil) end
    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
  end

  test "rejects local and external functions, pids, ports, and references" do
    port = Port.open({:spawn_executable, System.find_executable("cat")}, [:binary])
    on_exit(fn -> if Port.info(port), do: Port.close(port) end)

    for value <- [fn -> :ok end, &:erlang.system_time/0, self(), port, make_ref()] do
      assert_rejected(value)
    end
  end

  test "rejects unsafe terms nested in tuples, lists, maps, structs, and improper lists" do
    fun = fn -> :ok end

    for value <- [
          {:ok, fun},
          [1, fun],
          %{callback: fun},
          %{fun => :value},
          %{nested: [%Message{value: {:callback, fun}}]},
          [1 | fun],
          [fun | :tail]
        ] do
      assert_rejected(value)
    end
  end

  test "round trips ordinary values including structs and improper lists" do
    for value <- [
          nil,
          true,
          :ok,
          42,
          1.5,
          "payload",
          <<1::1>>,
          [],
          {},
          %{},
          {:ok, [1, 2, 3]},
          %{nested: [%Message{value: {:ok, "value"}}]},
          [1, 2 | :tail]
        ] do
      assert Erlpack.decode(Erlpack.encode(value), nil) == value
    end
  end

  test "rejects malformed external term data" do
    assert_raise ArgumentError, fn -> Erlpack.decode(<<0>>, nil) end
  end

  defp assert_rejected(value) do
    assert_raise ArgumentError, fn -> Erlpack.decode(Erlpack.encode(value), nil) end
  end
end
