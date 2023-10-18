## 👨🏻‍💻 ДЗ №4 Глава 5. Основы языка определения данных

Содержание:
1. [Задание 2.](#задание_2)
2. [Задание 9.](#задание_9)
3. [Задание 17.](#задание_17)
4. [Задание 18.](#задание_18)

### **Задание 2.** <a name="задание_2"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

Посмотрите, какие ограничения уже наложены на атрибуты таблицы «Успеваемость» 
(`progress)`. Воспользуйтесь командой `\d` утилиты `psql`. А теперь предложите 
для этой таблицы ограничение уровня таблицы.

В качестве примера рассмотрим такой вариант. Добавьте в таблицу `progress`
еще один атрибут — «Форма проверки знаний» (`test_form`), который может
принимать только два значения: «экзамен» или «зачет». Тогда набор допустимых 
значений атрибута «Оценка» (`mark`) будет зависеть от того, экзамен или зачет 
предусмотрены по данной дисциплине. Если предусмотрен экзамен, тогда
допускаются значения 3, 4, 5, если зачет — тогда 0 (не зачтено) или 1 (зачтено).

Не забудьте, что значения `NULL` для атрибутов `test_form` и `mark` не допускаются.
Новое ограничение может быть таким:

```SQL
ALTER TABLE progress
ADD CHECK (
( test_form = 'экзамен' AND mark IN ( 3, 4, 5 ) )
OR
( test_form = 'зачет' AND mark IN ( 0, 1 ) )
);
```

Проверьте, как будет работать новое ограничение в модифицированной таблице 
`progress`. Для этого выполните команды `INSERT`, как удовлетворяющие ограничению, 
так и нарушающие его.

В таблице уже было ограничение на допустимые значения атрибута `mark`. Как
вы думаете, не будет ли оно конфликтовать с новым ограничением? Проверьте
эту гипотезу. Если ограничения конфликтуют, тогда удалите старое ограничение 
и снова попробуйте добавить строки в таблицу.

Подумайте, какое еще ограничение уровня таблицы можно предложить для
этой таблицы?
</details>

Ответ:

Создадим требуемые таблицы:
```SQL
CREATE TABLE students
( record_book numeric( 5 ) NOT NULL,
 name text NOT NULL,
 doc_ser numeric( 4 ),
 doc_num numeric( 6 ),
 PRIMARY KEY ( record_book )
);

CREATE TABLE progress
( record_book numeric( 5 ) NOT NULL,
 subject text NOT NULL,
 acad_year text NOT NULL,
 term numeric( 1 ) NOT NULL CHECK ( term = 1 OR term = 2 ),
 mark numeric( 1 ) NOT NULL CHECK ( mark >= 3 AND mark <= 5 )
 DEFAULT 5,
 FOREIGN KEY ( record_book )
 REFERENCES students ( record_book )
 ON DELETE CASCADE
 ON UPDATE CASCADE
);
```
Добавим пару студентов:
```SQL
INSERT INTO students 
VALUES 
(12345, 'Алексеев Иван Петрович', 1234, 567890),
(15796, 'Петров Василий Иванович', 5423, 124583),
(73548, 'Браун Джеймс', 1111, 123456);
```

Посмотрим, какие ограничения уже наложены на атрибуты таблицы (`progress`):
```SQL
\d progress
```
```
                             Таблица "public.progress"
   Столбец   |     Тип      | Правило сортировки | Допустимость NULL | По умолчанию 
-------------+--------------+--------------------+-------------------+--------------
 record_book | numeric(5,0) |                    | not null          | 
 subject     | text         |                    | not null          | 
 acad_year   | text         |                    | not null          | 
 term        | numeric(1,0) |                    | not null          | 
 mark        | numeric(1,0) |                    | not null          | 5
Ограничения-проверки:
    "progress_mark_check" CHECK (mark >= 3::numeric AND mark <= 5::numeric)
    "progress_term_check" CHECK (term = 1::numeric OR term = 2::numeric)
Ограничения внешнего ключа:
    "progress_record_book_fkey" FOREIGN KEY (record_book) REFERENCES students(record_book) ON UPDATE CASCADE ON DELETE CASCADE
```

Видим три ограничения: два `CHECK` и один `FOREIGN KEY`.
Добавим в таблицу `progress` атрибут «Форма проверки знаний» (`test_form`):
```SQL
ALTER TABLE progress 
    ADD COLUMN test_form text NOT NULL 
        CHECK(test_form in ('экзамен', 'зачет'));
```

Добавим новое ограничение:
```SQL
ALTER TABLE progress
ADD CHECK (
( test_form = 'экзамен' AND mark IN ( 3, 4, 5 ) )
OR
( test_form = 'зачет' AND mark IN ( 0, 1 ) )
);
```

Сейчас в таблице `progress` есть ограничение `progress_mark_check`
на допустимые значения атрибута `mark`. Оно будет конфликтовать с новым
ограничением, если у студента был зачет и он получил 0 или 1, т.к.
эти числа меньше 3.

Проверим гипотезу:
```SQL
INSERT INTO progress 
VALUES 
(12345, 'Философия', '2023/2024', 2, 1, 'зачет'),
(15796, 'Философия', '2023/2024', 2, 0, 'зачет');
```
Запрос вернул ошибку, мы ввели корректные данные:
```
ОШИБКА:  новая строка в отношении "progress" нарушает ограничение-проверку "progress_mark_check"
ПОДРОБНОСТИ:  Ошибочная строка содержит (12345, Философия, 2023/2024, 2, 1, зачет).
```
Удалим старое ограничение:
```SQL
ALTER TABLE progress 
    DROP CONSTRAINT progress_mark_check ;
```
Теперь предыдущий запрос работает корректно:
```SQL
INSERT INTO progress 
VALUES 
(12345, 'Философия', '2023/2024', 2, 1, 'зачет'),
(15796, 'Философия', '2023/2024', 2, 0, 'зачет');

INSERT 0 2
```
```SQL
SELECT * FROM progress ;

 record_book |     subject      | acad_year | term | mark | test_form 
-------------+------------------+-----------+------+------+-----------
       12345 | Философия        | 2023/2024 |    2 |    1 | зачет
       15796 | Философия        | 2023/2024 |    2 |    0 | зачет
(2 строки)
```

Проверим, как работает новое ограничение в `progress`:
```SQL
INSERT INTO progress 
VALUES 
(12345, 'Линейная алгебра', '2023/2024', 1, 5, 'экзамен'),
(15796, 'Линейная алгебра', '2023/2024', 1, 3, 'экзамен'),
(73548, 'Линейная алгебра', '2023/2024', 1, 2, 'экзамен');
```
```
ОШИБКА:  новая строка в отношении "progress" нарушает ограничение-проверку "progress_check"
ПОДРОБНОСТИ:  Ошибочная строка содержит (73548, Линейная алгебра, 2023/2024, 1, 2, экзамен).
```

```SQL
INSERT INTO progress 
VALUES 
(12345, 'Философия', '2023/2024', 2, 1, 'зачет'),
(15796, 'Философия', '2023/2024', 2, 0, 'зачет'),
(73548, 'Философия', '2023/2024', 2, 5, 'зачет');
```
```
ОШИБКА:  новая строка в отношении "progress" нарушает ограничение-проверку "progress_check"
ПОДРОБНОСТИ:  Ошибочная строка содержит (73548, Философия, 2023/2024, 2, 5, зачет).
```
Все работает корректно.

В качестве еще одного ограничения уровня таблицы можно добавить ограничение
уникальности двух столбцов: `record_book` и `subject`, чтобы не допустить наличия
в таблице одновременно двух и более оценок за один и тот же курс у одного 
студента. Будем считать, что в случае пересдачи в таблице будет вноситься
изменение в существующую строку.

```SQL
ALTER TABLE progress
ADD CONSTRAINT unique_mark UNIQUE (record_book, subject );
```
Посмотрим, как выглядит новое ограничение:
```SQL
\d progress
```
```
                             Таблица "public.progress"
   Столбец   |     Тип      | Правило сортировки | Допустимость NULL | По умолча
нию 
-------------+--------------+--------------------+-------------------+----------
----
 record_book | numeric(5,0) |                    | not null          | 
 subject     | text         |                    | not null          | 
 acad_year   | text         |                    | not null          | 
 term        | numeric(1,0) |                    | not null          | 
 mark        | numeric(1,0) |                    | not null          | 5
 test_form   | text         |                    | not null          | 
Индексы:
    "unique_mark" UNIQUE CONSTRAINT, btree (record_book, subject)
Ограничения-проверки:
    "progress_check" CHECK (test_form = 'экзамен'::text AND (mark = ANY (ARRAY[3
::numeric, 4::numeric, 5::numeric])) OR test_form = 'зачет'::text AND (mark = AN
Y (ARRAY[0::numeric, 1::numeric])))
    "progress_term_check" CHECK (term = 1::numeric OR term = 2::numeric)
    "progress_test_form_check" CHECK (test_form = ANY (ARRAY['экзамен'::text, 'з
ачет'::text]))
Ограничения внешнего ключа:
    "progress_record_book_fkey" FOREIGN KEY (record_book) REFERENCES students(re
cord_book) ON UPDATE CASCADE ON DELETE CASCADE
```
Видим ограничение `unique_mark`, для него был создан индекс.

Протестируем его:
```SQL
INSERT INTO progress 
VALUES 
(12345, 'История', '2022/2023', 2, 1, 'зачет'),
(15796, 'История', '2022/2023', 2, 0, 'зачет'),
(73548, 'История', '2022/2023', 2, 1, 'зачет');
```
Ввели значения в первый раз. Теперь попробуем ввести новую оценку студенту,
который не сдал курс, в следующем семестре:
```SQL
INSERT INTO progress 
VALUES (15796, 'История', '2023/2024', 1, 1, 'зачет');
```
Получили ошибку:
```
ОШИБКА:  повторяющееся значение ключа нарушает ограничение уникальности "unique_mark"
ПОДРОБНОСТИ:  Ключ "(record_book, subject)=(15796, История)" уже существует.
```
Все работает так, как мы хотели!

---
### **Задание 9.** <a name="задание_9"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

В таблице «Студенты» (`students`) есть текстовый атрибут `name`, на который наложено 
ограничение `NOT NULL`. Как вы думаете, что будет, если при вводе новой
строки в эту таблицу дать атрибуту name в качестве значения пустую строку?

Например:
```SQL
INSERT INTO students ( record_book, name, doc_ser, doc_num )
VALUES ( 12300, '', 0402, 543281 );
```

Наверное, проектируя эту таблицу, мы хотели бы все же, чтобы пустые строки
в качестве значения атрибута `name` не проходили в базу данных? Какое 
решение вы можете предложить? 
Видимо, нужно добавить ограничение `CHECK` для
столбца `name`. 

Если вы еще не изучили команду `ALTER TABLE`, то удалите таблицу 
`students` и создайте ее заново с учетом нового ограничения, а если вы уже
познакомились с командой `ALTER TABLE`, то сделайте так:

```SQL
ALTER TABLE students ADD CHECK ( name <> '' );
```

Добавив ограничение, попробуйте теперь вставить в таблицу `students` строку
(`row`), в которой значение атрибута `name` было бы пустой строкой (`string`).
Давайте продолжим эксперименты и предложим в качестве значения атрибута
`name` строку, содержащую сначала один пробел, а потом — два пробела.
```SQL
INSERT INTO students VALUES ( 12346, ' ', 0406, 112233 );
INSERT INTO students VALUES ( 12347, ' ', 0407, 112234 );
```
Для того чтобы «увидеть» эти пробелы в выборке, сделаем так:
```SQL
SELECT *, length( name ) FROM students;
```
Оказывается, эти невидимые значения имеют ненулевую длину. Что делать,
чтобы не допустить таких значений-невидимок? Один из способов: возложить
проверку таких ситуаций на прикладную программу. А что можно сделать на
уровне определения таблицы `students`? Какое ограничение нужно предложить? 

В разделе 9.4 документации «Строковые функции и операторы» есть
функция `trim`. Попробуйте воспользоваться ею. Если вы еще не изучили команду 
`ALTER TABLE`, то удалите таблицу `students` и создайте ее заново с учетом
нового ограничения, а если уже познакомились с ней, то сделайте так:
```SQL
ALTER TABLE students ADD CHECK (...);
```
Есть ли подобные слабые места в таблице «Успеваемость» (progress)?
</details>

Ответ:

Если при ограничении `NOT NULL` ввести в качестве значения атрибута 
`name` пустую строку, команда пройдет и добавит студента с "пустым"
именем:
```SQL
INSERT INTO students ( record_book, name, doc_ser, doc_num )
VALUES ( 12300, '', 0402, 543281 );

select * from students ;

 record_book |          name           | doc_ser | doc_num 
-------------+-------------------------+---------+---------
       12345 | Алексеев Иван Петрович  |    1234 |  567890
       15796 | Петров Василий Иванович |    5423 |  124583
       73548 | Браун Джеймс            |    1111 |  123456
       12300 |                         |     402 |  543281
(4 строки)
```

Удалим запись с пустой строкой и добавим ограничение в таблицу:
```SQL
DELETE from students WHERE name = '' ;
ALTER TABLE students ADD CHECK ( name <> '' );
```
Теперь такая запись не пройдет:
```SQL
INSERT INTO students ( record_book, name, doc_ser, doc_num )
VALUES ( 12300, '', 0402, 543281 );

ОШИБКА:  новая строка в отношении "students" нарушает ограничение-проверку "students_name_check"
ПОДРОБНОСТИ:  Ошибочная строка содержит (12300, , 402, 543281).
```
Но строки с пробелами вместо имени все равно можно будет добавить:
```SQL
INSERT INTO students VALUES ( 12346, ' ', 0406, 112233 );
INSERT INTO students VALUES ( 12347, '  ', 0407, 112234 );
```
Посмотрим на них:
```SQL
SELECT 
    *, 
    length(name),
    length(trim(name))
FROM students;

 record_book |          name           | doc_ser | doc_num | length | length 
-------------+-------------------------+---------+---------+--------+--------
       12345 | Алексеев Иван Петрович  |    1234 |  567890 |     22 |     22
       15796 | Петров Василий Иванович |    5423 |  124583 |     23 |     23
       73548 | Браун Джеймс            |    1111 |  123456 |     12 |     12
       12346 |                         |     406 |  112233 |      1 |      0
       12347 |                         |     407 |  112234 |      2 |      0
(5 строк)
```
Видим длину наших сток из пробелов: 1 и 2.
Чтобы не допустить их добавление, воспользуемся функцией trim, которая
удаляет пробелы слева и справа от строки. Видно, что, если применить
ее к строкам из пробелов, они превратятся в пустые строки, и их
длина будет 0. Перед этим тоже удалим проблемные строки.

```SQL
DELETE from students 
WHERE length(trim(name)) = 0 ;

ALTER TABLE students ADD CHECK ( length(trim(name) ) > 0);
```
Теперь не получится ввести строки без символов даже из большого 
числа пробелов:
```SQL
INSERT INTO students VALUES ( 12346, ' ', 0406, 112233 );
INSERT INTO students VALUES ( 12347, '     ', 0407, 112234 );  

ОШИБКА:  новая строка в отношении "students" нарушает ограничение-проверку "students_name_check1"
ПОДРОБНОСТИ:  Ошибочная строка содержит (12346,  , 406, 112233).
ОШИБКА:  новая строка в отношении "students" нарушает ограничение-проверку "students_name_check1"
ПОДРОБНОСТИ:  Ошибочная строка содержит (12347,      , 407, 112234).
```

Если говорить о таблице «Успеваемость» (progress), она имеет те же
слабые места из-за полей типа `text`: subject, acad_year. У поля test_form
такой проблемы не должно возникнуть, т.к. для него была добавлена проверка
на равенство значению "зачет" или "экзамен".
```SQL
INSERT INTO progress VALUES (12345, '', '', 2, 1, 'зачет');
INSERT INTO progress VALUES (15796, '  ', '   ', 1, 5, 'экзамен');

select *, length(subject), length(acad_year) from progress ;

 record_book | subject | acad_year | term | mark | test_form | length | length 
-------------+---------+-----------+------+------+-----------+--------+--------
       12345 |         |           |    2 |    1 | зачет     |      0 |      0
       15796 |         |           |    1 |    5 | экзамен   |      2 |      3
(2 строки)
```

Конечно, это можно исправить так же, как и выше.

---
### **Задание 17.** <a name="задание_17"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

Представления могут быть, условно говоря, вертикальными и горизонтальными.
При создании вертикального представления в список его столбцов включается
лишь часть столбцов базовой таблицы (таблиц). Например:
```SQL
CREATE VIEW airports_names AS
SELECT airport_code, airport_name, city
FROM airports;
SELECT * FROM airports_names;
```
В горизонтальное представление включаются не все строки базовой таблицы
(таблиц), а производится их отбор с помощью фраз `WHERE` или `HAVING`.
Например:
```SQL
CREATE VIEW siberian_airports AS
SELECT * FROM airports
WHERE city = 'Новосибирск' OR city = 'Кемерово';
SELECT * FROM siberian_airports;
```
Конечно, вполне возможен и смешанный вариант, когда ограничивается как
список столбцов, так и множество строк при создании представления.
Подумайте, какие представления было бы целесообразно создать для нашей
базы данных «Авиаперевозки». Необходимо учесть наличие различных групп
пользователей, например: пилоты, диспетчеры, пассажиры, кассиры.
Создайте представления и проверьте их в работе.
</details>

Ответ:

Моя идея представления, которое могут использовать пилоты и диспетчеры 
аэропорта "Домодедово" - помочь понять, успеют ли они между рейсами
выпить кофе со своими коллегами.

Представление будет брать из таблицы flights сегодняшние рейсы, сортировать
их по возрастанию оставшегося времени и возвращать с числом оставшихся часов.
Быстрого взгляда будет достаточно, чтобы понять, какого пилота или диспетчера
с какого рейса можно позвать на кофе в перерыве.

Поскольку данные в таблице за 2016 год, в качестве "заглушки" я выбрал 
14 окт. 2016 г.
```SQL
CREATE VIEW time_to_flights AS
SELECT 
    flight_no,
    scheduled_departure,
    aircraft_code,
    -- в реальной жизни конкретное время нужно заменить на current_timestamp
    round((EXTRACT(
    EPOCH FROM scheduled_departure - '2016-10-14 14:35:00+03'::timestamptz
    ) / 3600)::numeric(10,4), 2) as hours_to_flight
FROM flights
WHERE departure_airport = 'DME' 
 -- в реальной жизни конкретную дату нужно заменить на current_date
 AND scheduled_departure::date = '2016-10-14'::date
ORDER BY hours_to_flight;

SELECT * FROM time_to_flights WHERE hours_to_flight >= 0;
```
```
 flight_no |  scheduled_departure   | aircraft_code | hours_to_flight 
-----------+------------------------+---------------+-----------------
 PG0368    | 2016-10-14 14:35:00+03 | CR2           |            0.00
 PG0593    | 2016-10-14 14:50:00+03 | CN1           |            0.25
 PG0645    | 2016-10-14 15:05:00+03 | CR2           |            0.50
 PG0657    | 2016-10-14 15:15:00+03 | CR2           |            0.67
 PG0607    | 2016-10-14 15:15:00+03 | CR2           |            0.67
 PG0054    | 2016-10-14 16:05:00+03 | CN1           |            1.50
 PG0289    | 2016-10-14 16:25:00+03 | CR2           |            1.83
 PG0210    | 2016-10-14 17:00:00+03 | 733           |            2.42
 PG0220    | 2016-10-14 17:05:00+03 | 763           |            2.50
 PG0019    | 2016-10-14 17:10:00+03 | CR2           |            2.58
 PG0212    | 2016-10-14 17:20:00+03 | 321           |            2.75
 PG0605    | 2016-10-14 17:40:00+03 | SU9           |            3.08
 PG0404    | 2016-10-14 18:05:00+03 | 321           |            3.50
 PG0416    | 2016-10-14 18:20:00+03 | CR2           |            3.75
 PG0213    | 2016-10-14 18:20:00+03 | 321           |            3.75
 PG0118    | 2016-10-14 18:55:00+03 | SU9           |            4.33
 PG0168    | 2016-10-14 19:05:00+03 | 319           |            4.50
 PG0208    | 2016-10-14 19:40:00+03 | 763           |            5.08
(18 строк)
```
Видим, что рейсы из "Домодедово" действительно отсортированы, начиная с 
2016-10-14 14:35 и до конца дня.

Следующее представление поможет кассирам на регистрации понимать, сколько 
мест в самолете осталось, учитывая число зарегистрированных пассажиров.
Например, это может помочь распределять очереди людей и не выдать посадочных 
талонов больше, чем мест в самолете.

В начале я на основе таблицы seats считаю число мест в каждом самолете, потом
на основе таблиц flights и boarding_passes считаю число зарегистрированных
пассажиров на конкретный рейс, а потом вычитаю максимальное число из текущего.
Единственным ограничением является необходимость вручную вводить flight_id.
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
    aircraft_code,
    count(aircraft_code) as count
from flights
join boarding_passes on flights.flight_id = boarding_passes.flight_id
--join num_seats on flights.aircraft_code = num_seats.aircraft_code
where flights.flight_id = 30625
group by aircraft_code
)
select 
    num_seats.aircraft_code,
    max_num, 
    count as current_seats,
    max_num - count as seats_left
from num_seats
join cur_seats on num_seats.aircraft_code = cur_seats.aircraft_code;
```
```
 aircraft_code | max_num | current_seats | seats_left 
---------------+---------+---------------+------------
 773           |     402 |            92 |        310
```


---
### **Задание 18.** <a name="задание_18"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>
Задание:

Предположим, что нам понадобилось иметь в базе данных сведения о 
технических характеристиках самолетов, эксплуатируемых в авиакомпании. Пусть это
будут такие сведения, как число членов экипажа (пилоты), тип двигателей и их
количество

Следовательно, необходимо добавить новый столбец в таблицу «Самолеты»
(`aircrafts`). Дадим ему имя `specifications`, а в качестве типа данных 
выберем `jsonb`. Если впоследствии потребуется добавить и другие характеристики,
то мы сможем это сделать, не модифицируя определение таблицы.
```SQL
ALTER TABLE aircrafts ADD COLUMN specifications jsonb;
ALTER TABLE
```
Добавим сведения для модели самолета Airbus A320-200:
```SQL
UPDATE aircrafts
    SET specifications =
    '{ "crew": 2,
    "engines": { "type": "IAE V2500",
                "num": 2
                }
    }'::jsonb
WHERE aircraft_code = '320';

UPDATE 1
```
Посмотрим, что получилось:
```SQL
SELECT model, specifications
FROM aircrafts
WHERE aircraft_code = '320';
```
```
      model      |                     specifications                      
-----------------+---------------------------------------------------------
 Airbus A320-200 | {"crew": 2, "engines": {"num": 2, "type": "IAE V2500"}}
(1 строка)
```
Можно посмотреть только сведения о двигателях:
```SQL
SELECT model, specifications->'engines' AS engines
FROM aircrafts
WHERE aircraft_code = '320';
```
```
      model      |             engines             
-----------------+---------------------------------
 Airbus A320-200 | {"num": 2, "type": "IAE V2500"}
(1 строка)
```
Чтобы получить еще более детальные сведения, например, о типе двигателей,
нужно учитывать, что созданный JSON-объект имеет сложную структуру: он 
содержит вложенный JSON-объект. Поэтому нужно использовать оператор `#>` для
указания пути доступа к ключу второго уровня.
```SQL
SELECT model, specifications #> '{ engines, type }'
FROM aircrafts
WHERE aircraft_code = '320';
```
```
WHERE aircraft_code = '320';
      model      |  ?column?   
-----------------+-------------
 Airbus A320-200 | "IAE V2500"
(1 строка)
```
**Задание**. Подумайте, какие еще таблицы было бы целесообразно дополнить
столбцами типа json/jsonb. Вспомните, что, например, в таблице «Билеты»
(`tickets`) уже есть столбец такого типа `contact_data`. Выполните 
модификации таблиц и измените в них одну-две строки для проверки правильности
ваших решений.
</details>

1. Предлагаю в таблицу `airports` добавить поле типа `jsonb`, которое
будет описывать различные условия, имеющиеся есть в аэропорте, которые
часто интересны пассажирам: DutyFree, WiFi, площадь аэропорта.
```SQL
ALTER TABLE airports ADD COLUMN conditions jsonb;
```
Добавим сведения для модели самолета Airbus A320-200:
```SQL
UPDATE airports
    SET conditions =
    '{ "WiFi": "free",
    "facilities": { "DutyFree": ["alcohol", "perfume", "watches", "jewelry"],
                    "kids_area": true
                     },
    "square": 10000
    }'::jsonb
WHERE airport_code = 'VKO';

UPDATE airports
    SET conditions =
    '{ "WiFi": "paid",
    "facilities": { "DutyFree": ["alcohol", "perfume"],
                    "kids_area": false
                     },
    "square": 1500
    }'::jsonb
WHERE airport_code = 'MRV';

select airport_name, city, conditions from airports 
where airport_code in ('VKO', 'MRV');
```
```
   airport_name   |       city       |                                                           
conditions                                                           
------------------+------------------+-----------------------------------------------------------
---------------------------------------------------------------------
 Внуково          | Москва           | {"WiFi": "free", "square": 10000, "facilities": {"DutyFree
": ["alcohol", "perfume", "watches", "jewelry"], "kids_area": true}}
 Минеральные Воды | Минеральные Воды | {"WiFi": "paid", "square": 1500, "facilities": {"DutyFree"
: ["alcohol", "perfume"], "kids_area": false}}
(2 строки)
```
Посмотрим только на значения по ключу `facilities`:
```SQL
select airport_name, conditions->'facilities' from airports where airport_code in ('VKO', 'MRV')
;
   airport_name   |                                   ?column?                                   
 
------------------+------------------------------------------------------------------------------
-
 Внуково          | {"DutyFree": ["alcohol", "perfume", "watches", "jewelry"], "kids_area": true}
 Минеральные Воды | {"DutyFree": ["alcohol", "perfume"], "kids_area": false}
(2 строки)
```

2. Хотя в таблице `tickets` уже есть поле типа `jsonb`, предлагаю добавить 
поле `tariff` типа `jsonb`, 
в котором будет указываться доп. информация о тарифе, выбранном пассажиром,
например, включена ли еда, дополнительный багаж (и какой) и т.д.
```SQL
ALTER TABLE tickets ADD COLUMN tariff jsonb;
```
Добавим пару примеров:
```SQL
UPDATE tickets
    SET tariff =
    '{ "extra_luggage": { "pets": 2, "extra_kilos": 10 },
    "additional": { "food": ["tea", "infant food"]},
    "babies": true
    }'::jsonb
WHERE ticket_no = '0005432000988';

UPDATE tickets
    SET tariff =
    '{ "extra_luggage": { "extra_kilos": 15, "ski": true },
    "additional": { "food": ["alcohol"]},
    "babies": false
    }'::jsonb
WHERE ticket_no = '0005432000991';

select passenger_name, tariff from tickets 
where ticket_no in ('0005432000988', '0005432000991');
```
```
   passenger_name   |                                                      tariff                
                                       
--------------------+----------------------------------------------------------------------------
---------------------------------------
 EVGENIYA ALEKSEEVA | {"babies": true, "additional": {"food": ["tea", "infant food"]}, "extra_lug
gage": {"pets": 2, "extra_kilos": 10}}
 MAKSIM ZHUKOV      | {"babies": false, "additional": {"food": ["alcohol"]}, "extra_luggage": {"s
ki": true, "extra_kilos": 15}}
(2 строки)
```
Сейчас здесь много информации, выведем инфо только про доп. багаж пассажиров:
```SQL
select passenger_name, tariff-> 'extra_luggage' from tickets 

where ticket_no in ('0005432000988', '0005432000991');
   passenger_name   |             ?column?             
--------------------+----------------------------------
 EVGENIYA ALEKSEEVA | {"pets": 2, "extra_kilos": 10}
 MAKSIM ZHUKOV      | {"ski": true, "extra_kilos": 15}
(2 строки)
```

3. Еще предлагаю в таблицу `bookings` добавить поле `payment_info` типа `jsonb`, 
в котором будет представлена информация об оплате бронирования. Это может 
пригодиться в целях аналитики: как чаще всего клиенты оплачивают 
бронирования в нашем сервисе, и как это связано с суммой заказа.
```SQL
ALTER TABLE bookings ADD COLUMN payment_info jsonb;
```
Несколько примеров:
```SQL
UPDATE bookings
    SET payment_info =
    '{ "payment_type": "cash",
    "book_type": {"online": "phone"}
    }'::jsonb
WHERE book_ref = '000012';

UPDATE bookings
    SET payment_info =
    '{ "payment_type": "card",
    "book_type": {"offline": "ticket_office"}
    }'::jsonb
WHERE book_ref = '000181';

select book_ref, total_amount, payment_info from bookings 
where book_ref in ('000012', '000181');
```
```
 book_ref | total_amount |                            payment_info                             
----------+--------------+---------------------------------------------------------------------
 000012   |     37900.00 | {"book_type": {"online": "phone"}, "payment_type": "cash"}
 000181   |    131800.00 | {"book_type": {"offline": "ticket_office"}, "payment_type": "card"}
(2 строки)
```
Получилось успешно.

---