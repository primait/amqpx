defmodule ConnectionTest do
  use ExUnit.Case

  import Amqpx.Core
  alias Amqpx.Connection

  @obfuscate_password false

  test "open connection with host as binary" do
    assert {:ok, conn} = Connection.open(host: "rabbit", obfuscate_password: @obfuscate_password)
    assert :ok = Connection.close(conn)
  end

  test "open connection with host as char list" do
    assert {:ok, conn} = Connection.open(host: 'rabbit', obfuscate_password: @obfuscate_password)
    assert :ok = Connection.close(conn)
  end

  test "open connection using uri" do
    assert {:ok, conn} = Connection.open("amqp://rabbit", obfuscate_password: @obfuscate_password)
    assert :ok = Connection.close(conn)
  end

  test "open connection using both uri and options" do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent:5672", host: 'rabbit', obfuscate_password: @obfuscate_password)

    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, name, and options" do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent:5672", "my-connection",
               host: 'rabbit',
               obfuscate_password: @obfuscate_password
             )

    assert :ok = Connection.close(conn)
  end

  test "override uri with options" do
    uri = "amqp://guest:guest@rabbit:5672"
    {:ok, amqp_params} = uri |> String.to_charlist() |> :amqp_uri.parse()

    record =
      Connection.merge_options_to_amqp_params(amqp_params, username: "guest", obfuscate_password: @obfuscate_password)

    params = amqp_params_network(record)

    assert params[:username] == "guest"
    assert params[:password] == "guest"
    assert params[:host] == 'rabbit'
  end
end
