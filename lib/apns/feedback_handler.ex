defmodule APNS.FeedbackHandler do
  require Logger

  def connect(%{config: config, ssl_opts: opts} = state) do
    ssl_close(state.socket_feedback)
    host = to_char_list(config.feedback_host)
    port = config.feedback_port
    opts = Keyword.delete(opts, :reuse_sessions)
    timeout = config.timeout * 1000
    address = "#{config.feedback_host}:#{config.feedback_port}"

    case APNS.Sender.connect_socket(host, port, opts, timeout) do
      {:ok, socket} ->
        Logger.debug "[APNS] connected to #{address}"
        {:ok, socket}
      {:error, reason} ->
        Logger.error "[APNS] failed to connect #{address}, reason given: #{inspect reason}"
        {:error, {:connection_failed, address}}
    end
  end

  def handle_response(state, socket, data) do
    case <<state.buffer_feedback :: binary, data :: binary>> do
      <<time :: 32, length :: 16, token :: size(length)-binary, rest :: binary>> ->
        %APNS.Feedback{time: time, token: Base.encode16(token)}
        |> state.config.callback_module.feedback()
        state = %{state | buffer_feedback: ""}

        case rest do
          "" -> state
          _ -> handle_response(state, socket, rest)
        end

      buffer ->
        %{state | buffer_feedback: buffer}
    end
  end

  defp ssl_close(nil), do: nil
  defp ssl_close(socket), do: :ssl.close(socket)
end
