defmodule GRPC.Transport.HTTP2Test do
  use ExUnit.Case, async: true
  alias GRPC.Channel
  alias GRPC.Transport.HTTP2

  @channel %Channel{scheme: "http", host: "grpc.io"}
  @codec GRPC.Codec.Proto

  alias GRPC.Client.Stream


  test "client_headers/3 returns basic headers" do
    stream = %Stream{channel: @channel, path: "/foo/bar", codec: @codec}
    headers = HTTP2.client_headers(stream, %{grpc_version: "1.0.0"})

    assert headers == [
             {":method", "POST"},
             {":scheme", "http"},
             {":path", "/foo/bar"},
             {":authority", "grpc.io"},
             {"content-type", "application/grpc+proto"},
             {"user-agent", "grpc-elixir/1.0.0"},
             {"te", "trailers"}
           ]
  end

  test "client_headers/3 returns grpc-encoding" do
    stream = %Stream{channel: @channel, path: "/foo/bar", codec: @codec}
    headers = HTTP2.client_headers(stream, %{grpc_encoding: "gzip"})
    assert List.last(headers) == {"grpc-encoding", "gzip"}
  end

  test "client_headers/3 returns custom metadata" do
    stream = %Stream{channel: @channel, path: "/foo/bar", codec: @codec}
    headers = HTTP2.client_headers(stream, %{metadata: %{foo: "bar", foo1: :bar1}})
    assert [{"foo1", "bar1"}, {"foo", "bar"} | _] = Enum.reverse(headers)
  end

  test "client_headers/3 returns custom metadata with *-bin key" do
    stream = %Stream{channel: @channel, path: "/foo/bar", codec: @codec}

    headers =
      HTTP2.client_headers(stream, %{metadata: %{"key1-bin" => "abc", "key2-bin" => <<194, 128>>}})

    assert [{"key2-bin", "woA="}, {"key1-bin", "YWJj"} | _] = Enum.reverse(headers)
  end

  test "client_headers/3 rejects reserved headers in metadata" do
    stream = %Stream{channel: @channel, path: "/foo/bar", codec: @codec}

    metadata = %{
      "foo" => "bar",
      ":foo" => ":bar",
      "grpc-foo" => "bar",
      "content-type" => "bar",
      "te" => "et"
    }

    headers = HTTP2.client_headers(stream, %{metadata: metadata})
    assert [{"foo", "bar"}, {"te", "trailers"} | _] = Enum.reverse(headers)
  end

  test "client_headers/3 downcase keys of metadata" do
    stream = %Stream{channel: @channel, path: "/foo/bar", codec: @codec}
    metadata = %{:Foo => "bar", "Foo-Bar" => "bar"}
    headers = HTTP2.client_headers(stream, %{metadata: metadata})
    assert [{"foo-bar", "bar"}, {"foo", "bar"} | _] = Enum.reverse(headers)
  end

  test "client_headers/3 merges metadata with same keys" do
    stream = %Stream{channel: @channel, path: "/foo/bar", codec: @codec}
    headers = HTTP2.client_headers(stream, %{metadata: [foo: "bar", foo: :bar1]})
    assert [{"foo", "bar,bar1"} | _] = Enum.reverse(headers)
  end

  test "client_headers/3 has timeout with :timeout option" do
    stream = %Stream{channel: @channel, path: "/foo/bar", codec: @codec}
    headers = HTTP2.client_headers(stream, %{timeout: 5})
    assert [{"grpc-timeout", "5m"} | _] = Enum.reverse(headers)
  end

  test "client_headers/3 support custom content-type" do
    # TODO mairbek figure otu
    stream = %Stream{channel: @channel, path: "/foo/bar", codec: %{content_subtype: "proto"}}
    headers = HTTP2.client_headers(stream, %{})

    assert {_, "application/grpc+proto"} =
             Enum.find(headers, fn {key, _} -> key == "content-type" end)
  end
end
