defmodule APNS.MessageHandlerTest do
  use ExUnit.Case

  alias APNS.MessageHandler

  import ExUnit.CaptureLog

  setup do
    {:ok, queue_pid} = APNS.Queue.start_link()
    {:ok, %{
      queue_pid: queue_pid,
      apple_success_buffer: <<0 :: 8, 0 :: 8, "1337" :: binary>>
    }}
  end

  test "handle_response calls error callback if status byte is 0", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(0, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "No errors encountered" for message "1234")
  end

  test "handle_response calls error callback if status byte is 1", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(1, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Processing error" for message "1234")
  end

  test "handle_response calls error callback if status byte is 2", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(2, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Missing device token" for message "1234")
  end

  test "handle_response calls error callback if status byte is 3", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(3, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Missing topic" for message "1234")
  end

  test "handle_response calls error callback if status byte is 4", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(4, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Missing payload" for message "1234")
  end

  test "handle_response calls error callback if status byte is 5", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(5, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Invalid token size" for message "1234")
  end

  test "handle_response calls error callback if status byte is 6", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(6, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Invalid topic size" for message "1234")
  end

  test "handle_response calls error callback if status byte is 7", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(7, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Invalid payload size" for message "1234")
  end

  test "handle_response calls error callback if status byte is 8", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(8, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Invalid token" for message "1234")
  end

  test "handle_response calls error callback if status byte is 10", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(10, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Shutdown" for message "1234")
  end

  test "handle_response calls error callback if status byte is 255", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(255, queue_pid), "socket", "") end)
    assert output =~ ~s/[APNS] Error "None (unknown)" for message "1234"/
  end

  test "handle_response retries messages later in queue", %{queue_pid: queue_pid} do
    msg1 = %APNS.Message{id: 1}
    msg2 = %APNS.Message{id: "1234"}
    msg3 = %APNS.Message{id: 3}
    msg4 = %APNS.Message{id: 4}
    Agent.update(queue_pid, fn(_) -> [msg4, msg3, msg2, msg1] end)

    MessageHandler.handle_response(response_state(8, queue_pid), "socket", "", self())

    refute_receive {_, %APNS.Message{id: 1}}
    refute_receive {_, %APNS.Message{id: "1234"}}
    assert_receive {_, %APNS.Message{id: 3}}
    assert_receive {_, %APNS.Message{id: 4}}
  end

  test "handle_response returns state if rest is blank", %{queue_pid: queue_pid} do
    input_state = response_state(8, queue_pid)
    state = MessageHandler.handle_response(input_state, "socket", "", self())

    assert state == input_state
  end

  test "handle_response iterates over packages until rest is blank", %{queue_pid: queue_pid} do
    state = response_state(6, queue_pid)
    package1 = apple_buffer(8)
    package2 = apple_buffer(7)
    data = <<package1 :: binary, package2 :: binary>>
    output = capture_log(fn -> MessageHandler.handle_response(state, "socket", data) end)

    assert output =~ ~s([APNS] Error "Invalid topic size" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid token" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid payload size" for message "1234")
  end

  @tag :pending
  test "handle_response iteration works with error response after success", %{queue_pid: queue_pid, apple_success_buffer: apple_success_buffer} do
    state = %{buffer_apple: apple_success_buffer, config: %{callback_module: APNS.Callback}, queue: queue_pid}
    package1 = apple_buffer(8)
    package2 = apple_buffer(7)
    data = <<package1 :: binary, package2 :: binary>>
    output = capture_log(fn -> MessageHandler.handle_response(state, "socket", data) end)

    assert output =~ ~s([APNS] Error "Invalid token" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid payload size" for message "1234")
  end

  @tag :pending
  test "handle_response iteration works with success response after error", %{queue_pid: queue_pid, apple_success_buffer: apple_success_buffer} do
    state = response_state(6, queue_pid)
    package1 = apple_buffer(8)
    package2 = apple_success_buffer
    package3 = apple_buffer(7)
    data = <<package1 :: binary, package2 :: binary, package3 :: binary>>
    output = capture_log(fn -> MessageHandler.handle_response(state, "socket", data) end)

    assert output =~ ~s([APNS] Error "Invalid topic size" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid token" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid payload size" for message "1234")
  end

  defp response_state(status_code, queue_pid) do
    %{
      buffer_apple: apple_buffer(status_code),
      config: %{callback_module: APNS.Callback},
      queue: queue_pid
    }
  end

  defp apple_buffer(status_code) do
    <<8 :: 8, status_code :: 8, "1234" :: binary>>
  end
end
