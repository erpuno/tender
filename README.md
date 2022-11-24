TENDER: SmartTender Prozorro API SDK
====================================

[![Hex pm](http://img.shields.io/hexpm/v/smarttender.svg?style=flat&x=1)](https://hex.pm/packages/smarttender)

Інформація
----------

Тут представлений конектор на мові Elixir
для <a href="https://api-test.smarttender.biz/prozorro/swagger/index.html">SmartTender API</a>, яке дозволяє створювати торги на площадці Prozorro.

Конфігурація
------------

Перед роботою додайте креденшиали для тестового середовища:

```
config: :n2o,
  tender_upload: 'https://api-test.smarttender.biz/prozorro/',
  tender_bearer: 'Bearer xxx',
  login: "Максим Сохацький",
```

Пререквізити
------------

```
$ sudo apt install erlang elixir
```

Білд
----

Компіляція та запуск:

```
$ mix deps.get
$ iex -S mix
> 
```

```
> :supervisor.which_children TENDER
[
  {{:tender, 'c9983ae3f517fbc9a147d5c34f22932f42fe965b'}, #PID<0.465.0>, :worker, [TENDER.DOWN]},
  {{:tender, "tenderLink"}, #PID<0.219.0>, :worker, [TENDER]}
]
```

Автор
-----

* Максим Сохацький
