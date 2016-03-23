defmodule APNS.Sender do
  require Logger
  alias APNS.Queue

  def send_package(socket, packet, message, queue) do
    result = :ssl.send(socket, [packet])

    case result do
      :ok ->
        Queue.add(queue, message)
        Logger.debug("[APNS] success sent to #{message.token}")
      {:error, reason} ->
        Queue.clear(queue)
        Logger.error("[APNS] error (#{reason}) sending to #{message.token}")
    end

    result
  end

  def connect_socket(host, port, opts, timeout) do
    :ssl.connect(host, port, opts, timeout)
  end
end
