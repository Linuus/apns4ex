defmodule APNS.Payload do
  def build_json(msg, limit) do
    payload = %{aps: %{}}

    if msg.sound do
      payload = put_in(payload[:aps][:sound], msg.sound)
    end

    if msg.category != nil do
      payload = put_in(payload[:aps][:category], msg.category)
    end

    if msg.badge != nil do
      payload = put_in(payload[:aps][:badge], msg.badge)
    end

    if msg.content_available != nil do
      payload = put_in(payload[:aps][:'content-available'], msg.content_available)
    end

    if msg.extra != [] do
      payload = Map.merge(payload, msg.extra)
    end

    if is_binary(msg.alert) do
      payload = put_in(payload[:aps][:alert], msg.alert)
    else
      payload = put_in(payload[:aps][:alert], format_loc(msg.alert))
    end

    to_json(payload, limit)
  end

  def to_binary(msg, payload) do
    token_bin = msg.token |> Base.decode16!(case: :mixed)
    frame = <<
      1                  :: 8,
      32                 :: 16,
      token_bin          :: binary,
      2                  :: 8,
      byte_size(payload) :: 16,
      payload            :: binary,
      3                  :: 8,
      4                  :: 16,
      msg.id             :: 32,
      4                  :: 8,
      4                  :: 16,
      msg.expiry         :: 32,
      5                  :: 8,
      1                  :: 16,
      msg.priority       :: 8
    >>
    <<
      2                 ::  8,
      byte_size(frame)  ::  32,
      frame             ::  binary
    >>
  end

  defp to_json(payload, limit) do
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

  defp format_loc(%APNS.Message.Loc{title: title, body: body, title_loc_key: title_loc_key,
                                    title_loc_args: title_loc_args, action_loc_key: action_loc_key,
                                    loc_key: loc_key, loc_args: loc_args,
                                    launch_image: launch_image}) do
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
