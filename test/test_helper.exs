defmodule APNS.FakeSender do
  require Logger

  def connect_socket(host, port, opts, timeout) do
    Logger.debug [
      "APNS.FakeSender.connect_socket/4",
      " host:" <> inspect(host),
      " port: " <> inspect(port),
      " opts: " <> inspect(opts),
      " timeout: " <> inspect(timeout)
    ]

    {:ok, %{}}
  end

  def send_package(socket, binary_payload, message, queue) do
    Logger.debug [
      "APNS.FakeSender.send_package/4",
      " socket:" <> inspect(socket),
      " payload: " <> inspect(binary_payload),
      " message: " <> inspect(message),
      " queque: " <> inspect(queue)
    ]
  end

  def close(socket) do
    Logger.debug [
      "APNS.FakeSender.close/1",
      " socket:" <> inspect(socket)
    ]
  end
end

ExUnit.configure(exclude: [pending: true])
ExUnit.start()
