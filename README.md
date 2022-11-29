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
> TENDER.getPlan 299107

[
  mode: "real",
  tender: [
    procurementMethodType: "reporting",
    tenderPeriod: [dateStart: "2021-12-01T00:00:00"]
  ],
  classification: [id: "18140000-2", scheme: "ДК021"],
  additionalClassification: [],
  organizer: [
    contactPoint: [email: "KLIUKVIN@IT.UA"], 
    title: "Astartia-Энергетика",
    usreou: "77788899"
  ],
  dateCreated: "2021-05-25T16:49:49.193",
  status: "draft",
  id: 299107,
  dateCreated: "2021-05-25T16:49:49.193"
]
```

Автор
-----

* Максим Сохацький
