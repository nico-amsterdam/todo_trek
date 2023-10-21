defmodule TodoTrekWeb.Nonce do
  def on_mount(%{script_src_nonce: script_src_nonce_value}, _params, _session, socket) do
    {:cont, Phoenix.Component.assign(socket, :script_src_nonce, script_src_nonce_value)}
  end
end
