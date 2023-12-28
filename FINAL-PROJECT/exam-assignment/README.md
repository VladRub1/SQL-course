## 👨🏻‍💻 Экзаменационное задание

Содержание:
1. [Задание 1.](#задание_1)

### **Задание 1.** <a name="задание_1"></a>

<details>
<summary>🔽 Развернуть задание 🔽</summary>

**Задание**:

Необходимо смоделировать следующую модель начисления заработной платы сотрудникам.

Форма начисления зарплаты работникам банка: сотруднику выдается кредит под более низкий процент, 
чем другим заемщикам. Эти деньги помещаются на депозит по более выгодной процентной ставке. 
В качестве зарплаты выплачивается разница между платежом по кредиту и процентами по депозиту за месяц.
</details>

**Ответ**:

Поскольку подобная схема выплаты заработной платы изначально не учитывалась в моей
базе данных, в таблице `personnel` есть ограничение на столбец `salary`: он не может быть
`NULL` и должен быть больше `0`.
Поэтому я предлагаю реализовать несколько измененную схему выплаты зарплаты:
* сотруднику назначается некоторая (небольшая) базовая ставка з/п;
* банк увеличивает эту ставку в 100 раз, открывает на эту сумму кредит и депозит, как
  описано в задании;
* в качестве финального оклада банк выплачивает сотруднику в месяц базовый оклад +
  разницу между платежом по кредиту и процентами по депозиту за месяц.

Также напомню, что в изначальном варианте БД есть ограничение: нет связи между
таблицей сотрудников и клиентов (не предполагается, что сотрудники являются клиентами 
банка). 

Для реализации предложенной схемы оплаты труда мне нужно внести в таблицу  
`bank.personnel` изменение: добавить поле `client_id`, которое будет внешним ключом 
от таблицы `bank.clients` (пускай оно может быть `NULL` -- допустим, не все сотрудники
обязаны быть клиентами банка).
Также важно отметить, что тогда нарушится текущее отношение нормальной формы, 
в которой находятся `bank.personnel` и `bank.clients`, поскольку и там, и там
будет дублироваться имя и фамилия клиента, если он работает в банке. Это можно
устранить, но данный вопрос выходит за рамки этого задания.

Итак, я вношу изменения в таблицу `bank.personnel`:
```SQL
ALTER TABLE bank.personnel
ADD COLUMN client_id INT;

ALTER TABLE bank.personnel
ADD CONSTRAINT fk_personnel_client
FOREIGN KEY (client_id)
REFERENCES bank.clients (client_id);
```
Далее я добавляю два новых сотрудника в московское отделение с `branch_id = 1`.
Представим, что они устроились в банк 1 января 2023 г. (представим, что в 
таблице `bank.personnel` указаны служебные контактные данные, а в `bank.clients` -- личные). 
Как говорилось выше, сделаем их базовые ставки небольшими: 10 и 30 тысяч рублей:
```SQL
INSERT INTO bank.personnel (branch_id, name, position, contact_info, salary, client_id)
VALUES 
    (1, 'Алексей Иванов', 'Аналитик', '{"email": "ivanov@example.com", "phone": "+7 900 123 45 67"}', 10000, null),
    (1, 'Сергей Васильев', 'Программист', '{"email": "vasiliev@example.com", "phone": "+7 945 656 44 75"}', 30000, null);
```
Далее они сразу же стали клиентами банка:
```SQL
INSERT INTO bank.clients (name, address, passport, inn, phone, contact_info, client_type, status)
VALUES 
('Алексей Иванов', 'г. Москва, ул. Советская, д. 1', '7001 339789', '732281269254', '+75594796081', '{"email": "alex@example.com", "telegram": "@example"}', 'физическое лицо', 'активный'),
('Сергей Васильев', 'г. Москва, пр. Мира, д. 56', '7149 213887', '191988124126', '+79905204138', '{"email": "sergey@example.com", "telegram": "@example"}', 'физическое лицо', 'активный');
```
Укажем в таблице `bank.personnel` новые `client_id` для этих двух сотрудников 
(до этого я добавил 100 клиентов и 300 сотрудников, следовательно, они будут 101 и 102 клиентами 
и 301 и 302 сотрудником):
```SQL
UPDATE bank.personnel
SET client_id = 101
WHERE employee_id = 301;

UPDATE bank.personnel
SET client_id = 102
WHERE employee_id = 302;
```
Посмотрим, как они выглядят в таблице `bank.personnel`:
```SQL
SELECT employee_id, branch_id, name, position, salary, client_id  FROM personnel WHERE employee_id > 300 ;

 employee_id | branch_id |      name       |  position   |  salary  | client_id 
-------------+-----------+-----------------+-------------+----------+-----------
         301 |         1 | Алексей Иванов  | Аналитик    | 10000.00 |       101
         302 |         1 | Сергей Васильев | Программист | 30000.00 |       102
(2 строки)
```
Теперь "выдадим" новым сотрудникам кредит, в 100 раз превышающий их базовую ставку 
(здесь и далее я буду доставать базовую ставку через подзапрос, зная `client_id` новых
сотрудников в целях удобства и для разграничения доступа к чувствительным данным о 
зарплатах). Выдадим льготный кредит под 3% годовых, также укажем в `terms`,
что это кредит сотруднику:
```SQL
INSERT INTO bank.loans (client_id, amount, interest_rate, issue_date, maturity_date, status, terms)
VALUES 
    (101, (SELECT salary FROM bank.personnel WHERE client_id = 101) * 100, 
        0.03, '2023-01-01', '2024-01-01', 'активен', 'Кредит сотруднику'),
    (102, (SELECT salary FROM bank.personnel WHERE client_id = 102) * 100, 
        0.03, '2023-01-01', '2024-01-01', 'активен', 'Кредит сотруднику');
```
Теперь выдадим на ту же сумму депозит. Для определения суммы депозита я сделаю подзапрос,
как и для `loan_id`. Выдадим депозит под льготную ставку 23% годовых.
Функция `MAX` используется, чтобы взять последний кредит, который есть на этого сотрудника 
и который только что был выдан (вдруг у сотрудника есть еще другие кредиты):
```SQL
INSERT INTO bank.deposits (client_id, cur_id, issue_date, amount, interest_rate, maturity_date, status)
VALUES 
    (101, 643, '2023-01-01', 
     (SELECT amount FROM bank.loans WHERE loan_id = (SELECT max(loan_id) FROM bank.loans WHERE client_id = 101)), 
     0.23, '2024-01-01', 'активен'),
    (102, 643, '2023-01-01', 
     (SELECT amount FROM bank.loans WHERE loan_id = (SELECT max(loan_id) FROM bank.loans WHERE client_id = 102)), 
     0.23, '2024-01-01', 'активен');
```
Посмотрим на открытые депозиты:
```SQL
SELECT * FROM deposits WHERE deposit_id > 500 ;

 deposit_id | client_id | cur_id | issue_date |    amount    | interest_rate | maturity_date | status  
------------+-----------+--------+------------+--------------+---------------+---------------+---------
        501 |       101 |    643 | 2023-01-01 | 1000000.0000 |      0.230000 | 2024-01-01    | активен
        502 |       102 |    643 | 2023-01-01 | 3000000.0000 |      0.230000 | 2024-01-01    | активен
(2 строки)
```
Далее посчитаем, какую зарплату должен получить каждый из двух новых сотрудников
в январе 2023 г. Процентный расход на кредит и доход от депозита я буду считать 
как ((сумма кредита или депозита * годовая ставка) / число дней в году) * число дней в нужном месяце.

Первый новый сотрудник с базовым окладом `10000`:
```SQL
WITH credit_details AS (
    SELECT 
        loan.client_id,
        (loan.amount * loan.interest_rate / 365) AS daily_interest
    FROM bank.loans loan
    WHERE loan.client_id = 101
),
deposit_details AS (
    SELECT 
        deposit.client_id,
        (deposit.amount * deposit.interest_rate / 365) AS daily_interest
    FROM bank.deposits deposit
    WHERE deposit.client_id = 101
)
SELECT 
    (SELECT SUM(daily_interest) FROM deposit_details) * 
    (EXTRACT(day FROM AGE(DATE '2023-01-31', DATE '2023-01-01')) + 1) - 
    (SELECT SUM(daily_interest) FROM credit_details) * 
    (EXTRACT(day FROM AGE(DATE '2023-01-31', DATE '2023-01-01')) + 1) + 
    (SELECT salary FROM bank.personnel WHERE personnel.client_id = 101) AS net_income;
```
Результат:
```
   net_income    
-----------------
 26986.301369863
(1 строка)
```

Второй новый сотрудник с базовым окладом `30000`:
```SQL
WITH credit_details AS (
    SELECT 
        loan.client_id,
        (loan.amount * loan.interest_rate / 365) AS daily_interest
    FROM bank.loans loan
    WHERE loan.client_id = 102
),
deposit_details AS (
    SELECT 
        deposit.client_id,
        (deposit.amount * deposit.interest_rate / 365) AS daily_interest
    FROM bank.deposits deposit
    WHERE deposit.client_id = 102
)
SELECT 
    (SELECT SUM(daily_interest) FROM deposit_details) * 
    (EXTRACT(day FROM AGE(DATE '2023-01-31', DATE '2023-01-01')) + 1) - 
    (SELECT SUM(daily_interest) FROM credit_details) * 
    (EXTRACT(day FROM AGE(DATE '2023-01-31', DATE '2023-01-01')) + 1) + 
    (SELECT salary FROM bank.personnel WHERE personnel.client_id = 102) AS net_income;
```
Результат:
```
   net_income    
-----------------
 80958.904109589
(1 строка)
```

Видим, что с таким алгоритмом подсчета оклада первый сотрудник должен был бы
получить примерно 26986 рублей за январь 2023 г., а второй -- 80959 рублей.
В реальной жизни можно было бы сделать более удобные функции, которые
сами бы рассчитывали нужную сумму в зависимости от месяца.

---
