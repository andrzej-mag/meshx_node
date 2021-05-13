defmodule MeshxNode do
  @readme File.read!("docs/README.md") |> String.split("<!-- MDOC !-->") |> Enum.fetch!(1)

  @moduledoc """
  #{@readme}

  ## Configuration options
  * `:mesh_adapter` - Required. Specifies service mesh adapter module. Example: `mesh_adapter: MeshxConsul`.
  * `:service_params` - 2-arity function executed when distribution is started. First function argument is node "short name", second argument is host name. For example: `:mynode@myhost` translates to `(:mynode, 'myhost')`. Function should return first argument `params` passed to `c:Meshx.ServiceMesh.start/4`, for example: `"mynode@myhost"`. Default: `&MeshxNode.Default.service_params/2`.
  * `:service_reg` - service registration template passed as second argument to `c:Meshx.ServiceMesh.start/4`. Default: `[]`.
  * `:upstream_params` - 1-arity function executed when connection between nodes is setup. Function argument is remote node name: running `Node.connect(:node1@myhost)` will invoke function with `(:node1@myhost)`. Function should return first argument `params` passed to `c:Meshx.ServiceMesh.connect/3`, for example: `"node1@myhost"`. Default: `&MeshxNode.Default.upstream_params/1`.
  * `:upstream_reg` - upstream registration template passed as second argument to `c:Meshx.ServiceMesh.connect/3`. Default: `nil`.
  * `:upstream_proxy` - 2-arity function executed when connection between nodes is setup. Function arguments are `(:remote_node_name, :local_node_name)`. Function should return third argument `proxy` passed to `c:Meshx.ServiceMesh.connect/3`, for example: `{"node1@myhost", "node1@myhost"}`. Default: `&MeshxNode.Default.upstream_proxy/2`.
  * `:force_registration?` - boolean passed as third argument to `c:Meshx.ServiceMesh.start/4`. Default: `false`.
  * `:timeout` - timeout value passed as fourth argument to `c:Meshx.ServiceMesh.start/4`. Default: `5000`.

  ## Credits
  `MeshxNode` distribution module is based on [example code](https://github.com/erlang/otp/blob/master/lib/kernel/examples/erl_uds_dist/src/erl_uds_dist.erl) by Jérôme de Bretagne.
  """

  require Logger
  alias MeshxNode.App.C

  @retries 100
  @sleep_time 100

  @doc """
  Turns node into a distributed and sets node magic cookie.

  Function checks if service mesh adapter application specified by `:mesh_adapter` configuration entry was already started. If mesh adapter is started `Node.start/3` and `Node.set_cookie/2` are executed. Otherwise it will sleep for 100msec and retry, retries limit is 100.

  Function arguments are same as `Node.start/3`.
  """
  @spec start(node :: node(), cookie :: atom(), :longnames | :shortnames, non_neg_integer()) :: {:ok, pid()} | {:error, term()}
  def start(node, cookie, type \\ :longnames, tick_time \\ 15000), do: start_retry(node, cookie, type, tick_time)

  @doc """
  Asynchronous version of `start/4`.

  Function spawns `start/4` using `Kernel.spawn/3`.
  """
  @spec spawn_start(node :: node(), cookie :: atom(), :longnames | :shortnames, non_neg_integer()) :: pid()
  def spawn_start(name, cookie, type \\ :longnames, tick_time \\ 15000),
    do: spawn(__MODULE__, :start, [name, cookie, type, tick_time])

  @doc false
  def adapter_started?() do
    app = Application.get_application(C.mesh_adapter())

    if is_nil(app) do
      false
    else
      Application.started_applications()
      |> Enum.find(nil, fn {a, _desc, _ver} -> a == app end)
      |> is_nil()
      |> Kernel.not()
    end
  end

  defp start_retry(name, cookie, type, tick_time, retry \\ 0) do
    if adapter_started?() do
      case Node.start(name, type, tick_time) do
        {:ok, pid} ->
          Node.set_cookie(name, cookie)
          {:ok, pid}

        e ->
          Logger.error("[#{__MODULE__}]: #{inspect(e)}")
          e
      end
    else
      if retry < @retries do
        Process.sleep(@sleep_time)
        start_retry(name, cookie, type, tick_time, retry + 1)
      else
        Logger.error(
          "[#{__MODULE__}]: User defined service mesh adapter [#{C.mesh_adapter()}] not started. Giving up starting node [#{name}]."
        )
      end
    end
  end
end
