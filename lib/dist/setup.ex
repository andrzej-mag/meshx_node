defmodule MeshxNode.Dist.Setup do
  @moduledoc false
  require Logger
  alias MeshxNode.App.C
  alias MeshxNode.Dist.{Controller, HSData, NetAddress}

  @erl_dist_ver 6
  @spawn_opts [:link, priority: :max]
  @socket_opts [:binary, active: false, packet: 2]
  @retries 100
  @sleep_time 100

  def setup(node, type, my_node, _long_or_short_names, setup_time) do
    Process.spawn(
      __MODULE__,
      :setup_supervisor,
      [self(), node, type, my_node, setup_time],
      @spawn_opts
    )
  end

  def setup_supervisor(kernel, node, type, my_node, setup_time) do
    with {:ok, [ok: addr]} <-
           C.mesh_adapter().connect(
             [C.upstream_params().(node)],
             C.upstream_reg(),
             C.upstream_proxy().(node, my_node)
           ),
         {:ok, socket} <- connect(addr) do
      dist_ctrl = Controller.spawn_dist_controller(socket)
      Controller.call_controller(dist_ctrl, {:supervisor, self()})
      Controller.flush_controller(dist_ctrl, socket)
      :gen_tcp.controlling_process(socket, dist_ctrl)
      Controller.flush_controller(dist_ctrl, socket)

      net_address =
        %NetAddress{(NetAddress.net_address(addr) |> NetAddress.from_record()) | address: []}
        |> NetAddress.to_record()

      %HSData{
        kernel_pid: kernel,
        other_node: node,
        this_node: my_node,
        socket: dist_ctrl,
        timer: :dist_util.start_timer(setup_time),
        other_version: @erl_dist_ver,
        request_type: type,
        f_address: fn _dist_ctrlr, _node -> net_address end
      }
      |> HSData.build_hsdata(dist_ctrl)
      |> :dist_util.handshake_we_started()
    else
      err ->
        Logger.warn(inspect(err))
        :dist_util.shutdown(Mesh, 744, node)
    end
  end

  defp connect(addr, retry \\ 0) do
    case gen_conn(addr) do
      {:ok, socket} ->
        {:ok, socket}

      _ ->
        if retry < @retries do
          Process.sleep(@sleep_time)
          connect(addr, retry + 1)
        else
          {:error, :timedout}
        end
    end
  end

  defp gen_conn({:tcp, ip, port}), do: :gen_tcp.connect(ip, port, @socket_opts)
  defp gen_conn({:uds, path}), do: :gen_tcp.connect({:local, path}, 0, @socket_opts)
end
