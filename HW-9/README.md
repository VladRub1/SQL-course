## 👨🏻‍💻 ДЗ № 9 Глава 10. Повышение производительности

Содержание:
1. [Задание 3.](#задание_3)
2. [Задание 6.](#задание_6)
3. [Задание 8.](#задание_8)

### **Задание 3.** <a name="задание_3"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

Самостоятельно выполните команду `EXPLAIN` для запроса, содержащего общее
табличное выражение (`CTE`). Посмотрите, на каком уровне находится узел плана, 
отвечающий за это выражение, как он оформляется. Учтите, что общие табличные 
выражения всегда материализуются, т. е. вычисляются однократно и
результат их вычисления сохраняется в памяти, а затем все последующие обращения 
в рамках запроса направляются уже к этому материализованному результату.
</details>

Ответ:

В качестве `CTE` я возьму свой запрос из одного из прошлых ДЗ, в котором я считал, 
сколько мест занято и свободно на конкретном рейсе во время регистрации. Предполагалось,
что этот запрос может помочь сотрудникам авиакомпании понимать, сколько людей 
потенциально может прийти на регистрацию, а после окончания рейса — оценивать
утилизацию мест авиапарка.

К предыдущей версии запроса я добавил значение поля .flight_id для наглядности.

```SQL
with num_seats as (
select 
    aircraft_code,
    count(seat_no) as max_num
from seats
group by aircraft_code
),
cur_seats as (
select 
    flights.flight_id,
    aircraft_code,
    count(aircraft_code) as count
from flights
join boarding_passes on flights.flight_id = boarding_passes.flight_id
where flights.flight_id = 30625
group by aircraft_code, flights.flight_id
)
select 
    cur_seats.flight_id,
    num_seats.aircraft_code,
    max_num, 
    count as current_seats,
    max_num - count as seats_left
from num_seats
join cur_seats on num_seats.aircraft_code = cur_seats.aircraft_code;
```
Запрос должен возвращать такой результат:
```
 flight_id | aircraft_code | max_num | current_seats | seats_left 
-----------+---------------+---------+---------------+------------
     30625 | 773           |     402 |            92 |        310
(1 строка)
```
Видим, что на этом рейсе больше половины мест остались свободными.

Теперь попробуем воспользоваться функцией `EXPLAIN`. Также для наглядности я 
добавлю к ней `ANALYZE`. Для чистоты эксперимента я перезапустил сервер PostgreSQL.
```SQL
explain analyze
with num_seats as (
select 
    aircraft_code,
    count(seat_no) as max_num
from seats
group by aircraft_code
),
cur_seats as (
select 
    flights.flight_id,
    aircraft_code,
    count(aircraft_code) as count
from flights
join boarding_passes on flights.flight_id = boarding_passes.flight_id
where flights.flight_id = 30625
group by aircraft_code, flights.flight_id
)
select 
    cur_seats.flight_id,
    num_seats.aircraft_code,
    max_num, 
    count as current_seats,
    max_num - count as seats_left
from num_seats
join cur_seats on num_seats.aircraft_code = cur_seats.aircraft_code;
```

Результат:
```
                                                                             QUERY PLAN                                                                             
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=265.21..265.44 rows=1 width=44) (actual time=1.368..1.378 rows=1 loops=1)
   Hash Cond: (num_seats.aircraft_code = cur_seats.aircraft_code)
   CTE num_seats
     ->  HashAggregate  (cost=28.09..28.18 rows=9 width=12) (actual time=1.205..1.211 rows=9 loops=1)
           Group Key: seats.aircraft_code
           ->  Seq Scan on seats  (cost=0.00..21.39 rows=1339 width=7) (actual time=0.014..0.274 rows=1339 loops=1)
   CTE cur_seats
     ->  GroupAggregate  (cost=5.19..237.00 rows=1 width=16) (actual time=0.121..0.122 rows=1 loops=1)
           Group Key: flights.flight_id
           ->  Nested Loop  (cost=5.19..236.69 rows=61 width=8) (actual time=0.052..0.097 rows=92 loops=1)
                 ->  Index Scan using flights_pkey on flights  (cost=0.29..8.31 rows=1 width=8) (actual time=0.015..0.016 rows=1 loops=1)
                       Index Cond: (flight_id = 30625)
                 ->  Bitmap Heap Scan on boarding_passes  (cost=4.90..227.77 rows=61 width=4) (actual time=0.032..0.044 rows=92 loops=1)
                       Recheck Cond: (flight_id = 30625)
                       Heap Blocks: exact=1
                       ->  Bitmap Index Scan on boarding_passes_flight_id_seat_no_key  (cost=0.00..4.88 rows=61 width=0) (actual time=0.022..0.022 rows=92 loops=1)
                             Index Cond: (flight_id = 30625)
   ->  CTE Scan on num_seats  (cost=0.00..0.18 rows=9 width=24) (actual time=1.209..1.220 rows=9 loops=1)
   ->  Hash  (cost=0.02..0.02 rows=1 width=28) (actual time=0.132..0.133 rows=1 loops=1)
         Buckets: 1024  Batches: 1  Memory Usage: 9kB
         ->  CTE Scan on cur_seats  (cost=0.00..0.02 rows=1 width=28) (actual time=0.125..0.126 rows=1 loops=1)
 Planning time: 0.531 ms
 Execution time: 1.531 ms
(23 строки)
```

Если выполнить запрос повторно:
```
                                                                             QUERY PLAN                                                                             
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=265.21..265.44 rows=1 width=44) (actual time=0.513..0.517 rows=1 loops=1)
   Hash Cond: (num_seats.aircraft_code = cur_seats.aircraft_code)
   CTE num_seats
     ->  HashAggregate  (cost=28.09..28.18 rows=9 width=12) (actual time=0.447..0.449 rows=9 loops=1)
           .......
   CTE cur_seats
     ->  GroupAggregate  (cost=5.19..237.00 rows=1 width=16) (actual time=0.049..0.050 rows=1 loops=1)
           ......
   ->  CTE Scan on num_seats  (cost=0.00..0.18 rows=9 width=24) (actual time=0.449..0.453 rows=9 loops=1)
           ......
         ->  CTE Scan on cur_seats  (cost=0.00..0.02 rows=1 width=28) (actual time=0.050..0.051 rows=1 loops=1)
 Planning time: 0.271 ms
 Execution time: 0.584 ms
(23 строки)
```

Во-первых, действительно видим, что во второй раз операции, связанные с CTE,
выполнялись в 2-3 раза быстрее, а также сам запрос выполнялся быстрее, несмотря
на то, что оцениваемое число ресурсов на операцию (cost) не менялось.

Посмотрите, на каком уровне находится узел плана, отвечающий за это выражение, как он оформляется. 

Во-вторых, проанализируем место `CTE` в плане запроса. Видим, что в плане есть 
несколько узлов, отвечающих за `CTE`, как и в моем запросе. "Вершины"
`CTE` находятся на самых верхних уровнях плана. Это логично, получается, что
планировщик рассматривает их как практически независимые отдельные таблицы.
Также можем заметить, что внутри узлов с `CTE` мы можем увидеть типичное
поведение при выполнении таких запросов по отдельности, т.е. скорее
всего ничего бы не отличалось, если бы мы отдельно делали такой запрос.
Можно увидеть, что в самом конце `CTE` объединяются в итоговый результат.

Попробую для эксперимента посмотреть на план каждого из двух `CTE`-запроса по отдельности.
Вывожу результат:
```
HashAggregate  (cost=28.09..28.18 rows=9 width=12) (actual time=0.502..0.505 rows=9 loops=1)
   Group Key: aircraft_code
   ->  Seq Scan on seats  (cost=0.00..21.39 rows=1339 width=7) (actual time=0.011..0.116 rows=1339 loops=1)
 Planning time: 0.076 ms
 Execution time: 0.538 ms
(5 строк)

 GroupAggregate  (cost=5.19..237.00 rows=1 width=16) (actual time=0.102..0.103 rows=1 loops=1)
   Group Key: flights.flight_id
   ->  Nested Loop  (cost=5.19..236.69 rows=61 width=8) (actual time=0.050..0.077 rows=92 loops=1)
         ->  Index Scan using flights_pkey on flights  (cost=0.29..8.31 rows=1 width=8) (actual time=0.015..0.016 rows=1 loops=1)
               Index Cond: (flight_id = 30625)
         ->  Bitmap Heap Scan on boarding_passes  (cost=4.90..227.77 rows=61 width=4) (actual time=0.031..0.041 rows=92 loops=1)
               Recheck Cond: (flight_id = 30625)
               Heap Blocks: exact=1
               ->  Bitmap Index Scan on boarding_passes_flight_id_seat_no_key  (cost=0.00..4.88 rows=61 width=0) (actual time=0.021..0.021 rows=92 loops=1)
                     Index Cond: (flight_id = 30625)
 Planning time: 0.252 ms
 Execution time: 0.164 ms
(12 строк)
```

Видим, что планы не отличаются от "общего плана". Запланированное
число ресурсов также совпадает.

---

### **Задание 6.** <a name="задание_6"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

Выполните команду `EXPLAIN` для запроса, в котором использована 
какая-нибудь из оконных функций. Найдите в плане выполнения запроса узел с 
именем `WindowAgg`. Попробуйте объяснить, почему он занимает именно этот 
уровень в плане.
</details>

Ответ:

Допустим, мы хотим решить следующую задачу: найти первый рейс из 
Домодедово (по реальному времени отправления) для каждого самолета. Для этого
лучше всего подойдет оконная функция `ROW_NUMBER()`.
Также для удобства дальнейшей фильтрации я сделаю номинальный 
`CTE`-запрос, но он не должен тратить много времени на себя.

Итак,запрос:
```SQL
with cte as 
(
    select 
        a.model,
        --f.*
        f.flight_no,
        f.departure_airport,
        f.arrival_airport,
        f.actual_departure,
        f.actual_arrival,
        ROW_NUMBER() 
        OVER (PARTITION BY f.aircraft_code ORDER BY actual_departure ASC) as rn
    from flights f
    join aircrafts a on f.aircraft_code = a.aircraft_code
    where departure_airport = 'DME'
)
select * from cte
where rn = 1;
```

Результат следующий:
```
        model        | flight_no | departure_airport | arrival_airport |    actual_departure    |     actual_arrival     | rn 
---------------------+-----------+-------------------+-----------------+------------------------+------------------------+----
 Airbus A319-100     | PG0134    | DME               | BTK             | 2016-09-13 08:54:00+03 | 2016-09-13 14:05:00+03 |  1
 Airbus A321-200     | PG0405    | DME               | LED             | 2016-09-13 08:44:00+03 | 2016-09-13 09:39:00+03 |  1
 Boeing 737-300      | PG0210    | DME               | MRV             | 2016-09-13 17:01:00+03 | 2016-09-13 18:50:00+03 |  1
 Boeing 767-300      | PG0517    | DME               | SCW             | 2016-09-13 09:35:00+03 | 2016-09-13 10:57:00+03 |  1
 Boeing 777-300      | PG0222    | DME               | OVB             | 2016-09-13 10:06:00+03 | 2016-09-13 13:31:00+03 |  1
 Cessna 208 Caravan  | PG0335    | DME               | JOK             | 2016-09-13 08:31:00+03 | 2016-09-13 10:37:00+03 |  1
 Bombardier CRJ-200  | PG0341    | DME               | PES             | 2016-09-13 09:52:00+03 | 2016-09-13 10:58:00+03 |  1
 Sukhoi SuperJet-100 | PG0239    | DME               | HMA             | 2016-09-13 08:05:00+03 | 2016-09-13 10:39:00+03 |  1
(8 строк)
```

Можем увидеть, что в нашей БД нет рейсов у самолета Airbus A320-200 из Домодедово
(как и в целом во весх полетах).

Если применить к запросу команды `EXPLAIN ANALYZE`, получится:
```
                                                              QUERY PLAN                                                              
--------------------------------------------------------------------------------------------------------------------------------------
 CTE Scan on cte  (cost=1071.12..1143.44 rows=16 width=116) (actual time=8.958..12.158 rows=8 loops=1)
   Filter: (rn = 1)
   Rows Removed by Filter: 3209
   CTE cte
     ->  WindowAgg  (cost=1006.84..1071.12 rows=3214 width=83) (actual time=8.954..10.636 rows=3217 loops=1)
           ->  Sort  (cost=1006.84..1014.88 rows=3214 width=67) (actual time=8.947..9.090 rows=3217 loops=1)
                 Sort Key: f.aircraft_code, f.actual_departure
                 Sort Method: quicksort  Memory: 449kB
                 ->  Hash Join  (cost=1.20..819.62 rows=3214 width=67) (actual time=0.025..7.145 rows=3217 loops=1)
                       Hash Cond: (f.aircraft_code = a.aircraft_code)
                       ->  Seq Scan on flights f  (cost=0.00..806.01 rows=3214 width=35) (actual time=0.011..5.953 rows=3217 loops=1)
                             Filter: (departure_airport = 'DME'::bpchar)
                             Rows Removed by Filter: 29904
                       ->  Hash  (cost=1.09..1.09 rows=9 width=48) (actual time=0.010..0.010 rows=9 loops=1)
                             Buckets: 1024  Batches: 1  Memory Usage: 9kB
                             ->  Seq Scan on aircrafts a  (cost=0.00..1.09 rows=9 width=48) (actual time=0.003..0.005 rows=9 loops=1)
 Planning time: 0.185 ms
 Execution time: 12.264 ms
(18 строк)
```

Видим узел с именем `WindowAgg`. Он находится в самом верху `CTE` (т.е. выполняется последним).
Думаю это так, поскольку оконные функции применяются уже к итоговой выборке:
после фильтраций и агрегаций. К тому же, выборку еще нужно разделить на партиции (окна)
для применения оконной функции по ним.

---

### **Задание 8.** <a name="задание_8"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

Замена коррелированного подзапроса соединением таблиц является одним из
способов повышения производительности.

Предположим, что мы задались вопросом: сколько маршрутов обслуживают 
самолеты каждого типа? При этом нужно учитывать, что может иметь место такая
ситуация, когда самолеты какого-либо типа не обслуживают ни одного 
маршрута. Поэтому необходимо использовать не только представление «Маршруты»
(`routes`), но и таблицу «Самолеты» (`aircrafts`).

Это первый вариант запроса, в нем используется коррелированный подзапрос.
```SQL
EXPLAIN ANALYZE
SELECT a.aircraft_code AS a_code,
a.model,
( SELECT count( r.aircraft_code )
FROM routes r
WHERE r.aircraft_code = a.aircraft_code
) AS num_routes
FROM aircrafts a
GROUP BY 1, 2
ORDER BY 3 DESC;
```

А в этом варианте коррелированный подзапрос раскрыт и заменен внешним
соединением:
```SQL
EXPLAIN ANALYZE
SELECT a.aircraft_code AS a_code,
a.model,
count( r.aircraft_code ) AS num_routes
FROM aircrafts a
LEFT OUTER JOIN routes r
ON r.aircraft_code = a.aircraft_code
GROUP BY 1, 2
ORDER BY 3 DESC;
```

Причина использования внешнего соединения в том, что может найтись 
модель самолета, не обслуживающая ни одного маршрута, и если не использовать
внешнее соединение, она вообще не попадет в результирующую выборку.

Исследуйте планы выполнения обоих запросов. Попытайтесь найти объяснение
различиям в эффективности их выполнения. Чтобы получить усредненную
картину, выполните каждый запрос несколько раз. Поскольку таблицы, 
участвующие в запросах, небольшие, то различие по абсолютным затратам времени
выполнения будет незначительным. Но если бы число строк в таблицах было
большим, то экономия ресурсов сервера могла оказаться заметной.

Предложите аналогичную пару запросов к базе данных «Авиаперевозки». 
Проведите необходимые эксперименты с вашими запросами.
</details>

Ответ:

Попробуем замерить скорость работы следующих двух запросов, усреднив 5 
запусков и посмотрим на планы их исполнения:

```SQL
EXPLAIN ANALYZE
SELECT a.aircraft_code AS a_code,
a.model,
( SELECT count( r.aircraft_code )
FROM routes r
WHERE r.aircraft_code = a.aircraft_code
) AS num_routes
FROM aircrafts a
GROUP BY 1, 2
ORDER BY 3 DESC;
```
```SQL
EXPLAIN ANALYZE
SELECT a.aircraft_code AS a_code,
a.model,
count( r.aircraft_code ) AS num_routes
FROM aircrafts a
LEFT OUTER JOIN routes r
ON r.aircraft_code = a.aircraft_code
GROUP BY 1, 2
ORDER BY 3 DESC;
```

Скорость исполнения первого запроса: 
1. 12.264
2. 1.664
3. 2.215
4. 1.293
5. 2.841

Среднее время: 4.055 мс (без первого запуска — 2.003 мс).

План первого запуска:
```
                                                       QUERY PLAN                                                        
-------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=236.31..236.34 rows=9 width=56) (actual time=2.763..2.765 rows=9 loops=1)
   Sort Key: ((SubPlan 1)) DESC
   Sort Method: quicksort  Memory: 25kB
   ->  HashAggregate  (cost=1.11..236.17 rows=9 width=56) (actual time=0.401..2.745 rows=9 loops=1)
         Group Key: a.aircraft_code
         ->  Seq Scan on aircrafts a  (cost=0.00..1.09 rows=9 width=48) (actual time=0.008..0.010 rows=9 loops=1)
         SubPlan 1
           ->  Aggregate  (cost=26.10..26.11 rows=1 width=8) (actual time=0.299..0.299 rows=1 loops=9)
                 ->  Seq Scan on routes r  (cost=0.00..25.88 rows=89 width=4) (actual time=0.058..0.281 rows=79 loops=9)
                       Filter: (aircraft_code = a.aircraft_code)
                       Rows Removed by Filter: 631
 Planning time: 0.239 ms
 Execution time: 2.841 ms
(13 строк)
```

Скорость исполнения второго запроса: 
1. 1.106
2. 1.096
3. 1.424 
4. 1.108
5. 0.693

Среднее время: 1.085 мс.

План второго запуска:
```
                                                          QUERY PLAN                                                          
------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=31.83..31.85 rows=9 width=56) (actual time=0.650..0.651 rows=9 loops=1)
   Sort Key: (count(r.aircraft_code)) DESC
   Sort Method: quicksort  Memory: 25kB
   ->  HashAggregate  (cost=31.60..31.69 rows=9 width=56) (actual time=0.636..0.639 rows=9 loops=1)
         Group Key: a.aircraft_code
         ->  Hash Right Join  (cost=1.20..28.05 rows=710 width=52) (actual time=0.048..0.416 rows=711 loops=1)
               Hash Cond: (r.aircraft_code = a.aircraft_code)
               ->  Seq Scan on routes r  (cost=0.00..24.10 rows=710 width=4) (actual time=0.004..0.094 rows=710 loops=1)
               ->  Hash  (cost=1.09..1.09 rows=9 width=48) (actual time=0.039..0.039 rows=9 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     ->  Seq Scan on aircrafts a  (cost=0.00..1.09 rows=9 width=48) (actual time=0.017..0.019 rows=9 loops=1)
 Planning time: 0.139 ms
 Execution time: 0.693 ms
(13 строк)
```

При сравнении двух планов видим большую разницу в затрачиваемых
ресурсах: почти в 10 раз. По времени работы видим разницу в 
среднем времени в 4 раза, при этом в первом варианте с коррелированными подзапросами
самый первый запуск занимает очень много времени (около 12 мс), 
а последующие — всего в 2 раза медленнее второго запроса, в среднем (около 2 мс).

Прежде всего, такая большая разница достигается засчет того, что
в первом запросе нам приходится 9 раз (по числу самолетов) 
отфильтровывать нужные рейсы, чтобы сделать агрегацию и посчитать число
строк для каждой модели (по сути, всех оставшихся строк).

Это заметно в первом плане (`loops=9`):
```
Seq Scan on routes r  (cost=0.00..25.88 rows=89 width=4) (actual time=0.058..0.281 rows=79 loops=9)
                       Filter: (aircraft_code = a.aircraft_code)
                       Rows Removed by Filter: 631
```

Во втором плане мы один раз присоединяем названия моделей самолетов
с помощью хеширования (`Hash Right Join`), и затем один раз группируем
данные по `aircraft_code`, благодаря этому нам не нужно 9 раз обращаться к 
таблице `routes`.

Дополнительно мне кажется важным отметить, что `GROUP BY` 
в первом запросе является избыточным, поскольку запрос правильно отработает и 
без него, т.к. во "внешнем" запросе нам уже не нужна группировка:
```SQL
SELECT a.aircraft_code AS a_code,
a.model,
( SELECT count( r.aircraft_code )
FROM routes r
WHERE r.aircraft_code = a.aircraft_code
) AS num_routes
FROM aircrafts a
ORDER BY 3 DESC;

 a_code |        model        | num_routes 
--------+---------------------+------------
 CR2    | Bombardier CRJ-200  |        232
 CN1    | Cessna 208 Caravan  |        170
 SU9    | Sukhoi SuperJet-100 |        158
 319    | Airbus A319-100     |         46
 733    | Boeing 737-300      |         36
 321    | Airbus A321-200     |         32
 763    | Boeing 767-300      |         26
 773    | Boeing 777-300      |         10
 320    | Airbus A320-200     |          0
(9 строк)
```

Однако это практически не влияет на требуемые ресурсы и скорость исполнения,
поскольку мы все еще 9 раз обращаемся к `routes`:
```SQL
EXPLAIN ANALYZE
......

                                                       QUERY PLAN                                                        
-------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=236.20..236.22 rows=9 width=56) (actual time=1.250..1.252 rows=9 loops=1)
   Sort Key: ((SubPlan 1)) DESC
   Sort Method: quicksort  Memory: 25kB
   ->  Seq Scan on aircrafts a  (cost=0.00..236.06 rows=9 width=56) (actual time=0.177..1.240 rows=9 loops=1)
         SubPlan 1
           ->  Aggregate  (cost=26.10..26.11 rows=1 width=8) (actual time=0.136..0.136 rows=1 loops=9)
                 ->  Seq Scan on routes r  (cost=0.00..25.88 rows=89 width=4) (actual time=0.022..0.127 rows=79 loops=9)
                       Filter: (aircraft_code = a.aircraft_code)
                       Rows Removed by Filter: 631
 Planning time: 0.092 ms
 Execution time: 1.282 ms
(11 строк)
```

* Было:  `cost=236.31..236.34`
* Стало: `cost=236.20..236.22`

---

В качестве еще одного примера разницы между неоптимальным коррелированным 
подзапросом и соединением я решил взять свой запрос из первого задания 
текущего ДЗ, немного доработать его, чтобы он решал следующую задачу,
которая в реальной работе может быть полезной:
считаем долю выданных посадочных талонов от макс. числа мест по каждому 
завершившемуся рейсу (со статусом Arrived). Пропустим завершившиеся рейсы
с 0 проданных билетов (на удивление их оказалось около 2/3), поскольку
в реальной жизни это маловероятно. 

Потенциально такой запрос может помочь нам грамотно рассчитывать запас
топлива на каждый рейс, а также понимать, как утилизируется наш
авиапарк.

Я немного доработал изначальный запрос:
```SQL
-- good
with num_seats as (
select 
    aircraft_code,
    count(seat_no) as max_num
from seats
group by aircraft_code
)
select 
    flights.flight_id,
    num_seats.aircraft_code,
    num_seats.max_num,
    count(*) as count_num,
    num_seats.max_num - count(*) as left,
    round(( count(*)::numeric / num_seats.max_num::numeric ) * 100, 2) as utilization
from flights
right outer join boarding_passes on flights.flight_id = boarding_passes.flight_id
right outer join num_seats on flights.aircraft_code = num_seats.aircraft_code
where flights.status = 'Arrived'
group by num_seats.aircraft_code, num_seats.max_num, flights.flight_id
order by flights.flight_id
;
```

Результат, который он возвращает:
```
 flight_id | aircraft_code | max_num | count_num | left | utilization 
-----------+---------------+---------+-----------+------+-------------
         1 | 321           |     170 |        79 |   91 |       46.47
         2 | 321           |     170 |       101 |   69 |       59.41
         3 | 321           |     170 |        97 |   73 |       57.06
        17 | 321           |     170 |       101 |   69 |       59.41
        18 | 321           |     170 |        96 |   74 |       56.47
        21 | 321           |     170 |        85 |   85 |       50.00
        22 | 321           |     170 |         1 |  169 |        0.59
        25 | 321           |     170 |       115 |   55 |       67.65
        26 | 321           |     170 |        90 |   80 |       52.94
        27 | 321           |     170 |        92 |   78 |       54.12
...........
```

Сейчас он довольно эффективен, поскольку соединяет все нужные данные 
в одной выборке и далее агрегирует их нужным нам образом. При этом 
макс. число мест заранее один раз считается в `CTE`.

Вот как выглядит план этого запроса:
```SQL
EXPLAIN ANALYZE
with num_seats as (
select 
    aircraft_code,
    count(seat_no) as max_num
from seats
group by aircraft_code
)
select 
    --cur_seats.flight_id,
    flights.flight_id,
    num_seats.aircraft_code,
    num_seats.max_num,
    count(*) as count_num,
    num_seats.max_num - count(*) as left,
    round(( count(*)::numeric / num_seats.max_num::numeric ) * 100, 2) as utilization
from flights
right outer join boarding_passes on flights.flight_id = boarding_passes.flight_id
right outer join num_seats on flights.aircraft_code = num_seats.aircraft_code
where flights.status = 'Arrived'
group by num_seats.aircraft_code, num_seats.max_num, flights.flight_id
order by flights.flight_id
;
```
```
                                                                QUERY PLAN                                                                
------------------------------------------------------------------------------------------------------------------------------------------
 GroupAggregate  (cost=49951.70..58822.59 rows=150273 width=76) (actual time=577.662..777.627 rows=11438 loops=1)
   Group Key: flights.flight_id, num_seats.aircraft_code, num_seats.max_num
   CTE num_seats
     ->  HashAggregate  (cost=28.09..28.18 rows=9 width=12) (actual time=0.757..0.761 rows=9 loops=1)
           Group Key: seats.aircraft_code
           ->  Seq Scan on seats  (cost=0.00..21.39 rows=1339 width=7) (actual time=0.007..0.161 rows=1339 loops=1)
   ->  Sort  (cost=49923.53..50654.11 rows=292232 width=28) (actual time=577.624..652.689 rows=574830 loops=1)
         Sort Key: flights.flight_id, num_seats.aircraft_code, num_seats.max_num
         Sort Method: external merge  Disk: 14656kB
         ->  Hash Join  (cost=1244.60..16400.60 rows=292232 width=28) (actual time=21.116..247.489 rows=574830 loops=1)
               Hash Cond: (boarding_passes.flight_id = flights.flight_id)
               ->  Seq Scan on boarding_passes  (cost=0.00..10059.86 rows=579686 width=4) (actual time=0.010..59.847 rows=579686 loops=1)
               ->  Hash  (cost=1035.89..1035.89 rows=16697 width=28) (actual time=21.001..21.003 rows=16707 loops=1)
                     Buckets: 32768  Batches: 1  Memory Usage: 1040kB
                     ->  Hash Join  (cost=0.29..1035.89 rows=16697 width=28) (actual time=0.791..16.289 rows=16707 loops=1)
                           Hash Cond: (flights.aircraft_code = num_seats.aircraft_code)
                           ->  Seq Scan on flights  (cost=0.00..806.01 rows=16697 width=8) (actual time=0.005..9.385 rows=16707 loops=1)
                                 Filter: ((status)::text = 'Arrived'::text)
                                 Rows Removed by Filter: 16414
                           ->  Hash  (cost=0.18..0.18 rows=9 width=24) (actual time=0.774..0.775 rows=9 loops=1)
                                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                 ->  CTE Scan on num_seats  (cost=0.00..0.18 rows=9 width=24) (actual time=0.760..0.768 rows=9 loops=1)
 Planning time: 0.574 ms
 Execution time: 780.417 ms
(24 строки)
```

Видим, что везде используется один цикл.

Теперь "испортим" этот запрос, добавив коррелированные подзапросы для
самолетов (aircraft_code) и рейсов (flight_id), чтобы находить
макс. число мест и число выданных посадочных талонов:
```SQL
-- bad
select
    flights.flight_id,
    flights.aircraft_code,
    ( select count(seat_no) 
      from seats
      where seats.aircraft_code = flights.aircraft_code
    ) as max_num,
    ( select count(*) 
      from boarding_passes
      where flights.flight_id = boarding_passes.flight_id
    ) as count_num,
    ( select count(seat_no) 
      from seats
      where seats.aircraft_code = flights.aircraft_code
    )
     - 
    ( select count(*) 
      from boarding_passes
      where flights.flight_id = boarding_passes.flight_id
    ) as left,
    round(( ( select count(*) 
              from boarding_passes
              where flights.flight_id = boarding_passes.flight_id
     )::numeric / ( select count(seat_no) 
                    from seats
                    where seats.aircraft_code = flights.aircraft_code
     )::numeric ) * 100, 2) as utilization
from flights
where flights.status = 'Arrived'
and ( select count(*) 
      from boarding_passes
      where flights.flight_id = boarding_passes.flight_id
     ) > 0
order by flights.flight_id
;
```

Можем увидеть, что результат запроса такой же:
```
 flight_id | aircraft_code | max_num | count_num | left | utilization 
-----------+---------------+---------+-----------+------+-------------
         1 | 321           |     170 |        79 |   91 |       46.47
         2 | 321           |     170 |       101 |   69 |       59.41
         3 | 321           |     170 |        97 |   73 |       57.06
        17 | 321           |     170 |       101 |   69 |       59.41
        18 | 321           |     170 |        96 |   74 |       56.47
        21 | 321           |     170 |        85 |   85 |       50.00
        22 | 321           |     170 |         1 |  169 |        0.59
        25 | 321           |     170 |       115 |   55 |       67.65
        26 | 321           |     170 |        90 |   80 |       52.94
        27 | 321           |     170 |        92 |   78 |       54.12
...............
```

Но сам запрос гораздо менее эффективный:
```SQL
EXPLAIN ANALYZE
select
    flights.flight_id,
    flights.aircraft_code,
    ( select count(seat_no) 
      from seats
      where seats.aircraft_code = flights.aircraft_code
    ) as max_num,
    ( select count(*) 
      from boarding_passes
      where flights.flight_id = boarding_passes.flight_id
    ) as count_num,
    ( select count(seat_no) 
      from seats
      where seats.aircraft_code = flights.aircraft_code
    )
     - 
    ( select count(*) 
      from boarding_passes
      where flights.flight_id = boarding_passes.flight_id
    ) as left,
    round(( ( select count(*) 
              from boarding_passes
              where flights.flight_id = boarding_passes.flight_id
     )::numeric / ( select count(seat_no) 
                    from seats
                    where seats.aircraft_code = flights.aircraft_code
     )::numeric ) * 100, 2) as utilization
from flights
where flights.status = 'Arrived'
and ( select count(*) 
      from boarding_passes
      where flights.flight_id = boarding_passes.flight_id
     ) > 0
order by flights.flight_id
;
```
```
                                                                            QUERY PLAN                                                                            
------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using flights_pkey on flights  (cost=0.29..12138437.10 rows=5566 width=64) (actual time=0.272..1859.740 rows=11438 loops=1)
   Filter: (((status)::text = 'Arrived'::text) AND ((SubPlan 7) > 0))
   Rows Removed by Filter: 21683
   SubPlan 7
     ->  Aggregate  (cost=238.36..238.37 rows=1 width=8) (actual time=0.013..0.013 rows=1 loops=16707)
           ->  Bitmap Heap Scan on boarding_passes boarding_passes_3  (cost=4.92..238.20 rows=64 width=0) (actual time=0.006..0.009 rows=34 loops=16707)
                 Recheck Cond: (flights.flight_id = flight_id)
                 Heap Blocks: exact=15584
                 ->  Bitmap Index Scan on boarding_passes_flight_id_seat_no_key  (cost=0.00..4.91 rows=64 width=0) (actual time=0.004..0.004 rows=34 loops=16707)
                       Index Cond: (flights.flight_id = flight_id)
   SubPlan 1
     ->  Aggregate  (cost=15.67..15.68 rows=1 width=8) (actual time=0.029..0.029 rows=1 loops=11438)
           ->  Bitmap Heap Scan on seats  (cost=5.43..15.29 rows=149 width=3) (actual time=0.012..0.018 rows=92 loops=11438)
                 Recheck Cond: (aircraft_code = flights.aircraft_code)
                 Heap Blocks: exact=18263
                 ->  Bitmap Index Scan on seats_pkey  (cost=0.00..5.39 rows=149 width=0) (actual time=0.008..0.008 rows=92 loops=11438)
                       Index Cond: (aircraft_code = flights.aircraft_code)
   SubPlan 2
     ->  Aggregate  (cost=238.36..238.37 rows=1 width=8) (actual time=0.016..0.016 rows=1 loops=11438)
           ->  Bitmap Heap Scan on boarding_passes  (cost=4.92..238.20 rows=64 width=0) (actual time=0.007..0.011 rows=50 loops=11438)
                 Recheck Cond: (flights.flight_id = flight_id)
                 Heap Blocks: exact=15584
                 ->  Bitmap Index Scan on boarding_passes_flight_id_seat_no_key  (cost=0.00..4.91 rows=64 width=0) (actual time=0.005..0.005 rows=50 loops=11438)
                       Index Cond: (flights.flight_id = flight_id)
   SubPlan 3
     ->  Aggregate  (cost=15.67..15.68 rows=1 width=8) (actual time=0.031..0.031 rows=1 loops=11438)
           ->  Bitmap Heap Scan on seats seats_1  (cost=5.43..15.29 rows=149 width=3) (actual time=0.012..0.019 rows=92 loops=11438)
                 Recheck Cond: (aircraft_code = flights.aircraft_code)
                 Heap Blocks: exact=18263
                 ->  Bitmap Index Scan on seats_pkey  (cost=0.00..5.39 rows=149 width=0) (actual time=0.008..0.008 rows=92 loops=11438)
                       Index Cond: (aircraft_code = flights.aircraft_code)
   SubPlan 4
     ->  Aggregate  (cost=238.36..238.37 rows=1 width=8) (actual time=0.016..0.016 rows=1 loops=11438)
           ->  Bitmap Heap Scan on boarding_passes boarding_passes_1  (cost=4.92..238.20 rows=64 width=0) (actual time=0.007..0.011 rows=50 loops=11438)
                 Recheck Cond: (flights.flight_id = flight_id)
                 Heap Blocks: exact=15584
                 ->  Bitmap Index Scan on boarding_passes_flight_id_seat_no_key  (cost=0.00..4.91 rows=64 width=0) (actual time=0.005..0.005 rows=50 loops=11438)
                       Index Cond: (flights.flight_id = flight_id)
   SubPlan 5
     ->  Aggregate  (cost=238.36..238.37 rows=1 width=8) (actual time=0.015..0.015 rows=1 loops=11438)
           ->  Bitmap Heap Scan on boarding_passes boarding_passes_2  (cost=4.92..238.20 rows=64 width=0) (actual time=0.007..0.011 rows=50 loops=11438)
                 Recheck Cond: (flights.flight_id = flight_id)
                 Heap Blocks: exact=15584
                 ->  Bitmap Index Scan on boarding_passes_flight_id_seat_no_key  (cost=0.00..4.91 rows=64 width=0) (actual time=0.005..0.005 rows=50 loops=11438)
                       Index Cond: (flights.flight_id = flight_id)
   SubPlan 6
     ->  Aggregate  (cost=15.67..15.68 rows=1 width=8) (actual time=0.029..0.030 rows=1 loops=11438)
           ->  Bitmap Heap Scan on seats seats_2  (cost=5.43..15.29 rows=149 width=3) (actual time=0.012..0.018 rows=92 loops=11438)
                 Recheck Cond: (aircraft_code = flights.aircraft_code)
                 Heap Blocks: exact=18263
                 ->  Bitmap Index Scan on seats_pkey  (cost=0.00..5.39 rows=149 width=0) (actual time=0.008..0.008 rows=92 loops=11438)
                       Index Cond: (aircraft_code = flights.aircraft_code)
 Planning time: 0.292 ms
 Execution time: 1860.923 ms
(54 строки)
```

Помимо того, что сам код запроса стал очень большим и нечитаемым,
разброс затрачиваемых ресурсов увеличился с 
* `cost=49951.70..58822.59 rows=150273 width=76)`
до 
* `cost=0.29..12138437.10 rows=5566 width=64`
, хотя самих строк и стало меньше.

Время запроса увеличилось с 780.417 ms до 1860.923 ms.

И мы снова видим, что, как и выше, число циклов увеличилось с `loops=1`
(в случае с `JOIN`) до `loops=11438` и `loops=16707` с подзапросами, 
поскольку теперь нужно было делать сразу два подзапроса: чтобы посчитать 
число максимальных мест
(по таблице `seats`) и число занятых мест (по таблице `boarding_passes`).

Поэтому в такой постановке задачи гораздо лучше выбрать изначальный вариант.

---

