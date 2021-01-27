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
defmodule Gpilot.Web.Autopilot do
  @behaviour :cowboy_handler
  def init(req, opts) do
    with "POST" <- :cowboy_req.method(req),
         key <- req.bindings[:key],
         true <- :cowboy_req.has_body(req),
         {:ok, body, req} <- :cowboy_req.read_body(req),
         autopilot <- parse_autopilot(body)
    do
      Gpilot.Boat.set_autopilot(key, autopilot)
      {:ok, :cowboy_req.reply(303, %{"Location" => "../boat/#{key}"}, "", req), opts}
    else
      _other ->
        headers = %{"content-type" => "text/html"}
        req = :cowboy_req.reply(400, headers, "Some error", req)
        {:ok, req, opts}
    end
  end

  defp parse_autopilot(data) do
    data
    |> String.split("&")
    |> Enum.map(&(String.split(&1, "=")))
    |> Enum.map(fn [k,v] -> {k,v} end)
    |> Map.new()
  end
end
