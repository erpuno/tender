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

  def cancel(doc), do: spawn(fn -> :timer.sleep(2000) ; :n2o_pi.stop(:cipher, doc) end)

  def publish(bearer,id,_) do
      url = :application.get_env(:n2o, :tender_upload, []) ++ id
      headers = [{'Authorization',bearer}]
      {:ok,{status,_headers,body}} = :httpc.request(:put, {url, headers},
                                    [{:timeout,100000}], [{:body_format,:binary}])
      TENDER.debug 'PUBLISH: ~ts ~p', [id,status]
      body
  end

  def metainfo(bearer,id,doc) do
      author = [firstName: "Максим",
                surname: "Сохацький",
                position: "Провідний інженер",
                department: "Розробки інформаційних систем",
                organization: "ІНФОТЕХ"]

      body = :jsone.encode([fileName: doc, description: "Бінарний файл", ownNumber: "123/20",
                            comment: "Коментар від архіваріуса", authors: [author], outerId: "123/20"])
      url = :application.get_env(:n2o, :tender_upload, []) ++ id ++ '/metadata'
      app_json = 'application/json'
      headers = [{'Content-Type',app_json},{'Authorization',bearer}]
      {:ok,{status,_headers,body}} = :httpc.request(:put, {url, headers, app_json, body},
                                    [{:timeout,100000}], [{:body_format,:binary}])
      case status do
         {_,200,_} -> TENDER.debug 'METAINFO: ~ts ~p', [id,status]
           _ -> res = :jsone.decode body
                msg = :maps.get "message", res
                code = :maps.get "code", res
                TENDER.error 'METAINFO: id: ~ts, code: ~ts, message: ~ts', [id,code,msg]
      end
      body
  end

  def upload(bearer,doc) do
      case :file.read_file(doc) do
         {:error, reason} -> {[],reason}
         {:ok, file} ->
      file_len = :io_lib.format('~p',[:erlang.size(file)])
      url = :application.get_env(:n2o, :tender_upload, []) ++ '1'
      TENDER.debug 'bearer: ~ts', [bearer]
      octet = 'application/octet-stream'
      headers = [{'Authorization',bearer},{'Content-Type',octet},{'Content-Length', file_len}]
      {:ok,{status,_headers,body}} = :httpc.request(:post, {url, headers, octet, file},
                                      [{:timeout,100000}], [{:body_format,:binary}])
      TENDER.debug 'UPLOAD: ~p', [status]
      res = :jsone.decode body
      id = :maps.get("id", res, []) |> :erlang.binary_to_list
      {id,res}
      end
  end

  def uploadSignature(bearer,id,doc) do
      case :file.read_file(doc <> ".p7s") do
      {:error, _reason} -> TENDER.warning 'P7S is not available for ~p ~p.', [id,doc]
      {:ok, file} ->
         url = :application.get_env(:n2o, :tender_upload, []) ++ id ++ '/signature'
         octet = 'application/octet-stream'
         headers = [{'Authorization',bearer},{'Content-Type',octet}]
         {:ok,{status,_headers,body}} = :httpc.request(:put, {url, headers, octet, file},
                                      [{:timeout,100000}], [{:body_format,:binary}])
         case status do
            {_,200,_} -> TENDER.debug 'UPLOAD SIGNATURE: ~ts ~p', [id,status]
              _ -> res = :jsone.decode body
                   msg = :maps.get "message", res
                   code = :maps.get "code", res
                   TENDER.error 'UPLOAD SIGNATURE: id: ~ts, code: ~ts, message: ~ts', [id,code,msg]
         end
         {id,body}
      end
  end

  def download(bearer,id) do
      url = :application.get_env(:n2o, :tender_upload, []) ++ id ++ '/data'
      headers = [{'Authorization',bearer}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000}], [{:body_format,:binary}])
      TENDER.debug 'DOWNLOAD ~ts: ~p', [id,status]
      {status,id,body}
  end

  def downloadSignature(bearer,id) do
      url = :application.get_env(:n2o, :tender_upload, []) ++ id ++ '/signature'
      headers = [{'Authorization',bearer}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                      [{:timeout,100000}], [{:body_format,:binary}])
      case status do
        {_,200,_} -> TENDER.debug 'DOWNLOAD SIGNATURE: ~ts ~p', [id,status]
          _ -> res = :jsone.decode body
               msg = :maps.get "message", res
               code = :maps.get "code", res
               TENDER.error 'DOWNLOAD SIGNATURE: id: ~ts, code: ~ts, message: ~ts', [id,code,msg]
      end
      {status,id,:jsone.decode(body)}
  end

  def auth(login,pass) do
      url = :application.get_env(:n2o, :tender_auth, [])
      body = :jsone.encode([grant_type: "password", username: login, client_id: "arch-client", password: pass])
      len = :io_lib.format('~p',[:erlang.size(body)])
      app_json = 'application/json'
      headers = [{'Content-Type',app_json},{'Content-Length', len}]
      {:ok,{_status,_headers,body}} = :httpc.request(:post, {url, headers, app_json, body},
                                    [{:timeout,10000}], [{:body_format,:binary}])
      res = :jsone.decode body
      bearer = :maps.get "token_type", res
      TENDER.debug 'AUTH: ~p', [bearer]
      token = :maps.get "access_token", res
      bearer <> " " <> token |> :erlang.binary_to_list
  end

end
