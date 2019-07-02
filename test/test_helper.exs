Enum.each(Application.get_env(:amqpx, :consumers), &Amqpx.Consumer.start_link(&1))
Amqpx.Producer.start_link(Application.get_env(:amqpx, :producer))

ExUnit.start()
