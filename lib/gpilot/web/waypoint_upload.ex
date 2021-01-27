# Copyright (C) 2020 ghislain-l <ghislain.lemaur@gmail.com>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
defmodule Gpilot.Web.WaypointUpload do
  @behaviour :cowboy_handler
  alias Gpilot.Web.Html, as: Html

  def init(req, opts) do
    with "POST" <- :cowboy_req.method(req),
         {:ok, _headers, req} = :cowboy_req.read_part(req),
         {:ok, data, req} = :cowboy_req.read_part_body(req),
         key <- req.bindings[:key],
         {:ok, waypoints} <- extract_waypoints(data)
    do
      Gpilot.Boat.set_waypoints(key, waypoints)
      {:ok, :cowboy_req.reply(303, %{"Location" => "../boat/#{key}"}, "", req), opts}
    else
      _ ->
        {:ok, :cowboy_req.reply(400, Html.content_type(), "Bad request\n", req), opts}
    end
  end

  defp extract_waypoints(xml) do
    try do
      data =
        xml
        |> XmlToMap.naive_map()
        |> Map.get("gpx")
        |> Map.get("#content")
        |> Map.get("trk")
        |> Map.get("trkseg")
        |> Map.get("trkpt")
        |> Enum.drop(1) # first point is considered the starting point, not a target
        |> Enum.map(fn m ->
            case [Map.get(m, "-lat",""), Map.get(m, "-lon","")] |> Enum.map(&Float.parse/1) do
              [{lat, ""},{lon, ""}] ->
                {lat,lon}
              _ ->
                nil
            end
        end)
        |> Enum.reject(&is_nil/1)
      {:ok, data}
    catch
      _ ->
        :error
    end
  end
end
