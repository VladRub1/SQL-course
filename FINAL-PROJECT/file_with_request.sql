-- Вывод первой большой транзакции клиента (от 10 тыс. рублей) и признака,
-- получал ли он чьи-то первые большие транзакции
WITH transactions_in_rubles AS (
    SELECT 
        t.transaction_id,
        t.prpl_account_num,
        t.bene_account_num,
        t.amount * dr.rate AS amount_in_rubles,
        a.client_id,
        t.date
    FROM 
        bank.transactions t
    JOIN 
        bank.accounts a ON t.prpl_account_num = a.account_num
    LEFT JOIN 
        bank.daily_rates dr ON t.cur_id = dr.cur_id AND dr.date = t.date
),
ranked_transactions AS (
    SELECT 
        tr.transaction_id,
        tr.prpl_account_num,
        tr.bene_account_num,
        tr.amount_in_rubles,
        tr.client_id,
        ROW_NUMBER() OVER (PARTITION BY tr.client_id ORDER BY tr.date, tr.transaction_id) AS rn
    FROM 
        transactions_in_rubles tr
    WHERE 
        tr.amount_in_rubles > 10000
),
first_large_transactions AS (
    SELECT 
        rt.transaction_id,
        rt.prpl_account_num,
        rt.bene_account_num,
        rt.amount_in_rubles,
        rt.client_id
    FROM 
        ranked_transactions rt
    WHERE 
        rt.rn = 1
),
final_pre AS 
(
    SELECT 
        flt.transaction_id,
        flt.prpl_account_num,
        flt.bene_account_num,
        flt.amount_in_rubles,
        flt.client_id,
        (SELECT COUNT(*)
        FROM bank.transactions t
        JOIN bank.accounts a ON t.bene_account_num = a.account_num
        WHERE a.client_id = flt.client_id AND t.prpl_account_num = flt.bene_account_num) AS transactions_as_beneficiary
    FROM 
        first_large_transactions flt
)
SELECT * 
FROM final_pre
WHERE transactions_as_beneficiary > 0;


-- Топ-10 клиентов по общему объему транзакций за последний месяц
WITH monthly_transactions AS (
    SELECT 
        a.client_id,
        SUM(t.amount) AS total_amount
    FROM 
        bank.transactions t
    JOIN 
        bank.accounts a ON t.prpl_account_num = a.account_num
    WHERE 
        t.date BETWEEN '2023-11-01' AND '2023-11-30'
    GROUP BY 
        a.client_id
),
ranked_clients AS (
    SELECT 
        mt.client_id,
        mt.total_amount,
        RANK() OVER (ORDER BY mt.total_amount DESC) AS rank
    FROM 
        monthly_transactions mt
),
total_transaction_volume AS (
    SELECT 
        SUM(total_amount) AS total_volume
    FROM 
        ranked_clients
)
SELECT 
    rc.client_id,
    c.name,
    rc.total_amount,
    rc.rank,
    (rc.total_amount / ttv.total_volume) * 100 AS percentage_of_total
FROM 
    ranked_clients rc
CROSS JOIN 
    total_transaction_volume ttv
JOIN 
    bank.clients c ON rc.client_id = c.client_id
WHERE 
    rc.rank <= 10
ORDER BY 
    rc.total_amount DESC;
