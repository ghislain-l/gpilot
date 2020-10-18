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
defmodule Gpilot.Wind do

  @doc """
  Gets the speed of the boat for several directions
  return a tuple {wind_response, list_of_angles}
  where
  - wind_response is a list of {course, speed}, and course is ranging from 0 to 360
  - list_of_angles contains:
    - first 2 are the best heading for upwind direction
    - next  2 are the best heading for downwind direction
    - last  2 are the best heading for maximum speed
  """
  def get_response(boat_type, wind_dir, wind_speed) do
    wr =
      boat_type
      |> wind_response_data()
      |> interpolate(wind_speed)
      |> interpolate_headings()
    {wr |> Enum.map(rotate(wind_dir)), wr |> best_angles(wind_dir)}
  end

  @doc """
  Generate a svg graph of wind response, with interesting angles
  """
  def svg_graph(boat_type, wind_dir, wind_speed, angle) do

    """
    <svg width="800" height="800" id="wind_graph">
      <circle cx="400" cy="400" r="400" stroke="white" stroke-width="1" fill="dodgerblue" />
      <circle cx="400" cy="400" r="350" stroke="white" stroke-width="1" fill="deepskyblue" />
      <circle cx="400" cy="400" r="300" stroke="white" stroke-width="1" fill="dodgerblue" />
      <circle cx="400" cy="400" r="250" stroke="white" stroke-width="1" fill="deepskyblue" />
      <circle cx="400" cy="400" r="200" stroke="white" stroke-width="1" fill="dodgerblue" />
      <circle cx="400" cy="400" r="150" stroke="white" stroke-width="1" fill="deepskyblue" />
      <circle cx="400" cy="400" r="100" stroke="white" stroke-width="1" fill="dodgerblue" />
      <circle cx="400" cy="400" r="50"  stroke="white" stroke-width="1" fill="deepskyblue" />
      <circle cx="400" cy="400" r="1"   stroke="white" stroke-width="1" fill="black" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate(  0 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate( 10 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate( 20 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate( 30 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate( 40 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate( 50 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate( 60 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate( 70 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate( 80 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate( 90 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate(100 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate(110 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate(120 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate(130 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate(140 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate(150 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate(160 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      <line x1="400" y1="800" x2="400" y2="0"   transform="rotate(170 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" stroke-dasharray="1,5" />
      #{wind_response_path(boat_type, wind_dir, wind_speed, angle)}
    </svg>
    """
  end

  defp wind_response_path(boat_type, wind_dir, wind_speed, angle) do
    {wind_response, angles} = get_response(boat_type, wind_dir, wind_speed)
    wr_path =
      wind_response
      |> Enum.map(fn {d,s} ->
        s = Util.ms_to_kts(s)
        x = 10*s*:math.sin(d/180*:math.pi())
        y = 10*s*:math.cos(d/180*:math.pi())
        "L#{400+round(x)} #{400-round(y)}" 
      end)
      |> Enum.join(" ")
    angles_text =
      for a <- angles do
        """
        <text x="#{400+round(375*Util.sin(a))}" y="#{400-round(375*Util.cos(a))}" fill="black">#{round(a)}</text>
        """
      end
    vmg =
      if is_number(angle) do
        {vmg_dir, vmg_speed} =
          Enum.reduce(wind_response, {0,0.0}, fn {d,s},{_,ms}=acc ->
            s = Util.cos(d-angle)*s # speed along the "angle" direction
            if s > ms do
              {d, s}
            else
              acc
            end
          end)
        s = 10*Util.ms_to_kts(vmg_speed)
        """
        <text x="#{400+round(s*Util.sin(vmg_dir))}" y="#{400-round(s*Util.cos(vmg_dir))}" fill="black">#{round(Util.normalize_angle(vmg_dir))}</text>
        <line x1="0" y1="#{round(399-s)}" x2="800" y2="#{round(399-s)}" transform="rotate(#{round(angle)} 400,400)" style="stroke:rgb(0,0,0);stroke-width:1" />
        """
      else
        ""
      end

    """
    #{angles_text}
    <path d="M400 400 #{wr_path}" fill="none" stroke="red"/>
    #{vmg}
    """
  end

  # Wind response data taken from
  # repo https://github.com/ls4096/sailnavsim-core
  # file src/BoatWindResponse.c
  defp wind_response_data(boat_type)
  defp wind_response_data(0) do
    # Classic
    [
      #  1      2      4      8     12      16    24     x     m/s
      [-0.10, -0.10, -0.10, -0.10, -0.10, -0.10, -0.10, 0.0], # 0 deg
      [-0.08, -0.08, -0.08, -0.08, -0.08, -0.08, -0.08, 0.0], # 10 deg
      [-0.05, -0.05, -0.05, -0.05, -0.05, -0.05, -0.05, 0.0], # 20 deg
      [0.00,  0.00,   0.00,  0.00,  0.00,  0.00,  0.00, 0.0], # 30 deg
      [0.45,  0.58,   0.55,  0.36,  0.25,  0.17,  0.10, 0.0], # 40 deg
      [0.52,  0.63,   0.63,  0.42,  0.30,  0.21,  0.12, 0.0], # 50 deg
      [0.60,  0.68,   0.68,  0.45,  0.32,  0.22,  0.13, 0.0], # 60 deg
      [0.62,  0.75,   0.69,  0.46,  0.33,  0.22,  0.14, 0.0], # 70 deg
      [0.61,  0.78,   0.70,  0.47,  0.34,  0.23,  0.14, 0.0], # 80 deg
      [0.60,  0.76,   0.71,  0.48,  0.34,  0.23,  0.14, 0.0], # 90 deg
      [0.58,  0.74,   0.72,  0.48,  0.35,  0.23,  0.14, 0.0], # 100 deg
      [0.55,  0.71,   0.72,  0.49,  0.35,  0.23,  0.15, 0.0], # 110 deg
      [0.53,  0.68,   0.70,  0.49,  0.35,  0.24,  0.15, 0.0], # 120 deg
      [0.51,  0.65,   0.68,  0.48,  0.35,  0.24,  0.15, 0.0], # 130 deg
      [0.48,  0.60,   0.61,  0.47,  0.35,  0.25,  0.15, 0.0], # 140 deg
      [0.45,  0.57,   0.58,  0.45,  0.34,  0.25,  0.16, 0.0], # 150 deg
      [0.43,  0.54,   0.54,  0.42,  0.33,  0.24,  0.16, 0.0], # 160 deg
      [0.41,  0.52,   0.52,  0.40,  0.32,  0.23,  0.15, 0.0], # 170 deg
      [0.39,  0.50,   0.50,  0.37,  0.30,  0.20,  0.13, 0.0], # 180 deg
    ]
  end
  defp wind_response_data(1) do
    # Seascape 18
    [
      #  1      2      4      8     12      16    24     x     m/s
      [-0.10, -0.10, -0.10, -0.10, -0.10, -0.10, -0.10, 0.0], # 0 deg
      [-0.08, -0.08, -0.08, -0.08, -0.08, -0.08, -0.08, 0.0], # 10 deg
      [-0.05, -0.05, -0.05, -0.05, -0.05, -0.05, -0.05, 0.0], # 20 deg
      [0.400, 0.400, 0.250, 0.200, 0.180, 0.139, 0.092, 0.0], # 30 deg
      [0.620, 0.620, 0.595, 0.350, 0.290, 0.226, 0.149, 0.0], # 40 deg
      [0.755, 0.755, 0.668, 0.394, 0.317, 0.246, 0.162, 0.0], # 50 deg
      [0.792, 0.792, 0.688, 0.417, 0.337, 0.261, 0.172, 0.0], # 60 deg
      [0.811, 0.811, 0.698, 0.444, 0.359, 0.278, 0.183, 0.0], # 70 deg
      [0.826, 0.826, 0.712, 0.469, 0.386, 0.300, 0.198, 0.0], # 80 deg
      [0.837, 0.837, 0.730, 0.490, 0.420, 0.325, 0.214, 0.0], # 90 deg
      [0.841, 0.841, 0.733, 0.515, 0.451, 0.350, 0.231, 0.0], # 100 deg
      [0.845, 0.845, 0.736, 0.540, 0.483, 0.374, 0.247, 0.0], # 110 deg
      [0.818, 0.818, 0.721, 0.575, 0.546, 0.423, 0.279, 0.0], # 120 deg
      [0.767, 0.767, 0.692, 0.540, 0.602, 0.467, 0.308, 0.0], # 130 deg
      [0.706, 0.706, 0.652, 0.497, 0.594, 0.461, 0.304, 0.0], # 140 deg
      [0.635, 0.635, 0.602, 0.447, 0.523, 0.405, 0.267, 0.0], # 150 deg
      [0.555, 0.555, 0.525, 0.385, 0.465, 0.360, 0.249, 0.0], # 160 deg
      [0.525, 0.525, 0.475, 0.355, 0.440, 0.341, 0.237, 0.0], # 170 deg
      [0.475, 0.475, 0.445, 0.338, 0.425, 0.329, 0.228, 0.0], # 180 deg
    ]
  end
  defp wind_response_data(2) do
    # Contessa 25
    [
      #  1      2      4      8     12      16    24     x     m/s
      [-0.10, -0.10, -0.10, -0.10, -0.10, -0.10, -0.10, 0.0], # 0 deg
      [-0.08, -0.08, -0.08, -0.08, -0.08, -0.08, -0.08, 0.0], # 10 deg
      [-0.05, -0.05, -0.05, -0.05, -0.05, -0.05, -0.05, 0.0], # 20 deg
      [0.100, 0.100, 0.080, 0.050, 0.040, 0.032, 0.022, 0.0], # 30 deg
      [0.580, 0.580, 0.530, 0.350, 0.280, 0.223, 0.152, 0.0], # 40 deg
      [0.693, 0.693, 0.618, 0.382, 0.301, 0.241, 0.164, 0.0], # 50 deg
      [0.727, 0.727, 0.651, 0.391, 0.310, 0.248, 0.169, 0.0], # 60 deg
      [0.743, 0.743, 0.665, 0.398, 0.320, 0.256, 0.175, 0.0], # 70 deg
      [0.753, 0.753, 0.678, 0.404, 0.327, 0.262, 0.179, 0.0], # 80 deg
      [0.757, 0.757, 0.689, 0.409, 0.331, 0.265, 0.181, 0.0], # 90 deg
      [0.760, 0.760, 0.691, 0.418, 0.341, 0.273, 0.186, 0.0], # 100 deg
      [0.763, 0.763, 0.694, 0.428, 0.351, 0.280, 0.192, 0.0], # 110 deg
      [0.735, 0.735, 0.675, 0.425, 0.357, 0.285, 0.195, 0.0], # 120 deg
      [0.692, 0.692, 0.635, 0.416, 0.350, 0.280, 0.192, 0.0], # 130 deg
      [0.639, 0.639, 0.590, 0.403, 0.338, 0.271, 0.184, 0.0], # 140 deg
      [0.578, 0.578, 0.538, 0.383, 0.320, 0.256, 0.175, 0.0], # 150 deg
      [0.490, 0.490, 0.465, 0.363, 0.315, 0.252, 0.173, 0.0], # 160 deg
      [0.440, 0.440, 0.417, 0.348, 0.305, 0.244, 0.167, 0.0], # 170 deg
      [0.400, 0.400, 0.386, 0.353, 0.305, 0.244, 0.167, 0.0], # 180 deg
    ]
  end
  defp wind_response_data(3) do
    # Hanse 385
    [
      #  1      2      4      8     12      16    24     x     m/s
      [-0.10, -0.10, -0.10, -0.10, -0.10, -0.10, -0.10, 0.0], # 0 deg
      [-0.08, -0.08, -0.08, -0.08, -0.08, -0.08, -0.08, 0.0], # 10 deg
      [-0.05, -0.05, -0.05, -0.05, -0.05, -0.05, -0.05, 0.0], # 20 deg
      [0.200, 0.200, 0.180, 0.150, 0.120, 0.097, 0.067, 0.0], # 30 deg
      [0.660, 0.660, 0.620, 0.400, 0.320, 0.256, 0.175, 0.0], # 40 deg
      [0.835, 0.835, 0.758, 0.472, 0.369, 0.295, 0.201, 0.0], # 50 deg
      [0.910, 0.910, 0.819, 0.489, 0.383, 0.307, 0.209, 0.0], # 60 deg
      [0.960, 0.960, 0.855, 0.503, 0.396, 0.317, 0.217, 0.0], # 70 deg
      [0.985, 0.985, 0.873, 0.515, 0.411, 0.329, 0.224, 0.0], # 80 deg
      [0.985, 0.985, 0.872, 0.523, 0.427, 0.341, 0.234, 0.0], # 90 deg
      [0.945, 0.945, 0.853, 0.531, 0.438, 0.351, 0.239, 0.0], # 100 deg
      [0.905, 0.905, 0.834, 0.539, 0.450, 0.360, 0.245, 0.0], # 110 deg
      [0.873, 0.873, 0.806, 0.534, 0.458, 0.367, 0.250, 0.0], # 120 deg
      [0.812, 0.812, 0.755, 0.521, 0.447, 0.357, 0.244, 0.0], # 130 deg
      [0.741, 0.741, 0.698, 0.503, 0.428, 0.342, 0.234, 0.0], # 140 deg
      [0.660, 0.660, 0.632, 0.478, 0.402, 0.321, 0.219, 0.0], # 150 deg
      [0.575, 0.575, 0.545, 0.450, 0.391, 0.311, 0.213, 0.0], # 160 deg
      [0.500, 0.500, 0.488, 0.428, 0.383, 0.302, 0.206, 0.0], # 170 deg
      [0.440, 0.440, 0.450, 0.425, 0.380, 0.300, 0.204, 0.0], # 180 deg
    ]
  end
  defp wind_response_data(4) do
    # Volvo70
    [
      #  1      2      4      8     12      16    24     x     m/s
      [-0.10, -0.10, -0.10, -0.10, -0.10, -0.10, -0.10, 0.0], # 0 deg
      [-0.08, -0.08, -0.08, -0.08, -0.08, -0.08, -0.08, 0.0], # 10 deg
      [-0.05, -0.05, -0.05, -0.05, -0.05, -0.05, -0.05, 0.0], # 20 deg
      [0.300, 0.300, 0.333, 0.400, 0.280, 0.217, 0.141, 0.0], # 30 deg
      [1.240, 1.240, 1.100, 0.780, 0.512, 0.396, 0.258, 0.0], # 40 deg
      [1.442, 1.442, 1.330, 0.868, 0.595, 0.461, 0.300, 0.0], # 50 deg
      [1.562, 1.562, 1.396, 0.931, 0.647, 0.500, 0.326, 0.0], # 60 deg
      [1.634, 1.634, 1.459, 1.022, 0.706, 0.547, 0.356, 0.0], # 70 deg
      [1.697, 1.697, 1.520, 1.098, 0.752, 0.581, 0.378, 0.0], # 80 deg
      [1.750, 1.750, 1.580, 1.159, 0.783, 0.605, 0.394, 0.0], # 90 deg
      [1.737, 1.737, 1.570, 1.179, 0.826, 0.639, 0.416, 0.0], # 100 deg
      [1.723, 1.723, 1.560, 1.199, 0.870, 0.673, 0.438, 0.0], # 110 deg
      [1.642, 1.642, 1.474, 1.220, 0.886, 0.685, 0.446, 0.0], # 120 deg
      [1.446, 1.446, 1.338, 1.129, 0.887, 0.686, 0.447, 0.0], # 130 deg
      [1.266, 1.266, 1.192, 1.020, 0.836, 0.647, 0.421, 0.0], # 140 deg
      [1.102, 1.102, 1.037, 0.892, 0.730, 0.565, 0.368, 0.0], # 150 deg
      [0.920, 0.920, 0.927, 0.795, 0.651, 0.504, 0.328, 0.0], # 160 deg
      [0.860, 0.860, 0.880, 0.757, 0.615, 0.476, 0.309, 0.0], # 170 deg
      [0.833, 0.833, 0.862, 0.742, 0.600, 0.464, 0.302, 0.0], # 180 deg
    ]
  end
  defp wind_response_data(5) do
    # Super Maxi Scallywag
    [
      #  1      2      4      8     12      16    24     x     m/s
      [-0.10,  -0.10, -0.10, -0.10, -0.10, -0.10, -0.10, 0.0], # 0 deg
      [-0.08,  -0.08, -0.08, -0.08, -0.08, -0.08, -0.08, 0.0], # 10 deg
      [-0.05,  -0.05, -0.05, -0.05, -0.05, -0.05, -0.05, 0.0], # 20 deg
      [0.400,  0.400, 0.450, 0.550, 0.400, 0.310, 0.196, 0.0], # 30 deg
      [1.510,  1.510, 1.400, 0.950, 0.580, 0.449, 0.284, 0.0], # 40 deg
      [1.867,  1.867, 1.628, 1.012, 0.674, 0.521, 0.330, 0.0], # 50 deg
      [2.020,  2.020, 1.712, 1.079, 0.728, 0.563, 0.356, 0.0], # 60 deg
      [2.131,  2.131, 1.812, 1.174, 0.801, 0.620, 0.392, 0.0], # 70 deg
      [2.193,  2.193, 1.884, 1.245, 0.859, 0.665, 0.420, 0.0], # 80 deg
      [2.205,  2.205, 1.929, 1.292, 0.902, 0.698, 0.441, 0.0], # 90 deg
      [2.152,  2.152, 1.884, 1.325, 0.915, 0.708, 0.447, 0.0], # 100 deg
      [2.098,  2.098, 1.839, 1.358, 0.928, 0.718, 0.454, 0.0], # 110 deg
      [2.028,  2.028, 1.822, 1.356, 0.959, 0.742, 0.469, 0.0], # 120 deg
      [1.873,  1.873, 1.709, 1.331, 0.954, 0.738, 0.466, 0.0], # 130 deg
      [1.682,  1.682, 1.563, 1.257, 0.924, 0.715, 0.452, 0.0], # 140 deg
      [1.457,  1.457, 1.384, 1.134, 0.866, 0.670, 0.424, 0.0], # 150 deg
      [1.135,  1.135, 1.130, 0.986, 0.777, 0.617, 0.390, 0.0], # 160 deg
      [0.997,  0.997, 0.990, 0.862, 0.699, 0.555, 0.360, 0.0], # 170 deg
      [0.928,  0.928, 0.900, 0.778, 0.634, 0.518, 0.335, 0.0], # 180 deg
    ]
  end
  defp wind_response_data(6) do
    # 140-foot Brigantine
    [
      #  1      2      4      8     12      16    24     x     m/s
      [-0.10, -0.10, -0.10, -0.10, -0.10, -0.10, -0.10, 0.0], # 0 deg
      [-0.08, -0.08, -0.08, -0.08, -0.08, -0.08, -0.08, 0.0], # 10 deg
      [-0.05, -0.05, -0.05, -0.05, -0.05, -0.05, -0.05, 0.0], # 20 deg
      [0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.0], # 30 deg
      [0.122, 0.122, 0.092, 0.073, 0.056, 0.042, 0.030, 0.0], # 40 deg
      [0.533, 0.533, 0.401, 0.321, 0.273, 0.247, 0.176, 0.0], # 50 deg
      [0.704, 0.704, 0.530, 0.424, 0.367, 0.319, 0.228, 0.0], # 60 deg
      [0.782, 0.782, 0.588, 0.471, 0.394, 0.331, 0.236, 0.0], # 70 deg
      [0.882, 0.882, 0.663, 0.531, 0.433, 0.350, 0.249, 0.0], # 80 deg
      [0.910, 0.910, 0.684, 0.547, 0.442, 0.356, 0.253, 0.0], # 90 deg
      [0.943, 0.943, 0.709, 0.567, 0.448, 0.360, 0.256, 0.0], # 100 deg
      [0.977, 0.977, 0.734, 0.588, 0.468, 0.372, 0.265, 0.0], # 110 deg
      [0.999, 0.999, 0.751, 0.601, 0.477, 0.378, 0.269, 0.0], # 120 deg
      [1.016, 1.016, 0.764, 0.611, 0.485, 0.389, 0.277, 0.0], # 130 deg
      [1.010, 1.010, 0.760, 0.608, 0.491, 0.417, 0.297, 0.0], # 140 deg
      [0.977, 0.977, 0.735, 0.588, 0.474, 0.406, 0.289, 0.0], # 150 deg
      [0.916, 0.916, 0.689, 0.551, 0.444, 0.381, 0.271, 0.0], # 160 deg
      [0.850, 0.850, 0.639, 0.511, 0.403, 0.336, 0.239, 0.0], # 170 deg
      [0.833, 0.833, 0.626, 0.501, 0.390, 0.322, 0.230, 0.0], # 180 deg
    ]
  end
  defp wind_response_data(7) do
    # Maxi Trimaran
    [
      #  1      2      4      8     12      16    24     x     m/s
      [-0.10, -0.10, -0.10, -0.10, -0.10, -0.10, -0.10, 0.0], # 0 deg
      [-0.08, -0.08, -0.08, -0.08, -0.08, -0.08, -0.08, 0.0], # 10 deg
      [-0.05, -0.05, -0.05, -0.05, -0.05, -0.05, -0.05, 0.0], # 20 deg
      [1.37,   1.33,  1.12,  0.67,  0.50,  0.38,  0.22, 0.0], # 30 deg
      [2.01,   2.02,  1.66,  1.00,  0.76,  0.58,  0.33, 0.0], # 40 deg
      [2.38,   2.41,  1.76,  1.10,  0.84,  0.65,  0.38, 0.0], # 50 deg
      [2.66,   2.70,  1.87,  1.18,  0.91,  0.73,  0.43, 0.0], # 60 deg
      [2.92,   2.85,  1.96,  1.25,  1.01,  0.83,  0.51, 0.0], # 70 deg
      [3.06,   2.96,  2.14,  1.38,  1.14,  0.95,  0.56, 0.0], # 80 deg
      [3.06,   2.96,  2.19,  1.45,  1.26,  1.05,  0.61, 0.0], # 90 deg
      [2.92,   2.85,  2.14,  1.55,  1.34,  1.07,  0.60, 0.0], # 100 deg
      [2.64,   2.67,  2.17,  1.59,  1.35,  1.11,  0.65, 0.0], # 110 deg
      [2.59,   2.59,  2.14,  1.59,  1.37,  1.17,  0.69, 0.0], # 120 deg
      [2.38,   2.34,  2.01,  1.61,  1.39,  1.21,  0.72, 0.0], # 130 deg
      [2.01,   1.98,  1.80,  1.53,  1.40,  1.23,  0.78, 0.0], # 140 deg
      [1.58,   1.58,  1.53,  1.31,  1.31,  1.30,  0.77, 0.0], # 150 deg
      [1.30,   1.26,  1.26,  1.16,  1.11,  1.15,  0.74, 0.0], # 160 deg
      [1.10,   1.13,  1.13,  0.97,  0.92,  0.95,  0.62, 0.0], # 170 deg
      [0.92,   0.98,  0.96,  0.85,  0.81,  0.84,  0.51, 0.0], # 180 deg
    ]
  end
  defp wind_response_data(8) do
    # IMOCA 60
    [
      #  1      2      4      8     12      16    24     x     m/s
      [-0.10, -0.10, -0.10, -0.10, -0.10, -0.10, -0.10, 0.0], # 0 deg
      [-0.08, -0.08, -0.08, -0.08, -0.08, -0.08, -0.08, 0.0], # 10 deg
      [-0.05, -0.05, -0.05, -0.05, -0.05, -0.05, -0.05, 0.0], # 20 deg
      [0.565, 1.013, 0.918, 0.464, 0.288, 0.214, 0.141, 0.0], # 30 deg
      [0.900, 1.418, 1.128, 0.605, 0.402, 0.303, 0.202, 0.0], # 40 deg
      [1.135, 1.678, 1.236, 0.671, 0.455, 0.349, 0.236, 0.0], # 50 deg
      [1.304, 1.853, 1.305, 0.727, 0.501, 0.390, 0.266, 0.0], # 60 deg
      [1.425, 1.978, 1.364, 0.787, 0.562, 0.445, 0.306, 0.0], # 70 deg
      [1.525, 2.030, 1.416, 0.864, 0.640, 0.517, 0.358, 0.0], # 80 deg
      [1.475, 2.030, 1.454, 0.959, 0.740, 0.605, 0.422, 0.0], # 90 deg
      [1.430, 1.948, 1.476, 1.049, 0.817, 0.667, 0.465, 0.0], # 100 deg
      [1.385, 1.968, 1.456, 1.141, 0.898, 0.732, 0.511, 0.0], # 110 deg
      [1.335, 1.945, 1.459, 1.235, 0.989, 0.803, 0.561, 0.0], # 120 deg
      [1.235, 1.823, 1.476, 1.225, 1.051, 0.845, 0.591, 0.0], # 130 deg
      [1.045, 1.620, 1.438, 1.274, 1.053, 0.851, 0.595, 0.0], # 140 deg
      [0.905, 1.400, 1.358, 1.289, 1.070, 0.865, 0.604, 0.0], # 150 deg
      [0.710, 1.158, 1.258, 1.164, 0.982, 0.791, 0.553, 0.0], # 160 deg
      [0.665, 1.010, 1.173, 1.059, 0.889, 0.717, 0.501, 0.0], # 170 deg
      [0.520, 0.843, 0.990, 0.956, 0.793, 0.641, 0.448, 0.0], # 180 deg
    ]
  end

  defp interpolate(wr, wind_speed) do
    {si,sf} =
      cond do
        wind_speed>=24 ->
          {6, 0.0}
        wind_speed>=16 ->
          {5, (wind_speed-16)/8.0}
        wind_speed>=12 ->
          {4, (wind_speed-12)/4.0}
        wind_speed>=8 ->
          {3, (wind_speed-8)/4.0}
        wind_speed>=4 ->
          {2, (wind_speed-4)/4.0}
        wind_speed>=2 ->
          {1, (wind_speed-2)/2.0}
        wind_speed>=1 ->
          {0, (wind_speed-1)/1.0}
        true ->
          {0, 0.0}
      end
    wr_s = 
      for x <- wr do
        [a,b|_] = Enum.drop(x, si)
        a*(1-sf) + b*sf
      end
    for {wri,i} <- (wr_s ++ (wr_s |> Enum.reverse() |> Enum.drop(1))) |> Enum.with_index() do
      {i*10, wind_speed*wri}
    end
  end

  defp rotate(wind_dir) do
    fn {d,s} -> {d+wind_dir, s} end
  end

  defp best_angles(wr, dir) do
    wr
    |> Enum.take(181) # only right half
    |> Enum.reduce([{0,0},{0,0},{0,0}], fn {d,s},[{up_d, up_s}, {all_d, all_s}, {down_d, down_s}] ->
      new_up =
        if Util.cos(d)*s > Util.cos(up_d)*up_s do
          {d,s}
        else
          {up_d, up_s}
        end
      new_all =
        if s > all_s do
          {d,s}
        else
          {all_d, all_s}
        end
      new_down =
        if Util.cos(d)*s < Util.cos(down_d)*down_s do
          {d,s}
        else
          {down_d, down_s}
        end
      [new_up, new_all, new_down]
    end)
    # add left part and rotate
    |> Enum.map(fn {a,_} -> [Util.normalize_angle(-a+dir), Util.normalize_angle(a+dir)] end)
    |> List.flatten()
  end

  # assume interval of 10 degrees
  defp interpolate_headings(list, acc\\[])
  defp interpolate_headings([{h,s}], acc) do
    acc ++ [{h,s}]
  end
  defp interpolate_headings([{h1,s1},{h2,s2}|tail], acc) do
    interpolated =
      for i <- 0..9 do
        {h1+i, (s1*(10-i)+s2*i)/10}
      end
    interpolate_headings([{h2,s2}|tail], acc++interpolated)
  end
end
