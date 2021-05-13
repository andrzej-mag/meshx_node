defmodule MeshxNode.Dist.NetAddress do
  @moduledoc false
  use MeshxNode.Hrl, record_name: :net_address, hrl_file_path: "kernel/include/net_address.hrl"

  def net_address({:uds, path}) do
    %__MODULE__{
      address: {:local, path},
      host: :localhost,
      family: :local,
      protocol: :stream
    }
    |> to_record()
  end

  def net_address({:tcp, ip, port}) do
    %__MODULE__{
      address: {ip, port},
      host: :localhost,
      family: :inet,
      protocol: :tcp
    }
    |> to_record()
  end
end
