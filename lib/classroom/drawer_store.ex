defmodule Classroom.DrawerStore do
  '''
  One drawer per student, will be per students in each class
  '''
  use GenServer

  def start_link(_args) do
    # debug: [:trace]
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def notify_change(username, from) do
    GenServer.cast(__MODULE__, {:notify_change, username, from})
  end

  def get_all_filename() do
    GenServer.call(__MODULE__, {:get_all_filename, self()})
  end

  def share(filename, share_target) do
    GenServer.call(__MODULE__, {:share, filename, share_target, self()})
  end

  def delete(filename) do
    GenServer.call(__MODULE__, {:delete, filename, self()})
  end

  def init(_args) do
    {:ok, Path.expand("~/tmp_upload")}
  end

  def handle_cast({:notify_change, username, from}, path) do
    {:ok, user_pid} = Classroom.ActiveUsers.find_pid_by_user(username)
    send user_pid, {:notify_change, return_all_file_list(username), from}
    {:noreply, path}
  end

  def handle_call({:get_all_filename, owner_pid}, _from, path) do
    {:ok, owner_name} = Classroom.ActiveUsers.find_user_by_pid(owner_pid)
    {:reply, return_all_file_list(owner_name), path}
  end

  def handle_call({:share, filename, share_target, owner_pid}, _from, path) do
    {:ok, owner_name} = Classroom.ActiveUsers.find_user_by_pid(owner_pid)
    origin_file_path = "#{path}/#{owner_name}/#{filename}"
    file_path = "#{path}/#{share_target}/"
    File.mkdir_p! file_path

    new_file_name = get_no_repeat_filepath(file_path, filename, 0)

    File.write!(new_file_name, File.read! origin_file_path)
    {:reply, :ok, path}
  end

  def handle_call({:delete, filename, owner_pid}, _from, path) do
    {:ok, owner_name} = Classroom.ActiveUsers.find_user_by_pid(owner_pid)
    file_path = "#{path}/#{owner_name}/#{filename}"
    case File.exists?(file_path) do
      true -> File.rm(file_path)
        {:reply, %{result: :ok, files: return_all_file_list(owner_name)}, path}

      false ->
        {:reply, %{result: :error, reason: :already_deleted}, path}
    end
  end

  defp return_all_file_list(username) do
    Path.wildcard(Path.expand("~/tmp_upload/#{username}/*.*")) # do not support sub-directory
    |> Enum.map(&Path.basename/1)
  end

  defp get_no_repeat_filepath(path, filename, i) do
    new_filename =
      if i > 0 do
        {dot_index, _} = :binary.match filename, "."
        first = String.slice(filename, 0..(dot_index-1))
        second = String.slice(filename, (dot_index+1)..-1)
        first <> " (#{i})." <> second
      else
        filename
      end
    case File.exists?("#{path}#{new_filename}") do # path <> filename
      true -> get_no_repeat_filepath(path, filename, i+1)
      false -> "#{path}#{new_filename}"
    end
  end

end
