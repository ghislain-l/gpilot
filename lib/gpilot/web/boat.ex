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
defmodule Gpilot.Web.Boat do
  @behaviour :cowboy_handler
  alias Gpilot.Web.Html, as: Html

  def init(req, opts) do
    case :cowboy_req.method(req) do
      "GET" ->
        key = :cowboy_req.binding(:key, req, "")
        req = :cowboy_req.reply(200, Html.content_type(), body(key), req)
        {:ok, req, opts}
      _ ->
        {:stop, "bad method"}
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
    """
  end

  defp render_page(status, key) do
    [
      render_wind_graph(status, key),
      render_status(status, key),
      render_action(status, key),
      render_waypoints(status, key),
      render_footer(status, key),
    ]
    |> Html.div()
  end

  defp render_status(status, _key) do
    [
      [Html.b("Position"), "#{Float.round(status["lat"],4)}&#176;,#{Float.round(status["lon"],4)}&#176;"],
      [Html.b("Wind"),     "#{round(status["windDir"])}&#176; @ #{status["windSpeed"] |> Util.ms_to_kts()} kts with #{Html.b("gust")} @ #{status["windGust"] |> Util.ms_to_kts()} kts"],
      [Html.b("Current"),  "#{round(status["oceanCurrentDir"])}&#176; @ #{status["oceanCurrentSpeed"] |> Util.ms_to_kts()} kts"],
      [Html.b("SOW"),      "#{status["courseWater"]}&#176; @ #{status["speedWater"] |> Util.ms_to_kts()} kts"],
      [Html.b("SOG"),      "#{round(status["trackGround"])}&#176; @ #{status["speedGround"] |> Util.ms_to_kts()} kts"],
    ]
    |> Html.table()
  end

  defp render_action(status, key) do  
    (  "Course"
    <> Html.input([{"id", "value"},{"name", "value"},{"type", "number"},{"value", status["courseWater"]}]) <> "&#176;<br>"
    <> Html.input([{"type", "submit"},{"value", "Change course"}])
    )
    |> Html.form(method: "POST", action: "/course/#{key}")
  end

  defp render_wind_graph(status, _key) do
    angle =
      case status[:autopilot][:waypoints] do
        [tgt={_,_}|_tail] ->
          Util.get_course({status["lat"],status["lon"]}, tgt)
        _ ->
          nil
      end
    Gpilot.Wind.svg_graph(status["boatType"], status["windDir"], status["windSpeed"], angle)
    |> Html.div([{"style", "float:right"}])
  end

  defp render_waypoints(status, key) do
    waypoints =
      [
        render_waypoint_list(status["speedGround"] |> Util.ms_to_kts(), {status["lat"], status["lon"]}, 0, 0, status[:autopilot][:waypoints]),
        Html.input([{"type", "submit"},{"value", "Set waypoints"}]),
      ]
      |> Html.div()
      |> Html.form(method: "POST", action: "/waypoint/#{key}")

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
        Html.input([{"type", "submit"}, {"value", "Set autopilot"}])
      ]
      |> Enum.join("")
      |> Html.form(method: "POST", action: "/autopilot/#{key}")

    upload =
      [
        Html.input([{"type", "file"},{"id", "waypoints"}, {"name", "waypoints"}]),
        Html.input([{"type", "submit"}, {"value", "Upload GPX"}])
      ]
      |> Enum.join("")
      |> Html.form(method: "POST", action: "/waypoint/#{key}/upload", enctype: "multipart/form-data")

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
      Html.a("https://www.windy.com/?gfs,#{Float.round(status["lat"],3)},#{Float.round(status["lon"],3)},8", "Windy", "_blank"),
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
end
