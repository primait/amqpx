defmodule Amqpx.Connection do
  @moduledoc """
  Functions to operate on Connections.
  """

  import Amqpx.Core

  alias Amqpx.{Connection, Helper}

  defstruct [:pid]
  @type t :: %Connection{pid: pid}

  @default_params [
    username: "guest",
    password: "guest",
    virtual_host: "/",
    host: 'localhost',
    port: 5672,
    channel_max: 0,
    frame_max: 0,
    heartbeat: 10,
    connection_timeout: 50_000,
    ssl_options: :none,
    client_properties: [],
    socket_options: [],
    auth_mechanisms: [
      &:amqp_auth_mechanisms.plain/3,
      &:amqp_auth_mechanisms.amqplain/3
    ]
  ]

  @doc """
  Opens a new connection without a name.

  Behaves exactly like `open(options_or_uri, :undefined)`. See `open/2`.
  """
  @spec open(keyword | String.t()) :: {:ok, t()} | {:error, atom()} | {:error, any()}
  def open(options_or_uri \\ []) when is_binary(options_or_uri) or is_list(options_or_uri) do
    open(options_or_uri, :undefined)
  end

  @doc """
  Opens an new Connection to an Amqpx broker.

  The connections created by this module are supervised under  amqp_client's supervision tree.
  Please note that connections do not get restarted automatically by the supervision tree in
  case of a failure. If you need robust connections and channels, use monitors on the returned
  connection PID.

  This function can be called in three ways:

    * with a list of options and a name
    * with an Amqpx URI and a name
    * with an Amqpx URI and a list of options (in this case, the options are merged with
      the Amqpx URI, taking precedence on same keys)

  ## Options

    * `:username` - The name of a user registered with the broker (defaults to `"guest"`);
    * `:password` - The password of user (defaults to `"guest"`);
    * `:virtual_host` - The name of a virtual host in the broker (defaults to `"/"`);
    * `:host` - The hostname of the broker (defaults to `"localhost"`);
    * `:port` - The port the broker is listening on (defaults to `5672`);
    * `:channel_max` - The channel_max handshake parameter (defaults to `0`);
    * `:frame_max` - The frame_max handshake parameter (defaults to `0`);
    * `:heartbeat` - The hearbeat interval in seconds (defaults to `10`);
    * `:connection_timeout` - The connection timeout in milliseconds (defaults to `50000`);
    * `:ssl_options` - Enable SSL by setting the location to cert files (defaults to `:none`);
    * `:client_properties` - A list of extra client properties to be sent to the server, defaults to `[]`;
    * `:socket_options` - Extra socket options. These are appended to the default options. \
                          See http://www.erlang.org/doc/man/inet.html#setopts-2 and http://www.erlang.org/doc/man/gen_tcp.html#connect-4 \
                          for descriptions of the available options.

  ## Enabling SSL

  To enable SSL, supply the following in the `ssl_options` field:

    * `cacertfile` - Specifies the certificates of the root Certificate Authorities that we wish to implicitly trust;
    * `certfile` - The client's own certificate in PEM format;
    * `keyfile` - The client's private key in PEM format;

  ### Example

  ```
  Amqpx.Connection.open port: 5671,
                       ssl_options: [cacertfile: '/path/to/testca/cacert.pem',
                                     certfile: '/path/to/client/cert.pem',
                                     keyfile: '/path/to/client/key.pem',
                                     # only necessary with intermediate CAs
                                     # depth: 2,
                                     verify: :verify_peer,
                                     fail_if_no_peer_cert: true]
  ```

  ## Connection name

  RabbitMQ supports user-specified connection names since version 3.6.2.

  Connection names are human-readable strings that will be displayed in the management UI.
  Connection names do not have to be unique and cannot be used as connection identifiers.

  If the name is `:undefined`, the connection is not registered with any name.

  ## Examples

      iex> options = [host: "localhost", port: 5672, virtual_host: "/", username: "guest", password: "guest"]
      iex> Amqpx.Connection.open(options, :undefined)
      {:ok, %Amqpx.Connection{}}

      iex> Amqpx.Connection.open("amqp://guest:guest@localhost", port: 5673)
      {:ok, %Amqpx.Connection{}}

      iex> Amqpx.Connection.open("amqp://guest:guest@localhost", "a-connection-with-a-name")
      {:ok, %Amqpx.Connection{}}

  """
  @spec open(keyword | String.t(), String.t() | :undefined | keyword) ::
          {:ok, t()} | {:error, atom()} | {:error, any()}
  def open(options_or_uri, options_or_name)

  def open(uri, name) when is_binary(uri) and (is_binary(name) or name == :undefined) do
    open(uri, name, _options = [])
  end

  def open(options, name) when is_list(options) and (is_binary(name) or name == :undefined) do
    do_open(options, @default_params, name)
  end

  def open(uri, options) when is_binary(uri) and is_list(options) do
    open(uri, :undefined, options)
  end

  @doc """
  Opens a new connection with a name, merging the given Amqpx URI and options.

  This function opens a new connection by merging the given Amqpx URI `uri` and
  the given `options` and assigns it the name `name`.

  The options in `options` take precedence over the values in `uri`.

  See `open/2` for options.

  ## Examples

      iex> Amqpx.Connection.open("amqp://guest:guest@localhost", "a-connection-name", port: 5673)
      {:ok, %Amqpx.Connection{}}

  """
  @spec open(String.t(), String.t() | :undefined, keyword) ::
          {:ok, t()} | {:error, atom()} | {:error, any()}
  def open(uri, name, options) when is_binary(uri) and is_list(options) do
    case uri |> String.to_charlist() |> :amqp_uri.parse() do
      {:ok, amqp_params} ->
        amqp_params = amqp_params_network(amqp_params)
        do_open(options, amqp_params, name)

      error ->
        error
    end
  end

  @doc false
  @spec merge_options(keyword, keyword) :: tuple
  def merge_options(params, default) do
    default = normalize_ssl_options(default)

    amqp_params_network(
      username: keys_get(params, default, :username),
      password: Helper.get_password(params, default),
      virtual_host: keys_get(params, default, :virtual_host),
      host: params |> keys_get(default, :host) |> to_charlist(),
      port: keys_get(params, default, :port),
      channel_max: keys_get(params, default, :channel_max),
      frame_max: keys_get(params, default, :frame_max),
      heartbeat: keys_get(params, default, :heartbeat),
      connection_timeout: keys_get(params, default, :connection_timeout),
      ssl_options: keys_get(params, default, :ssl_options),
      client_properties: keys_get(params, default, :client_properties),
      socket_options: keys_get(params, default, :socket_options),
      auth_mechanisms: keys_get(params, default, :auth_mechanisms)
    )
  end

  # Gets the value from k1. If empty, gets the value from k2.
  defp keys_get(k1, k2, key) do
    Keyword.get(k1, key, Keyword.get(k2, key))
  end

  @doc """
  Closes an open Connection.
  """
  @spec close(t) :: :ok | {:error, any}
  def close(conn) do
    case :amqp_connection.close(conn.pid, 5_000) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec do_open(Keyword.t(), Keyword.t(), String.t()) :: {:ok, t()} | {:error, atom()} | {:error, any()}
  defp do_open(params, default_params, name) do
    params
    |> keys_get(default_params, :host)
    |> to_charlist()
    |> resolve_ips()
    |> Enum.reduce_while(nil, fn ip, _ ->
      amqp_params = params |> Keyword.put(:host, ip) |> merge_options(default_params)

      case :amqp_connection.start(amqp_params, name) do
        {:ok, pid} ->
          IO.inspect("Connection opened to: #{ip}")
          {:halt, {:ok, %Connection{pid: pid}}}
        error -> {:cont, error}
      end
    end)
  end

  defp normalize_ssl_options(options) when is_list(options) do
    for {k, v} <- options do
      if k in [:cacertfile, :certfile, :keyfile] do
        {k, to_charlist(v)}
      else
        {k, v}
      end
    end
  end

  defp normalize_ssl_options(options), do: options

  # Resolves the IP addresses of a given hostname. If the hostname cannot be resolved, it returns the hostname itself.
  @spec resolve_ips(charlist) :: [charlist]
  def resolve_ips(host) do
    case :inet.gethostbyname(host) do
      {:ok, {:hostent, _, _, _, _, ips}} ->
        ips |> Enum.map(&:inet.ntoa/1) |> Enum.dedup()
      _ -> [host]
    end
  end
end
