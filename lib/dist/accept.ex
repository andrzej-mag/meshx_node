defmodule MeshxNode.Dist.Accept do
  @moduledoc false
  alias MeshxNode.App.C
  alias MeshxNode.Dist.{Controller, HSData}

  @spawn_opts [:link, priority: :max]

  def accept(listen_socket),
    do: Process.spawn(__MODULE__, :accept_loop, [self(), listen_socket], @spawn_opts)

  def accept_connection(acceptor_pid, dist_ctrl, my_node, allowed, setup_time),
    do:
      Process.spawn(
        __MODULE__,
        :accept_supervisor,
        [self(), acceptor_pid, dist_ctrl, my_node, allowed, setup_time],
        @spawn_opts
      )

  def accept_loop(kernel, listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        dist_ctrl = Controller.spawn_dist_controller(socket)
        Controller.flush_controller(dist_ctrl, socket)
        :gen_tcp.controlling_process(socket, dist_ctrl)
        Controller.flush_controller(dist_ctrl, socket)

        case :inet.sockname(listen_socket) do
          {:ok, {:local, _path}} -> send(kernel, {:accept, self(), dist_ctrl, :local, :stream})
          {:ok, {_ip, _port}} -> send(kernel, {:accept, self(), dist_ctrl, :inet, :tcp})
        end

        receive do
          {^kernel, :controller, supervisor_pid} ->
            Controller.call_controller(dist_ctrl, {:supervisor, supervisor_pid})
            send(supervisor_pid, {self(), :controller})

          {^kernel, :unsupported_protocol} ->
            exit(:unsupported_protocol)
        end

        accept_loop(kernel, listen_socket)

      {:error, :closed} ->
        exit(:closing_connection)

      err ->
        exit(err)
    end
  end

  def accept_supervisor(kernel, acceptor_pid, dist_ctrl, my_node, allowed, setup_time) do
    receive do
      {^acceptor_pid, :controller} ->
        %HSData{
          kernel_pid: kernel,
          this_node: my_node,
          socket: dist_ctrl,
          timer: :dist_util.start_timer(setup_time),
          allowed: allowed,
          f_address: fn _socket, _node ->
            # FIXME: _socket is a pid and not a port in this code?
            # todo add fallback to Controller or: :inet.peername(socket)
            :persistent_term.get({C.lib(), :net_address})
          end
        }
        |> HSData.build_hsdata(dist_ctrl)
        |> :dist_util.handshake_other_started()
    end
  end
end
