defmodule APNS.Worker do
  use GenServer
  require Logger

  def start_link(pool_conf) do
    GenServer.start_link(__MODULE__, pool_conf, [])
  end

  def init(pool_conf) do
    state = APNS.Configuration.get(pool_conf)
    send(self, :connect_apple)
    send(self, :connect_feedback)
    {:ok, state}
  end

  def handle_info(:connect_apple, %{config: %{timeout: timeout}} = state) do
    case APNS.MessageHandler.connect(state) do
      {:ok, socket} ->
        {:noreply, %{state | socket_apple: socket, counter: 0}}
      {:error, reason} ->
        :timer.sleep(timeout) # TODO: why?
        {:stop, reason, state}
    end
  end

  def handle_info(:connect_feedback, %{config: config} = state) do
    case APNS.FeedbackHandler.connect(state) do
      {:ok, socket} ->
        {:noreply, %{state | socket_feedback: socket}}
      {:error, reason} ->
        :timer.sleep(config.timeout * 1000) # TODO: why?
        {:stop, reason, state}
    end
  end

  def handle_info({:ssl_closed, socket}, %{socket_apple: socket, config: %{timeout: timeout}} = state) do
    case APNS.MessageHandler.reconnect(state) do
      {:ok, _socket} ->
        {:noreply, state}
      {:error, reason} ->
        :timer.sleep(timeout) # TODO: why?
        {:stop, reason, state}
    end
  end

  def handle_info({:ssl_closed, socket}, %{socket_feedback: socket, config: %{feedback_interval: interval}} = state) do
    Logger.debug "[APNS] Feedback socket was closed. Reconnect in #{interval} seconds"
    :erlang.send_after(interval * 1000, self, :connect_feedback)
    {:noreply, %{state | socket_feedback: nil}}
  end

  def handle_info({:ssl, socket, data}, %{socket_apple: socket} = state) do
    {:noreply, APNS.MessageHandler.handle_response(state, socket, data)}
  end

  def handle_info({:ssl, socket, data}, %{socket_feedback: socket} = state) do
    {:noreply, APNS.FeedbackHandler.handle_response(state, socket, data)}
  end

  def handle_cast(msg, state) do
    {:noreply, APNS.MessageHandler.push(msg, state)}
  end
end
