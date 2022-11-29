defmodule TENDER do
  require Record
  require N2O
  use Application

  def start(_, _) do
      :logger.add_handlers(:n2o)
      app = Supervisor.start_link([], strategy: :one_for_one, name: TENDER)
      pass = :application.get_env(:n2o, :tender_pass,  "")
      login = :application.get_env(:n2o, :tender_login, "")
      :n2o_pi.start(N2O.pi(module: TENDER, table: :cipher, sup: TENDER,
              state: {"tenderLink", login, pass, 0}, name: "tenderLink"))
      app
  end

  def send(to, doc)  do
      :gen_server.cast :n2o_pi.pid(:cipher, "tenderLink"), {:send, "tenderLink", to, doc}
  end

  def down(id)  do
      :gen_server.cast :n2o_pi.pid(:cipher, "tenderLink"), {:download, id}
  end

  def proc(:init, pi) do
      {:ok, pi}
  end

  def proc({:send, from, to, doc}, N2O.pi(state: {_, login, pass, cnt}) = pi) do
      TENDER.UP.start(login, pass, from, to, doc, cnt)
      {:noreply, pi}
  end

  def proc({:download, msg_id}, N2O.pi(state: {_, login, pass, _}) = pi) do
      TENDER.DOWN.start(login, pass, msg_id)
      {:noreply, pi}
  end

  # helpers

  def error(f, x), do: :logger.error(:io_lib.format('TENDER ' ++ f, x))
  def warning(f, x), do: :logger.warning(:io_lib.format('TENDER ' ++ f, x))
  def debug(f, x), do: :logger.debug(:io_lib.format('TENDER ' ++ f, x))
  def info(f, x), do: :logger.info(:io_lib.format('TENDER ' ++ f, x))

  # REST/JSON API

  def to_list(x) when is_integer(x), do: :erlang.integer_to_list(x)
  def to_list(x) when is_binary(x), do: :erlang.binary_to_list(x)
  def to_list(x) when is_map(x), do: :maps.to_list(x)
  def to_list(x) when is_list(x), do: x
  def to_list(x), do: :io_lib.format '~p', [x]

  def to_atom(x) when is_integer(x), do: :erlang.list_to_atom(:erlang.integer_to_list(x))
  def to_atom(x) when is_binary(x), do: :erlang.list_to_atom(:erlang.binary_to_list(x))
  def to_atom(x), do: :io_lib.format '~p', [x]

  def decode(""), do: []
  def decode(x), do: :jsone.decode(x)

  def cancel(doc), do: spawn(fn -> :timer.sleep(2000) ; :n2o_pi.stop(:cipher, doc) end)

  def convert(list) when is_list(list), do: :lists.map fn {k,v} -> {to_atom(k),convert(v)} end, list
  def convert(list) when is_map(list), do: convert(:maps.to_list(list))
  def convert(x), do: x

  def getPlan(id) do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Plans/' ++ to_list(id)
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','text/plain'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000}], [{:body_format,:binary}])
      json = case decode(body) do
         x when is_map(x) ->
            [  mode: :maps.get("mode", x, []),
               tender: convert(:maps.get("tender", x, []) |> :maps.to_list),
               classification: convert(:maps.get("classification", x, [])),
               additionalClassification: :maps.get("additionalClassification", x, []),
               organizer: convert(:maps.get("organizer", x, [])),
               dateCreated: :maps.get("dateCreated", x, []),
               status: :maps.get("status", x, []),
               id: :maps.get("id", x, []),
               externalId: :maps.get("externalId", x, []),
               cdbId: :maps.get("cdbId", x, []),
               items: :maps.get("items", x, []),
               dateModified: :maps.get("dateModifed", x, []),
               datePublished: :maps.get("datePublished", x, []),
               dateCreated: :maps.get("dateCreated", x, []),
            ]
        _ -> []
      end
      json
  end

  def listPlans() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Plans'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','text/plain'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000}], [{:body_format,:binary}])
      json = case :jsone.decode(body) do
         x = %{} -> x
         _ -> []
      end
      lastDateModified = :maps.get("lastDateModified", json)
      data = :maps.get("data", json)
      list = :lists.map fn map  -> 
                     dateModified = :maps.get "dateModified", map, []
                     id = :maps.get "id", map, []
                     {dateModified,id} end, data
      [lastDateModified: lastDateModified, data: list]
  end

end
