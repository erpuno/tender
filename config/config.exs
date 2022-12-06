use Mix.Config

config :n2o,
  tables: [:cookies, :file, :web, :caching, :async, :tender],
  logger: [{:handler, :synrc, :logger_std_h,
    %{ level: :info, id: :synrc, max_size: 2000, module: :logger_std_h, config: %{type: :file, file: 'smarttender.log'},
       formatter: {:logger_formatter, %{ template: [:time, ' ', :pid, ' ', :module, ' ', :msg, '\n'], single_line: true }}}}],
  tender_upload: 'https://api-test.smarttender.biz/prozorro/',
  tender_bearer: 'Basic 1',
  jwt_prod: false,
  login: "Максим Сохацький",
  logger_level: :info
