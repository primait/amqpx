defmodule ConnectionTest do
  use ExUnit.Case

  import Amqpx.Core
  import Mock

  alias Amqpx.{Connection, DNS}

  @obfuscate_password false

  @invalid_ip '192.168.1.1'
  @valid_ip '192.168.1.2'

  @open_options [
    username: "amqpx",
    password: "amqpx",
    host: "rabbit",
    obfuscate_password: @obfuscate_password
  ]

  test "open connection with host as binary" do
    assert {:ok, conn} = Connection.open(@open_options)
    assert :ok = Connection.close(conn)
  end

  test "open connection with host as char list" do
    assert {:ok, conn} = Connection.open(@open_options)
    assert :ok = Connection.close(conn)
  end

  test "open connection using uri" do
    assert {:ok, conn} = Connection.open("amqp://amqpx:amqpx@rabbit", obfuscate_password: @obfuscate_password)
    assert :ok = Connection.close(conn)
  end

  test "open connection using both uri and options" do
    assert {:ok, conn} =
             Connection.open("amqp://amqpx:amqpx@nonexistent:5672",
               host: ~c"rabbit",
               obfuscate_password: @obfuscate_password
             )

    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, name, and options" do
    assert {:ok, conn} =
             Connection.open("amqp://amqpx:amqpx@nonexistent:5672", "my-connection",
               host: ~c"rabbit",
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
    assert params[:host] == ~c"rabbit"
  end

  describe "connecting using dns name resolution" do
    test "Connection.open fails if none of the ips are reachable" do
      with_mock DNS, resolve_ips: fn _host -> [@invalid_ip] end do
        start = fn params, _name ->
          params = amqp_params_network(params)

          if params[:host] == @valid_ip do
            {:ok, :c.pid(0, 250, 0)}
          else
            {:error, :econnrefused}
          end
        end

        with_mock :amqp_connection, start: start do
          assert {:error, :econnrefused} = Connection.open(@open_options)
        end
      end
    end

    test "Connection.open retry every ip until one succeed" do
      with_mock DNS, resolve_ips: fn _host -> [@invalid_ip, @valid_ip] end do
        pid = :c.pid(0, 250, 0)

        start = fn params, _name ->
          params = amqp_params_network(params)

          if params[:host] == @valid_ip do
            {:ok, pid}
          else
            {:error, :econnrefused}
          end
        end

        with_mock :amqp_connection, start: start do
          assert {:ok, %Connection{pid: ^pid}} = Connection.open(@open_options)
        end
      end
    end

    test "Connection.open retry every ip until one succeed, reversed" do
      with_mock DNS, resolve_ips: fn _host -> [@valid_ip, @invalid_ip] end do
        pid = :c.pid(0, 250, 0)

        start = fn params, _name ->
          params = amqp_params_network(params)

          if params[:host] == @valid_ip do
            {:ok, pid}
          else
            {:error, :econnrefused}
          end
        end

        with_mock :amqp_connection, start: start do
          assert {:ok, %Connection{pid: ^pid}} = Connection.open(@open_options)
        end
      end
    end
  end

  describe "ip resolution" do
    test "localhost is resolved as 127.0.0.1" do
      assert [~c"127.0.0.1"] = DNS.resolve_ips(~c"localhost")
    end

    test "rabbit can be resolved into an ip" do
      assert [ip] = DNS.resolve_ips(~c"rabbit")
      assert {:ok, _} = :inet.parse_address(ip)
    end

    test "unknown host will not be resolved" do
      assert [~c"nonexistent"] = DNS.resolve_ips(~c"nonexistent")
    end
  end
end
