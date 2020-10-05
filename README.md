# Gpilot

Help you play the naval simulation at https://8bitbyte.ca/sailnavsim

Tested on a debian with Elixir 1.7 and 1.9, and Erlang 21 and 22

## Install

Clone this repo in /opt/gpilot
Then run setup.sh to compile and install as a systemd service

## Configuration

Some settings can be changed in config/config.exs.
Comments in this file should help you.

Description of available runtime options:

- By default, an index page shows the list of active boats. If the service is available publicly, it is advised to disable the index page, as it will leak your boats keys
- The default http port is 8080, can be changed freely

## Use

### Starting a boat

You can start/stop the monitoring of an existing boat by
visiting
- your_host_ip:8080/new/your_boat_key
- your_host_ip:8080/del/your_boat_key

If, for any reason, the service is restarted, the list of boat process is persisted and all restarts automatically.
If you want to clear all data, remove /opt/gpilot/database.ets when the service is stopped.

## Controlling a boat

After the process is started, the boat page is available at
```
your_host_ip:8080/boat/your_boat_key
```

where you will see the position, a wind graph with the latest wind data.
On the wind graph, 6 angles are displayed:

- 2 for best course when going directly upwind 
- 2 for best course when going directly downwind 
- 2 for course with the highest speed

There is an autopilot allowing 2 modes of operation (and a disabled mode):

- constant angle with respect to the wind. It will adjust every minute to follow the wind direction.
- following a list of waypoints, using shortest path between waypoints.

When waypoints are set, an additionnal line (and angle) is shown on the wind graph. It is perpendicular to the direction of the next waypoint and allow easy manual trade-off between following the direct route, or deviating for increased speed. Autopilot should be disabled if you do not want a direct route, as manual actions will be overidden by the autopilot.

You can upload a GPX file to set a new list of waypoints. The first position in the gpx is assumed to be the boat position, and thus is discarded.
You can also manually add/edit/delete waypoints and see the resulting course/distance.

