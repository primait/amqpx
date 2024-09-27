defmodule ConnectionTest do
  use ExUnit.Case

  import Amqpx.Core
  alias Amqpx.Connection

  @obfuscate_password false

  test "open connection with host as binary" do
    assert {:ok, conn} =
             Connection.open(
               username: "amqpx",
               password: "amqpx",
               host: "rabbit",
               obfuscate_password: @obfuscate_password
             )

    assert :ok = Connection.close(conn)
  end

  test "open connection with host as char list" do
    assert {:ok, conn} =
             Connection.open(
               username: "amqpx",
               password: "amqpx",
               host: 'rabbit',
               obfuscate_password: @obfuscate_password
             )

    assert :ok = Connection.close(conn)
  end

  test "open connection using uri" do
    assert {:ok, conn} = Connection.open("amqp://amqpx:amqpx@rabbit", obfuscate_password: @obfuscate_password)
    assert :ok = Connection.close(conn)
  end

  test "open connection using both uri and options" do
    assert {:ok, conn} =
             Connection.open("amqp://amqpx:amqpx@nonexistent:5672",
               host: 'rabbit',
               obfuscate_password: @obfuscate_password
             )

    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, name, and options" do
    assert {:ok, conn} =
             Connection.open("amqp://amqpx:amqpx@nonexistent:5672", "my-connection",
               host: 'rabbit',
               obfuscate_password: @obfuscate_password
             )

    assert :ok = Connection.close(conn)
  end

  test "override uri with options" do
    uri = "amqp://guest:amqpx@rabbit:5672"
    {:ok, amqp_params} = uri |> String.to_charlist() |> :amqp_uri.parse()

    params = [username: "amqpx", obfuscate_password: @obfuscate_password]
    default = amqp_params_network(amqp_params)
    record = Connection.merge_options(params, default)
    params = amqp_params_network(record)

    assert params[:username] == "amqpx"
    assert params[:password] == "amqpx"
    assert params[:host] == 'rabbit'
  end

  describe "ip resolution" do
    test "localhost is resolved as 127.0.0.1" do
      assert ['127.0.0.1'] = Connection.resolve_ips('localhost')
    end

    test "rabbit can be resolved into an ip" do
      assert [ip] = Connection.resolve_ips('rabbit')
      assert {:ok, _} = :inet.parse_address(ip)
    end

    test "unknown host will not be resolved" do
      assert ['nonexistent'] = Connection.resolve_ips('nonexistent')
    end
  end
end
