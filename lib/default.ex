defmodule MeshxNode.Default do
  @moduledoc """
  Defaults for service and upstream registration.

  todo: Documentation will be provided at a later date.
  """

  def service_params(name, host) do
    node = "#{name}@#{host}"
    {node, node}
  end

  def upstream_params(node), do: node
  def upstream_proxy(_node, my_node), do: {my_node, my_node}
end
