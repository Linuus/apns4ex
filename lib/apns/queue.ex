defmodule APNS.Queue do
  def start_link do
    Agent.start_link(fn -> [] end)
  end

  def stop(pid), do: Agent.stop(pid)

  def get(pid), do: Agent.get(pid, fn(messages)-> messages end)

  def add(pid, %APNS.Message{} = new_message) do
    Agent.update(pid, fn(messages) -> [new_message | messages] end)
  end

  def get_resends(pid, failed_id) do
    messages = Agent.get_and_update(pid, fn(messages)-> {messages, []} end)
    Enum.take_while(messages, fn(message) -> message.id != failed_id end)
  end
end
