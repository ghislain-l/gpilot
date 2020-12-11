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
defmodule Gpilot.Web.Gates do
  @behaviour :cowboy_handler
  def init(req, opts) do
    with "POST" <- :cowboy_req.method(req),
         key <- req.bindings[:key],
         true <- :cowboy_req.has_body(req),
         {:ok, body, req} <- :cowboy_req.read_body(req),
         {:ok, ordering} <- parse_ordering(body)
    do
      # ordering contains the id of each gate in the right order
      # we need the "sorting index" of all gates in the race data order
      gates_ordering =
        ordering
        |> Enum.with_index()
        |> Enum.sort(fn {i,_},{j,_} -> i<=j end)
        |> Enum.map(fn {_,x} -> x end)
      Gpilot.Boat.set_gates_ordering(key, gates_ordering)
      {:ok, :cowboy_req.reply(303, %{"Location" => "/boat/#{key}"}, "", req), opts}
    else
      _other ->
        headers = %{"content-type" => "text/html"}
        req = :cowboy_req.reply(400, headers, "Some error", req)
        {:ok, req, opts}
    end
  end

  defp parse_ordering(data) do
    data
    |> String.split("=")
    |> Enum.map(&(String.split(&1,"-")))
    |> case do
      [["ordering"], ["ordering" | tail]] ->
        {:ok, Enum.map(tail, &String.to_integer/1)}
      _ ->
        :error
    end
  end
end
