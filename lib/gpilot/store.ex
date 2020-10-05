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
defmodule Gpilot.Store do
  use GenServer

  def start_link(file: f) do
    GenServer.start_link(__MODULE__, f, name: __MODULE__)
  end

  @doc """
  Add a new boat to the DB
  """
  def add_boat(key) do
    GenServer.cast(__MODULE__, {:add_boat, key})
  end

  @doc """
  Remove the boat data from the DB
  """
  def del_boat(key) do
    GenServer.cast(__MODULE__, {:del_boat, key})
  end

  @doc """
  Return the list (MapSet) of boat keys
  """
  def get_boats() do
    GenServer.call(__MODULE__, :get_boats)
  end

  @doc """
  Stores the boat data
  """
  def set_boat(key, data) do
    GenServer.cast(__MODULE__, {:set_boat, key, data})
  end
  @doc """
  Loads the boat data
  """
  def get_boat(key) do
    GenServer.call(__MODULE__, {:get_boat, key})
  end
  
  defmodule State do
    defstruct [
      filename: nil,
      boats: MapSet.new(),
      boat_data: %{},
    ]
  end

  @impl GenServer
  def init(file) do
    {:ok, %State{
      filename: to_charlist(file),
    }, {:continue, :load}}
  end

  @impl GenServer
  def handle_continue(:load, state) do
    boats = load_db(state.filename, :boats, MapSet.new())
    boat_data =
      for b <- boats, into: %{} do
        {b, load_db(state.filename, {:boat, b}, %{})}
      end
    {:noreply, %State{state |
      boats: boats,
      boat_data: boat_data,
    }}
  end

  @impl GenServer
  def handle_call(:get_boats, _from, state) do
    {:reply, state.boats, state}
  end
  def handle_call({:get_boat, key}, _from, state) do
    {:reply, state.boat_data |> Map.get(key, %{}), state}
  end
  @impl GenServer
  def handle_cast({:add_boat, key}, state) do
    {:noreply, %State{state | boats: MapSet.put(state.boats, key)} |> save(:boats)}
  end
  def handle_cast({:del_boat, key}, state) do
    {:noreply, %State{state | boats: MapSet.delete(state.boats, key)} |> save(:boats)}
  end
  def handle_cast({:set_boat, key, data}, state) do
    {:noreply, %State{state | boat_data: Map.put(state.boat_data, key, data)} |> save({:boat, key})}
  end


  defp save(state, what)
  defp save(state, :boats) do
    save_to_db(state.filename, {:boats, state.boats})
    state
  end
  defp save(state, {:boat, key}) do
    save_to_db(state.filename, {{:boat, key}, Map.get(state.boat_data, key)})
    state
  end
  defp save(state, _) do
    state
  end

  defp save_to_db(filename, object={_k,_v}) do
    {:ok, f} = :dets.open_file(filename, [type: :set])
    :dets.insert(f, object)
    :dets.close(f)
  end

  defp load_db(filename, key, default) do
    {:ok, f} = :dets.open_file(filename, [type: :set])
    ret =
      case :dets.lookup(f, key) do
        [{^key, v}] ->
          v
        _ ->
          default
      end
    :dets.close(f)
    ret
  end
end
