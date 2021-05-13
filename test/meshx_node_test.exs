defmodule MeshxNode.Test do
  use ExUnit.Case

  doctest MeshxNode.test("greets the world") do
    assert MeshxNode..hello() == :world
  end
end
