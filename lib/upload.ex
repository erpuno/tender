defmodule TENDER.UP do
  require Record
  require N2O

  def start(login, pass, from, to, doc, _cnt) do

    spawn(fn ->
      case :n2o_pi.start(
        N2O.pi(
          module: __MODULE__,
          table: :cipher,
          sup: CIPHER,
          state: {login, pass, from, to, doc, []},
          name: doc)) do
        {:error, x} -> TENDER.error 'CIPHER ERROR: ~p', [x]
        x -> TENDER.warning 'CIPHER: ~p', [x]
      end
    end)
  end

  def proc(:init, N2O.pi(state: {login, pass, from, to, doc, _}) = pi) do
      bearer = case :application.get_env(:n2o, :jwt_prod, false) do
          false -> :application.get_env(:n2o, :tender_bearer, [])
          true -> TENDER.auth(login, pass)
      end
      {id,res} = TENDER.upload(bearer, doc)
      case {id,res} do
           {[],_} -> TENDER.error 'UPLOAD ERROR: ~p', [res]
           {id,_} -> TENDER.debug 'UPLOAD ID: ~p', [id]
                     TENDER.uploadSignature(bearer,id,doc)
                     TENDER.publish(bearer,id,doc)
                     TENDER.metainfo(bearer,id,doc)
      end
      TENDER.cancel(doc)
      {:ok, N2O.pi(pi, state: {login, pass, from, to, doc, id})}
  end

  def proc(_,pi) do
      {:noreply, pi}
  end

end
