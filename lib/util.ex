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
defmodule Util do
  @doc """
  Convert m/s to knots, with 2 decimals
  """
  def ms_to_kts(speed) do
    (speed * 3600)
    |> m_to_nm()
    |> Float.round(2)
  end

  @doc """
  Convert m to nautical mile
  """
  def m_to_nm(distance) do
    distance / 1852.0
  end

  @doc """
  Normalize angles (in degree) into the range 0..360 inclusive
  """
  def normalize_angle(a) do
    cond do
      a<0 ->
        normalize_angle(a+360.0)
      a>360 ->
        normalize_angle(a-360.0)
      true ->
        a
    end
  end

  @doc """
  Convert to a pretty string representation of time
  t is a float representing hours
  """
  def show_duration(t) do
    mins = round(t*60)
    hours = div(mins,60)
    days = div(hours,24)
    hours = rem(hours,24)
    mins = rem(mins,60)
    cond do
      days > 0 ->
        "#{days}d #{hours}h #{to_string(mins) |> String.pad_leading(2, "0")}m"
      hours > 0 ->
        "#{hours}h #{to_string(mins) |> String.pad_leading(2, "0")}m"
      true ->
        "#{to_string(mins) |> String.pad_leading(2, "0")}m"
    end
  end

  @doc """
  sin with degree input
  """
  def sin(a) do
    :math.sin(a*:math.pi()/180.0)
  end
  @doc """
  cos with degree input
  """
  def cos(a) do
    :math.cos(a*:math.pi()/180.0)
  end
  @doc """
  tan with degree input
  """
  def tan(a) do
    :math.tan(a*:math.pi()/180.0)
  end
  @doc """
  atan2 with degree output
  """
  def atan2(a,b) do
    :math.atan2(a,b)*180.0/:math.pi()
  end


  @doc """
  Get the "great circle navigation" heading (shortest distance on a sphere)
  see: https://en.wikipedia.org/wiki/Great-circle_navigation
  """
  def get_course(_from={p1,l1}, _to={p2,l2}) do
    atan2( cos(p2)*sin(l2-l1) , cos(p1)*sin(p2) - sin(p1)*cos(p2)*cos(l2-l1) )
    |> normalize_angle()
  end

  @doc """
  Get distance in miles (assuming earth is a sphere of radius 3959mi)
  """
  def get_distance(_from={p1,l1}, _to={p2,l2}) do
    a = cos(p1)*sin(p2) - sin(p1)*cos(p2)*cos(l2-l1)
    b = cos(p2)*sin(l2-l1)
    n = :math.sqrt(a*a+b*b)
    d = sin(p1)*sin(p2) + cos(p1)*cos(p2)*cos(l2-l1)
    :math.atan2(n, d) * 3959.0
  end
end
