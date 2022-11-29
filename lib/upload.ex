defmodule TENDER.UP do
  require Record
  require N2O

  def start(login, pass, from, to, doc, _cnt) do

    spawn(fn ->
      case :n2o_pi.start(
        N2O.pi(
          module: __MODULE__,
          table: :tender,
          sup: TENDER,
          state: {login, pass, from, to, doc, []},
          name: doc)) do
        {:error, x} -> TENDER.error 'TENDER ERROR: ~p', [x]
        x -> TENDER.warning 'TENDER: ~p', [x]
      end
    end)
  end

  def proc(:init, N2O.pi(state: {login, pass, from, to, doc, _}) = pi) do
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      {:ok, N2O.pi(pi, state: {login, pass, from, to, doc, bearer})}
  end

  def proc(_,pi) do
      {:noreply, pi}
  end

end
