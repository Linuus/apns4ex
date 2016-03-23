defmodule APNS.Configuration do
  @payload_max_old 256
  @payload_max_new 2048

  def get(pool_conf) do
    opts = [
      cert: nil,
      key: nil,
      certfile: nil,
      cert_password: nil,
      keyfile: nil,
      callback_module: APNS.Callback,
      timeout: 30,
      feedback_interval: 1200,
      reconnect_after: 1000,
      support_old_ios: true
    ]
    global_conf = Application.get_all_env :apns
    config = Enum.reduce opts, %{}, fn({key, default}, map) ->
      val = case pool_conf[key] do
        nil -> Keyword.get(global_conf, key, default)
        v -> v
      end
      Map.put(map, key, val)
    end

    hosts = [
      dev: [apple: [host: "gateway.sandbox.push.apple.com", port: 2195],
        feedback: [host: "feedback.sandbox.push.apple.com", port: 2196]],
      prod: [apple: [host: "gateway.push.apple.com", port: 2195],
        feedback: [host: "feedback.push.apple.com", port: 2196]]
    ]
    env = pool_conf[:env]
    payload_limit = case config.support_old_ios do
      true -> @payload_max_old
      false -> @payload_max_new
    end
    config2 = %{
      payload_limit: payload_limit,
      apple_host:    hosts[env][:apple][:host],
      apple_port:    hosts[env][:apple][:port],
      feedback_host: hosts[env][:feedback][:host],
      feedback_port: hosts[env][:feedback][:port]
    }
    config = Map.merge(config, config2)

    ssl_opts = [
      reuse_sessions: false,
      mode: :binary
    ]
    if config.certfile != nil do
      ssl_opts = ssl_opts
      |> Dict.put(:certfile, certfile_path(config.certfile))
    end
    if config.cert != nil do
      ssl_opts = case :public_key.pem_decode(config.cert) do
                   [{:Certificate, certDer, _}] -> ssl_opts |> Dict.put(:cert, certDer)
                   _ -> ssl_opts
                 end
    end
    if config.key != nil do
      ssl_opts = case :public_key.pem_decode(config.key) do
                   [{:RSAPrivateKey, keyDer, _}] -> ssl_opts |> Dict.put(:key, { :RSAPrivateKey, keyDer})
                   _ -> ssl_opts
                 end
    end
    if config.keyfile != nil do
      ssl_opts = ssl_opts
      |> Dict.put(:keyfile, Path.absname(config.keyfile))
    end
    if config.cert_password != nil do
      ssl_opts = ssl_opts
      |> Dict.put(:password, to_char_list(config.cert_password))
    end

    {:ok, queue_pid} = APNS.Queue.start_link

    %{
      config: config,
      ssl_opts: ssl_opts,
      socket_feedback: nil,
      socket_apple: nil,
      buffer_feedback: "",
      buffer_apple: "",
      queue: queue_pid,
      counter: 0
    }
  end

  defp certfile_path(string) when is_binary(string) do
    Path.expand(string)
  end

  defp certfile_path({app_name, path}) when is_atom(app_name) do
    Path.expand(path, :code.priv_dir(app_name))
  end
end
