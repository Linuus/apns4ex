defmodule APNS.Payload do
  def build_json(message, limit) do
    payload = %{aps: %{}}

    if message.sound do
      payload = put_in(payload[:aps][:sound], message.sound)
    end

    if message.category != nil do
      payload = put_in(payload[:aps][:category], message.category)
    end

    if message.badge != nil do
      payload = put_in(payload[:aps][:badge], message.badge)
    end

    if message.content_available != nil do
      payload = put_in(payload[:aps][:'content-available'], message.content_available)
    end

    if message.extra != [] do
      payload = Map.merge(payload, message.extra)
    end

    if is_binary(message.alert) do
      payload = put_in(payload[:aps][:alert], message.alert)
    else
      payload = put_in(payload[:aps][:alert], format_loc(message.alert))
    end

    json = Poison.encode!(payload)

    length_diff = byte_size(json) - limit
    length_alert = case payload.aps.alert do
      %{body: body} -> byte_size(body)
      str when is_binary(str) -> byte_size(str)
    end

    cond do
      length_diff <= 0 -> json
      length_diff >= length_alert -> {:error, :payload_size_exceeded}
      true ->
        payload = put_in(payload[:aps][:alert], truncate(payload.aps.alert, length_alert - length_diff))
        Poison.encode!(payload)
    end
  end

  def to_binary(message, payload) do
    token_bin = message.token |> Base.decode16!(case: :mixed)

    frame = <<
      1                  :: 8,
      32                 :: 16,
      token_bin          :: binary,
      2                  :: 8,
      byte_size(payload) :: 16,
      payload            :: binary,
      3                  :: 8,
      4                  :: 16,
      message.id             :: 32,
      4                  :: 8,
      4                  :: 16,
      message.expiry         :: 32,
      5                  :: 8,
      1                  :: 16,
      message.priority       :: 8
    >>

    <<
      2                 ::  8,
      byte_size(frame)  ::  32,
      frame             ::  binary
    >>
  end

  defp truncate(%{body: string} = alert, size) do
    %{alert | body: truncate(string, size)}
  end

  defp truncate(string, size) when is_binary(string) do
    string2 = string <> "…"
    if byte_size(string2) <= size do
      string2
    else
      string = String.slice(string, 0, String.length(string) - 1)
      truncate(string, size)
    end
  end

  defp format_loc(%APNS.Message.Loc{
    title: title, body: body, title_loc_key: title_loc_key,
    title_loc_args: title_loc_args, action_loc_key: action_loc_key,
    loc_key: loc_key, loc_args: loc_args, launch_image: launch_image}) do

    # These are required parameters
    alert = %{title: title, body: body, "loc-key": loc_key, "loc-args": loc_args}

    # Following are optional parameters
    if title_loc_key != nil do
      alert = alert
      |> Map.put(:'title-loc-key', title_loc_key)
    end

    if title_loc_args != nil do
      alert = alert
      |> Map.put(:'title-loc-args', title_loc_args)
    end

    if action_loc_key != nil do
      alert = alert
      |> Map.put(:'action-loc-key', action_loc_key)
    end

    if launch_image != nil do
      alert = alert
      |> Map.put(:'launch-image', launch_image)
    end

    alert
  end
end
