defmodule Metex.Worker do
  use GenServer

  ## Client API
  def get_temperature(pid, location) do
    GenServer.call(pid, {:location, location})
  end

  def get_stats(pid) do
    GenServer.call(pid, :get_stats)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def reset_stats(pid) do
    GenServer.cast(pid, :reset_stats)
  end

  ## Server API
  def handle_call({:location, location}, _from, stats) do
    case temperature_of(location) do
      {:ok, temp} ->
        new_stats = update_stats(stats, location)
        {:reply, "#{temp}°C", new_stats}

      _ ->
        {:reply, :error, stats}
    end
  end

  def handle_call(:get_stats, _from, stats) do
    {:reply, stats, stats}
  end

  ## Server Callbacks
  def init(:ok) do
    {:ok, %{}}
  end

  def handle_cast(:reset_stats, _stats) do
    {:noreply, %{}}
  end

  ## Helper Functions
  defp temperature_of(location) do
    url_for(location)
    |> HTTPoison.get()
    |> parse_response
  end

  defp url_for(location) do
    prepared_location = URI.encode(location)
    "http://api.openweathermap.org/data/2.5/weather?q=#{prepared_location}&appid=#{apikey()}"
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body |> JSON.decode!() |> compute_temperature
  end

  defp parse_response(_) do
    :error
  end

  defp compute_temperature(json) do
    try do
      temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
      {:ok, temp}
    rescue
      _ ->
        :error
    end
  end

  def apikey do
    "c649529fc9c340bf4861e9259165d067"
  end

  defp update_stats(old_stats, location) do
    case Map.has_key?(old_stats, location) do
      true ->
        Map.update!(old_stats, location, &(&1 + 1))

      false ->
        Map.put_new(old_stats, location, 1)
    end
  end
end
