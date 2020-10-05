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
defmodule Gpilot.Web.BoatSup do
  @behaviour :cowboy_handler
  alias Gpilot.Web.Html, as: Html

  def init(req, [action]=opts) do
    case :cowboy_req.method(req) do
      "GET" ->
        key = :cowboy_req.binding(:key, req, "")
        req = :cowboy_req.reply(200, Html.content_type(), body(key, action), req)
        {:ok, req, opts}
      _ ->
        {:stop, "bad method"}
    end
  end

  defp body(key, action) do
    content =
      case {action, Gpilot.Boat.exists?(key)} do
        {:new, false} ->
          Gpilot.BoatSup.add_boat(key)
          Html.p("Starting boat process, please refresh in a few seconds")
        {:del, true} ->
          Gpilot.BoatSup.del_boat(key)
          Html.p("Stopping boat process")
        _ ->
          Html.p("Nothing to do")
      end
    Html.head(title: "Boat #{key} start/stop")
    <>
    Html.body(script: "", content: content)
  end
end
