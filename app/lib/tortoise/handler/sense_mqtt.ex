defmodule Tortoise.Handler.SenseMQTT do
  require Logger

  use Tortoise.Handler
  alias Sense.{Actuator, Device, Measure, Metric, Repo, User}

  @moduledoc """
  Mqtt message handler, It takes new events from external sources(devices, browsers) and perform actions over this data (Store in database, mock device...)
  """

  def init(args) do
    Logger.info("Initializing handler")
    {:ok, args}
  end

  def connection(:up, state) do
    Logger.info("Connection has been established")
    {:ok, state}
  end

  def connection(:down, state) do
    Logger.info("Connection has been dropped")
    {:ok, state}
  end

  def connection(:terminating, state) do
    Logger.warn("Connection is terminating")
    {:ok, state}
  end

   def subscription(:up, topic, state) do
    Logger.info("Subscribed to #{topic}")
    {:ok, state}
  end

  def subscription({:warn, [requested: req, accepted: qos]}, topic, state) do
    Logger.warn("Subscribed to #{topic}; requested #{req} but got accepted with QoS #{qos}")
    {:ok, state}
  end

  def subscription({:error, reason}, topic, state) do
    Logger.error("Error subscribing to #{topic}; #{inspect(reason)}")
    {:ok, state}
  end

  def subscription(:down, topic, state) do
    Logger.info("Unsubscribed from #{topic}")
    {:ok, state}
  end

  def terminate(reason, _state) do
    Logger.warn("Client has been terminated with reason: #{inspect(reason)}")
    :ok
  end

  def send_message([username, device_id, actuator_id], payload) do
    topic = Enum.join([username, device_id, "actuator",  actuator_id], "/")
    Tortoise.publish("my_client_id", topic, payload, qos: 0)
  end

  # topic filter username/device_name/metric/metric_name
  def handle_message([username, device_name, "metric", metric_name], payload, state) do
    {:ok, device} = check_and_autogenerate_relationships(username, device_name)

    metric =
      case Repo.get_by(Metric, device_id: device.id, name: metric_name) do
        nil  -> %Metric{name: metric_name, description: "Autogenerated", device_id: device.id}
        metric -> metric
      end

    metric
    |> Metric.changeset
    |> Repo.insert_or_update

    Measure.write_measure(metric, parse_payload(payload))

    IO.puts "[Tortoise.Handler.SenseMQTT] held message: #{Enum.join([username, device_name, 'metric', metric_name], "-")}/#{payload}/#{state}"

    {:ok, state}
  end

  def handle_message([username, device_name, "actuator", actuator_name], payload, state) do
    {:ok, device} = check_and_autogenerate_relationships(username, device_name)
    value = parse_payload(payload, Integer)

    metric =
      case Repo.get_by(Actuator, device_id: device.id, name: actuator_name) do
        nil  -> %Actuator{name: actuator_name, description: "Autogenerated", device_id: device.id, type: "button", value: value}
        actuator ->
          if actuator.value != value do
            Tortoise.Handler.SenseMQTT.send_message([username, device.id, actuator.id], value |> Integer.to_string)
          end

          Actuator.changeset(actuator, %{value: value})
      end

     metric
     |> Actuator.changeset
     |> Repo.insert_or_update

    IO.puts "[Tortoise.Handler.SenseMQTT] held message: #{Enum.join([username, device_name, 'actuator', actuator_name], "-")}/#{payload}/#{state}"

    {:ok, state}
  end

  def handle_message(topic, payload, state) do
    IO.puts "[Tortoise.Handler.SenseMQTT] Unheld message: #{Enum.join(topic, "-")}/#{payload}/#{state}"

    {:ok, state}
  end

  defp check_and_autogenerate_relationships(username, device_name) do
    user = Repo.get_by!(User, username: username)

    device =
      case Repo.get_by(Device, user_id: user.id, name: device_name) do
        nil  -> %Device{name: device_name, description: "Autogenerated", user_id: user.id} # not found, we build one
        device -> device                   # exists, let's use it
      end

    device
    |> Device.changeset
    |> Repo.insert_or_update
  end

  defp parse_payload(payload, type  \\ Float) do
    payload
    |> type.parse
    |> Tuple.to_list
    |> List.first
  end
end
