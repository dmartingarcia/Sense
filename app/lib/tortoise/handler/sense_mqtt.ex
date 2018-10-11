defmodule Tortoise.Handler.SenseMQTT do
  use Tortoise.Handler
  alias Sense.{Repo, User, Device, Metric, Measure, Actuator}

  def init(args) do
    {:ok, args}
  end

  def connection(status, state) do
    {:ok, state}
  end

  def send_message([username, device_name, metric_name], payload) do
    topic = Enum.join([username, device_name, "actuator",  metric_name], "/")
    IO.inspect Tortoise.publish("my_client_id", topic, payload, qos: 0)
  end

  #  topic filter username/device/metric
  def handle_message([username, device_name, "metric", metric_name], payload, state) do
    {:ok, device} = check_and_autogenerate_relationships(username, device_name)

    {:ok, metric} =
      case Repo.get_by(Metric, device_id: device.id, name: metric_name) do
        nil  -> %Metric{name: metric_name, description: "Autogenerated", device_id: device.id}
        metric -> metric
      end
      |> Metric.changeset
      |> Repo.insert_or_update

    Measure.write_measure(metric, parse_payload(payload))

    IO.puts "[Tortoise.Handler.SenseMQTT] held message: #{Enum.join([username, device_name, 'metric', metric_name], "-")}/#{payload}/#{state}"

    {:ok, state}
  end

  def handle_message([username, device_name, "actuator", actuator_name], payload, state) do
    {:ok, device} = check_and_autogenerate_relationships(username, device_name)
    value = parse_payload(payload)

    {:ok, metric} =
      case Repo.get_by(Actuator, device_id: device.id, name: actuator_name) do
        nil  -> %Actuator{name: actuator_name, description: "Autogenerated", device_id: device.id, type: "button", value: value}
        actuator ->
          Actuator.changeset(actuator, %{value: value})
      end
      |> Actuator.changeset
      |> Repo.insert_or_update

    IO.puts "[Tortoise.Handler.SenseMQTT] held message: #{Enum.join([username, device_name, 'actuator', actuator_name], "-")}/#{payload}/#{state}"

    {:ok, state}
  end

  def handle_message(topic, payload, state) do
    IO.puts "[Tortoise.Handler.SenseMQTT] Unheld message: #{Enum.join(topic, "-")}/#{payload}/#{state}"
    IO.inspect topic

    {:ok, state}
  end

  def subscription(status, topic_filter, state) do
    {:ok, state}
  end

  def terminate(reason, state) do
    # tortoise doesn't care about what you return from terminate/2,
    # that is in alignment with other behaviours that implement a
    # terminate-callback
    :ok
  end

  defp check_and_autogenerate_relationships(username, device_name) do
      user = Repo.get_by!(User, username: username)

    {:ok, device} =
      case Repo.get_by(Device, user_id: user.id, name: device_name) do
        nil  -> %Device{name: device_name, description: "Autogenerated", user_id: user.id} # not found, we build one
        device -> device                   # exists, let's use it
      end
      |> Device.changeset
      |> Repo.insert_or_update
  end

  defp parse_payload(payload) do
    Integer.parse(payload) |> Tuple.to_list |> List.first
  end
end
