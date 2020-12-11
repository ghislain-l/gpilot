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
defmodule Gpilot.WebServer do
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500,
    }
  end
  def start_link([port: http_port, show_index_page: show_index_page]) do
    routes = [
      {"/", Gpilot.Web.Index, [show_index_page]},
      {"/boat/:key", Gpilot.Web.Boat, []},
      {"/new/:key", Gpilot.Web.BoatSup, [:new]},
      {"/del/:key", Gpilot.Web.BoatSup, [:del]},
      {"/course/:key", Gpilot.Web.Course, []},
      {"/waypoint/:key/upload", Gpilot.Web.WaypointUpload, []},
      {"/waypoint/:key", Gpilot.Web.Waypoint, []},
      {"/autopilot/:key", Gpilot.Web.Autopilot, []},
      {"/gates/:key", Gpilot.Web.Gates, []},
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
    :cowboy.start_clear(__MODULE__, [port: http_port], %{env: %{dispatch: dispatch}})
  end
end



