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
defmodule Gpilot.Web.Index do
  @behaviour :cowboy_handler
  alias Gpilot.Web.Html, as: Html

  def init(req, opts) do
    case :cowboy_req.method(req) do
      "GET" ->
        req = :cowboy_req.reply(200, Html.content_type(), body(opts), req)
        {:ok, req, opts}
      _ ->
        {:stop, "bad method"}
    end
  end

  defp body([true]) do
    boat_links =
      for k <- Gpilot.Store.get_boats() do
        Html.a("boat/#{k}", "#{k}", "_blank")
      end
      |> Html.ul()

    Html.head(title: "GPilot Index")
    <>
    Html.body(script: "", content: Html.div([Html.p("List of boats"), boat_links]))
  end
  defp body(_) do
    Html.head(title: "GPilot Index")
    <>
    Html.body(script: "", content: Html.p("This page is empty on purpose"))
  end
end
