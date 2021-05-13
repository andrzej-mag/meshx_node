defmodule MeshxNode.Dist.HSData do
  @moduledoc false
  use MeshxNode.Hrl, record_name: :hs_data, hrl_file_path: "kernel/include/dist_util.hrl"
  alias MeshxNode.Dist.{Controller, HSData}

  def build_hsdata(custom_hsdata, dist_ctrl) do
    tick_handler = Controller.call_controller(dist_ctrl, :tick_handler)
    socket = Controller.call_controller(dist_ctrl, :socket)

    default_hsdata = %HSData{
      this_flags: 0,
      f_send: fn ctrl, packet -> Controller.call_controller(ctrl, {:send, packet}) end,
      f_recv: fn ctrl, length, timeout ->
        case Controller.call_controller(ctrl, {:recv, length, timeout}) do
          {:ok, bin} when is_binary(bin) -> {:ok, :erlang.binary_to_list(bin)}
          other -> other
        end
      end,
      f_setopts_pre_nodeup: fn ctrl -> Controller.call_controller(ctrl, :pre_nodeup) end,
      f_setopts_post_nodeup: fn ctrl -> Controller.call_controller(ctrl, :post_nodeup) end,
      f_getll: fn ctrl -> Controller.call_controller(ctrl, :getll) end,
      mf_tick: fn ctrl when ctrl == dist_ctrl -> send(tick_handler, :tick) end,
      mf_getstat: fn ctrl when ctrl == dist_ctrl ->
        case :inet.getstat(socket, [:recv_cnt, :send_cnt, :send_pend]) do
          {:ok, stat} -> split_stat(stat, 0, 0, 0)
          err -> err
        end
      end,
      mf_setopts: fn ctrl, options when ctrl == dist_ctrl ->
        MeshxNode_dist.setopts(socket, options)
      end,
      mf_getopts: fn ctrl, options when ctrl == dist_ctrl ->
        MeshxNode_dist.getopts(socket, options)
      end,
      f_handshake_complete: fn ctrl, node, d_handle ->
        Controller.call_controller(ctrl, {:handshake_complete, node, d_handle})
      end
    }

    Map.merge(custom_hsdata, default_hsdata, fn _k, v1, v2 -> if !is_nil(v2), do: v2, else: v1 end)
    |> HSData.to_record()
  end

  defp split_stat([{:recv_cnt, r} | stat], _, w, p), do: split_stat(stat, r, w, p)
  defp split_stat([{:send_cnt, w} | stat], r, _, p), do: split_stat(stat, r, w, p)
  defp split_stat([{:send_pend, p} | stat], r, w, _), do: split_stat(stat, r, w, p)
  defp split_stat([], r, w, p), do: {:ok, r, w, p}
end
