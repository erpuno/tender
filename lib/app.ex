defmodule TENDER do
  require Record
  require N2O
  use Application

  def verify() do
      {:ssl, [{:verify, :verify_none}]}
  end

  def start(_, _) do
      :logger.add_handlers(:n2o)
      app = Supervisor.start_link([], strategy: :one_for_one, name: TENDER)
      pass = :application.get_env(:n2o, :tender_pass,  "")
      login = :application.get_env(:n2o, :tender_login, "")
      :n2o_pi.start(N2O.pi(module: TENDER, table: :tender, sup: TENDER,
              state: {"tenderLink", login, pass, 0}, name: "tenderLink"))
      app
  end

  def send(to, doc)  do
      :gen_server.cast :n2o_pi.pid(:tender, "tenderLink"), {:send, "tenderLink", to, doc}
  end

  def down(id)  do
      :gen_server.cast :n2o_pi.pid(:tender, "tenderLink"), {:download, id}
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

  def cancel(doc), do: spawn(fn -> :timer.sleep(2000) ; :n2o_pi.stop(:tender, doc) end)

  def convert(list) when is_map(list) do
      convert(:maps.to_list(list))
  end
  def convert(list) when is_list(list) do
      case list do
         [] -> []
         x -> case hd(x) do
                %{} -> :lists.map fn map -> convert(map) end, list
                  _ -> :lists.map fn {k,v} -> {to_atom(k),convert(v)} end, list
              end
      end
  end
  def convert(x) do
      x
  end

  def createPlan() do
      createPlan(%{"mode" => "test", "scheme" => "????021", "id" => "22990000-6",
                   "method" => "aboveThresholdUA", "currency" => "UAH"})
  end

  def participationRequest(id) do
      json = [
         userLogin: "testWebApi@smarttender.biz",
         id: id,
         lotsIds: [4631597]
        ]

      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ParticipationRequests'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      accept = 'application/json'
      headers = [{'Authorization',bearer},{'accept',accept}]
      {:ok,{{_,status,_},_headers,body}} = :httpc.request(:post, {url, headers, accept, :jsone.encode(json)},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])

      info '~p', [{body}]
      case status do
         201 ->
              case decode(body) do
                 x when is_map(x) ->
                    [
                       status: convert(:maps.get("status", x, [])),
                    ]
                 _ -> []
              end
         _ -> info 'ERROR/participationRequest: ~p', [body]

      end
  end

  def downloadFile(tender,file) do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Tenders/' ++ to_list(tender) ++ '/documents/' ++ to_list(file)
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      accept = 'text/plain'
      headers = [{'Authorization',bearer},{'accept',accept}]
      {:ok,{{_,status,_},_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])

      case status do
         200 ->
              case decode(body) do
                 y when is_map(y) ->
                    [
                       id: convert(:maps.get("id", y, [])),
                       title: convert(:maps.get("title", y, [])),
                       url: convert(:maps.get("url", y, [])),
                       dateModified: convert(:maps.get("dateModified", y, [])),
                    ]
                 _ -> []
              end
         _ -> info 'ERROR/downloadFile: ~p', [status]

      end
  end

  def listFiles(id) do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Tenders/' ++ to_list(id) ++ '/documents'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      accept = 'text/plain'
      headers = [{'Authorization',bearer},{'accept',accept}]
      {:ok,{{_,status,_},_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])

      case status do
         200 ->
              case decode(body) do
                 x when is_list(x) ->
                    :lists.map(fn y ->
                    [
                       id: convert(:maps.get("id", y, [])),
                       title: convert(:maps.get("title", y, [])),
                       url: convert(:maps.get("url", y, [])),
                       dateModified: convert(:maps.get("dateModified", y, [])),
                    ]
                    end, x)
                 _ -> []
              end
         _ -> info 'ERROR/listFiles: ~p', [status]

      end
  end

  def addFile(id) do

      json = [
         title: "aile",
         description: "Desc",
         url: "http://5ht.co/index.html",
         format: "html",
        ]

      {_,file} = :file.read_file 'N2O.docx'

      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Tenders/' ++ to_list(id) ++ '/documents'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      accept = 'application/json'
      headers = [{'Authorization',bearer},{'accept',accept}]
      {:ok,{{_,status,_},_headers,body}} = :httpc.request(:post, {url, headers, accept, file},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])

      info '~p', [{url,file}]
      case status do
         201 ->
              case decode(body) do
                 x when is_map(x) ->
                    [
                       status: convert(:maps.get("status", x, [])),
                    ]
                 _ -> []
              end
         _ -> info 'ERROR/addFile: ~p', [body]

      end

  end

  def createTender() do
      json = [
         title: "?????????????? ?????????????? ?????????????? ????????",
         description: "???????? ?????????????? ?????????????? ????????",
         mode: "test",
         procurementMethodType: "belowThreshold",
         mainProcurementCategory: "works",
         organizer: [contactPoint: [login: "testOrganizerWebApi@smarttender.biz"]],
         enquiryPeriod: [dateEnd: "2022-12-16T00:00:00"],
         tenderPeriod: [dateStart: "2022-12-17T00:00:00", dateEnd: "2022-12-21T00:00:00"],
         lots: [ [title: "?????????????? ????????", description: "????????", value: [valueAddedTaxIncluded: true, amount: 100000, currency: "UAH"],
                minimalStep: 3000, paymentTerms: [
                    [
                        type: "prepayment",
                        event: "deliveryOfGoods",
                        dayType: "banking",
                        days: 10,
                        description: "????????...",
                        percentage: 100
                    ] ],
               items: [ [ description: "???????? ????????????????????????",
                          classification: [scheme: "????021", id: "22990000-6"],
                          additionalClassifications: [ [scheme: "????????", id: "55.90"] ],
                          unitCode: "H87",
                          quantity: 346,
                          deliveryDate: [dateStart: "2022-12-30T00:00:00", dateEnd: "2022-12-31T00:00:00"],
                          deliveryAddress: [postalCode: "03194", streetAddress: "???????? ????????????????, 1"]
                      ] ]
                ] ]
       ]

      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Tenders'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      accept = 'application/json'
      headers = [{'Authorization',bearer},{'accept','text/plain'},{'Content-Type',accept}]
      {:ok,{{_,status,_},_headers,body}} = :httpc.request(:post, {url, headers, accept, :jsone.encode(json)},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])

      case status do
         201 ->
              case decode(body) do
                 x when is_map(x) ->
                    [
                       mode: convert(:maps.get("number", x, [])),
                       title: convert(:maps.get("title", x, [])),
                       description: convert(:maps.get("description", x, [])),
                       procurementMethodType: convert(:maps.get("procurementMethodType", x, [])),
                       mainProcurementCategory: convert(:maps.get("mainProcurementCategory", x, [])),
                       status: convert(:maps.get("status", x, [])),
                       classification: convert(:maps.get("classification", x, [])),
                       value: convert(:maps.get("value", x, [])),
                       organizer: convert(:maps.get("organizer", x, [])),
                       enquiryPeriod: convert(:maps.get("enquiryPeriod", x, [])),
                       tenderPeriod: convert(:maps.get("tenderPeriod", x, [])),
                       features: convert(:maps.get("features", x, [])),
                       lots: convert(:maps.get("lots", x, [])),
                       id: convert(:maps.get("id", x, [])),
                       dateModified: convert(:maps.get("dateModified", x, [])),
                    ]
                 _ -> []
              end
         _ -> info 'ERROR/createPlan: ~p', [body]

      end

  end

  def createPlan(o) do
      mode = :maps.get("mode", o, [])
      scheme = :maps.get("scheme", o, [])
      id = :maps.get("id", o, [])
      method = :maps.get("method", o, [])
      currency = :maps.get("currency", o, [])

      json =   [ mode: mode,
                 tender: [procurementMethodType: method,
                         tenderPeriod: [dateStart: "2022-12-01T11:38:59.324Z"]],
                 classification: [scheme: scheme, id: id],
                 additionalClassifications: [[scheme: "????????", id: "2000"]],
                 budget: [year: 2022, yearPeriod: [yearFrom: 2020, yearTo: 2020],
                          description: "Test", currency: currency, amount: 10000, notes: "notes",
                          financingSources: [[title: "state", description: "string", amount: 20]]],
                 items: [[description: "item description",
                         classification: [scheme: scheme, id: id],
                         unitCode: "H87",
                         quantity: 7,
                         deliveryDate: [dateStart: "2022-12-07T00:00:00", dateEnd: "2022-12-07T00:00:00"]
                        ]],
                 organizer: [contactPoint: [login: "testOrganizerWebApi@smarttender.biz"]]
               ]
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Plans'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      accept = 'application/json'
      headers = [{'Authorization',bearer},{'accept','text/plain'},{'Content-Type',accept}]
      {:ok,{{_,status,_},_headers,body}} = :httpc.request(:post, {url, headers, accept, :jsone.encode(json)},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])

      case status do
         201 ->
              case decode(body) do
                 x when is_map(x) ->
                    [
                       id: convert(:maps.get("id", x, [])),
                       mode: convert(:maps.get("mode", x, [])),
                       status: convert(:maps.get("status", x, [])),
                       dateCreated: convert(:maps.get("dateCreated", x, [])),
                       tender: convert(:maps.get("tender", x, [])),
                       classification: convert(:maps.get("classification", x, [])),
                       additionalClassifications: convert(:maps.get("additionalClassification", x, [])),
                       organizer: convert(:maps.get("organizer", x, [])),
                       budget: convert(:maps.get("budget", x, [])),
                       items: convert(:maps.get("items", x, [])),
                    ]
                 _ -> []
              end
         _ -> info 'ERROR/createPlan: ~p', [body]

      end
  end

  def getPlan(id) do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Plans/' ++ to_list(id)
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','text/plain'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
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
        _ -> info 'ERROR/getPlan: ~p', [body]
      end
      json
  end

  def getTender(id) do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Tenders/' ++ to_list(id)
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','text/plain'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = case decode(body) do
         x when is_map(x) ->
            [
                       mode: convert(:maps.get("number", x, [])),
                       title: convert(:maps.get("title", x, [])),
                       description: convert(:maps.get("description", x, [])),
                       procurementMethodType: convert(:maps.get("procurementMethodType", x, [])),
                       mainProcurementCategory: convert(:maps.get("mainProcurementCategory", x, [])),
                       status: convert(:maps.get("status", x, [])),
                       classification: convert(:maps.get("classification", x, [])),
                       value: convert(:maps.get("value", x, [])),
                       organizer: convert(:maps.get("organizer", x, [])),
                       enquiryPeriod: convert(:maps.get("enquiryPeriod", x, [])),
                       tenderPeriod: convert(:maps.get("tenderPeriod", x, [])),
                       features: convert(:maps.get("features", x, [])),
                       lots: convert(:maps.get("lots", x, [])),
                       id: convert(:maps.get("id", x, [])),
                       dateModified: convert(:maps.get("dateModified", x, [])),
            ]
        _ -> info 'ERROR/getTender: ~p', [body]
      end
      json
  end

  def listPlans() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Plans'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','text/plain'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
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

  def listTenders() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'Tenders'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','text/plain'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
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

  def catTenderStatuses() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/tenderStatuses'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catLotStatuses() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/lotStatuses'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catUnits() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/units'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     shortTitle = :maps.get "shortTitle", map, []
                     id = :maps.get "id", map, []
                     {id,shortTitle,title} end, json
  end

  def catCurrencies() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/currencies'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catCurrencies() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/currencies'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catTradeGoalTypes() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/tradeGoalTypes'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catProcurementMethodTypes() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/procurementMethodTypes'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catProcurementMethodRationales() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/procurementMethodRationales'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catIdentifierSchemes() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/identifierSchemes'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catClassificationSchemes() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/classificationSchemes'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catClassificationSchemes() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/classificationSchemes'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def classificationSchemes(id) do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/classificationSchemes/' ++ URI.encode(id)
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catCities() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/cities'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     cn = :maps.get "countryName", map, []
                     region = :maps.get "region", map, []
                     locality = :maps.get "locality", map, []
                     {cn,region,locality} end, json
  end

  def catMainProcurementCategories() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/mainProcurementCategories'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catDayTypes() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/dayTypes'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catPaymentTermEvents() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/paymentTermEvents'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catPaymentTermTypes() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/paymentTermTypes'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catComplaintTypes() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/complaintTypes'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catComplaintStatuses() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/complaintStatuses'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catBidStatuses() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/bidStatuses'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catAwardStatuses() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/awardStatuses'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catContractStatuses() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/contractStatuses'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def catPreQualificationStatuses() do
      url = :application.get_env(:n2o, :tender_upload, []) ++ 'ReferenceBooks/preQualificationStatuses'
      bearer = :application.get_env(:n2o, :tender_bearer, [])
      headers = [{'Authorization',bearer},{'accept','*'}]
      {:ok,{status,_headers,body}} = :httpc.request(:get, {url, headers},
                                     [{:timeout,100000},verify()], [{:body_format,:binary}])
      json = :jsone.decode(body)
      :lists.map fn map  -> 
                     title = :maps.get "title", map, []
                     id = :maps.get "id", map, []
                     {id,title} end, json
  end

  def dumpDKPP() do
      x = TENDER.classificationSchemes "????????"
      :lists.map fn {x,y} -> :io.format '~ts:~ts~n', [x,y] end, :lists.sort(x)
      length(x)
  end

  def dumpDK21() do
      x = TENDER.classificationSchemes "????021"
      :lists.map fn {x,y} -> :io.format '~ts:~ts~n', [x,y] end, :lists.sort(x)
      length(x)
  end

end
