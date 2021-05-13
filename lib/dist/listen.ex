defmodule MeshxNode.Dist.Listen do
  @moduledoc false
  alias MeshxNode.App.C
  alias MeshxNode.Dist.NetAddress

  @opts [:binary, active: false, packet: 2]

  def listen(name, host) do
    if MeshxNode.adapter_started?() do
      with {:ok, service_id, address} <-
             C.mesh_adapter().start(
               C.service_params().(name, host),
               C.service_reg(),
               C.force_registration?(),
               C.timeout()
             ),
           {:ok, socket} <- gen_tcp_listen(address) do
        net_address = NetAddress.net_address(address)
        :persistent_term.put({C.lib(), :net_address}, net_address)
        :persistent_term.put({C.lib(), :mesh_name}, service_id)
        {:ok, {socket, net_address, creation()}}
      end
    else
      raise(
        "User defined service mesh adapter [#{C.mesh_adapter()}] not started. Giving up starting node [#{
          name
        }@#{host}]."
      )
    end
  end

  defp gen_tcp_listen({:tcp, ip, port}), do: :gen_tcp.listen(port, [ip: ip] ++ @opts)
  defp gen_tcp_listen({:uds, path}), do: :gen_tcp.listen(0, [ifaddr: {:local, path}] ++ @opts)

  defp creation() do
    # rand.uniform(2^32-1-3) + 3
    :rand.uniform(4_294_967_292) + 3
  end
end
