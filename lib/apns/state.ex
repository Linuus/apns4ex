defmodule APNS.State do
  def get(options) do
    %{
      config: APNS.Configuration.get(options),
      ssl_opts: APNS.SslConfiguration.get(options),
      pool: Keyword.fetch!(options, :pool),
      socket_feedback: nil,
      socket_apple: nil,
      buffer_feedback: "",
      buffer_apple: "",
      queue: [],
      connection_counter: 0,
      counter: 0
    }
  end
end
