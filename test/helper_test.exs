defmodule HelperTest do
  use ExUnit.Case

  alias Amqpx.{Channel, Connection, Queue, Exchange, Helper}

  setup do
    {:ok, conn} = Connection.open(Application.fetch_env!(:amqpx, :amqp_connection))
    {:ok, chan} = Channel.open(conn)
    on_exit(fn -> :ok = Connection.close(conn) end)
    {:ok, conn: conn, chan: chan}
  end

  test "declare a queue with a bind to an exchange and a dead letter queue with an errored exchange", meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()

    queue_name_errored = "#{queue_name}_errored"
    exchange_name_errored = "#{exchange_name}_errored"

    assert :ok =
             Helper.declare(meta[:chan], %{
               exchanges: [
                 %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
               ],
               opts: [
                 durable: true,
                 arguments: [
                   {"x-dead-letter-exchange", :longstr, exchange_name_errored},
                   {"x-dead-letter-routing-key", :longstr, routing_key_name}
                 ]
               ],
               queue: queue_name
             })

    assert :ok = Queue.unbind(meta[:chan], queue_name, exchange_name)
    assert :ok = Queue.unbind(meta[:chan], queue_name_errored, exchange_name_errored)
    assert :ok = Exchange.delete(meta[:chan], exchange_name)
    assert :ok = Exchange.delete(meta[:chan], exchange_name_errored)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue_name)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue_name_errored)
  end

  test "configuration without an exchange and with routing key set with correct dead letter queue should not raise an error",
       meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()

    queue_name_errored = "#{queue_name}_errored"

    assert :ok =
             Helper.declare(meta[:chan], %{
               exchanges: [
                 %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
               ],
               opts: [
                 durable: true,
                 arguments: [
                   {"x-dead-letter-exchange", :longstr, ""},
                   {"x-dead-letter-routing-key", :longstr, queue_name_errored}
                 ]
               ],
               queue: queue_name
             })

    assert :ok = Queue.unbind(meta[:chan], queue_name, exchange_name)
    assert :ok = Exchange.delete(meta[:chan], exchange_name)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue_name)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue_name_errored)
  end

  test "bad configuration with dead letter exchange empty and routing key set should raise an error", meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()

    queue_name_errored = "BadDeadLetterQueue"

    assert_raise RuntimeError,
                 "If x-dead-letter-exchange is an empty string, x-dead-letter-routing-key should be '#{queue_name}_errored' instead of '#{queue_name_errored}'",
                 fn ->
                   Helper.declare(meta[:chan], %{
                     exchanges: [
                       %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
                     ],
                     opts: [
                       durable: true,
                       arguments: [
                         {"x-dead-letter-exchange", :longstr, ""},
                         {"x-dead-letter-routing-key", :longstr, queue_name_errored}
                       ]
                     ],
                     queue: queue_name
                   })
                 end
  end

  test "bad configuration with empty dead letter exchange and routing key should raise an error", meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()

    assert_raise RuntimeError,
                 "If x-dead-letter-exchange is an empty string, x-dead-letter-routing-key should be '#{queue_name}_errored' instead of ''",
                 fn ->
                   Helper.declare(meta[:chan], %{
                     exchanges: [
                       %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
                     ],
                     opts: [
                       durable: true,
                       arguments: [
                         {"x-dead-letter-exchange", :longstr, ""},
                         {"x-dead-letter-routing-key", :longstr, ""}
                       ]
                     ],
                     queue: queue_name
                   })
                 end
  end

  test "bad configuration with empty dead letter exchange and routing key is not a blocking error if the check is disabled",
       meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()
    wrong_dead_letter_key = rand_name()

    Application.put_env(:amqpx, :skip_dead_letter_routing_key_check_for, [wrong_dead_letter_key])

    :ok =
      Helper.declare(meta[:chan], %{
        exchanges: [
          %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
        ],
        opts: [
          durable: true,
          arguments: [
            {"x-dead-letter-exchange", :longstr, ""},
            {"x-dead-letter-routing-key", :longstr, wrong_dead_letter_key}
          ]
        ],
        queue: queue_name
      })

    Application.put_env(:amqpx, :skip_dead_letter_routing_key_check_for, [])
  end

  test "declare/2 propagates x-queue-type to dead letter queue declaration",
       meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()
    dead_letter_queue = "#{queue_name}_errored"

    assert :ok ==
             Helper.declare(meta[:chan], %{
               exchanges: [
                 %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
               ],
               opts: [
                 durable: true,
                 arguments: [
                   {"x-dead-letter-exchange", :longstr, ""},
                   {"x-dead-letter-routing-key", :longstr, dead_letter_queue},
                   {"x-queue-type", :longstr, "quorum"}
                 ]
               ],
               queue: queue_name
             })

    rabbit_manager = Application.get_env(:amqpx, :rabbit_manager_url).rabbit
    amqp_conn = Application.get_env(:amqpx, :amqp_connection)
    credentials = Base.encode64("#{amqp_conn[:username]}:#{amqp_conn[:password]}")
    headers = [{~c"Authorization", "Basic #{credentials}"}]

    assert {:ok, {{_, 200, ~c"OK"}, _headers, body}} =
             :httpc.request(:get, {"http://#{rabbit_manager}/api/queues", headers}, [], [])

    assert {:ok, queues} = Jason.decode(body)

    assert %{"durable" => true, "arguments" => %{"x-queue-type" => "quorum"}} =
             Enum.find(queues, fn q -> match?(%{"name" => ^queue_name}, q) end)

    assert %{"durable" => true, "arguments" => %{"x-queue-type" => "quorum"}} =
             Enum.find(queues, fn q -> match?(%{"name" => ^dead_letter_queue}, q) end)
  end

  test "consumers_supervisor_configuration/1 duplicates the configuration based on concurrency_level" do
    confs = [
      %{concurrency_level: 2, my_conf: :concurrent_conf},
      %{my_conf: :normal_conf}
    ]

    specs = Helper.consumers_supervisor_configuration(confs)

    # Configs are duplicated according to concurrency_level
    actual_confs = Enum.map(specs, fn %{start: {Amqpx.Gen.Consumer, :start_link, [conf]}} -> conf.my_conf end)
    assert actual_confs == [:concurrent_conf, :concurrent_conf, :normal_conf]

    # They all have different ids
    unique_ids = specs |> Enum.map(& &1.id) |> Enum.uniq()
    assert length(unique_ids) == 3
  end

  test "consumers_supervisor_configuration/1 raises if concurrency_level is not a positive integer" do
    conf = %{concurrency_level: -2, my_conf: :negative_conf}

    assert_raise FunctionClauseError, fn -> Helper.consumers_supervisor_configuration([conf]) end
  end

  defp rand_name do
    :crypto.strong_rand_bytes(8) |> Base.encode64()
  end
end
