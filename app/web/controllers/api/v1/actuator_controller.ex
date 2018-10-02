defmodule Sense.Api.V1.ActuatorController do
  use Sense.Web, :controller
  alias Sense.{Device, Actuator}

  def index(conn, %{"device_id" => device_id}) do
    actuators = Actuator |> where([m], m.device_id == ^device_id) |> Repo.all
    render(conn, "index.json", actuators: actuators)
  end

  def create(conn, %{"actuator" => actuator_params, "device_id" => device_id}) do
    device = Repo.get!(Device, device_id)
    changeset = Actuator.changeset(%Actuator{device_id: device.id}, actuator_params)

    case Repo.insert(changeset) do
      {:ok, actuator} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", api_v1_device_actuator_path(conn, :show, device_id, actuator))
        |> render("show.json", actuator: actuator)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Sense.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id, "device_id" => device_id}) do
    actuator = Repo.get!(Actuator, id)
    render(conn, "show.json", actuator: actuator)
  end

  def update(conn, %{"id" => id, "device_id" => device_id, "actuator" => actuator_params}) do
    actuator = Repo.get!(Actuator, id)
    changeset = Actuator.changeset(actuator, actuator_params)

    case Repo.update(changeset) do
      {:ok, actuator} ->
        render(conn, "show.json", actuator: actuator)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Sense.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id, "device_id" => device_id}) do
    actuator = Repo.get_by!(Actuator, id: id, device_id: device_id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(actuator)

    send_resp(conn, :no_content, "")
  end
end
