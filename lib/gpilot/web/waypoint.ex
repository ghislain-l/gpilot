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
defmodule Gpilot.Web.Waypoint do
  @behaviour :cowboy_handler
  def init(req, opts) do
    with "POST" <- :cowboy_req.method(req),
         key <- req.bindings[:key],
         true <- :cowboy_req.has_body(req),
         {:ok, body, req} <- :cowboy_req.read_body(req),
         waypoints <- parse_waypoints(body)
    do
      Gpilot.Boat.set_waypoints(key, waypoints)
      {:ok, :cowboy_req.reply(303, %{"Location" => "../boat/#{key}"}, "", req), opts}
    else
      _other ->
        headers = %{"content-type" => "text/html"}
        req = :cowboy_req.reply(400, headers, "Some error", req)
        {:ok, req, opts}
    end
  end

  defp parse_waypoints(data) do
    map =
      data
      |> String.split("&")
      |> Enum.map(&(String.split(&1, "=")))
      |> Enum.map(fn [k,v] ->
        if String.starts_with?(k, "lat_") or String.starts_with?(k, "lon_") do
          case Float.parse(v) do
            {v, ""} ->
              {k,v}
            _ ->
              nil
          end
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    index_max = div(length(Map.keys(map)),2)
    for i <- 0..index_max do
      {Map.get(map, "lat_#{i}"), Map.get(map, "lon_#{i}")}
    end
    |> Enum.filter(&(match?({a,b} when is_number(a) and is_number(b), &1)))
  end
end
