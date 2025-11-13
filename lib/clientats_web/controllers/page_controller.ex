defmodule ClientatsWeb.PageController do
  use ClientatsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
