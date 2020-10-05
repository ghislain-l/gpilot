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
defmodule Gpilot.Boat do
  use GenServer

  @boat_url   "https://8bitbyte.ca/sailnavsim/api/boatinfo.php?key="
  @race_url   "https://8bitbyte.ca/sailnavsim/api/raceinfo.php?id="
  @action_url "https://8bitbyte.ca/sailnavsim/?key="


  def start_link(key) do
    GenServer.start_link(__MODULE__, key, [name: boat_name(key)])
  end
  def stop(key) do    
    GenServer.cast(boat_name(key), :stop)
  end

  @doc """
  Check if a process for that boat exists
  """
  def exists?(key) do
    nil != GenServer.whereis(boat_name(key))
  end

  @doc """
  Get the last known status of the boat
  """
  def get(key) do
    GenServer.call(boat_name(key), :get)
  end

  def change_course(key, course) do
    GenServer.call(boat_name(key), {:change_course, course})
  end

  def set_waypoints(key, data) when is_list(data) do
    GenServer.cast(boat_name(key), {:set_waypoints, data})
  end

  def set_autopilot(key, params) when is_map(params) do
    GenServer.cast(boat_name(key), {:set_autopilot, params})
  end

  defmodule State do
    defstruct [
      key: nil,
      status: %{},
      boat_type: nil,
      waypoints: [],
      autopilot: nil, # nil, :waypoints, :wind
      wind_angle: 90.0,
    ]
  end

  @impl GenServer
  def init(key) do
    send(self(), :query_status)
    data = Gpilot.Store.get_boat(key)
    {:ok, %State{
      key: key,
      waypoints:  Map.get(data, :waypoints, []),
      autopilot:  Map.get(data, :autopilot, nil),
      wind_angle: Map.get(data, :wind_angle, 90.0),
    }}
  end


  @impl GenServer
  def handle_call(:get, _from, state) do
    ret =
      state.status
      |> Map.put("boatType", state.boat_type)
      |> Map.put(:autopilot, %{
        waypoints:  state.waypoints,
        mode:       state.autopilot,
        wind_angle: state.wind_angle,
        })
    {:reply, ret, state}
  end
  def handle_call({:change_course, course}, _from, state) do
    {:reply, post_request(state.key, "course", "#{Util.normalize_angle(course)}"), state}
  end

  @impl GenServer
  def handle_cast({:set_waypoints, waypoints}, state) do
    if validate_waypoints(waypoints) do
      {:noreply, %State{state|
        waypoints: waypoints
      }
      |> save()
      |> run_autopilot()
      }
    else
      {:noreply, state}
    end
  end
  def handle_cast({:set_autopilot, params}, state) do
    case validate_autopilot(params) do
      {:ok, mode, angle} ->
        {:noreply, %State{state|
          autopilot:  mode,
          wind_angle: angle,
        }
        |> save()
        |> run_autopilot()
        }
      _ ->
        {:noreply, state}
    end
  end
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(:query_status, state) do
    Process.send_after(self(), :query_status, 1000*(61+:rand.uniform(5)-DateTime.utc_now().second))
    new_status = get_new_status(state.key)
    if is_nil(state.boat_type) && not is_nil(new_status["race"]) do
      send(self(), :query_race)
    end
    {:noreply, %State{state|
      status: new_status
    }
    |> run_autopilot()
    }
  end
  def handle_info(:query_race, state) do
    {:noreply, %State{state|
      boat_type: get_boat_type(state.status["race"])
    }}
  end

  # internals

  defp boat_name(key) do
    {:via, Registry, {Gpilot.Registry, key}}
  end

  defp get_new_status(key) do
    (@boat_url <> key)
    |> to_charlist()
    |> :httpc.request()
    |> parse_reply()
  end

  defp get_boat_type(race_id) do
    (@race_url <> race_id)
    |> to_charlist()
    |> :httpc.request()
    |> parse_reply()
    |> Map.get("boatType")
  end

  defp parse_reply({:ok, {{_, 200, _}, _, json}}) do
    case Jason.decode(json) do
      {:ok, m} when is_map(m) ->
        m
      _ ->
        %{}
    end
  end
  defp parse_reply(_any) do
    %{}
  end

  defp post_request(key, cmd, value) do
    url = (@action_url <> key)
          |> to_charlist()
    body = [
        {"key", key},
        {"cmd", cmd},
        {"value", value},
      ]
      |> Enum.map(fn {k,v} -> "#{k}=#{v}" end)
      |> Enum.join("&")
    case :httpc.request(:post, {url, [], 'application/x-www-form-urlencoded', body}, [], []) do
      {:ok, {{_, 200,_},_,_}} ->
        :ok
      _ ->
        :error
    end
  end

  defp run_autopilot(state) do
    new_course =
      case {state.autopilot, state.waypoints} do
        {:wind,_} ->
          if is_number(state.wind_angle) do
            Util.normalize_angle(state.wind_angle + state.status["windDir"])
          end
        {:waypoints, [target={_lat,_lon}|tail]} ->
          current = {state.status["lat"], state.status["lon"]}
          if Util.get_distance(current, target) < 0.5 do
            Gpilot.Boat.set_waypoints(state.key, tail)
            nil
          else
            desired_course = Util.get_course(current, target)
            Util.normalize_angle(desired_course - (state.status["trackGround"]-state.status["courseWater"]))
          end
        _ ->
          nil
      end
    if is_number(new_course) do
      new_course = round(new_course)
      if new_course != state.status["courseWater"] do
        spawn(fn ->
          change_course(state.key, new_course)
        end)
      end
    end
    state
  end

  defp save(state) do
    data =
      %{
        waypoints: state.waypoints,
        autopilot: state.autopilot,
        wind_angle: state.wind_angle,
      }
    Gpilot.Store.set_boat(state.key, data)
    state
  end
  defp validate_waypoints(waypoints) do
    Enum.all?(waypoints, fn x ->
      case x do
        {lat,lon} ->
          is_float(lat) and is_float(lon)
        _ ->
          false
      end
    end)
  end
  defp validate_autopilot(map) do
    m =
      case Map.get(map, "autopilot") do
        "idle" -> nil
        "wind" -> :wind
        "waypoints" -> :waypoints
        _ -> nil
      end
    case Float.parse(Map.get(map, "windangle", "")) do
      {a,""} ->
        {:ok, m,a}
      _ ->
        :error
    end
  end
end
