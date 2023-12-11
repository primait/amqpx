ExUnit.start()

rabbit_manager_url = Application.get_env(:amqpx, :rabbit_manager_url)[:rabbit]
rabbit_two_manager_url = Application.get_env(:amqpx, :rabbit_manager_url)[:rabbit_two]

stream =
  Stream.unfold(100, fn x ->
    with {_, {_, 0}} <- {:rabbit, System.cmd("curl", ["-s", "--fail", rabbit_manager_url])},
         {_, {_, 0}} <- {:rabbit_two, System.cmd("curl", ["-s", "--fail", rabbit_two_manager_url])} do
      nil
    else
      {serv, _} ->
        IO.puts("Rabbit #{serv} not ready...")
        :timer.sleep(500)

        {:ok, x}
    end
  end)

Stream.run(stream)
