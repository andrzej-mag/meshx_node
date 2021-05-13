defmodule MeshxNode.App.C do
  @moduledoc false

  @lib Mix.Project.config() |> Keyword.fetch!(:app)

  def lib, do: @lib

  def mesh_adapter, do: Application.fetch_env!(@lib, :mesh_adapter)

  def service_params,
    do: Application.get_env(@lib, :service_params, &MeshxNode.Default.service_params/2)

  def service_reg, do: Application.get_env(@lib, :service_reg, [])

  def upstream_params,
    do: Application.get_env(@lib, :upstream_params, &MeshxNode.Default.upstream_params/1)

  def upstream_reg, do: Application.get_env(@lib, :upstream_reg, nil)

  def upstream_proxy,
    do: Application.get_env(@lib, :upstream_proxy, &MeshxNode.Default.upstream_proxy/2)

  def force_registration?,
    do: Application.get_env(@lib, :force_registration?, false)

  def timeout,
    do: Application.get_env(@lib, :timeout, 5000)
end
