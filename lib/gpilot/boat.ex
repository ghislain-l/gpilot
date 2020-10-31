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
      waypoints_lateral_deviation: 0.0, # in m
      waypoints_max_lateral_deviation: Util.nm_to_m(10.0), # in m
      autopilot_wind_exclusion: 45.0, # minimum angle to the wind when following waypoints (beat angle)
      autopilot: nil, # nil, :waypoints, :wind
      wind_angle: 90.0,
      waypoint_ref: nil,
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
      autopilot_wind_exclusion: Map.get(data, :autopilot_wind_exclusion, 45.0),
      waypoints_max_lateral_deviation: Map.get(data, :waypoints_max_lateral_deviation, Util.nm_to_m(10.0)),
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
        autopilot_wind_exclusion: state.autopilot_wind_exclusion,
        waypoints_max_lateral_deviation: state.waypoints_max_lateral_deviation,
        })
    {:reply, ret, state}
  end
  def handle_call({:change_course, course}, _from, state) do
    course
    |> trace("changing course")
    {:reply, post_request(state.key, "course", "#{Util.normalize_angle(course)}"), state}
  end

  @impl GenServer
  def handle_cast({:set_waypoints, waypoints}, state) do
    if validate_waypoints(waypoints) do
      {:noreply, %State{state|
        waypoints: waypoints,
        waypoints_lateral_deviation: 0.0,
        waypoint_ref: nil,
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
      {:ok, mode, angle, beat_angle, max_dev} ->
        {:noreply, %State{state|
          autopilot:  mode,
          wind_angle: angle,
          waypoints_max_lateral_deviation: Util.nm_to_m(max_dev),
          autopilot_wind_exclusion: beat_angle,
          waypoints_lateral_deviation: 0.0,
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
    Process.send_after(self(), :query_status, 1000*(54+:rand.uniform(11)))
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
  def handle_info({:next_waypoint_time, t}, state) do
    ref = make_ref()
    now = DateTime.utc_now() |> DateTime.to_unix()
    Process.send_after(self(), {:next_waypoint, ref}, max(0, round((t-now)*1000)))
    {:noreply, %State{state|
      waypoint_ref: ref
    }}
  end
  def handle_info({:next_waypoint, ref}, state) do
    # only change if this is the last ref
    if ref == state.waypoint_ref and state.autopilot do
      Gpilot.Boat.set_waypoints(state.key, Enum.drop(state.waypoints, 1))
    end
    {:noreply, state}
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
      other ->
        other
        |> trace("error posting request")
        :error
    end
  end

  defp run_autopilot(state) do
    case {state.autopilot, state.waypoints} do
      {:wind,_} ->
        if is_number(state.wind_angle) do
          state
          |> maybe_change_course(state.wind_angle + state.status["windDir"])
        end
      {:waypoints, [target={_lat,_lon}|_tail]} ->
        # estimate when to turn to next waypoint (assume a direct course)
        current = {state.status["lat"], state.status["lon"]}
        report_time = state.status["time"]
        course_to_waypoint   = Util.get_course(current, target)
        distance_to_waypoint = Util.get_distance(current, target)
        speed_to_waypoint = state.status["speedGround"] |> Util.ms_to_kts()
        if speed_to_waypoint/60*5 > distance_to_waypoint do # next waypoint in less than 5 minutes after report
          time_of_turn = report_time + 3600*(distance_to_waypoint/speed_to_waypoint)
          send(self(), {:next_waypoint_time, time_of_turn})
        end
        # update the deviation integral
        lateral_deviation = state.waypoints_lateral_deviation + 60*Util.sin(state.status["trackGround"]-course_to_waypoint)*state.status["speedGround"]
        # find the best course to the waypoint
        desired_course = course_to_waypoint - (state.status["trackGround"]-state.status["courseWater"])
        # exclusion zone
        left  = state.status["windDir"] - state.autopilot_wind_exclusion
        right = state.status["windDir"] + state.autopilot_wind_exclusion
        going_right? = Util.sin( state.status["courseWater"] - course_to_waypoint) > 0
        new_course =
          cond do
            # can go directly to waypoint
            not Util.angle_in_interval?([left, right], desired_course) ->
              desired_course
            # must tack according to wind
            lateral_deviation > state.waypoints_max_lateral_deviation ->
              # too much to the right
              left
            lateral_deviation < -state.waypoints_max_lateral_deviation ->
              # too much to the left
              right
            true ->
              # continue on a heading closest to what we are now
              if going_right? do
                right
              else
                left
              end
          end
        %State{state|
          waypoints_lateral_deviation: lateral_deviation
        }
        |> trace("autopilot waypoint")
        |> maybe_change_course(new_course)
      _ ->
        state
    end
  end

  defp maybe_change_course(state, new_course) do
    if is_number(new_course) do
      new_course = round(Util.normalize_angle(new_course))
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
        autopilot_wind_exclusion: state.autopilot_wind_exclusion,
        waypoints_max_lateral_deviation: state.waypoints_max_lateral_deviation,
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
    ["windangle", "beatangle", "maxdev"]
    |> Enum.map(&(Map.get(map, &1, "") |> Float.parse()))
    |> case do
      [{wa,""},{ba,""},{md,""}] ->
        {:ok, m, wa, ba, md}
      _ ->
        :error
    end
  end

  defp trace(data, label) do
    data
    #|> IO.inspect(label: label)
  end
end
