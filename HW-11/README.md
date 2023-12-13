## 👨🏻‍💻 ДЗ № 11. Полнотекстовый поиск

Содержание:
1. [Задание 1.](#задание_1)

### **Задание 1.** <a name="задание_1"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

Задание выполняется на основе презентации 10 «Полнотекстовый поиск» и 
главы 12 документации на Постгрес https://postgrespro.ru/docs/postgresql/12/textsearch

**Задание**. Придумать и реализовать пример использования полнотекстового поиска, 
аналогичный (можно более простой или более сложный) тому примеру с библиотечным 
каталогом, который был приведен в презентации. Можно использовать исходные 
тексты, приведенные в презентации: https://edu.postgrespro.ru/sqlprimer/sqlprimer-2019-msu-10.tgz
</details>

Ответ:

Для выполнения этого задания я решил взять набор данных, приближенный
к реальности, а именно: датасет из множества электронных 
писем: https://www.kaggle.com/datasets/wcukierski/enron-email-dataset/data

Поскольку в оригинальном наборе их больше 500 тыс., для этого задания
я сделал случайную выборку из 10 тыс. писем, а также предобработал их
на языке python, чтобы они лучше подходили под формат задания.
В частности, я убрал лишние служебные символы и оставил только 
дату письма, тему и содержание.

Моя выборка доступна здесь: [emails-sample.csv](./emails-sample.csv) (разделитель: `^`).

Итак, для выполнения задания, в начале я создам
таблицу нужного формата:
```SQL
CREATE TABLE emails
( email_id integer PRIMARY KEY,
  email_content text
);

CREATE TABLE
```

Дальше я скопирую в нее данные из csv-файла, где уже есть 
столбец с индексом:
```SQL
COPY emails FROM '/home/postgres/emails-sample.csv' ( FORMAT CSV, DELIMITER('^') );
```

Теперь я создам столбец с типом данных `tsvector`, чтобы
обработать тексты электронных писем:
```SQL
ALTER TABLE emails ADD COLUMN ts_description tsvector;

ALTER TABLE
```

И передам в него письма:
```SQL
UPDATE emails
SET ts_description = to_tsvector( 'english',
                                  email_content );
                                  
ЗАМЕЧАНИЕ:  слишком длинное слово для индексации
ПОДРОБНОСТИ:  Слова длиннее 2047 символов игнорируются.
```

Интересно, что в ходе выполнения задания я узнал, что у 
формата данных `tsvector` есть ограничение по символам: 2047.
В наборе данных действительно встречаются очень длинные письма.

Можем посмотреть на примеры относительно небольших писем:
```SQL
SELECT * 
FROM emails
WHERE length(email_content) < 200
LIMIT 5 ;

-[ RECORD 1 ]--+---------------------------------------------------------------------------------------------------------------------------------------------------------------------
email_id       | 838
email_content  | Date: Tue, 27 Nov 2001 11:21:51 -0800 (PST) Subject: Content: http://www.familyfeud.tv/
ts_description | '-0800':9 '11':6 '2001':5 '21':7 '27':3 '51':8 'content':12 'date':1 'nov':4 'pst':10 'subject':11 'tue':2 'www.familyfeud.tv':13
-[ RECORD 2 ]--+---------------------------------------------------------------------------------------------------------------------------------------------------------------------
email_id       | 5488
email_content  | Date: Thu, 15 Jun 2000 00:56:00 -0700 (PDT) Subject: Re: TigersContent: daddy is in.
ts_description | '-0700':9 '00':6,8 '15':3 '2000':5 '56':7 'daddi':14 'date':1 'jun':4 'pdt':10 're':12 'subject':11 'thu':2 'tigerscont':13
-[ RECORD 3 ]--+---------------------------------------------------------------------------------------------------------------------------------------------------------------------
email_id       | 1499
email_content  | Date: Mon, 20 Nov 2000 00:10:00 -0800 (PST) Subject: testContent: test
ts_description | '-0800':9 '00':6,8 '10':7 '20':3 '2000':5 'date':1 'mon':2 'nov':4 'pst':10 'subject':11 'test':13 'testcont':12
-[ RECORD 4 ]--+---------------------------------------------------------------------------------------------------------------------------------------------------------------------
email_id       | 7505
email_content  | Date: Wed, 22 Nov 2000 04:39:00 -0800 (PST) Subject: Content: Here is the latest Brownsville Presentation.Ben
ts_description | '-0800':9 '00':8 '04':6 '2000':5 '22':3 '39':7 'brownsvill':17 'content':12 'date':1 'latest':16 'nov':4 'presentation.ben':18 'pst':10 'subject':11 'wed':2
-[ RECORD 5 ]--+---------------------------------------------------------------------------------------------------------------------------------------------------------------------
email_id       | 1867
email_content  | Date: Tue, 11 Dec 2001 11:40:10 -0800 (PST) Subject: Termination List 12-10Content: Attached is the termination list for Dec. 12.
ts_description | '-0800':9 '-10':15 '10':8 '11':3,6 '12':14,24 '2001':5 '40':7 'attach':17 'content':16 'date':1 'dec':4,23 'list':13,21 'pst':10 'subject':11 'termin':12,20 'tue':2
```

Теперь попробуем найти какое-нибудь письмо по фильтру:
```SQL
SELECT * FROM emails
WHERE ts_description @@ to_tsquery(
 'we & were & there & for & new & yearafter & a & california & visit' 
 );
 
-[ RECORD 1 ]--+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
email_id       | 137
email_content  | Date: Tue, 16 Jan 2001 15:13:00 -0800 (PST) Subject: key westContent: thanks for your call about travel to key west. we were there for new yearafter a california visit. i will be back on jan 24 for a week. it would begreat to see you there. if you need a place to stay my friend del brixeyhas a room that might be available. let me know your dates etc...best to ted and you from us both, hal and doneley_________________________________________________________________Get your FREE download of MSN Explorer at http://explorer.msn.com
ts_description | '-0800':9 '00':8 '13':7 '15':6 '16':3 '2001':5 '24':38 'avail':65 'back':35 'begreat':44 'best':72 'brixeyha':59 'california':30 'call':17 'date':1,70 'del':58 'doneley':82 'download':86 'etc':71 'explor':89 'explorer.msn.com':91 'free':85 'friend':57 'get':83 'hal':80 'jan':4,37 'key':12,21 'know':68 'let':66 'might':63 'msn':88 'need':51 'new':27 'place':53 'pst':10 'room':61 'see':46 'stay':55 'subject':11 'ted':74 'thank':14 'travel':19 'tue':2 'us':78 'visit':31 'week':41 'west':22 'westcont':13 'would':43 'yearaft':28
```

Среди 10 тыс. писем нашлось ровно одно под мой запрос.
```

 email_id | email_content | ts_description  
                                   
----------+---------------+-----------------------------------------------------
..............
------------------------------------------------------------------------------
      137 | Date: Tue, 16 Jan 2001 15:13:00 -0800 (PST) Subject: key westContent: thanks for your ca
ll about travel to key west. we were there for new yearafter a california visit. i will be back on j
an 24 for a week. it would begreat to see you there. if you need a place to stay my friend del brixe
yhas a room that might be available. let me know your dates etc...best to ted and you from us both, 
hal and doneley_________________________________________________________________Get your FREE downlo
ad of MSN Explorer at http://explorer.msn.com | '-0800':9 '00':8 '13':7 '15':6 '16':3 '2001':5 '24':
38 'avail':65 'back':35 'begreat':44 'best':72 'brixeyha':59 'california':30 'call':17 'date':1,70 '
del':58 'doneley':82 'download':86 'etc':71 'explor':89 'explorer.msn.com':91 'free':85 'friend':57 
'get':83 'hal':80 'jan':4,37 'key':12,21 'know':68 'let':66 'might':63 'msn':88 'need':51 'new':27 '
place':53 'pst':10 'room':61 'see':46 'stay':55 'subject':11 'ted':74 'thank':14 'travel':19 'tue':2
 'us':78 'visit':31 'week':41 'west':22 'westcont':13 'would':43 'yearaft':28
(1 строка)
```
Видим, что всего два слова: jan и key встречались два раза (причем
именно в данном виде).

Посмотрим на план выполнения команды:
```SQL
EXPLAIN ANALYZE SELECT * FROM emails
WHERE ts_description @@ to_tsquery(
 'we & were & there & for & new & yearafter & a & california & visit' 
 );
```
```
                                                         QUERY PLAN                                                      
   
-------------------------------------------------------------------------------------------------------------------------
---
 Gather  (cost=1000.00..4764.22 rows=1 width=994) (actual time=214.725..215.920 rows=1 loops=1)
   Workers Planned: 1
   Workers Launched: 1
   ->  Parallel Seq Scan on emails  (cost=0.00..3764.12 rows=1 width=994) (actual time=112.344..204.386 rows=0 loops=2)
         Filter: (ts_description @@ to_tsquery('we & were & there & for & new & yearafter & a & california & visit'::text
))
         Rows Removed by Filter: 5000
 Planning time: 0.321 ms
 Execution time: 215.951 ms
(8 строк)
```
Запрос производится параллельно, но относительно долго.

Попробуем добавить индекс типа GIN, который в [документации](https://postgrespro.ru/docs/postgresql/12/textsearch-indexes) 
приводится как желательный для ускорения полнотекстового поиска.
```SQL
CREATE INDEX email_idx ON emails
USING GIN ( ts_description );

CREATE INDEX
```
Посмотрим на него:
```SQL
\d emails

                              Таблица "public.emails"
    Столбец     |   Тип    | Правило сортировки | Допустимость NULL | По умолчанию 
----------------+----------+--------------------+-------------------+--------------
 email_id       | integer  |                    | not null          | 
 email_content  | text     |                    |                   | 
 ts_description | tsvector |                    |                   | 
Индексы:
    "emails_pkey" PRIMARY KEY, btree (email_id)
    "email_idx" gin (ts_description)
```

Попробуем еще раз проанализировать исполнение команды:
```SQL
EXPLAIN ANALYZE SELECT * FROM emails
WHERE ts_description @@ to_tsquery(
 'we & were & there & for & new & yearafter & a & california & visit' 
 );
```

Вывод:
```
                                                           QUERY PLAN                                                    
       
-------------------------------------------------------------------------------------------------------------------------
-------
 Bitmap Heap Scan on emails  (cost=52.25..56.51 rows=1 width=994) (actual time=0.150..0.151 rows=1 loops=1)
   Recheck Cond: (ts_description @@ to_tsquery('we & were & there & for & new & yearafter & a & california & visit'::text
))
   Heap Blocks: exact=1
   ->  Bitmap Index Scan on email_idx  (cost=0.00..52.25 rows=1 width=0) (actual time=0.144..0.144 rows=1 loops=1)
         Index Cond: (ts_description @@ to_tsquery('we & were & there & for & new & yearafter & a & california & visit'::
text))
 Planning time: 0.378 ms
 Execution time: 0.186 ms
(7 строк)
```
Видим ускорение более чем в 1000 раз! Думаю это связано с
большим объемом данных: хотя писем относительно немного (10 тыс.),
некоторые из них очень длинные.

---