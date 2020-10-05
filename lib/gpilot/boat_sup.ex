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
defmodule Gpilot.BoatSup do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Add a boat process
  Will be stored and restarted automatically if app restarts
  """
  def add_boat(key) do
    GenServer.cast(__MODULE__, {:add_boat, key})
  end

  @doc """
  Delete/stop a boat process
  """
  def del_boat(key) do
    GenServer.cast(__MODULE__, {:del_boat, key})
  end

  @impl GenServer
  def init(_) do
    boats = Gpilot.Store.get_boats()
    {:ok, sup} = DynamicSupervisor.start_link(strategy: :one_for_one)
    {:ok, sup, {:continue, {:start, boats}}}
  end

  @impl GenServer
  def handle_continue({:start, boats}, sup) do
    for b <- boats do
      start_boat(sup, b)
      DynamicSupervisor.start_child(sup, %{id: b, start: {Gpilot.Boat, :start_link, [b]}})
    end
    {:noreply, sup}
  end

  @impl GenServer
  def handle_cast({:add_boat, k}, sup) do
    Gpilot.Store.add_boat(k)
    start_boat(sup, k)
    {:noreply, sup}
  end
  def handle_cast({:del_boat, k}, sup) do
    Gpilot.Store.del_boat(k)
    stop_boat(sup, k)
    {:noreply, sup}
  end


  defp start_boat(sup, b) do
    DynamicSupervisor.start_child(sup, %{id: b, start: {Gpilot.Boat, :start_link, [b]}, restart: :transient})
  end
  defp stop_boat(_sup, b) do
    Gpilot.Boat.stop(b)
  end
end
