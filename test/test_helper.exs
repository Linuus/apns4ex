defmodule APNS.FakeSender do
  require Logger

  def send_package(socket, binary_payload, message, queue) do
    Logger.debug [
      "APNS.FakeSender.send_package/4",
      " socket:" <> inspect(socket),
      " payload: " <> inspect(binary_payload),
      " message: " <> inspect(message),
      " queque: " <> inspect(queue)
    ]
  end
end

ExUnit.configure(exclude: [pending: true])
ExUnit.start()
