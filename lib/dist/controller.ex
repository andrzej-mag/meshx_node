defmodule MeshxNode.Dist.Controller do
  @moduledoc false
  require Logger

  def call_controller(dist_ctrl, message) do
    ref = :erlang.monitor(:process, dist_ctrl)
    send(dist_ctrl, {ref, self(), message})

    receive do
      {^ref, result} ->
        Process.demonitor(ref, [:flush])
        result

      {'DOWN', ^ref, :process, ^dist_ctrl, reason} ->
        exit({:dist_controller_exit, reason})
    end
  end

  def flush_controller(pid, socket) do
    receive do
      {:tcp, ^socket, data} ->
        send(pid, {:tcp, socket, data})
        flush_controller(pid, socket)

      {:tcp_closed, ^socket} ->
        send(pid, {:tcp_closed, socket})
        flush_controller(pid, socket)
    after
      0 ->
        :ok
    end
  end

  @dist_controller_common_spawn_opts [message_queue_data: :off_heap, fullsweep_after: 0]

  def spawn_dist_controller(socket) do
    Process.spawn(
      fn -> dist_controller_setup(socket) end,
      [priority: :max] ++ @dist_controller_common_spawn_opts
    )
  end

  defp dist_controller_setup(socket) do
    tick_handler =
      Process.spawn(
        fn -> tick_handler(socket) end,
        [:link, priority: :max] ++ @dist_controller_common_spawn_opts
      )

    dist_controller_setup_loop(socket, tick_handler, :undefined)
  end

  defp dist_controller_setup_loop(socket, tick_handler, sup) do
    receive do
      {:tcp_closed, ^socket} ->
        exit(:connection_closed)

      {ref, from, {:supervisor, pid}} ->
        res = Process.link(pid)
        send(from, {ref, res})
        dist_controller_setup_loop(socket, tick_handler, pid)

      {ref, from, :tick_handler} ->
        send(from, {ref, tick_handler})
        dist_controller_setup_loop(socket, tick_handler, sup)

      {ref, from, :socket} ->
        send(from, {ref, socket})
        dist_controller_setup_loop(socket, tick_handler, sup)

      {ref, from, {:send, packet}} ->
        res = :gen_tcp.send(socket, packet)
        send(from, {ref, res})
        dist_controller_setup_loop(socket, tick_handler, sup)

      {ref, from, {:recv, length, timeout}} ->
        res = :gen_tcp.recv(socket, length, timeout)

        case res do
          {:ok, "snot_allowed"} -> Logger.warn("** Connection attempt to disallowed node **")
          _ -> :ok
        end

        send(from, {ref, res})
        dist_controller_setup_loop(socket, tick_handler, sup)

      {ref, from, :getll} ->
        send(from, {ref, {:ok, self()}})
        dist_controller_setup_loop(socket, tick_handler, sup)

      {ref, from, :pre_nodeup} ->
        res = :inet.setopts(socket, active: false, packet: 4)
        send(from, {ref, res})
        dist_controller_setup_loop(socket, tick_handler, sup)

      {ref, from, :post_nodeup} ->
        res = :inet.setopts(socket, active: false, packet: 4)
        send(from, {ref, res})
        dist_controller_setup_loop(socket, tick_handler, sup)

      {ref, from, {:handshake_complete, _node, d_handle}} ->
        send(from, {ref, :ok})

        input_handler =
          Process.spawn(
            fn -> dist_controller_input_handler(d_handle, socket, sup) end,
            [:link] ++ @dist_controller_common_spawn_opts
          )

        flush_controller(input_handler, socket)
        :gen_tcp.controlling_process(socket, input_handler)
        flush_controller(input_handler, socket)
        :erlang.dist_ctrl_input_handler(d_handle, input_handler)
        send(input_handler, d_handle)
        Process.flag(:priority, :normal)
        :erlang.dist_ctrl_get_data_notification(d_handle)
        dist_controller_output_handler(d_handle, socket)
    end
  end

  @active_input 10
  defp dist_controller_input_handler(d_handle, socket, sup) do
    Process.link(sup)

    receive do
      ^d_handle ->
        dist_controller_input_loop(d_handle, socket, 0)
    end
  end

  defp dist_controller_input_loop(d_handle, socket, n) when n <= @active_input / 2 do
    :inet.setopts(socket, active: @active_input - n)
    dist_controller_input_loop(d_handle, socket, @active_input)
  end

  defp dist_controller_input_loop(d_handle, socket, n) do
    receive do
      {:tcp, socket, data} ->
        try do
          :erlang.dist_ctrl_put_data(d_handle, data)
        catch
          _, _ -> death_row()
        end

        dist_controller_input_loop(d_handle, socket, n - 1)

      {:tcp_closed, ^socket} ->
        exit(:connection_closed)

      _ ->
        dist_controller_input_loop(d_handle, socket, n)
    end
  end

  defp dist_controller_output_handler(d_handle, socket) do
    receive do
      :dist_data ->
        try do
          dist_controller_send_data(d_handle, socket)
        catch
          _, _ -> death_row()
        end

        dist_controller_output_handler(d_handle, socket)

      _ ->
        dist_controller_output_handler(d_handle, socket)
    end
  end

  defp dist_controller_send_data(d_handle, socket) do
    case :erlang.dist_ctrl_get_data(d_handle) do
      :none ->
        :erlang.dist_ctrl_get_data_notification(d_handle)

      data ->
        socket_send(socket, data)
        dist_controller_send_data(d_handle, socket)
    end
  end

  defp tick_handler(socket) do
    receive do
      :tick ->
        socket_send(socket, '')

      _ ->
        :ok
    end

    tick_handler(socket)
  end

  defp socket_send(socket, data) do
    try do
      :gen_tcp.send(socket, data)
    catch
      {type, reason} -> death_row({:send_error, {type, reason}})
    else
      :ok ->
        :ok

      {:error, reason} ->
        death_row({:send_error, reason})
    end
  end

  defp death_row(), do: death_row(:connection_closed)

  defp death_row(reason) do
    receive do
      any -> any
    after
      5000 ->
        exit(reason)
    end
  end
end
