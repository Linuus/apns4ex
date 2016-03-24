defmodule APNS.ConfigurationTest do
  use ExUnit.Case

  alias APNS.Configuration

  @payload_min_size 38

  test "get adds merged application defaults with APNS.Configuration defaults" do
    configuration = Configuration.get([])

    assert configuration.buffer_apple == ""
    assert configuration.buffer_feedback == ""
    assert configuration.counter == 0
    refute configuration.queue == nil

    assert configuration.config.timeout == 30
    assert configuration.config.feedback_interval == 1200
    assert configuration.config.reconnect_after == 1100
    assert configuration.config.support_old_ios == true
    assert configuration.config.callback_module == APNS.Callback
    assert configuration.config.payload_limit == 256
    assert configuration.ssl_opts == [reuse_sessions: false, mode: :binary]
  end

  test "get sets Apple addresses to sandbox when given env :dev" do
    configuration = Configuration.get(env: :dev)

    assert configuration.config.apple_host == "gateway.sandbox.push.apple.com"
    assert configuration.config.apple_port == 2195
    assert configuration.config.feedback_host == "feedback.sandbox.push.apple.com"
    assert configuration.config.feedback_port == 2196
  end

  test "get sets Apple addresses to live when given env :prod" do
    configuration = Configuration.get(env: :prod)

    assert configuration.config.apple_host == "gateway.push.apple.com"
    assert configuration.config.apple_port == 2195
    assert configuration.config.feedback_host == "feedback.push.apple.com"
    assert configuration.config.feedback_port == 2196
  end

  test "get sets max payload to low limit if support_old_ios is true" do
    configuration = Configuration.get(support_old_ios: true)
    assert configuration.config.payload_limit == 256
  end

  test "getsets max payload to hight limit if support_old_ios is false" do
    configuration = Configuration.get(support_old_ios: false)
    assert configuration.config.payload_limit == 2048
  end

  test "getadds cartfile to ssl_opts if given" do
    configuration = Configuration.get(certfile: "/some/absolute/path")
    assert Keyword.fetch!(configuration.ssl_opts, :certfile) == "/some/absolute/path"
  end

  test "getadds cartfile relative to priv to ssl_opts if given as tuple" do
    configuration = Configuration.get(certfile: {:apns, "certs/dev.pem"})
    assert Keyword.fetch!(configuration.ssl_opts, :certfile) =~ "/_build/test/lib/apns/priv/certs/dev.pem"
  end

  test "get adds cert password as char list to ssl_opts if given" do
    configuration = Configuration.get(cert_password: "secret")
    assert Keyword.fetch!(configuration.ssl_opts, :password) == 'secret'
  end
end
