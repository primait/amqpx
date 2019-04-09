defmodule PrimaAmqpTest do
  use ExUnit.Case
  doctest PrimaAmqp

  test "greets the world" do
    assert PrimaAmqp.hello() == :world
  end
end
