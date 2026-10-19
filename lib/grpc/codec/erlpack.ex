defmodule GRPC.Codec.Erlpack do
  @moduledoc """
  Serializes messages using the Erlang external term format.

  Decoding rejects new atoms and terms containing functions, pids, ports, or
  references, including nested values (GHSA-grp7-v8xh-rj7h). Incoming atoms
  must already exist on the receiving node; applications must load the modules
  defining their message structs and atoms before decoding them.
  """

  @behaviour GRPC.Codec

  def name() do
    "erlpack"
  end

  def encode(struct) do
    :erlang.term_to_binary(struct)
  end

  def decode(binary, _module) do
    term = :erlang.binary_to_term(binary, [:safe])
    ensure_safe_term!(term)
    term
  end

  defp ensure_safe_term!(term)
       when is_function(term) or is_pid(term) or is_port(term) or is_reference(term) do
    raise ArgumentError, "refusing to decode unsafe erlpack payload"
  end

  # Walk both the head and tail so improper lists cannot hide unsafe terms.
  defp ensure_safe_term!([head | tail]) do
    ensure_safe_term!(head)
    ensure_safe_term!(tail)
  end

  defp ensure_safe_term!(term) when is_tuple(term) do
    term |> Tuple.to_list() |> Enum.each(&ensure_safe_term!/1)
  end

  defp ensure_safe_term!(term) when is_map(term) do
    # Map.to_list/1 supports structs without invoking their Enumerable protocol.
    Enum.each(Map.to_list(term), fn {key, value} ->
      ensure_safe_term!(key)
      ensure_safe_term!(value)
    end)
  end

  defp ensure_safe_term!(_term), do: :ok
end
