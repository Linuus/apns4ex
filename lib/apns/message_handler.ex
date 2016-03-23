defmodule APNS.MessageHandler do
  require Logger

  @payload_max_old 256
  @payload_max_new 2048

  def connect(%{config: config, ssl_opts: opts} = state) do
    ssl_close(state.socket_apple)
    host = to_char_list(config.apple_host)
    port = config.apple_port
    timeout = config.timeout * 1000
    address = "#{config.apple_host}:#{config.apple_port}"

    case APNS.Sender.connect_socket(host, port, opts, timeout) do
      {:ok, socket} ->
        Logger.debug "[APNS] connected to #{address}"
        {:ok, socket}
      {:error, reason} ->
        Logger.error "[APNS] failed to connect #{address}, reason given: #{inspect reason}"
        {:error, {:connection_failed, address}}
    end
  end

  def reconnect(state) do
    Logger.debug "[APNS] Apple socket was closed"
    # In case there's some error it will be caught at the following function and the server will stop
    connect(%{state | socket_apple: nil})
  end

  def push(%APNS.Message{token: token} = msg, state) when byte_size(token) != 64 do
    APNS.Error.new(msg.id, 5) |> state.config.callback_module.error()
    state
  end

  def push(%APNS.Message{} = msg, %{config: config, socket_apple: socket, queue: queue} = state) do
    limit = case msg.support_old_ios do
      nil -> config.payload_limit
      true -> @payload_max_old
      false -> @payload_max_new
    end

    case APNS.Payload.build_json(msg, limit) do
      {:error, :payload_size_exceeded} ->
        APNS.Error.new(msg.id, 7) |> state.config.callback_module.error()
        state
      payload ->
        binary_payload = APNS.Payload.to_binary(msg, payload)
        APNS.Sender.send_package(socket, binary_payload, msg, queue)

        if state.counter >= state.config.reconnect_after do
          Logger.debug "[APNS] #{state.counter} messages sent, reconnecting"
          send self, :connect_apple
        end

        %{state | counter: state.counter + 1}
    end
  end

  def handle_response(state, socket, data) do
    case <<state.buffer_apple :: binary, data :: binary>> do
      <<8 :: 8, status :: 8, msg_id :: binary-4, rest :: binary>> ->
        APNS.Error.new(msg_id, status) |> state.config.callback_module.error()

        for message <- APNS.Queue.messages_after(state.queue, msg_id) do
          GenServer.cast(self(), message)
        end

        case rest do
          "" -> state
          _ -> handle_response(%{state | buffer_apple: ""}, socket, rest)
        end

      buffer ->
        %{state | buffer_apple: buffer}
    end
  end

  defp ssl_close(nil), do: nil
  defp ssl_close(socket), do: :ssl.close(socket)
end
