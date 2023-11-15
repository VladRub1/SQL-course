## 👨🏻‍💻 ДЗ № 6. Глава 7. Изменение данных

Содержание:
1. [Задание 1.](#задание_1)
2. [Задание 2.](#задание_2)
3. [Задание 4.](#задание_4)

### **Задание 1.** <a name="задание_1"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

Добавьте в определение таблицы `aircrafts_log` значение по умолчанию
`current_timestamp` и соответствующим образом измените команды `INSERT`,
приведенные в тексте главы.
</details>

Ответ:

В начале создадим "основную" копию таблицы `aircrafts_tmp` вместе с ее
ограничениями:
```SQL
CREATE TEMP TABLE aircrafts_tmp AS
SELECT * FROM aircrafts WITH NO DATA;

ALTER TABLE aircrafts_tmp
    ADD PRIMARY KEY ( aircraft_code );

ALTER TABLE aircrafts_tmp
    ADD UNIQUE ( model );
```
Далее создадим таблицу для логов, добавив поле `operation_timestamp`, 
сделав по умолчанию значение функции `current_timestamp`:
```SQL
CREATE TEMP TABLE aircrafts_log AS
SELECT * FROM aircrafts WITH NO DATA;

ALTER TABLE aircrafts_log
    ADD COLUMN operation text;
ALTER TABLE aircrafts_log
    ADD COLUMN operation_timestamp timestamp DEFAULT ( current_timestamp );
```
Теперь изменим команду `INSERT` так, чтобы напрямую не указывать время
операции:
```SQL
WITH add_row AS
( 
    INSERT INTO aircrafts_tmp
    SELECT * FROM aircrafts
    RETURNING *
)
INSERT INTO aircrafts_log
SELECT 
    add_row.aircraft_code, 
    add_row.model, 
    add_row.range, 
    'INSERT'
FROM add_row;
```
Посмотрим на результат:
```SQL
SELECT * FROM aircrafts_log;

 aircraft_code |        model        | range | operation |    operation_timestamp     
---------------+---------------------+-------+-----------+----------------------------
 773           | Boeing 777-300      | 11100 | INSERT    | 2023-11-15 00:33:14.296826
 763           | Boeing 767-300      |  7900 | INSERT    | 2023-11-15 00:33:14.296826
 SU9           | Sukhoi SuperJet-100 |  3000 | INSERT    | 2023-11-15 00:33:14.296826
 320           | Airbus A320-200     |  5700 | INSERT    | 2023-11-15 00:33:14.296826
 321           | Airbus A321-200     |  5600 | INSERT    | 2023-11-15 00:33:14.296826
 319           | Airbus A319-100     |  6700 | INSERT    | 2023-11-15 00:33:14.296826
 733           | Boeing 737-300      |  4200 | INSERT    | 2023-11-15 00:33:14.296826
 CN1           | Cessna 208 Caravan  |  1200 | INSERT    | 2023-11-15 00:33:14.296826
 CR2           | Bombardier CRJ-200  |  2700 | INSERT    | 2023-11-15 00:33:14.296826
(9 строк)
```
Видим, как и на лекции, что результат функции `current_timestamp` везде одинаковый, 
поскольку она возвращает время начала транзакции.

Попробуем вместо функции ``current_timestamp`` использовать значение функции 
`clock_timestamp` по умолчанию:
```SQL
DROP TABLE aircrafts_tmp;
DROP TABLE aircrafts_log;

CREATE TEMP TABLE aircrafts_tmp AS
SELECT * FROM aircrafts WITH NO DATA;

CREATE TEMP TABLE aircrafts_log AS
SELECT * FROM aircrafts WITH NO DATA;

ALTER TABLE aircrafts_log
    ADD COLUMN operation text;
ALTER TABLE aircrafts_log
    ADD COLUMN operation_timestamp timestamp DEFAULT ( clock_timestamp() );

WITH add_row AS
( 
    INSERT INTO aircrafts_tmp
    SELECT * FROM aircrafts
    RETURNING *
)
INSERT INTO aircrafts_log
SELECT 
    add_row.aircraft_code, 
    add_row.model, 
    add_row.range, 
    'INSERT'
FROM add_row;
```
Результат:
```SQL
SELECT * FROM aircrafts_log;

 aircraft_code |        model        | range | operation |    operation_timestamp     
---------------+---------------------+-------+-----------+----------------------------
 773           | Boeing 777-300      | 11100 | INSERT    | 2023-11-15 00:41:22.769597
 763           | Boeing 767-300      |  7900 | INSERT    | 2023-11-15 00:41:22.769619
 SU9           | Sukhoi SuperJet-100 |  3000 | INSERT    | 2023-11-15 00:41:22.769622
 320           | Airbus A320-200     |  5700 | INSERT    | 2023-11-15 00:41:22.769624
 321           | Airbus A321-200     |  5600 | INSERT    | 2023-11-15 00:41:22.769625
 319           | Airbus A319-100     |  6700 | INSERT    | 2023-11-15 00:41:22.769627
 733           | Boeing 737-300      |  4200 | INSERT    | 2023-11-15 00:41:22.769629
 CN1           | Cessna 208 Caravan  |  1200 | INSERT    | 2023-11-15 00:41:22.76963
 CR2           | Bombardier CRJ-200  |  2700 | INSERT    | 2023-11-15 00:41:22.769632
(9 строк)
```
Видим, что теперь время операции разное (хоть и отличается на миллисекунды)

---
### **Задание 2.** <a name="задание_2"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

В предложении `RETURNING` можно указывать не только символ «`*`», означающий
выбор всех столбцов таблицы, но и более сложные выражения, сформированные
на основе этих столбцов. В тексте главы мы копировали содержимое таблицы
«Самолеты» в таблицу `aircrafts_tmp`, используя в предложении `RETURNING`
именно «`*`». Однако возможен и другой вариант запроса:
```SQL
WITH add_row AS
( INSERT INTO aircrafts_tmp
    SELECT * FROM aircrafts
    RETURNING aircraft_code, model, range,
              current_timestamp, 'INSERT'
)
INSERT INTO aircrafts_log
    SELECT ? FROM add_row;
```
Что нужно написать в этом запросе вместо вопросительного знака?

</details>

Ответ:

В начале пересоздадим существующие временные таблицы и ограничения:
```SQL
DROP TABLE IF EXISTS aircrafts_tmp;
DROP TABLE IF EXISTS aircrafts_log;

CREATE TEMP TABLE aircrafts_tmp AS
SELECT * FROM aircrafts WITH NO DATA;

ALTER TABLE aircrafts_tmp
    ADD PRIMARY KEY ( aircraft_code );
ALTER TABLE aircrafts_tmp
    ADD UNIQUE ( model );
--
CREATE TEMP TABLE aircrafts_log AS
SELECT * FROM aircrafts WITH NO DATA;

ALTER TABLE aircrafts_log
    ADD COLUMN when_add timestamp;
ALTER TABLE aircrafts_log
    ADD COLUMN operation text;
```
Чтобы добавить `aircrafts_log` нужную информацию, нужно передать ее 
после ключевого слова `RETURNING`. Для этого посмотрим, как устроена таблица 
`aircrafts_log`:
```SQL
\d aircrafts_log
                                  Таблица "pg_temp_3.aircrafts_log"
    Столбец    |             Тип             | Правило сортировки | Допустимость NULL | По умолчанию 
---------------+-----------------------------+--------------------+-------------------+--------------
 aircraft_code | character(3)                |                    |                   | 
 model         | text                        |                    |                   | 
 range         | integer                     |                    |                   | 
 when_add      | timestamp without time zone |                    |                   | 
 operation     | text                        |                    |                   | 
```
Я вижу два варианта:

1. передать значение полей `when_add` и operation непосредственно в подзапросе ``add_row``
2. передать их в "основном" запросе

Попробую оба варианта. Для первого нужно будет использовать псевдонимы для полей,
чтобы ниже обратиться к ним:
```SQL
WITH add_row AS
( INSERT INTO aircrafts_tmp
    SELECT * FROM aircrafts
    RETURNING aircraft_code, model, range,
              current_timestamp AS cur_tmstp, 
              'INSERT' AS cur_operation
)
INSERT INTO aircrafts_log
SELECT 
    aircraft_code,
    model,
    range,
    cur_tmstp,
    cur_operation
FROM add_row;

INSERT 0 9
```
Результат:
```SQL
select * from aircrafts_log ;

 aircraft_code |        model        | range |          when_add          | operation 
---------------+---------------------+-------+----------------------------+-----------
 773           | Boeing 777-300      | 11100 | 2023-11-15 09:40:40.817667 | INSERT
 763           | Boeing 767-300      |  7900 | 2023-11-15 09:40:40.817667 | INSERT
 SU9           | Sukhoi SuperJet-100 |  3000 | 2023-11-15 09:40:40.817667 | INSERT
 320           | Airbus A320-200     |  5700 | 2023-11-15 09:40:40.817667 | INSERT
 321           | Airbus A321-200     |  5600 | 2023-11-15 09:40:40.817667 | INSERT
 319           | Airbus A319-100     |  6700 | 2023-11-15 09:40:40.817667 | INSERT
 733           | Boeing 737-300      |  4200 | 2023-11-15 09:40:40.817667 | INSERT
 CN1           | Cessna 208 Caravan  |  1200 | 2023-11-15 09:40:40.817667 | INSERT
 CR2           | Bombardier CRJ-200  |  2700 | 2023-11-15 09:40:40.817667 | INSERT
(9 строк)
```
Все получилось. Теперь (снова перезаписав таблицы) попробую передать значения 
в основном запросе:
```SQL
WITH add_row AS
( 
  INSERT INTO aircrafts_tmp
    SELECT * FROM aircrafts
    RETURNING aircraft_code, 
              model, 
              range
)
INSERT INTO aircrafts_log
SELECT 
    aircraft_code,
    model,
    range,
    current_timestamp,
    'INSERT'
FROM add_row;

INSERT 0 9
```
Проверим:
```SQL
select * from aircrafts_log ;
 aircraft_code |        model        | range |          when_add          | operation 
---------------+---------------------+-------+----------------------------+-----------
 773           | Boeing 777-300      | 11100 | 2023-11-15 09:43:55.253377 | INSERT
 763           | Boeing 767-300      |  7900 | 2023-11-15 09:43:55.253377 | INSERT
 SU9           | Sukhoi SuperJet-100 |  3000 | 2023-11-15 09:43:55.253377 | INSERT
 320           | Airbus A320-200     |  5700 | 2023-11-15 09:43:55.253377 | INSERT
 321           | Airbus A321-200     |  5600 | 2023-11-15 09:43:55.253377 | INSERT
 319           | Airbus A319-100     |  6700 | 2023-11-15 09:43:55.253377 | INSERT
 733           | Boeing 737-300      |  4200 | 2023-11-15 09:43:55.253377 | INSERT
 CN1           | Cessna 208 Caravan  |  1200 | 2023-11-15 09:43:55.253377 | INSERT
 CR2           | Bombardier CRJ-200  |  2700 | 2023-11-15 09:43:55.253377 | INSERT
(9 строк)
```
Тоже получилось корректно, но, наверное, второй вариант удобнее.

---
### **Задание 4.** <a name="задание_4"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

В тексте главы в предложениях `ON CONFLICT` команды `INSERT` мы использовали 
только выражения, состоящие из имени одного столбца. Однако в таблице
«Места» (`seats`) первичный ключ является составным и включает два столбца.

Напишите команду `INSERT` для вставки новой строки в эту таблицу и 
предусмотрите возможный конфликт добавляемой строки со строкой, уже 
имеющейся в таблице. Сделайте два варианта предложения `ON CONFLICT`: первый — 
с использованием перечисления имен столбцов для проверки наличия 
дублирования, второй — с использованием предложения `ON CONSTRAINT`.

Для того чтобы не изменить содержимое таблицы «Места», создайте ее копию
и выполняйте все эти эксперименты с таблицей-копией.
</details>

Ответ:

В начале вспомним структуру таблицы `seats`:
```SQL
\d seats
                                    Таблица "bookings.seats"
     Столбец     |          Тип          | Правило сортировки | Допустимость NULL | По умолчанию 
-----------------+-----------------------+--------------------+-------------------+--------------
 aircraft_code   | character(3)          |                    | not null          | 
 seat_no         | character varying(4)  |                    | not null          | 
 fare_conditions | character varying(10) |                    | not null          | 
Индексы:
    "seats_pkey" PRIMARY KEY, btree (aircraft_code, seat_no)
Ограничения-проверки:
    "seats_fare_conditions_check" CHECK (fare_conditions::text = ANY (ARRAY['Economy'::character varying::text, 'Comfort'::character varying::text, 'Business'::character varying::text]))
Ограничения внешнего ключа:
    "seats_aircraft_code_fkey" FOREIGN KEY (aircraft_code) REFERENCES aircrafts(aircraft_code) ON DELETE CASCADE
```
Видим, что в ней всего три столбца: `aircraft_code`, `seat_no`, `fare_conditions`.
Также нас интересует ограничение первичного ключа с названием `seats_pkey`,
состоящее из двух столбцов: `aircraft_code`, `seat_no`.

Скопируем таблицу с данными и, для простоты, добавим одно интересующее нас
ограничение:
```SQL
CREATE TEMP TABLE seats_tmp AS 
SELECT * FROM SEATS;

ALTER TABLE seats_tmp
    ADD PRIMARY KEY (aircraft_code, seat_no);
    
SELECT 1339
```
Посмотрим на копию таблицы:
```SQL
\d seats_tmp 
                                  Таблица "pg_temp_3.seats_tmp"
     Столбец     |          Тип          | Правило сортировки | Допустимость NULL | По умолчанию 
-----------------+-----------------------+--------------------+-------------------+--------------
 aircraft_code   | character(3)          |                    | not null          | 
 seat_no         | character varying(4)  |                    | not null          | 
 fare_conditions | character varying(10) |                    |                   | 
Индексы:
    "seats_tmp_pkey" PRIMARY KEY, btree (aircraft_code, seat_no)
```
Итак, нас будет интересовать ограничение с названием "`seats_tmp_pkey`", созданным
автоматически.

Еще посмотрим на первые значения:
```SQL
SELECT * FROM seats_tmp LIMIT 10;

 aircraft_code | seat_no | fare_conditions 
---------------+---------+-----------------
 319           | 2A      | Business
 319           | 2C      | Business
 319           | 2D      | Business
 319           | 2F      | Business
 319           | 3A      | Business
 319           | 3C      | Business
 319           | 3D      | Business
 319           | 3F      | Business
 319           | 4A      | Business
 319           | 4C      | Business
(10 строк)
```
Попробуем при добавлении новых значений, в случае нарушения ограничения,
**обновлять** класс обслуживания (допустим, мы хотим таким образом изменить
распределение кресел в салоне по классам обслуживания).

В начале попробуем указать два столбца, входящие в ограничение, напрямую:
```SQL
INSERT INTO seats_tmp
    VALUES ( '319', '2A', 'Economy' )
    ON CONFLICT ( aircraft_code, seat_no ) 
    DO UPDATE 
    SET fare_conditions = excluded.fare_conditions
    RETURNING *;
    
 aircraft_code | seat_no | fare_conditions 
---------------+---------+-----------------
 319           | 2A      | Economy
(1 строка)
```
Видим, что мы изменили класс обслуживания с бизнес-класса на эконом-класс у 
кресла с номером `2A` самолета с кодом `319`. 

Попробуем вывести все кресла `2А` в наших самолетах, которые соответствуют 
эконом-классу:
```SQL
SELECT * FROM seats_tmp 
WHERE fare_conditions = 'Economy'
AND seat_no = '2A';

 aircraft_code | seat_no | fare_conditions 
---------------+---------+-----------------
 CN1           | 2A      | Economy
 CR2           | 2A      | Economy
 319           | 2A      | Economy
(3 строки)
```
Видим, среди небольших самолетов, _Airbus A319-100_, у которого мы добавили новое 
значение обновив старое.

Теперь напрямую обратимся к ограничению и попробуем добавить бизнес-класс
самолету _Cessna 208 Caravan_:
```SQL
INSERT INTO seats_tmp
    VALUES ( 'CN1', '2A', 'Business' )
    ON CONFLICT ON CONSTRAINT seats_tmp_pkey
    DO UPDATE 
    SET fare_conditions = excluded.fare_conditions
    RETURNING *;
    
 aircraft_code | seat_no | fare_conditions 
---------------+---------+-----------------
 CN1           | 2A      | Business
(1 строка)
```
У него не так много мест, поэтому посмотрим на все:
```SQL
SELECT * FROM seats_tmp 
WHERE aircraft_code = 'CN1'
ORDER BY seat_no;

 aircraft_code | seat_no | fare_conditions 
---------------+---------+-----------------
 CN1           | 1A      | Economy
 CN1           | 1B      | Economy
 CN1           | 2A      | Business
 CN1           | 2B      | Economy
 CN1           | 3A      | Economy
 CN1           | 3B      | Economy
 CN1           | 4A      | Economy
 CN1           | 4B      | Economy
 CN1           | 5A      | Economy
 CN1           | 5B      | Economy
 CN1           | 6A      | Economy
 CN1           | 6B      | Economy
(12 строк)
```
Видим, что в самолете с кодом `CN1` появилось одно кресло с бизнес-классом.

---