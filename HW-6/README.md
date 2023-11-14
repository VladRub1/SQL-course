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
Далее создадим таблицу для логов, добавив поле operation_timestamp, 
сделав по умолчанию значение функции current_timestamp:
```SQL
CREATE TEMP TABLE aircrafts_log AS
SELECT * FROM aircrafts WITH NO DATA;

ALTER TABLE aircrafts_log
    ADD COLUMN operation text;
ALTER TABLE aircrafts_log
    ADD COLUMN operation_timestamp timestamp DEFAULT ( current_timestamp );
```
Теперь изменим команду INSERT так, чтобы напрямую не указывать время
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
Видим, как и на лекции, что результат функции current_timestamp везде одинаковый, 
поскольку она возвращает время начала транзакции.

Попробуем вместо функции current_timestamp использовать значение функции 
clock_timestamp по умолчанию:
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