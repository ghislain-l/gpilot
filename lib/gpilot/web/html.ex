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
defmodule Gpilot.Web.Html do
  @moduledoc """
  The various helper function are meant to open/close the HTML elements
  and some various processing
  But not escaping any strings, this must be done by the caller if
  the strings are under user control or from unknown origin
  """
  import Kernel, except: [div: 2]

  def content_type() do
    %{
      "content-type" => "text/html"
    }
  end

  def head(title: title) do
    # maybe add this to refresh automatically?
    #<meta http-equiv="refresh" content="60">
    """
    <!DOCTYPE html>
    <head>
    <meta charset="UTF-8">
    <title>#{title}</title>
    </head>
    """
  end

  def body(script: script, content: content) do
    """
    <body>
    <script>
    #{script}
    </script>
    #{content}
    """
  end

  def attributes(attrs) when is_list(attrs) do
    for {k,v} <- attrs do
      "#{k}=\"#{v}\""
    end
    |> Enum.join(", ")
  end

  def div(content, attrs\\[])
  def div(content, attrs) when is_binary(content) do
    """
    <div #{attributes(attrs)}>
    #{content}
    </div>
    """
  end
  def div(content, attrs) when is_list(content) do
    content
    |> Enum.join()
    |> div(attrs)
  end

  def h1(content), do: tag("h1", content)
  def h2(content), do: tag("h2", content)
  def h3(content), do: tag("h3", content)
  def h4(content), do: tag("h4", content)
  def h5(content), do: tag("h5", content)
  def h6(content), do: tag("h6", content)

  def hr(), do: "<hr>"
  def br(), do: "<br>"

  def table(rows, attrs\\[])
  def table(rows, attrs) when is_list(rows) do
    """
    <table #{attributes(attrs)}>
    #{Enum.map_join(rows, &tr/1)}
    </table>
    """
  end

  def tr({datas,attrs}) when is_list(datas) do
    """
    <tr #{attributes(attrs)}>
    #{Enum.map_join(datas, &td/1)}
    </tr>
    """
  end
  def tr(datas) when is_list(datas) do
    tr({datas,[]})
  end

  def td({data,attrs}) when is_binary(data) do
    """
    <td #{attributes(attrs)}>
    #{data}
    </td>
    """
  end
  def td(data) when is_binary(data) do
    td({data,[]})
  end


  def ul(list, attr\\"") when is_list(list) do
    """
    <ul #{attr}>
    #{Enum.map_join(list, fn x -> "<li>#{x}</li>\n" end)}
    </ul>
    """
  end

  def a(href, content, target\\"_self") when is_binary(href) and is_binary(content) do
    tag("a", [{"href", href},{"target", target}], content)
  end

  def p(content, attrs\\[]) when is_binary(content) do
    tag("p", attrs, content)
  end

  def button(content, attrs) do
    tag("button", attrs, content)
  end

  def b(content), do: tag("b", content)

  def form(content, method: m, action: href, enctype: enctype) do
    tag("form", [{"method",m}, {"action", href}, {"enctype", enctype}], content)
  end

  def form(content, method: m, action: href, target: target) do
    tag("form", [{"method",m}, {"action", href}, {"target", target}], content)
  end

  def form(content, method: m, action: href) do
    tag("form", [{"method",m}, {"action", href}], content)
  end


  def input(attrs) when is_list(attrs) do
    tag("input", attrs, "")
  end

  # internal
  defp tag(t,c) when is_binary(c) do
    """
    <#{t}>
    #{c}
    </#{t}>
    """
  end
  defp tag(t,a,c) when is_binary(c) and is_list(a) do
    """
    <#{t} #{attributes(a)}>
    #{c}
    </#{t}>
    """
  end

end
