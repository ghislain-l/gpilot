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
defmodule Gpilot.Web.Course do
  @behaviour :cowboy_handler
  def init(req, opts) do
    with "POST" <- :cowboy_req.method(req),
         key <- :cowboy_req.binding(:key, req, ""),
         true <- :cowboy_req.has_body(req),
         {:ok, b, req} <- :cowboy_req.read_body(req),
         ["value", v] <- String.split(b, "="),
         {h, ""} <- Integer.parse(v),
         :ok <- Gpilot.Boat.change_course(key, h)
    do
      headers = %{"Location" => "/boat/#{key}"}
      req = :cowboy_req.reply(303, headers, <<>>, req)
      {:ok, req, opts}
    else
      other ->
        headers = %{"content-type" => "text/html"}
        req = :cowboy_req.reply(400, headers, "Some error: #{inspect(other)}", req)
        {:ok, req, opts}
    end
  end
end
