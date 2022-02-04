ExUnit.start()

stream =
  Stream.unfold(100, fn x ->
    with {_, 0} <- System.cmd("curl", ["-s", "--fail", "rabbit:15672"]),
         {_, 0} <- System.cmd("curl", ["-s", "--fail", "rabbit_two:15672"]) do
      nil
    else
      _ ->
        IO.puts("Rabbit not ready...")
        :timer.sleep(500)

        {:ok, x}
    end
  end)

Stream.run(stream)
