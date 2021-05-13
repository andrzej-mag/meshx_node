defmodule MeshxNode_dist do
  @moduledoc false
  alias MeshxNode.App.C
  alias MeshxNode.Dist.{Accept, Listen, Setup}

  def listen(name) do
    {:ok, host} = :inet.gethostname()
    listen(name, host)
  end

  defdelegate listen(name, host), to: Listen
  defdelegate accept(listen_socket), to: Accept
  defdelegate accept_connection(acceptor_pid, dist_ctrl, my_node, allowed, setup_time), to: Accept
  defdelegate setup(node, type, my_node, long_or_short_names, setup_time), to: Setup
  def address(), do: :persistent_term.get({C.lib(), :net_address})
  def select(_node_name), do: true

  def close(listen_socket) do
    node = :persistent_term.get({C.lib(), :mesh_name}, nil)
    if !is_nil(node), do: spawn(fn -> C.mesh_adapter().stop(node) end)
    :persistent_term.erase({C.lib(), :net_address})
    :persistent_term.erase({C.lib(), :mesh_name})
    :gen_tcp.close(listen_socket)

    case :inet.sockname(listen_socket) do
      {:ok, {:local, socket_path}} -> File.rm(socket_path)
      _ -> :ok
    end
  end

  def setopts(socket, options) do
    invalid? =
      Keyword.has_key?(options, :active) or
        Keyword.has_key?(options, :deliver) or
        Keyword.has_key?(options, :packet)

    if invalid?, do: {:error, {:badopts, options}}, else: :inet.setopts(socket, options)
  end

  def getopts(socket, options),
    do: :inet.getopts(socket, options)
end
