# Copyright (C) 2020-2021 ghislain-l <ghislain.lemaur@gmail.com>
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
defmodule Gpilot.Web.Boat do
  @behaviour :cowboy_handler
  alias Gpilot.Web.Html, as: Html

  def init(req, opts) do
    key = :cowboy_req.binding(:key, req, "")
    case :cowboy_req.method(req) do
      "GET" ->
        req = :cowboy_req.reply(200, Html.content_type(), body(key), req)
        {:ok, req, opts}
      "POST" ->
        with true <- :cowboy_req.has_body(req),
             {:ok, b, req} <- :cowboy_req.read_body(req),
             [["lat",lat],["lon",lon],["dec",dec]] <- b |> String.split("&") |> Enum.map(&(String.split(&1, "="))),
             [{lat,""}, {lon, ""}, {dec, ""}] <- [lat, lon, dec] |> Enum.map(&Float.parse/1)
        do
          Gpilot.Boat.set_position(key, {lat, lon, dec})
          req = :cowboy_req.reply(200, Html.content_type(), body(key), req)
          {:ok, req, opts}
        else
          _ ->
            req = :cowboy_req.reply(400, %{"content-type" => "text/plain"}, "FAIL\n", req)
            {:ok, req, opts}
        end
    end
  end

  defp body(key) do
    content =
      key
      |> Gpilot.Boat.get()
      |> render_page(key)
    Html.head(title: "Boat #{key}")
    <>
    Html.body(script: render_script(), content: content)
  end

  defp render_script() do
    """
    function erase_waypoint(i) {
      c = document.getElementById("w_lat_"+i);
      c.value = "";
      c = document.getElementById("w_lon_"+i);
      c.value = "";
    }
    function expand_gates() {
      c = document.getElementById("next_gate");
      c.style.display="none";
      c = document.getElementById("gates_div");
      c.style.display="initial";
    }
    function gate_up(button) {
      current_row = button.parentNode.parentNode;
      prev_row = current_row.previousElementSibling;
      if(prev_row) {
        tbody = current_row.parentNode;
        tbody.replaceChild(prev_row, current_row);
        tbody.insertBefore(current_row, prev_row);
      }
    }
    function gate_down(button) {
      current_row = button.parentNode.parentNode;
      next_row = current_row.nextElementSibling;
      if(next_row) {
        tbody = current_row.parentNode;
        tbody.replaceChild(current_row, next_row);
        tbody.insertBefore(next_row, current_row);
      }
    }
    function submit_ordering() {
      rows = document.getElementById("gates_table").rows;
      payload = "ordering";
      for(r of rows) {
        payload += "-" + r.firstElementChild.firstChild.textContent.trim();
      }
      console.log(payload);
      document.getElementById("ordering").value = payload;

    }
    """
  end

  defp render_page(status, key) do
    [
      render_wind_graph(status, key),
      render_status(status, key),
      render_action(status, key),
      render_gates(status, key),
      render_waypoints(status, key),
      render_footer(status, key),
    ]
    |> Html.div()
  end

  defp render_status(status, key) do
    [
      position_box(status, key),
      [Html.b("Wind"),     "#{round(status["windDir"])}&#176; @ #{status["windSpeed"] |> Util.ms_to_kts()} kts with #{Html.b("gust")} @ #{status["windGustApparent"] |> Util.ms_to_kts()} kts"],
      [Html.b("Current"),
        (if status["oceanCurrentDir"] && status["oceanCurrentSpeed"] do
          "#{round(status["oceanCurrentDir"])}&#176; @ #{status["oceanCurrentSpeed"] |> Util.ms_to_kts()} kts"
        else
          "N/A"
        end)
      ],
      [Html.b("SOW"),      "#{status["courseWater"]}&#176; @ #{status["speedWater"] |> Util.ms_to_kts()} kts"],
      [Html.b("SOG"),
        (if status["trackGround"] && status["speedGround"] do
          "#{round(status["trackGround"])}&#176; @ #{status["speedGround"] |> Util.ms_to_kts()} kts"
        else
          "N/A"
        end)
      ],
    ]
    |> Html.table()
  end

  defp position_box(status=%{"celestialNavMode" => 1}, key) do
    # maybe make it hidden, with a button to show it?
    [
      Html.b("Position"),
      (  Html.input([{"id", "lat"},{"name", "lat"},{"value", status["lat"]},{"size", "9"}]) <> "&#176;, "
      <> Html.input([{"id", "lon"},{"name", "lon"},{"value", status["lon"]},{"size", "9"}]) <> "&#176; dec"
      <> Html.input([{"id", "dec"},{"name", "dec"},{"value", status["declination"]}, {"size", "4"}]) <> "&#176;"
      <> Html.input([{"type", "submit"},{"value", "Update"}])
      )
      |> Html.form(method: "POST", action: "../boat/#{key}")
    ]
  end
  defp position_box(status, _key) do
    [Html.b("Position"), "#{show_coord(status["lat"])},#{show_coord(status["lon"])}"]
  end

  defp render_action(status, key) do  
    (  "Course"
    <> Html.input([{"id", "value"},{"name", "value"},{"type", "number"},{"value", round(status["courseWater"])}]) <> "&#176;<br>"
    <> Html.input([{"type", "submit"},{"value", "Change course"}])
    )
    |> Html.form(method: "POST", action: "../course/#{key}")
  end

  defp render_gates(status, key) do
    next_gate =
      case status[:next_gate] do
        [{north, east, south, west}] ->
          [
            [Html.b("Next gate"), Html.button("see all", [{"onclick", "expand_gates();"}])],
            ["", "N: #{show_coord(north)}", ""],
            ["W: #{show_coord(west)}", "", "E: #{show_coord(east)}"],
            ["", "S: #{show_coord(south)}", ""],
          ]
          |> Html.table([{"id", "next_gate"}])
        _ ->
          ""
      end
    all_gates =
      [
        status[:gates]
        |> Enum.with_index() # ordering of the race data
        |> Enum.sort(fn {{_,i},_},{{_,j},_} -> i<=j end) # sort according to user setting
        |> Enum.reduce([], fn {{{north, east, south, west},_},i}, acc -> # i is the index in the race data
          acc ++
          [
            [
              {"#{i}", [{"style", "display:none"}]},
              "N: #{show_coord(north)}", "S: #{show_coord(south)}", "W: #{show_coord(west)}", "E: #{show_coord(east)}",
              Html.button("up", [{"onclick", "gate_up(this);"}]),
              Html.button("down", [{"onclick", "gate_down(this);"}])
            ]
          ]
        end)
        |> Html.table([{"id", "gates_table"}]),
        (  Html.input([{"id", "ordering"},{"name", "ordering"}, {"type", "hidden"}])
        <> Html.input([{"type", "submit"},{"value", "Submit ordering"},{"onclick", "submit_ordering();"}])
        )
        |> Html.form(method: "POST", action: "../gates/#{key}")

      ]
      |> Html.div([{"id", "gates_div"}, {"style", "display:none;"}])
        
    next_gate <> all_gates
  end

  defp render_wind_graph(status, _key) do
    angle = Util.get_course({status["lat"],status["lon"]}, Enum.at(status[:autopilot][:waypoints], 0))
    Gpilot.Wind.svg_graph(status["boatType"], status["windDir"], status["windSpeed"], status["windGust"], status["declination"], angle)
    |> Html.div([{"style", "float:right"}])
  end

  defp render_waypoints(status, key) do
    speed = status["speedGround"] || status["speedWater"]
    waypoints =
      if speed && status["lat"] && status["lon"] do
        [
          render_waypoint_list(speed |> Util.ms_to_kts(), {status["lat"], status["lon"]}, 0, 0, status[:autopilot][:waypoints]),
          Html.input([{"type", "submit"},{"value", "Set waypoints"}]),
        ]
        |> Html.div()
        |> Html.form(method: "POST", action: "../waypoint/#{key}")
      else
        "Not enough information"
      end

    checkbox_attrs =
      fn value,checked ->
        (if checked do
          [{"checked", "true"}]
        else
          []
        end) ++ [{"type", "radio"}, {"id", value}, {"name", "autopilot"},{"value", value}]
      end
    autopilot =
      [
        "Autopilot<br>",
        Html.input(checkbox_attrs.("idle",      status[:autopilot][:mode] == nil)),        "None",      Html.br(),
        Html.input(checkbox_attrs.("wind",      status[:autopilot][:mode] == :wind)),      "Wind",
        " angle:",Html.input([{"type", "number"},{"id", "windangle"}, {"name", "windangle"},{"value",status[:autopilot][:wind_angle]}]) <> "&#176;", Html.br(),
        Html.input(checkbox_attrs.("waypoints", status[:autopilot][:mode] == :waypoints)), "Waypoints", Html.br(),
        " VMG: ", Html.input([{"type", "checkbox"}, {"id", "autopilot_vmg"}, {"name", "autopilot_vmg"}, {"value", "1"}] ++ (if status[:autopilot][:autopilot_vmg], do: [{"checked", "true"}], else: [])), Html.br(),
        " Beat angles:", Html.br(),
        " Upwind: ", Html.input([{"type", "number"},{"id", "beatangle1"}, {"name", "beatangle1"},{"value", status[:autopilot][:autopilot_beatangle1]}]) <> "&#176;", Html.br(),
        " Downwind: ", Html.input([{"type", "number"},{"id", "beatangle2"}, {"name", "beatangle2"},{"value", status[:autopilot][:autopilot_beatangle2]}]) <> "&#176;", Html.br(),
        " Max deviation:", Html.input([{"type", "number"},{"id", "maxdev"},    {"name", "maxdev"},   {"value", status[:autopilot][:waypoints_max_lateral_deviation] |> Util.m_to_nm() |> Float.round(1)}]) <> "nm",
        Html.br(),
        Html.input([{"type", "submit"}, {"value", "Set autopilot"}])
      ]
      |> Enum.join("")
      |> Html.form(method: "POST", action: "../autopilot/#{key}")

    upload =
      [
        Html.input([{"type", "file"},{"id", "waypoints"}, {"name", "waypoints"}]),
        Html.input([{"type", "submit"}, {"value", "Upload GPX"}])
      ]
      |> Enum.join("")
      |> Html.form(method: "POST", action: "../waypoint/#{key}/upload", enctype: "multipart/form-data")

    [
      Html.h2("Autopilot"),
      autopilot,
      Html.h2("Waypoints"),
      waypoints,
      upload,
    ]
    |> Html.div()
  end

  defp render_waypoint_list(sog, current, index, total_t, waypoints_list, acc\\[])
  defp render_waypoint_list(sog, current={_c_lat,_c_lon}, i, total_t, [next={lat,lon}| rest], acc) do
    heading  = Util.get_course(current, next)
    distance = Util.get_distance(current, next)
    duration =
      if sog > 1.0 do
        t = distance/sog
        Util.show_duration(t)
      else
        ""
      end
    total_t =
      if sog > 1.0 do
        total_t + distance/sog
      else
        total_t
      end
    timestring =
      if sog > 1.0 do
        Util.show_utc_datetime(total_t)
      else
        ""
      end
    line =
      [
        Html.input([{"size", "8"}, {"id", "w_lat_#{i}"}, {"name", "lat_#{i}"}, {"value", "#{Float.round(lat,4)}"}]),
        Html.input([{"size", "8"}, {"id", "w_lon_#{i}"}, {"name", "lon_#{i}"}, {"value", "#{Float.round(lon,4)}"}]),
        "#{round(heading)}&#176;",
        "#{Float.round(distance,1)}nm",
        duration,
        "[#{timestring}]",
        Html.button("x", [{"onclick", "erase_waypoint(#{i});"}])
      ]
    render_waypoint_list(sog, next, i+1, total_t, rest, [line | acc])
  end
  defp render_waypoint_list(_, _, i, _, [], acc) do
    l =
      [
        Html.input([{"size", "8"}, {"id", "w_lat_#{i}"}, {"name", "lat_#{i}"}, {"value", ""}]),
        Html.input([{"size", "8"}, {"id", "w_lon_#{i}"}, {"name", "lon_#{i}"}, {"value", ""}]),
        "",
        "",
        "",
        "",
        ""
      ]
    [l | acc]
    |> Enum.reverse()
    |> Html.table()
  end

  defp render_footer(status, key) do
    [
      Html.hr(),
      Html.a("https://8bitbyte.ca/sailnavsim/?key=#{key}", "Boat page", "_blank"),
      Html.br(),
      Html.br(),
      (if status["lat"] && status["lon"] do
        Html.a("https://www.windy.com/?gfs,#{Float.round(status["lat"],3)},#{Float.round(status["lon"],3)},8", "Windy", "_blank")
      else
        Html.a("https://www.windy.com/?gfs,0,0,5", "Windy", "_blank")
      end),
      Html.br(),
      Html.br(),
      [
        Html.input([{"type", "hidden"},{"name", "key"}, {"value", key}]),
        Html.input([{"type", "submit"},{"value", "map"}]),
      ]
      |> Enum.join("")
      |> Html.form(method: "POST", action: "https://8bitbyte.ca/sailnavsim/map.php", target: "_blank"),
      Html.hr(),
    ]
    |> Enum.join("")
    |> Html.div()
  end

  # show coordinates with rounding (and safe if not a number)
  defp show_coord(lat_or_lon) when is_float(lat_or_lon),   do: "#{Float.round(lat_or_lon, 4)}&#176;"
  defp show_coord(lat_or_lon) when is_integer(lat_or_lon), do: "#{lat_or_lon}.0&#176;"
  defp show_coord(_lat_or_lon), do: "N/A"

end
