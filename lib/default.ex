defmodule MeshxNode.Default do
  @moduledoc """
  Defaults for "node service" and upstream node connections registration parameters with service mesh adapter.
  """

  @doc """
  Returns service `params` required by `c:Meshx.ServiceMesh.start/4` as first argument.

  When node is transformed to distributed one using `Node.start/3` or `:net_kernel.start/1`, special downstream "node service" is registered with `:mesh_adapter` service mesh adapter using `c:Meshx.ServiceMesh.start/4` callback. `service_params/2` function return value is passed as first argument to this callback.

  Starting node by running `Node.start(:mynode@myhost)` will register "node service" with `params` set to: `{"mynode@myhost", "mynode@myhost"}`.

  Function can be overwritten by `:service_params` config option.
  """
  @spec service_params(name :: atom(), host :: nonempty_charlist()) :: {node :: String.t(), node :: String.t()}
  def service_params(name, host) do
    node = "#{name}@#{host}"
    {node, node}
  end

  @doc """
  Returns upstream `params` required by `c:Meshx.ServiceMesh.connect/3` as first argument.

  When connection to other node is requested by `Node.connect/1` or `:net_kernel.connect_node/1` `MeshxNode` will ask service mesh adapter to prepare mesh upstream endpoint associated with other node "node service" by running `c:Meshx.ServiceMesh.connect/3`. `upstream_params/1` function return value is passed as first argument to this callback.

  Function can be overwritten by `:upstream_params` config option.
  """
  @spec upstream_params(node :: atom()) :: node :: atom()
  def upstream_params(node), do: node

  @doc """
  Returns sidecar proxy service name used to register upstream connections to other nodes ("nodes services").

  Function return value is passed as third argument to `c:Meshx.ServiceMesh.connect/3`.

  Can be overwritten by `:upstream_proxy` config option.
  """
  @spec upstream_proxy(node :: atom(), my_node :: atom()) :: {my_node :: atom(), my_node :: atom()}
  def upstream_proxy(_node, my_node), do: {my_node, my_node}
end
