defmodule MeshxNode.Hrl do
  @moduledoc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @rec_name Keyword.fetch!(opts, :record_name)
      @lib_file Keyword.fetch!(opts, :hrl_file_path)
      @map_name __MODULE__

      record = Record.extract(@rec_name, from_lib: @lib_file)
      keys = :lists.map(&elem(&1, 0), record)
      vals = :lists.map(&{&1, [], nil}, keys)
      pairs = :lists.zip(keys, vals)

      defstruct keys

      def to_record(%@map_name{unquote_splicing(pairs)}) do
        {@rec_name, unquote_splicing(vals)}
      end

      def from_record({@rec_name, unquote_splicing(vals)}) do
        %@map_name{unquote_splicing(pairs)}
      end
    end
  end
end
