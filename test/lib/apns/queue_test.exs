defmodule APNS.QueueTest do
  use ExUnit.Case

  test "queue is initialized as an empty list" do
    {:ok, pid} = APNS.Queue.start_link

    assert APNS.Queue.get(pid) == []
    APNS.Queue.stop(pid)
  end

  test "stop stops the process" do
    {:ok, pid} = APNS.Queue.start_link
    APNS.Queue.stop(pid)

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  test "add adds a message to the queue" do
    {:ok, pid} = APNS.Queue.start_link

    msg = %APNS.Message{id: 123}
    APNS.Queue.add(pid, msg)

    assert APNS.Queue.get(pid) == [msg]
    APNS.Queue.stop(pid)
  end

  test "get_resends returns messages sent after the failed message and clears queue" do
    {:ok, pid} = APNS.Queue.start_link

    msg1 = %APNS.Message{id: 1}
    msg2 = %APNS.Message{id: 2}
    msg3 = %APNS.Message{id: 3}
    msg4 = %APNS.Message{id: 4}

    APNS.Queue.add(pid, msg1)
    APNS.Queue.add(pid, msg2)
    APNS.Queue.add(pid, msg3)
    APNS.Queue.add(pid, msg4)

    assert APNS.Queue.get_resends(pid, 2) == [msg4, msg3]
    assert APNS.Queue.get(pid) == []
    APNS.Queue.stop(pid)
  end
end
