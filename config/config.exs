use Mix.Config

config :apns,
  callback_module:  APNS.Callback,
  timeout:          30,
  reconnect_after:  1100,
  support_old_ios:  true,
  pools: [
    test: [
      env: :dev,
      certfile: {:apns, "certs/dev.pem"},
      pool_size: 10,
      pool_max_overflow: 5
    ]
  ]
