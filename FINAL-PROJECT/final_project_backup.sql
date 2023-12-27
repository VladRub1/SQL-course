--
-- PostgreSQL database dump
--

-- Dumped from database version 10.22
-- Dumped by pg_dump version 10.22

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: bank; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA bank;


ALTER SCHEMA bank OWNER TO postgres;

--
-- Name: SCHEMA bank; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA bank IS 'Банк "RuBank"';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: calculate_deposit_interests_on_date(date); Type: FUNCTION; Schema: bank; Owner: postgres
--

CREATE FUNCTION bank.calculate_deposit_interests_on_date(on_date date) RETURNS TABLE(deposit_id integer, calculated_interest numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    days_interval INT;
BEGIN
    RETURN QUERY
    SELECT d.deposit_id, 
           (d.amount * d.interest_rate / 100 / 365 * 
           (on_date - d.issue_date)) AS calculated_interest
    FROM bank.deposits d
    WHERE d.issue_date <= on_date AND d.maturity_date > on_date;
END;
$$;


ALTER FUNCTION bank.calculate_deposit_interests_on_date(on_date date) OWNER TO postgres;

--
-- Name: calculate_total_balance_in_rubles(integer); Type: FUNCTION; Schema: bank; Owner: postgres
--

CREATE FUNCTION bank.calculate_total_balance_in_rubles(client_id_param integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_balance_rubles DECIMAL(20,4) := 0;
    account_balance DECIMAL(20,4);
    exchange_rate DECIMAL(20,6);
BEGIN
    FOR account_balance, exchange_rate IN
        SELECT a.balance, COALESCE(r.rate, 1)
        FROM bank.accounts a
        LEFT JOIN bank.daily_rates r ON a.cur_id = r.cur_id AND r.date = '2023-12-25'
        WHERE a.client_id = client_id_param AND a.status = 'открыт'
    LOOP
        total_balance_rubles := total_balance_rubles + (account_balance * exchange_rate);
    END LOOP;
    
    RETURN total_balance_rubles;
END;
$$;


ALTER FUNCTION bank.calculate_total_balance_in_rubles(client_id_param integer) OWNER TO postgres;

--
-- Name: check_account_balance(); Type: FUNCTION; Schema: bank; Owner: postgres
--

CREATE FUNCTION bank.check_account_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.status = 'открыт' AND NEW.status = 'закрыт' AND OLD.balance > 0 THEN
        RAISE EXCEPTION 'Невозможно закрыть счет с положительным балансом';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION bank.check_account_balance() OWNER TO postgres;

--
-- Name: update_loan_status(); Type: FUNCTION; Schema: bank; Owner: postgres
--

CREATE FUNCTION bank.update_loan_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.maturity_date < CURRENT_DATE AND NEW.status != 'закрыт' THEN
        NEW.status := 'просрочен';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION bank.update_loan_status() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: accounts; Type: TABLE; Schema: bank; Owner: postgres
--

CREATE TABLE bank.accounts (
    account_num character varying(34) NOT NULL,
    client_id integer NOT NULL,
    cur_id smallint NOT NULL,
    issue_date date NOT NULL,
    balance numeric(20,4) NOT NULL,
    status text NOT NULL,
    close_date date,
    CONSTRAINT accounts_balance_check CHECK ((balance >= (0)::numeric)),
    CONSTRAINT accounts_status_check CHECK ((status = ANY (ARRAY['открыт'::text, 'закрыт'::text])))
);


ALTER TABLE bank.accounts OWNER TO postgres;

--
-- Name: TABLE accounts; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON TABLE bank.accounts IS 'Таблица содержит информацию о счетах клиентов, включая баланс и статус счета.';


--
-- Name: COLUMN accounts.account_num; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.accounts.account_num IS 'Уникальный номер счета';


--
-- Name: COLUMN accounts.client_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.accounts.client_id IS 'Идентификатор клиента, владельца счета';


--
-- Name: COLUMN accounts.cur_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.accounts.cur_id IS 'Идентификатор валюты счета';


--
-- Name: COLUMN accounts.issue_date; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.accounts.issue_date IS 'Дата открытия счета';


--
-- Name: COLUMN accounts.balance; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.accounts.balance IS 'Текущий баланс счета';


--
-- Name: COLUMN accounts.status; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.accounts.status IS 'Статус счета (активный, закрытый и т.д.)';


--
-- Name: COLUMN accounts.close_date; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.accounts.close_date IS 'Дата закрытия счета';


--
-- Name: banks_cors; Type: TABLE; Schema: bank; Owner: postgres
--

CREATE TABLE bank.banks_cors (
    cur_id smallint NOT NULL,
    swift_code character varying(11) NOT NULL,
    name character varying(50) NOT NULL,
    address character varying(100) NOT NULL,
    contact_info jsonb NOT NULL
);


ALTER TABLE bank.banks_cors OWNER TO postgres;

--
-- Name: TABLE banks_cors; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON TABLE bank.banks_cors IS 'Таблица содержит информацию о банках-корреспондентах, используемых для международных транзакций.';


--
-- Name: COLUMN banks_cors.swift_code; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.banks_cors.swift_code IS 'SWIFT код банка-корреспондента';


--
-- Name: COLUMN banks_cors.name; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.banks_cors.name IS 'Название банка-корреспондента';


--
-- Name: COLUMN banks_cors.address; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.banks_cors.address IS 'Адрес банка-корреспондента';


--
-- Name: COLUMN banks_cors.contact_info; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.banks_cors.contact_info IS 'Контактная информация банка-корреспондента в формате JSON';


--
-- Name: branches; Type: TABLE; Schema: bank; Owner: postgres
--

CREATE TABLE bank.branches (
    branch_id smallint NOT NULL,
    head smallint NOT NULL,
    address text NOT NULL,
    region text NOT NULL,
    phone text NOT NULL
);


ALTER TABLE bank.branches OWNER TO postgres;

--
-- Name: TABLE branches; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON TABLE bank.branches IS 'Таблица содержит информацию об отделениях банка, включая их адреса и контактные данные.';


--
-- Name: COLUMN branches.branch_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.branches.branch_id IS 'Уникальный идентификатор отделения';


--
-- Name: COLUMN branches.head; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.branches.head IS 'Идентификатор руководителя отделения';


--
-- Name: COLUMN branches.address; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.branches.address IS 'Адрес отделения';


--
-- Name: COLUMN branches.region; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.branches.region IS 'Регион, в котором находится отделение';


--
-- Name: COLUMN branches.phone; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.branches.phone IS 'Контактный телефон отделения';


--
-- Name: clients; Type: TABLE; Schema: bank; Owner: postgres
--

CREATE TABLE bank.clients (
    client_id integer NOT NULL,
    name text NOT NULL,
    address text NOT NULL,
    passport character varying(11) NOT NULL,
    inn character varying(12) NOT NULL,
    phone text NOT NULL,
    contact_info jsonb,
    client_type text NOT NULL,
    status text NOT NULL,
    CONSTRAINT clients_client_type_check CHECK ((client_type = ANY (ARRAY['физическое лицо'::text, 'юридическое лицо'::text]))),
    CONSTRAINT clients_status_check CHECK ((status = ANY (ARRAY['активный'::text, 'неактивный'::text])))
);


ALTER TABLE bank.clients OWNER TO postgres;

--
-- Name: TABLE clients; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON TABLE bank.clients IS 'Таблица содержит информацию о клиентах банка, включая их личные данные и статус.';


--
-- Name: COLUMN clients.client_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.clients.client_id IS 'Уникальный идентификатор клиента';


--
-- Name: COLUMN clients.name; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.clients.name IS 'Имя клиента';


--
-- Name: COLUMN clients.address; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.clients.address IS 'Адрес проживания клиента';


--
-- Name: COLUMN clients.passport; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.clients.passport IS 'Номер паспорта клиента';


--
-- Name: COLUMN clients.inn; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.clients.inn IS 'ИНН клиента';


--
-- Name: COLUMN clients.phone; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.clients.phone IS 'Контактный телефон клиента';


--
-- Name: COLUMN clients.contact_info; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.clients.contact_info IS 'Контактная информация в формате JSON';


--
-- Name: COLUMN clients.client_type; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.clients.client_type IS 'Тип клиента (физическое или юридическое лицо)';


--
-- Name: COLUMN clients.status; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.clients.status IS 'Статус клиента (активный или неактивный)';


--
-- Name: clients_client_id_seq; Type: SEQUENCE; Schema: bank; Owner: postgres
--

CREATE SEQUENCE bank.clients_client_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bank.clients_client_id_seq OWNER TO postgres;

--
-- Name: clients_client_id_seq; Type: SEQUENCE OWNED BY; Schema: bank; Owner: postgres
--

ALTER SEQUENCE bank.clients_client_id_seq OWNED BY bank.clients.client_id;


--
-- Name: daily_rates; Type: TABLE; Schema: bank; Owner: postgres
--

CREATE TABLE bank.daily_rates (
    cur_id smallint NOT NULL,
    date date NOT NULL,
    cur_name character varying(3),
    rate_source character varying(4),
    rate numeric(20,6),
    CONSTRAINT daily_rates_rate_check CHECK ((rate > (0)::numeric))
);


ALTER TABLE bank.daily_rates OWNER TO postgres;

--
-- Name: TABLE daily_rates; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON TABLE bank.daily_rates IS 'Таблица содержит информацию о курсах валют на каждый день, используемых для конвертации в транзакциях.';


--
-- Name: COLUMN daily_rates.cur_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.daily_rates.cur_id IS 'Идентификатор валюты';


--
-- Name: COLUMN daily_rates.date; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.daily_rates.date IS 'Дата, на которую указан курс';


--
-- Name: COLUMN daily_rates.cur_name; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.daily_rates.cur_name IS 'Название валюты';


--
-- Name: COLUMN daily_rates.rate_source; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.daily_rates.rate_source IS 'Источник информации о курсе';


--
-- Name: COLUMN daily_rates.rate; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.daily_rates.rate IS 'Курс валюты';


--
-- Name: deposits; Type: TABLE; Schema: bank; Owner: postgres
--

CREATE TABLE bank.deposits (
    deposit_id integer NOT NULL,
    client_id integer NOT NULL,
    cur_id smallint NOT NULL,
    issue_date date NOT NULL,
    amount numeric(20,4) NOT NULL,
    interest_rate numeric(10,6) NOT NULL,
    maturity_date date NOT NULL,
    status text NOT NULL,
    CONSTRAINT deposits_amount_check CHECK ((amount > (0)::numeric))
);


ALTER TABLE bank.deposits OWNER TO postgres;

--
-- Name: TABLE deposits; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON TABLE bank.deposits IS 'Таблица содержит информацию о депозитных счетах клиентов, включая сумму, срок и процентную ставку.';


--
-- Name: COLUMN deposits.deposit_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.deposits.deposit_id IS 'Уникальный идентификатор депозита';


--
-- Name: COLUMN deposits.client_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.deposits.client_id IS 'Идентификатор клиента, открывшего депозит';


--
-- Name: COLUMN deposits.cur_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.deposits.cur_id IS 'Идентификатор валюты депозита';


--
-- Name: COLUMN deposits.issue_date; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.deposits.issue_date IS 'Дата открытия депозита';


--
-- Name: COLUMN deposits.amount; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.deposits.amount IS 'Сумма депозита';


--
-- Name: COLUMN deposits.interest_rate; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.deposits.interest_rate IS 'Процентная ставка по депозиту';


--
-- Name: COLUMN deposits.maturity_date; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.deposits.maturity_date IS 'Дата окончания депозита';


--
-- Name: COLUMN deposits.status; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.deposits.status IS 'Статус депозита';


--
-- Name: deposits_deposit_id_seq; Type: SEQUENCE; Schema: bank; Owner: postgres
--

CREATE SEQUENCE bank.deposits_deposit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bank.deposits_deposit_id_seq OWNER TO postgres;

--
-- Name: deposits_deposit_id_seq; Type: SEQUENCE OWNED BY; Schema: bank; Owner: postgres
--

ALTER SEQUENCE bank.deposits_deposit_id_seq OWNED BY bank.deposits.deposit_id;


--
-- Name: loans; Type: TABLE; Schema: bank; Owner: postgres
--

CREATE TABLE bank.loans (
    loan_id integer NOT NULL,
    client_id integer NOT NULL,
    amount numeric(20,4) NOT NULL,
    interest_rate numeric(10,6) NOT NULL,
    issue_date date NOT NULL,
    maturity_date date NOT NULL,
    status text NOT NULL,
    terms text,
    CONSTRAINT loans_amount_check CHECK ((amount > (0)::numeric))
);


ALTER TABLE bank.loans OWNER TO postgres;

--
-- Name: TABLE loans; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON TABLE bank.loans IS 'Таблица содержит информацию о кредитах, выданных клиентам, включая условия, сумму и статус кредита.';


--
-- Name: COLUMN loans.loan_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.loans.loan_id IS 'Уникальный идентификатор кредита';


--
-- Name: COLUMN loans.client_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.loans.client_id IS 'Идентификатор клиента, получившего кредит';


--
-- Name: COLUMN loans.amount; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.loans.amount IS 'Сумма кредита';


--
-- Name: COLUMN loans.interest_rate; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.loans.interest_rate IS 'Процентная ставка по кредиту';


--
-- Name: COLUMN loans.issue_date; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.loans.issue_date IS 'Дата выдачи кредита';


--
-- Name: COLUMN loans.maturity_date; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.loans.maturity_date IS 'Дата погашения кредита';


--
-- Name: COLUMN loans.status; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.loans.status IS 'Статус кредита';


--
-- Name: COLUMN loans.terms; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.loans.terms IS 'Условия кредитования';


--
-- Name: loans_loan_id_seq; Type: SEQUENCE; Schema: bank; Owner: postgres
--

CREATE SEQUENCE bank.loans_loan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bank.loans_loan_id_seq OWNER TO postgres;

--
-- Name: loans_loan_id_seq; Type: SEQUENCE OWNED BY; Schema: bank; Owner: postgres
--

ALTER SEQUENCE bank.loans_loan_id_seq OWNED BY bank.loans.loan_id;


--
-- Name: personnel; Type: TABLE; Schema: bank; Owner: postgres
--

CREATE TABLE bank.personnel (
    employee_id integer NOT NULL,
    branch_id smallint NOT NULL,
    name text NOT NULL,
    "position" text NOT NULL,
    contact_info jsonb NOT NULL,
    salary numeric(10,2) NOT NULL,
    CONSTRAINT personnel_salary_check CHECK ((salary > (0)::numeric))
);


ALTER TABLE bank.personnel OWNER TO postgres;

--
-- Name: TABLE personnel; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON TABLE bank.personnel IS 'Таблица содержит данные о сотрудниках банка, включая их должности, контактную информацию и зарплату.';


--
-- Name: COLUMN personnel.employee_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.personnel.employee_id IS 'Уникальный идентификатор сотрудника';


--
-- Name: COLUMN personnel.branch_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.personnel.branch_id IS 'Идентификатор отделения, в котором работает сотрудник';


--
-- Name: COLUMN personnel.name; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.personnel.name IS 'Имя сотрудника';


--
-- Name: COLUMN personnel."position"; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.personnel."position" IS 'Должность сотрудника';


--
-- Name: COLUMN personnel.contact_info; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.personnel.contact_info IS 'Контактная информация сотрудника в формате JSON';


--
-- Name: COLUMN personnel.salary; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.personnel.salary IS 'Зарплата сотрудника';


--
-- Name: personnel_employee_id_seq; Type: SEQUENCE; Schema: bank; Owner: postgres
--

CREATE SEQUENCE bank.personnel_employee_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bank.personnel_employee_id_seq OWNER TO postgres;

--
-- Name: personnel_employee_id_seq; Type: SEQUENCE OWNED BY; Schema: bank; Owner: postgres
--

ALTER SEQUENCE bank.personnel_employee_id_seq OWNED BY bank.personnel.employee_id;


--
-- Name: transactions; Type: TABLE; Schema: bank; Owner: postgres
--

CREATE TABLE bank.transactions (
    transaction_id integer NOT NULL,
    prpl_account_num character varying(34) NOT NULL,
    cur_id smallint NOT NULL,
    date date NOT NULL,
    bene_account_num character varying(34) NOT NULL,
    type text NOT NULL,
    amount numeric(20,4) NOT NULL,
    commission numeric(14,4) NOT NULL,
    status text NOT NULL,
    bank_cor_swift character varying(11),
    CONSTRAINT transactions_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT transactions_commission_check CHECK ((commission >= (0)::numeric)),
    CONSTRAINT transactions_status_check CHECK ((status = ANY (ARRAY['отправлена'::text, 'доставлена'::text, 'отменена'::text]))),
    CONSTRAINT transactions_type_check CHECK ((type = ANY (ARRAY['внутренняя'::text, 'международная'::text])))
);


ALTER TABLE bank.transactions OWNER TO postgres;

--
-- Name: TABLE transactions; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON TABLE bank.transactions IS 'Таблица содержит записи о транзакциях, осуществленных клиентами, включая тип и сумму транзакции.';


--
-- Name: COLUMN transactions.transaction_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.transaction_id IS 'Уникальный идентификатор транзакции';


--
-- Name: COLUMN transactions.prpl_account_num; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.prpl_account_num IS 'Номер счета отправителя (принципала)';


--
-- Name: COLUMN transactions.cur_id; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.cur_id IS 'Идентификатор валюты транзакции';


--
-- Name: COLUMN transactions.date; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.date IS 'Дата осуществления транзакции';


--
-- Name: COLUMN transactions.bene_account_num; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.bene_account_num IS 'Номер счета получателя (бенефициара)';


--
-- Name: COLUMN transactions.type; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.type IS 'Тип транзакции (внутренняя, международная)';


--
-- Name: COLUMN transactions.amount; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.amount IS 'Сумма транзакции';


--
-- Name: COLUMN transactions.commission; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.commission IS 'Комиссия за транзакцию';


--
-- Name: COLUMN transactions.status; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.status IS 'Статус транзакции';


--
-- Name: COLUMN transactions.bank_cor_swift; Type: COMMENT; Schema: bank; Owner: postgres
--

COMMENT ON COLUMN bank.transactions.bank_cor_swift IS 'SWIFT-код банка-корреспондента';


--
-- Name: transactions_rub; Type: MATERIALIZED VIEW; Schema: bank; Owner: postgres
--

CREATE MATERIALIZED VIEW bank.transactions_rub AS
 SELECT t.transaction_id,
    t.prpl_account_num,
    t.cur_id,
    t.date,
    t.bene_account_num,
    t.type,
    t.amount,
    t.commission,
    t.status,
    t.bank_cor_swift,
        CASE
            WHEN (t.cur_id = 643) THEN t.amount
            ELSE (t.amount * r.rate)
        END AS amount_rub
   FROM (bank.transactions t
     LEFT JOIN bank.daily_rates r ON (((t.cur_id = r.cur_id) AND (t.date = r.date))))
  WITH NO DATA;


ALTER TABLE bank.transactions_rub OWNER TO postgres;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE; Schema: bank; Owner: postgres
--

CREATE SEQUENCE bank.transactions_transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bank.transactions_transaction_id_seq OWNER TO postgres;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: bank; Owner: postgres
--

ALTER SEQUENCE bank.transactions_transaction_id_seq OWNED BY bank.transactions.transaction_id;


--
-- Name: clients client_id; Type: DEFAULT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.clients ALTER COLUMN client_id SET DEFAULT nextval('bank.clients_client_id_seq'::regclass);


--
-- Name: deposits deposit_id; Type: DEFAULT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.deposits ALTER COLUMN deposit_id SET DEFAULT nextval('bank.deposits_deposit_id_seq'::regclass);


--
-- Name: loans loan_id; Type: DEFAULT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.loans ALTER COLUMN loan_id SET DEFAULT nextval('bank.loans_loan_id_seq'::regclass);


--
-- Name: personnel employee_id; Type: DEFAULT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.personnel ALTER COLUMN employee_id SET DEFAULT nextval('bank.personnel_employee_id_seq'::regclass);


--
-- Name: transactions transaction_id; Type: DEFAULT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.transactions ALTER COLUMN transaction_id SET DEFAULT nextval('bank.transactions_transaction_id_seq'::regclass);


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: bank; Owner: postgres
--

COPY bank.accounts (account_num, client_id, cur_id, issue_date, balance, status, close_date) FROM stdin;
RU9983803436545906901757432591750	19	840	2023-10-16	0.0000	закрыт	2023-10-22
RU1683803436596193217028081534610	83	356	2023-05-03	3982316.2495	открыт	\N
RU2583803436511360000518303822185	94	356	2023-01-04	0.0000	закрыт	2023-06-08
RU6783803436582018660242960957244	63	356	2023-11-02	3959272.1596	открыт	\N
RU7383803436567535429961689788567	92	978	2023-09-30	0.0000	закрыт	2023-12-14
RU6583803436546434088553514688778	75	356	2023-12-19	1879400.4639	открыт	\N
RU5983803436565674700991182664479	75	978	2023-12-06	0.0000	закрыт	2023-12-24
RU2983803436539974076802515756241	95	643	2023-03-19	0.0000	закрыт	2023-12-06
RU4083803436565489336932623834655	98	978	2023-02-10	6163537.9928	открыт	\N
RU5983803436561671607015303339932	96	156	2023-07-02	3243915.9712	открыт	\N
RU2783803436580745382811010865973	70	356	2023-04-03	0.0000	закрыт	2023-12-10
RU7483803436512314763652680872976	24	840	2023-08-23	0.0000	закрыт	2023-08-25
RU9683803436526786707929300961979	66	356	2023-02-27	1814052.1668	открыт	\N
RU8183803436584325139466333599286	23	978	2023-11-21	6278666.9198	открыт	\N
RU6383803436517724803474176712817	58	978	2023-05-23	5761935.2488	открыт	\N
RU3883803436515226766320509995235	68	978	2023-02-10	6509375.1621	открыт	\N
RU1083803436588429797000364388942	83	398	2023-03-15	0.0000	закрыт	2023-06-18
RU7483803436575212193030608824580	37	978	2023-11-03	0.0000	закрыт	2023-11-14
RU3183803436559935083955185145410	1	356	2023-08-15	0.0000	закрыт	2023-11-20
RU2183803436586747579379810386651	57	398	2023-08-24	0.0000	закрыт	2023-09-11
RU3083803436518573891716312234719	75	643	2023-11-18	0.0000	закрыт	2023-12-24
RU7483803436581386287039618321410	54	356	2023-12-12	7580124.9149	открыт	\N
RU5483803436551418630110242560620	7	356	2023-11-21	1488726.0761	открыт	\N
RU8183803436555934243334630961587	57	356	2023-07-07	0.0000	закрыт	2023-09-24
RU1383803436523658112524214881297	41	840	2023-09-12	0.0000	закрыт	2023-10-09
RU8983803436518961229187913059129	51	643	2023-06-06	0.0000	закрыт	2023-08-01
RU2283803436588289284937975921944	41	398	2023-08-19	7565553.5214	открыт	\N
RU8383803436583878629872361871714	12	840	2023-02-02	0.0000	закрыт	2023-10-12
RU7183803436546875767014611813689	1	978	2023-07-05	9758098.3803	открыт	\N
RU2883803436564862346362051659673	64	978	2023-03-02	5644941.9565	открыт	\N
RU3983803436583094600516227232333	7	356	2023-01-23	4159930.8962	открыт	\N
RU4983803436548786021946522460624	100	840	2023-12-01	9995093.0727	открыт	\N
RU8983803436513229118545499417330	55	356	2023-06-27	0.0000	закрыт	2023-07-18
RU9983803436515137760640096699879	83	398	2023-08-04	0.0000	закрыт	2023-12-11
RU4183803436598422593606583773593	95	398	2023-07-20	3556337.8740	открыт	\N
RU4383803436594641659799774635872	59	156	2023-12-08	5202147.7148	открыт	\N
RU7383803436534050516387288663509	2	643	2023-06-29	0.0000	закрыт	2023-07-17
RU7783803436585076163513647706071	81	398	2023-12-23	0.0000	закрыт	2023-12-23
RU2783803436598441945275189813351	13	643	2023-06-24	2769821.0501	открыт	\N
RU8083803436588746463552823930061	83	156	2023-07-06	0.0000	закрыт	2023-08-17
RU4883803436583846522749125412438	36	840	2023-06-30	8631503.2163	открыт	\N
RU3383803436540416635821116917223	23	978	2023-12-21	3759660.4363	открыт	\N
RU3583803436580986023375789999847	72	398	2023-12-23	7428617.6979	открыт	\N
RU1183803436569972795023903837949	53	156	2023-10-23	1627646.0892	открыт	\N
RU7083803436595909521339223196614	26	643	2023-08-04	3684260.8887	открыт	\N
RU5183803436573013692902081587761	56	840	2023-01-23	4053771.1020	открыт	\N
RU2983803436572678251629055132350	91	156	2023-08-29	1715586.4133	открыт	\N
RU6483803436527000884469712767990	74	643	2023-09-13	0.0000	закрыт	2023-10-03
RU4583803436588661449801193641363	22	978	2023-01-01	0.0000	закрыт	2023-11-07
RU5583803436525031727011657164177	39	156	2023-08-02	0.0000	закрыт	2023-08-03
RU2683803436532775565489898182986	76	356	2023-03-02	0.0000	закрыт	2023-09-26
RU9683803436531094862059243712475	84	978	2023-05-10	7526594.5816	открыт	\N
RU6583803436573484995572407857396	92	156	2023-11-21	0.0000	закрыт	2023-11-27
RU9383803436546841675173507423577	89	978	2023-11-17	0.0000	закрыт	2023-11-19
RU5283803436529894140873721164089	33	840	2023-04-19	1228885.3553	открыт	\N
RU5483803436547543071206231343471	14	356	2023-01-28	6343735.3208	открыт	\N
RU6983803436548066705729944547736	15	398	2023-07-22	893088.7423	открыт	\N
RU2983803436572636545308279163382	25	398	2023-05-19	0.0000	закрыт	2023-11-19
RU3883803436554504516286459147223	21	398	2023-01-31	9201118.2365	открыт	\N
RU2983803436585384738431881857607	72	356	2023-04-24	5380731.0853	открыт	\N
RU9683803436524115739172828059349	17	398	2023-02-06	0.0000	закрыт	2023-03-16
RU1683803436583298094705869717304	33	156	2023-03-11	1004704.4599	открыт	\N
RU6283803436541447099313442593938	75	356	2023-10-14	0.0000	закрыт	2023-11-14
RU8983803436519227550175732694863	76	398	2023-10-16	7375251.9065	открыт	\N
RU2483803436580851808318436691458	13	356	2023-03-10	0.0000	закрыт	2023-11-28
RU8983803436530366335955653516096	27	643	2023-06-26	8622825.0762	открыт	\N
RU3983803436569376600246742084811	74	398	2023-01-19	4058879.0776	открыт	\N
RU8583803436553386257766521949981	49	356	2023-03-07	3636872.7533	открыт	\N
RU6883803436521704893234788177503	81	398	2023-10-21	0.0000	закрыт	2023-10-26
RU4183803436575456526806163894045	7	398	2023-11-11	2049701.2452	открыт	\N
RU8583803436548069379320039967893	5	156	2023-03-16	0.0000	закрыт	2023-04-18
RU6483803436595566817980742907742	90	840	2023-03-02	0.0000	закрыт	2023-09-08
RU9183803436523189940915642395180	61	978	2023-12-09	0.0000	закрыт	2023-12-19
RU3183803436583121152517184662518	33	840	2023-02-28	3786399.8093	открыт	\N
RU5983803436596779338391553657957	70	840	2023-08-21	0.0000	закрыт	2023-11-01
RU4083803436525661046500520760430	52	356	2023-03-27	2720884.6004	открыт	\N
RU6683803436547011171926119923803	99	398	2023-10-12	0.0000	закрыт	2023-12-20
RU9683803436571883645805733128714	46	643	2023-10-19	0.0000	закрыт	2023-11-30
RU5683803436573106663960342062340	31	978	2023-05-11	0.0000	закрыт	2023-10-24
RU5083803436537344339331652897359	41	643	2023-04-08	0.0000	закрыт	2023-12-13
RU7783803436578403910419087666263	81	398	2023-01-28	0.0000	закрыт	2023-07-27
RU3683803436526413764026311806751	38	398	2023-09-16	1890026.5296	открыт	\N
RU8483803436597380246113206833117	38	156	2023-05-04	0.0000	закрыт	2023-05-23
RU7683803436578953117174553181317	85	643	2023-09-24	8768476.7490	открыт	\N
RU7083803436569474567525801645267	75	978	2023-03-29	0.0000	закрыт	2023-04-04
RU4583803436535138140020222748384	24	156	2023-01-20	345504.8958	открыт	\N
RU5683803436539120556194350818141	61	643	2023-01-22	0.0000	закрыт	2023-07-18
RU3883803436571430516571621799878	67	840	2023-06-09	0.0000	закрыт	2023-09-08
RU1083803436563162471160560931522	12	643	2023-02-18	0.0000	закрыт	2023-06-06
RU4183803436555804329090528802664	27	840	2023-12-22	8676108.3195	открыт	\N
RU5983803436563752601230784661821	82	156	2023-04-21	0.0000	закрыт	2023-06-05
RU2983803436596711612246779730808	36	356	2023-03-30	31637.7614	открыт	\N
RU7783803436556242953974983768067	54	643	2023-03-29	0.0000	закрыт	2023-06-04
RU5983803436558435772787343054218	98	643	2023-10-27	3812751.2727	открыт	\N
RU8483803436546395435496825405512	34	156	2023-07-09	8532913.0121	открыт	\N
RU8483803436586135450040789229889	13	398	2023-05-15	8192336.0018	открыт	\N
RU9783803436566819882292917709885	18	156	2023-04-07	0.0000	закрыт	2023-12-17
RU5483803436538988818998904026382	81	978	2023-09-11	0.0000	закрыт	2023-09-24
RU8183803436564595439284009293487	57	643	2023-05-08	7781177.7604	открыт	\N
RU9383803436575688788160155647011	12	356	2023-10-12	0.0000	закрыт	2023-12-23
RU1183803436547102061688733775669	30	356	2023-11-23	0.0000	закрыт	2023-12-18
RU5283803436570838144716210841495	25	156	2023-01-02	1466539.6626	открыт	\N
RU3583803436597484588589933917343	5	356	2023-10-04	0.0000	закрыт	2023-10-18
RU1983803436592911874717339237016	26	398	2023-05-15	0.0000	закрыт	2023-10-04
RU9783803436531316283778462589484	90	156	2023-09-20	7186442.6433	открыт	\N
RU2583803436510413813910694958748	56	643	2023-01-09	0.0000	закрыт	2023-11-10
RU2283803436551819000625747494652	62	978	2023-08-09	0.0000	закрыт	2023-11-27
RU5183803436531460410872953149827	50	643	2023-03-18	0.0000	закрыт	2023-09-02
RU2883803436510195395163379960366	5	156	2023-08-02	0.0000	закрыт	2023-09-04
RU1483803436556765140449291811625	16	156	2023-05-09	2726106.3200	открыт	\N
RU4383803436559640804885433764330	38	978	2023-10-29	0.0000	закрыт	2023-11-18
RU8183803436576334203563049364101	48	978	2023-05-24	0.0000	закрыт	2023-08-20
RU2483803436537933507280624045523	43	156	2023-02-17	2893039.2882	открыт	\N
RU3183803436538368625987340316428	10	398	2023-03-23	0.0000	закрыт	2023-08-18
RU6583803436565551879254347008316	37	398	2023-09-22	0.0000	закрыт	2023-09-23
RU1583803436578714315409224923820	46	840	2023-10-02	0.0000	закрыт	2023-12-21
RU2083803436593214630941740939011	71	978	2023-04-01	1254644.4981	открыт	\N
RU8783803436519169154241731281817	32	978	2023-03-15	0.0000	закрыт	2023-05-02
RU4583803436576777630615652907536	65	156	2023-12-07	0.0000	закрыт	2023-12-13
RU4483803436537144245226352938256	69	398	2023-06-23	0.0000	закрыт	2023-10-10
RU6583803436592149423686806465410	82	978	2023-05-01	0.0000	закрыт	2023-12-12
RU4283803436583191860084907222827	27	978	2023-05-31	0.0000	закрыт	2023-11-09
RU3683803436589669964829443545971	1	156	2023-03-14	0.0000	закрыт	2023-05-25
RU9283803436560888794155508079505	89	840	2023-05-28	9626299.3904	открыт	\N
RU7583803436593621382878998665048	21	840	2023-03-10	4734241.9446	открыт	\N
RU8483803436593374085227717891522	5	978	2023-03-16	0.0000	закрыт	2023-10-11
RU5583803436581992686445972740236	88	398	2023-07-02	3055290.9034	открыт	\N
RU7183803436584925378313266803439	36	398	2023-07-16	0.0000	закрыт	2023-07-20
RU4283803436532641085536208083176	85	398	2023-02-08	2446871.3738	открыт	\N
RU2583803436586349630493889324094	59	398	2023-09-17	9467241.8342	открыт	\N
RU2983803436597155052344917689453	95	398	2023-09-01	0.0000	закрыт	2023-10-18
RU8983803436551003507571679577910	69	978	2023-01-18	8329445.3219	открыт	\N
RU3583803436556382446278007957702	88	840	2023-05-13	0.0000	закрыт	2023-09-29
RU7183803436535160662680026565691	91	840	2023-06-19	0.0000	закрыт	2023-08-22
RU6283803436561107985248905256058	61	356	2023-07-20	2089705.6131	открыт	\N
RU9083803436527710172880684864084	89	643	2023-05-24	0.0000	закрыт	2023-07-11
RU7783803436520045957277741704368	23	356	2023-11-24	0.0000	закрыт	2023-12-20
RU4583803436567844239839748091371	45	156	2023-12-14	4319786.5697	открыт	\N
RU8583803436593152008036708778596	87	840	2023-05-31	0.0000	закрыт	2023-08-16
RU5983803436513359014201161572816	65	840	2023-05-29	0.0000	закрыт	2023-06-26
RU9883803436580908913943520973504	47	356	2023-09-02	0.0000	закрыт	2023-10-28
RU1883803436562141776165180370424	80	643	2023-11-06	3523648.8950	открыт	\N
RU6983803436557684576294868357987	3	978	2023-01-28	9758893.7937	открыт	\N
RU5883803436549838724600410631189	27	643	2023-11-01	7999991.6976	открыт	\N
RU3383803436551883036237842733910	77	156	2023-02-22	7495595.5760	открыт	\N
RU8583803436580493050529274956761	25	643	2023-09-26	6138123.0103	открыт	\N
RU3283803436586063041663029658571	37	978	2023-01-26	0.0000	закрыт	2023-02-02
RU1683803436549082108439124677076	58	356	2023-05-10	8467147.6617	открыт	\N
RU2283803436555228451424548337941	5	978	2023-07-23	0.0000	закрыт	2023-11-06
RU6983803436582618731634671628237	61	978	2023-01-14	1852535.9955	открыт	\N
RU3183803436522808312515599877028	47	840	2023-12-24	0.0000	закрыт	2023-12-24
RU8383803436554622159366581134752	61	840	2023-12-18	0.0000	закрыт	2023-12-24
RU6383803436599902939219818792376	97	156	2023-12-21	9047455.0345	открыт	\N
RU4483803436534969190676238532628	71	156	2023-07-28	0.0000	закрыт	2023-11-21
RU8483803436514025076841381077297	65	840	2023-05-01	0.0000	закрыт	2023-05-24
RU6083803436557649065533492172245	55	643	2023-06-19	5267108.9116	открыт	\N
RU2883803436581906276084692901201	61	978	2023-08-02	4175356.7293	открыт	\N
RU8983803436550652073660555482382	84	840	2023-08-06	0.0000	закрыт	2023-11-26
RU3683803436542925451475324573982	96	978	2023-05-16	2409031.8459	открыт	\N
RU6083803436583599210196850890015	77	398	2023-01-13	9415178.6975	открыт	\N
RU6783803436510078136565817264354	16	156	2023-11-21	6087320.2047	открыт	\N
RU3883803436519845868206132784952	45	643	2023-10-02	0.0000	закрыт	2023-11-28
RU2383803436518501918755699207235	91	840	2023-06-15	8653080.8475	открыт	\N
RU9083803436513364676730542126445	58	840	2023-09-13	3579826.2163	открыт	\N
RU2883803436512412400998624231254	83	840	2023-02-25	0.0000	закрыт	2023-06-23
RU1983803436574962372646294489745	100	978	2023-03-06	0.0000	закрыт	2023-07-07
RU9383803436563463129216774786629	85	978	2023-01-14	1685807.1641	открыт	\N
RU1983803436510686315036595318873	69	356	2023-12-11	0.0000	закрыт	2023-12-14
RU6383803436512605200896614597744	68	398	2023-03-19	0.0000	закрыт	2023-05-03
RU7483803436595528340078834029783	44	356	2023-03-10	0.0000	закрыт	2023-06-14
RU3683803436583826961336736431806	49	978	2023-05-27	0.0000	закрыт	2023-08-28
RU8683803436531608639655465618756	35	398	2023-10-26	0.0000	закрыт	2023-11-29
RU1183803436541561390025398925839	20	356	2023-11-09	8120082.8371	открыт	\N
RU9483803436516702191580023603147	89	398	2023-10-16	8099462.8248	открыт	\N
RU6583803436526807323529165700056	89	156	2023-03-22	9669254.4333	открыт	\N
RU6483803436531317735484528392559	90	398	2023-10-07	0.0000	закрыт	2023-10-25
RU8183803436576908594301902139271	54	978	2023-06-01	9406962.5299	открыт	\N
RU9483803436522220035875117822565	63	840	2023-04-21	0.0000	закрыт	2023-07-18
RU9483803436585469145832242711561	50	156	2023-09-12	6234735.5104	открыт	\N
RU9883803436597607312145326011401	57	156	2023-04-09	3062557.3555	открыт	\N
RU3383803436527231938190662146888	56	356	2023-12-03	0.0000	закрыт	2023-12-08
RU4283803436530972916151822377436	78	840	2023-03-11	0.0000	закрыт	2023-09-24
RU9383803436515318038329930627155	39	156	2023-01-13	0.0000	закрыт	2023-09-01
RU5883803436537252361294139722938	34	840	2023-07-05	7472337.0004	открыт	\N
RU7483803436516612664745741202549	41	398	2023-09-25	2246420.8827	открыт	\N
RU8683803436558409197465918354522	34	156	2023-02-27	5883785.6122	открыт	\N
RU7183803436596080848426828093950	49	643	2023-08-31	0.0000	закрыт	2023-09-03
RU3683803436529963181547651499120	3	643	2023-01-28	0.0000	закрыт	2023-05-20
RU5083803436563140090168469536649	73	643	2023-03-25	3532815.5503	открыт	\N
RU4583803436571583967013936520660	83	978	2023-04-23	273554.1049	открыт	\N
RU9183803436594783043422280553530	15	978	2023-07-22	0.0000	закрыт	2023-11-03
RU1383803436537041354890218533954	24	156	2023-02-17	7100766.6691	открыт	\N
RU6683803436575472065287991925682	20	643	2023-02-09	0.0000	закрыт	2023-04-23
RU8483803436523751116997614384937	6	643	2023-05-12	7158398.4129	открыт	\N
RU1183803436513944372774322746458	2	978	2023-03-17	2159925.3196	открыт	\N
RU6583803436552414284054924599360	18	398	2023-01-17	0.0000	закрыт	2023-04-30
RU5783803436568341660520010753753	18	356	2023-11-09	4876428.8957	открыт	\N
RU9983803436581801115411623274695	43	840	2023-01-21	4671023.1679	открыт	\N
RU8483803436552375991404578719285	49	978	2023-07-02	0.0000	закрыт	2023-11-07
RU1083803436532178175395898264605	67	356	2023-10-19	8474023.9843	открыт	\N
RU2983803436545911307181108696312	69	840	2023-07-09	1517121.1368	открыт	\N
RU2583803436569716293278278112122	63	840	2023-09-21	1386262.9248	открыт	\N
RU6883803436524866655852609791727	51	156	2023-06-22	0.0000	закрыт	2023-09-28
RU1583803436597114679330016317094	13	156	2023-01-11	0.0000	закрыт	2023-01-27
RU2083803436518033160343253894367	39	840	2023-05-26	0.0000	закрыт	2023-09-01
RU6183803436556503720110500069421	90	643	2023-09-21	4425595.0465	открыт	\N
RU4383803436557380827011382643653	7	356	2023-05-07	6467664.4323	открыт	\N
RU1383803436585969091171133733533	73	398	2023-03-01	0.0000	закрыт	2023-09-02
RU9783803436586848496167067081204	35	398	2023-10-16	0.0000	закрыт	2023-11-05
RU1583803436575905915250327615306	86	398	2023-11-22	0.0000	закрыт	2023-11-29
RU4883803436563163057705977553405	12	156	2023-12-06	0.0000	закрыт	2023-12-20
RU4883803436510661666911089208306	64	356	2023-08-27	0.0000	закрыт	2023-11-14
RU5683803436564237501745383797829	24	840	2023-08-30	0.0000	закрыт	2023-09-08
RU1583803436522600904788279282430	52	978	2023-04-07	3932572.6711	открыт	\N
RU5183803436588801456118987264753	34	156	2023-11-09	5321335.4594	открыт	\N
RU6683803436546559918630563560759	53	978	2023-07-01	7004696.0537	открыт	\N
RU7383803436546512723534280739575	27	398	2023-12-18	4613746.2360	открыт	\N
RU1383803436596151895061926683764	78	643	2023-10-09	3345914.3584	открыт	\N
RU1983803436537997284898110055528	67	840	2023-05-22	0.0000	закрыт	2023-09-17
RU3383803436533625475503259998648	8	978	2023-09-11	8578233.8508	открыт	\N
RU5083803436583492295875343805447	30	156	2023-02-18	0.0000	закрыт	2023-05-24
RU4083803436523112590591409946049	74	156	2023-12-08	0.0000	закрыт	2023-12-16
RU9883803436596118671708861810646	37	398	2023-01-24	9576445.4467	открыт	\N
RU7383803436569356631218275502161	40	840	2023-02-03	168655.8684	открыт	\N
RU1683803436543683792461716245841	81	356	2023-04-26	2416289.6741	открыт	\N
RU2983803436588011593439328399453	20	356	2023-07-03	2512008.2815	открыт	\N
RU2983803436530272226005609138408	67	840	2023-07-16	0.0000	закрыт	2023-09-22
RU1183803436587920364130887563809	28	643	2023-03-28	0.0000	закрыт	2023-05-30
RU3783803436585191546282680625888	83	643	2023-09-13	5062722.1517	открыт	\N
RU4283803436544879224116585983050	53	978	2023-07-06	4821184.0109	открыт	\N
RU4983803436522833268295991391237	32	398	2023-10-27	0.0000	закрыт	2023-12-15
RU1983803436510712914540451632365	36	398	2023-01-04	0.0000	закрыт	2023-01-11
RU3883803436531800763308499008852	93	398	2023-08-13	3902343.3075	открыт	\N
RU9683803436541591047480784615833	49	156	2023-07-12	0.0000	закрыт	2023-12-17
RU9283803436564588409350021574669	70	840	2023-05-30	0.0000	закрыт	2023-10-06
RU1983803436568263609873115174417	43	156	2023-02-16	390928.6425	открыт	\N
RU8483803436576032684947735830335	97	156	2023-08-16	0.0000	закрыт	2023-08-30
RU4883803436540069564759439339493	98	978	2023-04-29	0.0000	закрыт	2023-11-30
RU5683803436522754650880470438385	96	156	2023-03-03	0.0000	закрыт	2023-03-22
RU9583803436562562119396535016715	86	840	2023-10-14	0.0000	закрыт	2023-12-22
RU1383803436565139777755041333233	30	978	2023-06-01	5544289.1402	открыт	\N
RU4383803436535637847836978327691	69	978	2023-01-30	2179040.6604	открыт	\N
RU6183803436571932790348770462135	17	643	2023-06-04	0.0000	закрыт	2023-10-06
RU2683803436575198696607383546599	12	356	2023-07-01	0.0000	закрыт	2023-12-10
RU2983803436510489846489627969282	88	398	2023-10-31	3521539.4967	открыт	\N
RU6483803436513432249664452306210	60	840	2023-08-24	0.0000	закрыт	2023-11-12
RU6583803436547384322379422553840	32	398	2023-02-18	0.0000	закрыт	2023-03-10
RU5783803436573951128453151787227	26	398	2023-08-03	0.0000	закрыт	2023-11-15
RU3983803436580604058878329162478	41	978	2023-06-11	0.0000	закрыт	2023-11-05
RU7583803436593274051968042799324	31	978	2023-10-04	5633697.3149	открыт	\N
RU2283803436594102552659582448178	9	840	2023-11-03	0.0000	закрыт	2023-12-06
RU7283803436582085910615477000049	81	643	2023-08-17	7298630.6266	открыт	\N
RU4583803436546993711061481413708	28	643	2023-08-24	5618602.9528	открыт	\N
RU1583803436592948110594062864167	26	643	2023-10-19	4428246.6150	открыт	\N
RU5783803436523742307313248220811	16	978	2023-04-29	0.0000	закрыт	2023-09-03
RU4483803436593534887929979895004	16	356	2023-11-03	6130223.2944	открыт	\N
RU9683803436597203099828784600586	45	840	2023-03-03	0.0000	закрыт	2023-05-27
RU1283803436513390712190126736747	81	356	2023-05-24	0.0000	закрыт	2023-08-25
RU7783803436529059332090835348557	73	643	2023-10-29	0.0000	закрыт	2023-11-06
RU5883803436551017474710608700284	43	398	2023-05-09	0.0000	закрыт	2023-08-02
RU4883803436577275200947611443039	65	643	2023-11-01	2626909.7456	открыт	\N
RU3483803436534657689181631833463	82	398	2023-07-29	0.0000	закрыт	2023-12-15
RU6283803436577836700807681117407	35	978	2023-09-24	0.0000	закрыт	2023-10-09
RU6483803436557881046066137062384	66	840	2023-08-03	2061652.1666	открыт	\N
RU8483803436528403655778834568144	79	156	2023-06-27	0.0000	закрыт	2023-10-11
RU6983803436550083462130199504453	39	643	2023-03-12	9808713.5169	открыт	\N
RU6983803436551969328605594993446	77	978	2023-08-06	0.0000	закрыт	2023-10-09
RU4783803436556925313909023616425	95	643	2023-06-07	0.0000	закрыт	2023-06-13
RU6983803436521001508692071958064	25	356	2023-07-09	6704419.1902	открыт	\N
RU7783803436536804517087406327796	73	356	2023-05-02	7285403.8952	открыт	\N
RU7483803436591068390387769478580	12	398	2023-11-18	3292057.1336	открыт	\N
RU3183803436564747839620735247465	68	356	2023-05-10	0.0000	закрыт	2023-05-14
RU9883803436559947701649293062119	78	398	2023-12-05	0.0000	закрыт	2023-12-18
RU8183803436566794763466227027850	7	356	2023-10-15	0.0000	закрыт	2023-10-29
RU8683803436557989786811096289958	94	643	2023-09-28	0.0000	закрыт	2023-11-04
RU2083803436536025786076127901648	60	398	2023-09-17	0.0000	закрыт	2023-12-16
RU9383803436568402663247236595753	88	840	2023-05-26	3141637.2482	открыт	\N
RU4783803436576956010684046744289	84	156	2023-09-19	0.0000	закрыт	2023-12-18
RU6083803436582119843499506879640	19	398	2023-06-04	3263301.6712	открыт	\N
RU7583803436545511345420608427589	13	840	2023-07-30	0.0000	закрыт	2023-10-16
RU8483803436517523304653033637180	23	643	2023-11-19	0.0000	закрыт	2023-12-23
RU4683803436521950147450839996450	80	643	2023-01-28	0.0000	закрыт	2023-11-02
RU3483803436537283842522563725379	17	356	2023-06-16	6972953.7530	открыт	\N
RU4083803436530357399673623809331	26	356	2023-05-14	3890661.5744	открыт	\N
RU5883803436512174556620785995683	89	156	2023-07-03	0.0000	закрыт	2023-09-05
RU8983803436545494349013660032430	38	643	2023-03-29	0.0000	закрыт	2023-07-03
RU7683803436589524723383129532286	71	398	2023-12-05	509371.4909	открыт	\N
RU1483803436552189189819570176682	48	643	2023-01-05	7726742.3032	открыт	\N
RU3183803436545750333950215053352	11	978	2023-04-10	0.0000	закрыт	2023-06-15
RU8783803436544746989208687599320	80	978	2023-05-14	0.0000	закрыт	2023-06-05
RU5583803436556151120487866130687	74	356	2023-07-19	1362009.0537	открыт	\N
RU5683803436575772290627280121203	39	643	2023-01-06	0.0000	закрыт	2023-06-11
RU5383803436532276110708298062956	78	840	2023-08-03	3592377.9095	открыт	\N
RU1383803436546084241558471107471	7	156	2023-03-16	0.0000	закрыт	2023-08-07
RU8183803436532187852215520403243	70	978	2023-02-19	0.0000	закрыт	2023-04-28
RU9983803436588442958405952112241	4	643	2023-01-13	4547351.8561	открыт	\N
RU8983803436588264357315670765686	79	356	2023-10-08	8443392.2351	открыт	\N
RU2083803436573246597416370413406	10	643	2023-10-19	0.0000	закрыт	2023-10-25
RU1183803436536239647096212180861	89	643	2023-09-28	0.0000	закрыт	2023-12-12
RU9283803436581282514241262822584	14	398	2023-12-17	0.0000	закрыт	2023-12-17
RU4483803436531766422461159975910	36	356	2023-03-15	9843479.3616	открыт	\N
RU5583803436541779385547740767657	22	978	2023-06-14	0.0000	закрыт	2023-09-06
RU1683803436510344781123537250392	86	840	2023-05-27	7913339.3018	открыт	\N
RU2183803436551906716086082339754	31	356	2023-01-29	0.0000	закрыт	2023-06-10
RU7283803436565335970635584506660	42	156	2023-12-23	0.0000	закрыт	2023-12-24
RU8583803436598717986670697262250	100	840	2023-06-11	0.0000	закрыт	2023-12-20
RU1983803436549890414007715363567	58	156	2023-12-02	0.0000	закрыт	2023-12-06
RU6183803436555838927651384339574	25	398	2023-04-23	6289551.8291	открыт	\N
RU2283803436577856579987093576845	29	156	2023-09-28	0.0000	закрыт	2023-11-02
RU2183803436538160023828199079683	26	978	2023-09-13	8422437.2015	открыт	\N
RU8483803436562780872181379760829	7	643	2023-09-20	0.0000	закрыт	2023-12-07
RU6983803436517488129268543865126	24	840	2023-12-13	0.0000	закрыт	2023-12-21
RU5183803436596697120047636808100	4	643	2023-02-26	3534734.5162	открыт	\N
RU8783803436522200736153030297680	12	840	2023-07-09	0.0000	закрыт	2023-07-23
RU5783803436598085342824416355658	92	398	2023-06-22	0.0000	закрыт	2023-09-26
RU2383803436569895097903578030814	60	398	2023-03-01	0.0000	закрыт	2023-03-11
RU9083803436548965374028188380728	33	398	2023-02-21	0.0000	закрыт	2023-09-19
RU3783803436562091905141244310726	74	156	2023-01-05	0.0000	закрыт	2023-01-17
RU5783803436556321671762187197309	97	398	2023-01-01	9796780.1460	открыт	\N
RU2283803436527235231809863175226	97	156	2023-11-15	5557716.6001	открыт	\N
RU2083803436517185898516741185299	9	356	2023-05-17	0.0000	закрыт	2023-06-27
RU8483803436583598027317615125571	82	356	2023-09-13	2501408.0249	открыт	\N
RU5783803436553735504938098098542	52	643	2023-04-29	0.0000	закрыт	2023-09-13
RU2283803436521727957364583057084	93	840	2023-12-19	0.0000	закрыт	2023-12-23
RU4183803436512683300418013703414	93	156	2023-03-01	0.0000	закрыт	2023-11-04
RU9683803436511276549947859990709	71	840	2023-08-27	8207996.5916	открыт	\N
RU7283803436583841985241060182740	3	356	2023-02-03	3774158.2229	открыт	\N
RU7383803436515152831562897371432	19	398	2023-03-25	3884881.4512	открыт	\N
RU9583803436547610609904791788853	29	643	2023-11-14	2759656.5698	открыт	\N
RU5083803436521160540176223483455	91	978	2023-01-17	3132666.3208	открыт	\N
RU2783803436529440294678710752920	8	398	2023-02-26	0.0000	закрыт	2023-08-07
RU5583803436544105301147510534206	21	840	2023-07-13	8657468.0978	открыт	\N
RU5583803436533254773648721597711	51	156	2023-11-13	6547906.6638	открыт	\N
RU1683803436530784164352439032526	5	840	2023-10-14	0.0000	закрыт	2023-11-10
RU5383803436537654175631942789109	46	978	2023-08-10	2640981.4634	открыт	\N
RU5183803436550941857646482749776	19	156	2023-03-24	7192690.5401	открыт	\N
RU5183803436599553165549416662045	86	643	2023-05-18	0.0000	закрыт	2023-11-22
RU7483803436529598231033100377224	98	356	2023-01-14	0.0000	закрыт	2023-07-08
RU4383803436538414207445829899653	18	840	2023-08-08	5208312.7121	открыт	\N
RU8683803436520349379894661014091	98	156	2023-01-28	0.0000	закрыт	2023-01-30
RU8883803436542351475891948314875	90	840	2023-02-19	1577485.1244	открыт	\N
RU9983803436521153026985692784451	27	356	2023-02-06	8471195.2229	открыт	\N
RU5183803436588244188761426669013	7	356	2023-03-01	0.0000	закрыт	2023-03-07
RU1983803436518034161993382946183	36	840	2023-06-27	0.0000	закрыт	2023-07-12
RU6183803436551232797419519235346	4	643	2023-05-06	1660061.3545	открыт	\N
RU7083803436575256167282941443393	12	840	2023-07-08	5209258.5918	открыт	\N
RU5983803436533405804846460378377	75	643	2023-04-22	0.0000	закрыт	2023-08-05
RU6983803436518663051613263930888	74	156	2023-10-03	4990955.4243	открыт	\N
RU5183803436523181844916432548416	57	156	2023-11-04	5202922.2323	открыт	\N
RU7783803436557425582753958788900	84	356	2023-07-24	1348306.1570	открыт	\N
RU9183803436512467785925904841435	53	356	2023-11-11	764556.1748	открыт	\N
RU2483803436559904294875702128517	52	643	2023-03-06	0.0000	закрыт	2023-03-20
RU6983803436542868245387240901621	91	643	2023-03-10	3800827.3877	открыт	\N
RU8883803436592173067148862634991	77	398	2023-02-10	0.0000	закрыт	2023-04-15
RU7183803436578006903833632767386	9	643	2023-08-02	0.0000	закрыт	2023-11-12
RU4383803436597428452957764955765	80	398	2023-03-13	0.0000	закрыт	2023-09-08
RU9583803436589245078784775619456	25	643	2023-11-27	0.0000	закрыт	2023-12-15
RU3283803436579852018195047883736	53	356	2023-10-19	0.0000	закрыт	2023-12-22
RU9383803436587347167184231490115	33	978	2023-08-04	2661074.5223	открыт	\N
RU8683803436511417676206561932357	43	643	2023-06-23	0.0000	закрыт	2023-08-15
RU6383803436519000124215462920616	70	398	2023-01-28	0.0000	закрыт	2023-03-07
RU1083803436516100547774990634896	80	643	2023-12-19	0.0000	закрыт	2023-12-22
RU5883803436571013870275428717873	66	643	2023-05-29	6241637.1809	открыт	\N
RU4383803436586323329892508459044	6	398	2023-03-13	0.0000	закрыт	2023-09-09
RU5483803436549562102902686014927	52	398	2023-10-03	9655420.4229	открыт	\N
RU4283803436571605132393354830061	20	156	2023-01-28	0.0000	закрыт	2023-02-07
RU3383803436530100232705488681423	96	643	2023-10-25	0.0000	закрыт	2023-11-05
RU6183803436536163842184020816729	73	398	2023-10-01	8789074.4258	открыт	\N
RU7083803436565850801859363291526	90	840	2023-08-15	0.0000	закрыт	2023-10-14
RU4683803436518754352401343547893	85	398	2023-12-11	1334112.1295	открыт	\N
RU2683803436556115738690945420927	73	643	2023-10-29	4994687.7100	открыт	\N
RU3683803436533022850683714599602	30	978	2023-07-24	0.0000	закрыт	2023-09-04
RU9883803436510697875492928159959	69	398	2023-09-13	0.0000	закрыт	2023-11-14
RU2083803436571871160330810400191	89	356	2023-04-25	0.0000	закрыт	2023-11-11
RU9483803436570307762028951954874	56	156	2023-07-29	0.0000	закрыт	2023-09-26
RU7483803436544936047225386728318	53	356	2023-09-11	0.0000	закрыт	2023-11-23
RU2183803436555308456329784386702	74	398	2023-10-08	0.0000	закрыт	2023-11-21
RU3783803436559423561964096195262	8	156	2023-06-01	0.0000	закрыт	2023-06-06
RU2483803436563361420871450061347	8	978	2023-03-10	799527.2973	открыт	\N
RU1283803436591782126481419856685	37	356	2023-05-11	3693031.3610	открыт	\N
RU6483803436575827628326698282321	68	840	2023-06-05	3101522.9225	открыт	\N
RU5483803436559214869633349674125	95	398	2023-03-16	3323059.3989	открыт	\N
RU7283803436528848493351990702937	69	356	2023-02-17	0.0000	закрыт	2023-12-07
RU8583803436586707949034749896750	2	356	2023-07-13	9907240.3686	открыт	\N
RU6483803436599929208547720213297	43	978	2023-05-15	5861896.1894	открыт	\N
RU3583803436543438797337964557116	94	356	2023-01-08	0.0000	закрыт	2023-04-06
RU1283803436521770311179326367954	70	356	2023-06-24	0.0000	закрыт	2023-06-26
RU4283803436512174946847064448344	58	840	2023-12-13	2667213.7273	открыт	\N
RU3083803436556733352794187735054	62	643	2023-06-13	3880468.9164	открыт	\N
RU6783803436527708547728704282997	32	840	2023-07-31	4015815.5877	открыт	\N
RU9983803436563015974445739907644	19	643	2023-06-03	0.0000	закрыт	2023-07-29
RU9583803436574471411467135718624	36	643	2023-08-05	0.0000	закрыт	2023-09-12
RU3083803436572725983728902081378	18	643	2023-03-24	0.0000	закрыт	2023-09-25
RU1183803436512373318427988836252	5	840	2023-01-20	8790116.9973	открыт	\N
RU4483803436574648344464338946055	49	356	2023-06-01	3676957.1290	открыт	\N
RU3383803436548623436381587682007	24	978	2023-05-14	0.0000	закрыт	2023-08-23
RU2583803436573489146610412814439	85	356	2023-04-15	775856.8059	открыт	\N
RU9583803436537234117226554935344	5	978	2023-05-04	0.0000	закрыт	2023-07-07
RU2883803436538134433783624054557	16	156	2023-01-26	6314608.4572	открыт	\N
RU2783803436512588965300606208370	74	398	2023-12-09	6969477.8301	открыт	\N
RU4083803436534430125114460530795	5	356	2023-06-11	5148970.9677	открыт	\N
RU9283803436529032721317031749293	48	840	2023-01-27	0.0000	закрыт	2023-08-19
RU5983803436518386216122030936247	56	643	2023-07-14	0.0000	закрыт	2023-10-29
RU6683803436534213789698830771682	2	398	2023-07-19	4907060.2693	открыт	\N
RU9583803436515959194321808018014	70	643	2023-07-08	7836214.7300	открыт	\N
RU8983803436543970357311304848339	31	156	2023-08-29	0.0000	закрыт	2023-10-08
RU9483803436588743613330942629999	97	398	2023-11-09	0.0000	закрыт	2023-11-18
RU8483803436512925144599170278485	20	156	2023-01-27	432750.4852	открыт	\N
RU7283803436551671539996901196859	54	356	2023-12-14	6807239.2969	открыт	\N
RU8183803436546948351691601253240	55	398	2023-07-06	7529302.0732	открыт	\N
RU9683803436559214297350823715344	63	978	2023-12-02	0.0000	закрыт	2023-12-04
RU4283803436538514172142523078432	62	643	2023-12-20	6661790.1032	открыт	\N
RU6583803436599318340096840026283	46	356	2023-04-06	109835.9840	открыт	\N
RU7583803436597888322431139189153	86	156	2023-01-02	1222798.7262	открыт	\N
RU4183803436593654490331448399606	67	356	2023-03-22	0.0000	закрыт	2023-08-03
RU6983803436580831999013679742086	25	978	2023-03-17	9650579.9094	открыт	\N
RU4983803436534576819154749347962	47	356	2023-06-26	0.0000	закрыт	2023-07-30
RU4883803436561825246742556433732	98	643	2023-04-29	0.0000	закрыт	2023-11-03
RU6683803436563942598707878107815	71	156	2023-12-22	0.0000	закрыт	2023-12-22
RU8583803436590890149305918634043	9	840	2023-02-07	0.0000	закрыт	2023-03-19
RU3983803436583730529285495292571	80	356	2023-02-24	3906738.5902	открыт	\N
RU6383803436541953279771793851240	51	398	2023-08-01	0.0000	закрыт	2023-10-15
RU8683803436571821829992754282142	81	978	2023-06-10	4858613.0377	открыт	\N
RU3683803436521305656177527242839	99	978	2023-12-04	0.0000	закрыт	2023-12-24
RU7883803436577262824038798840088	6	356	2023-01-05	8575723.4983	открыт	\N
RU1883803436537462946976236392804	39	840	2023-04-17	0.0000	закрыт	2023-10-04
RU6183803436573612137819734816326	7	643	2023-03-10	0.0000	закрыт	2023-04-16
RU6983803436596433824452063468541	31	398	2023-03-07	4820609.9638	открыт	\N
RU4683803436584135461455281070651	46	398	2023-07-28	2428360.3427	открыт	\N
RU8083803436548053884024737088236	26	978	2023-03-19	6386050.4784	открыт	\N
RU8183803436559528710172368223769	71	978	2023-11-09	0.0000	закрыт	2023-11-22
RU3783803436562139250445157080524	41	156	2023-03-30	0.0000	закрыт	2023-07-31
RU5083803436556786327042016836549	55	643	2023-03-26	3958659.4499	открыт	\N
RU2783803436515955219320238454317	16	978	2023-03-12	0.0000	закрыт	2023-07-09
RU1883803436547883958852583813660	28	643	2023-03-27	4670043.0475	открыт	\N
RU1483803436555535016685486735994	72	643	2023-10-04	0.0000	закрыт	2023-12-01
RU7183803436551143317683635788042	91	156	2023-07-27	8580736.3210	открыт	\N
RU4383803436583134155448910498762	1	978	2023-06-07	235795.9111	открыт	\N
RU6783803436583735354795738130605	58	356	2023-09-26	0.0000	закрыт	2023-10-30
RU5883803436544935035293164341064	34	398	2023-09-03	5690288.5128	открыт	\N
RU5183803436585063037953141711870	66	398	2023-03-28	7046552.3735	открыт	\N
RU1983803436558651220197686454204	22	840	2023-10-24	9694502.7757	открыт	\N
RU6583803436556215016292535847892	72	398	2023-08-03	0.0000	закрыт	2023-12-11
RU5683803436581377733469772235779	99	978	2023-04-17	0.0000	закрыт	2023-11-16
RU6783803436534011789886956964173	79	643	2023-10-15	4299939.4438	открыт	\N
RU9583803436557636243711161422858	65	356	2023-05-09	0.0000	закрыт	2023-05-13
RU9683803436520170153501466272589	92	398	2023-07-25	5135459.6439	открыт	\N
RU7483803436560908970835757520521	98	978	2023-09-19	0.0000	закрыт	2023-10-26
RU3183803436556325220643083039724	69	398	2023-06-30	9033868.9136	открыт	\N
RU5983803436585678890114061651314	76	156	2023-08-31	0.0000	закрыт	2023-10-19
RU3983803436562540544761068231244	56	356	2023-10-02	0.0000	закрыт	2023-10-16
RU7683803436565241249132549566386	43	840	2023-07-04	0.0000	закрыт	2023-12-08
RU6183803436547326038705936576601	100	643	2023-11-16	0.0000	закрыт	2023-11-28
RU1683803436536773128968824249362	39	156	2023-10-12	3509973.6574	открыт	\N
RU2683803436566742853200336170327	73	643	2023-10-01	2815861.5416	открыт	\N
RU4583803436544769415444430855700	95	398	2023-01-02	0.0000	закрыт	2023-07-14
RU5583803436516539388298963058164	81	840	2023-03-13	0.0000	закрыт	2023-09-08
RU8183803436513368239655842198331	52	156	2023-05-30	9271442.8973	открыт	\N
RU4083803436519648806531502670697	34	643	2023-02-19	3336168.8234	открыт	\N
RU8383803436543267469021061769102	88	398	2023-11-02	0.0000	закрыт	2023-11-05
RU9483803436521022327823815694666	15	156	2023-07-14	3596558.3840	открыт	\N
RU5583803436555177704368963744222	7	398	2023-06-15	0.0000	закрыт	2023-12-24
RU3983803436554516084539411139147	62	978	2023-08-29	0.0000	закрыт	2023-12-15
RU8283803436558421168306139201398	20	156	2023-03-28	6321131.6210	открыт	\N
RU6083803436569163727288631654599	98	156	2023-12-02	308525.1028	открыт	\N
RU4083803436526038486689011711230	32	156	2023-03-07	6563657.6131	открыт	\N
RU4283803436515276086545867508581	71	643	2023-02-17	0.0000	закрыт	2023-11-09
RU3883803436559428008275215914286	76	356	2023-03-07	3048437.0641	открыт	\N
RU1283803436545193525808988988532	7	840	2023-11-23	0.0000	закрыт	2023-12-06
RU8283803436593409912626065485368	86	643	2023-07-14	0.0000	закрыт	2023-09-22
RU8583803436567351126582917385267	29	978	2023-05-27	8572061.6126	открыт	\N
RU8083803436567877444686336475183	65	398	2023-07-09	1725156.6542	открыт	\N
RU8283803436536082355231514909614	38	156	2023-08-26	0.0000	закрыт	2023-12-16
RU5783803436567884889437805923129	69	978	2023-04-26	1151422.3241	открыт	\N
RU2683803436512319317744369021772	60	156	2023-12-18	0.0000	закрыт	2023-12-22
RU8783803436562772820294479967682	58	156	2023-01-15	0.0000	закрыт	2023-11-02
RU1283803436597755454846611928328	32	398	2023-03-22	0.0000	закрыт	2023-04-13
RU3083803436548755847047281062638	32	356	2023-09-28	0.0000	закрыт	2023-11-12
RU2583803436525056668985275863842	91	978	2023-03-15	129856.3572	открыт	\N
RU8283803436517214496879594083501	27	156	2023-02-17	5551846.4360	открыт	\N
RU9683803436579408636311341559980	46	398	2023-02-18	0.0000	закрыт	2023-05-17
RU6583803436588261503476787515721	80	840	2023-09-08	7054541.6834	открыт	\N
RU1583803436513968949783488654583	21	643	2023-04-19	0.0000	закрыт	2023-11-11
RU3583803436531844714480494060517	62	156	2023-07-29	3376845.1788	открыт	\N
RU4083803436561171626967381260937	99	978	2023-07-04	0.0000	закрыт	2023-10-07
RU7483803436595027677837710467368	15	978	2023-12-09	0.0000	закрыт	2023-12-15
RU9083803436542335742968981386823	96	398	2023-04-10	0.0000	закрыт	2023-07-04
RU2483803436550335144467075253432	73	398	2023-05-07	0.0000	закрыт	2023-10-23
RU4183803436544525596730636267692	54	356	2023-01-30	6393516.4887	открыт	\N
RU8383803436557193853878723819444	95	156	2023-03-01	0.0000	закрыт	2023-09-02
RU1583803436533479152204865778047	3	398	2023-07-01	0.0000	закрыт	2023-09-18
RU7383803436585863943754594310819	7	840	2023-01-14	873885.1126	открыт	\N
RU2183803436535230801413319305895	97	356	2023-07-15	2088528.3394	открыт	\N
RU5883803436576828712243252221562	93	978	2023-01-29	7066753.3675	открыт	\N
RU8583803436529401978461350257287	35	398	2023-01-06	5943324.1954	открыт	\N
RU7183803436513501317784267991188	81	643	2023-04-25	0.0000	закрыт	2023-05-17
RU6383803436530975100435134167112	20	156	2023-04-06	0.0000	закрыт	2023-11-17
RU3883803436564256045508064629374	23	978	2023-06-30	0.0000	закрыт	2023-09-09
RU1383803436598073263367823117200	39	978	2023-01-22	6421337.9192	открыт	\N
RU4083803436537218400436107027314	21	978	2023-10-14	0.0000	закрыт	2023-11-11
\.


--
-- Data for Name: banks_cors; Type: TABLE DATA; Schema: bank; Owner: postgres
--

COPY bank.banks_cors (cur_id, swift_code, name, address, contact_info) FROM stdin;
978	DEUTDEFFXXX	DEUTSCHE BANK AG 	TAUNUSANLAGE 12, FRANKFURT AM MAIN, GERMANY	{"email": "deutsche.bank@db.com", "phone": "+49 (69) 9103-5754"}
978	RZBAATWW	RAIFFEISEN BANK INTERNATIONAL AG	AM STADTPARK 9, A-1030 VIENNA, AUSTRIA	{"url": "https://www.rbinternational.com/", "phone": "+43 1 71707 3537"}
978	SOGEFRPP	SOCIETE GENERALE	29 BOULEVARD HAUSMANN 75009, PARIS, FRANCE	{"url": "http://www.socgen.com", "phone": "+33-1-42-14-20-00"}
840	CHASUS33	JPMORGAN CHASE BANK, N.A.	383 MADISON AVENUE, NEW YORK, USA	{"url": "https://www.chase.com/", "phone": "+1-212-270-6000"}
840	IRVTUS3NXXX	THE BANK OF NEW YORK MELLON	240 GREENWICH STREET, NEW YORK, USA	{"url": "https://www.bnymellon.com", "phone": "+1 212 495 1784"}
398	CASPKZKAXXX	KASPI BANK JSC	NAURYZBAI BATYR STREET 154A, ALMATY, KAZAKHSTAN	{"url": "https://kaspi.kz", "email": "office@kaspi.kz", "phone": "+7 (727) 258-59-65"}
156	BKCHCNBJ	BANK OF CHINA	1 FUXINGMEN NEI DAJIE, BEIJING 100818, CHINA	{"url": "www.bankofchina.com", "phone": "(86) 010-66596688"}
356	SBININBBXXX	STATE BANK OF INDIA	MADAM CAMA ROAD C.O. 10121, MUMBAI, INDIA	{"url": "https://sbi.co.in/", "phone": "+91-80-26599990"}
\.


--
-- Data for Name: branches; Type: TABLE DATA; Schema: bank; Owner: postgres
--

COPY bank.branches (branch_id, head, address, region, phone) FROM stdin;
0	183	ул. Ленина, д. 90, Москва	Москва	+79107573872
1	197	ул. Мира, д. 93, Москва	Москва	+79392907845
2	267	ул. Школьная, д. 1, Санкт-Петербург	Санкт-Петербург	+79169080689
3	255	ул. Ленина, д. 96, Санкт-Петербург	Санкт-Петербург	+79798722456
4	172	ул. Молодежная, д. 95, Новосибирск	Новосибирская область	+79513493409
5	25	ул. Центральная, д. 49, Екатеринбург	Свердловская область	+79437443739
6	178	ул. Ленина, д. 16, Нижний Новгород	Нижегородская область	+79101799518
7	69	ул. Центральная, д. 66, Казань	Республика Татарстан	+79948127438
8	162	ул. Гагарина, д. 61, Челябинск	Челябинская область	+79528160702
9	105	ул. Молодежная, д. 39, Омск	Омская область	+79913057134
10	206	ул. Кирова, д. 36, Самара	Самарская область	+79130052220
11	45	ул. Заводская, д. 38, Ростов-на-Дону	Ростовская область	+79909904304
12	234	ул. Кирова, д. 16, Уфа	Республика Башкортостан	+79552779355
13	116	ул. Кирова, д. 93, Красноярск	Красноярский край	+79930706768
14	24	ул. Молодежная, д. 99, Воронеж	Воронежская область	+79095661306
15	143	ул. Гагарина, д. 54, Пермь	Пермский край	+79884883120
16	211	ул. Пушкина, д. 96, Волгоград	Волгоградская область	+79141851664
17	125	ул. Пушкина, д. 100, Краснодар	Краснодарский край	+79446373451
18	254	ул. Ленина, д. 23, Саратов	Саратовская область	+79265984226
19	268	ул. Гагарина, д. 100, Тюмень	Тюменская область	+79603458109
20	144	ул. Молодежная, д. 66, Тольятти	Самарская область	+79916837698
21	145	ул. Заводская, д. 81, Ижевск	Удмуртская Республика	+79550652882
22	193	ул. Заводская, д. 74, Барнаул	Алтайский край	+79032225613
23	284	ул. Заводская, д. 73, Ульяновск	Ульяновская область	+79621220368
24	218	ул. Советская, д. 66, Иркутск	Иркутская область	+79787323991
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: bank; Owner: postgres
--

COPY bank.clients (client_id, name, address, passport, inn, phone, contact_info, client_type, status) FROM stdin;
1	Соколов Дмитрий	г. Хабаровск, ул. Мира, д. 32	7240 583456	814337967707	+78521669886	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
2	Смирнов Сергей	г. Ставрополь, ул. Гагарина, д. 95	9269 716261	337823490330	+77068469731	{"email": "alex@example.com", "telegram": "@example"}	юридическое лицо	неактивный
3	Федоров Андрей	г. Москва, ул. Молодежная, д. 87	1414 662694	651192511646	+77642155099	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	активный
4	Смирнов Андрей	г. Омск, ул. Ленина, д. 69	6899 296039	179408709946	+77418446246	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	активный
5	Васильев Владимир	г. Санкт-Петербург, ул. Садовая, д. 28	7377 317367	660859580867	+72977455787	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
6	Федоров Александр	г. Москва, ул. Школьная, д. 99	3180 676997	791834404899	+73925842980	{"email": "alex@example.com", "telegram": "@example"}	юридическое лицо	неактивный
7	Попов Алексей	г. Санкт-Петербург, ул. Новая, д. 18	8469 192851	495342647903	+77898798785	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	неактивный
8	Петров Иван	г. Москва, ул. Школьная, д. 4	4894 727118	985116805088	+78654277108	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	активный
9	Попов Артем	г. Москва, ул. Молодежная, д. 53	8759 665192	592433087324	+74885885846	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	активный
10	Васильев Дмитрий	г. Хабаровск, ул. Новая, д. 33	6784 563899	575142071983	+77441560261	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	неактивный
11	Федоров Иван	г. Санкт-Петербург, ул. Молодежная, д. 63	4992 392076	778929979560	+79684375117	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
12	Петров Сергей	г. Санкт-Петербург, ул. Лесная, д. 63	8910 399722	378765029003	+77853043814	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
13	Кузнецов Александр	г. Ставрополь, ул. Молодежная, д. 50	7378 527911	879066276437	+71483876650	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	активный
14	Кузнецов Павел	г. Москва, ул. Новая, д. 78	9625 112308	794745750657	+71749478370	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	неактивный
15	Морозов Иван	г. Москва, ул. Лесная, д. 65	3183 610397	577885652988	+72867527571	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
16	Морозов Павел	г. Санкт-Петербург, ул. Садовая, д. 61	3619 676406	319733690137	+76845182566	{"email": "alex@example.com", "telegram": "@example"}	физическое лицо	неактивный
17	Петров Сергей	г. Санкт-Петербург, ул. Садовая, д. 76	7071 326930	133740779194	+72175386481	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	активный
18	Петров Андрей	г. Хабаровск, ул. Молодежная, д. 97	6957 943301	723043284403	+73036905702	{"email": "alex@example.com", "telegram": "@example"}	физическое лицо	неактивный
19	Морозов Дмитрий	г. Хабаровск, ул. Садовая, д. 99	9563 593746	374780918731	+76083008979	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	активный
20	Соколов Алексей	г. Москва, ул. Мира, д. 72	1919 575086	955973099589	+71325671821	{"email": "alex@example.com", "telegram": "@example"}	физическое лицо	неактивный
21	Михайлов Павел	г. Ставрополь, ул. Центральная, д. 7	5072 436767	107519175909	+77490558824	{"email": "alex@example.com", "telegram": "@example"}	юридическое лицо	неактивный
22	Смирнов Владимир	г. Москва, ул. Садовая, д. 85	5907 165399	257592836130	+73128307158	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	активный
23	Кузнецов Сергей	г. Москва, ул. Гагарина, д. 59	9193 893083	361298765138	+75791061339	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	активный
24	Васильев Иван	г. Омск, ул. Мира, д. 12	8115 632907	889369441163	+74005219358	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	неактивный
25	Морозов Дмитрий	г. Санкт-Петербург, ул. Гагарина, д. 57	6694 263386	590533083593	+76263026800	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
26	Смирнов Алексей	г. Хабаровск, ул. Молодежная, д. 51	7341 278373	445414967940	+78949248823	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
27	Васильев Владимир	г. Хабаровск, ул. Молодежная, д. 24	4629 892510	589720712874	+77406405754	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	активный
28	Смирнов Александр	г. Москва, ул. Ленина, д. 75	6445 393731	517916136965	+76522403489	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
29	Федоров Дмитрий	г. Москва, ул. Новая, д. 36	7090 605633	846110375001	+78051932201	{"email": "alex@example.com", "telegram": "@example"}	физическое лицо	неактивный
30	Морозов Андрей	г. Ставрополь, ул. Школьная, д. 36	2149 482620	805256564995	+76686684124	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	активный
31	Михайлов Павел	г. Хабаровск, ул. Новая, д. 11	1307 378777	608752001729	+74863945013	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
32	Кузнецов Павел	г. Хабаровск, ул. Мира, д. 47	8328 292266	644732683113	+78392193646	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
33	Иванов Андрей	г. Москва, ул. Центральная, д. 21	5271 892931	619520985199	+76161345645	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
34	Васильев Сергей	г. Санкт-Петербург, ул. Школьная, д. 64	1555 841831	785149056002	+74005945828	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	неактивный
35	Васильев Дмитрий	г. Хабаровск, ул. Центральная, д. 9	9113 971547	732216040965	+71683137552	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	неактивный
36	Петров Иван	г. Санкт-Петербург, ул. Молодежная, д. 97	3928 329707	272879806761	+75929563612	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	неактивный
37	Васильев Михаил	г. Санкт-Петербург, ул. Молодежная, д. 8	1024 650743	987193346993	+77217139520	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	неактивный
38	Морозов Александр	г. Омск, ул. Ленина, д. 71	8573 401971	135888756357	+71003528104	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	неактивный
39	Федоров Алексей	г. Москва, ул. Лесная, д. 23	9316 140103	724817985618	+73268603823	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	неактивный
40	Кузнецов Михаил	г. Москва, ул. Ленина, д. 2	6722 371370	629968742267	+71960284883	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	активный
41	Смирнов Алексей	г. Омск, ул. Мира, д. 84	5418 561713	229314154648	+74777494610	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	активный
42	Попов Андрей	г. Москва, ул. Советская, д. 69	8270 268258	312981168646	+75379765216	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	активный
43	Михайлов Михаил	г. Омск, ул. Ленина, д. 86	1493 490333	626376418476	+78329705208	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	активный
44	Васильев Павел	г. Москва, ул. Молодежная, д. 41	6356 603624	216018275223	+74142191297	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	активный
45	Кузнецов Владимир	г. Ставрополь, ул. Новая, д. 23	5793 587211	321322902629	+78590581832	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	активный
46	Морозов Артем	г. Ставрополь, ул. Гагарина, д. 78	3962 662071	905015271556	+72765577406	{"email": "alex@example.com", "telegram": "@example"}	физическое лицо	активный
47	Смирнов Алексей	г. Ставрополь, ул. Центральная, д. 59	3384 115205	427545930760	+79243972116	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	активный
48	Попов Михаил	г. Омск, ул. Гагарина, д. 11	4221 225748	425215415851	+78002552101	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
49	Попов Сергей	г. Омск, ул. Центральная, д. 18	2348 257685	825903576185	+77456427591	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	активный
50	Михайлов Андрей	г. Омск, ул. Школьная, д. 83	9494 910155	599668662050	+71404145594	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	неактивный
51	Петров Александр	г. Омск, ул. Школьная, д. 3	1193 601249	603772550943	+77703424513	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	активный
52	Смирнов Павел	г. Санкт-Петербург, ул. Лесная, д. 7	2858 282962	251955137761	+72705190669	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	неактивный
53	Кузнецов Дмитрий	г. Хабаровск, ул. Центральная, д. 95	9664 537807	204629896349	+75570968405	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
54	Соколов Владимир	г. Хабаровск, ул. Молодежная, д. 21	6066 847253	199206691245	+71362533796	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	активный
55	Федоров Михаил	г. Москва, ул. Ленина, д. 51	6559 910123	180708203522	+79495178252	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
56	Петров Владимир	г. Омск, ул. Гагарина, д. 79	8127 915062	872934075660	+71137951060	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	неактивный
57	Попов Иван	г. Санкт-Петербург, ул. Новая, д. 66	4428 320231	687385805338	+77989182988	{"email": "alex@example.com", "telegram": "@example"}	юридическое лицо	активный
58	Кузнецов Артем	г. Санкт-Петербург, ул. Гагарина, д. 10	9873 904139	564842414076	+77416920731	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	активный
59	Соколов Владимир	г. Москва, ул. Советская, д. 28	7191 268730	965714555993	+71734871558	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	активный
60	Федоров Алексей	г. Омск, ул. Мира, д. 73	9820 692919	169091253253	+79797507606	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	неактивный
61	Соколов Дмитрий	г. Санкт-Петербург, ул. Школьная, д. 82	2324 975500	621752460841	+73927328767	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
62	Соколов Александр	г. Ставрополь, ул. Гагарина, д. 81	7639 253981	973029242741	+72319916583	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	активный
63	Михайлов Андрей	г. Санкт-Петербург, ул. Ленина, д. 70	6778 580770	464406799443	+71294514485	{"email": "alex@example.com", "telegram": "@example"}	юридическое лицо	активный
64	Попов Владимир	г. Ставрополь, ул. Садовая, д. 64	3955 150432	335139715872	+71621331240	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	активный
65	Морозов Алексей	г. Москва, ул. Молодежная, д. 91	6498 716797	516478270792	+72768742879	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
66	Михайлов Владимир	г. Санкт-Петербург, ул. Школьная, д. 5	9435 204566	995073852637	+74899189739	{"email": "alex@example.com", "telegram": "@example"}	физическое лицо	активный
67	Иванов Павел	г. Хабаровск, ул. Новая, д. 45	2217 593315	702202852280	+79373747597	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	активный
68	Михайлов Павел	г. Санкт-Петербург, ул. Мира, д. 60	2550 484673	814098842776	+75401141646	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
69	Попов Владимир	г. Хабаровск, ул. Ленина, д. 17	6370 872734	896138650657	+75529207839	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
70	Морозов Михаил	г. Москва, ул. Садовая, д. 17	7748 915724	281990665754	+73199006585	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
71	Морозов Андрей	г. Хабаровск, ул. Центральная, д. 4	2942 453779	676529859159	+79959643027	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	активный
72	Васильев Александр	г. Хабаровск, ул. Советская, д. 83	9355 431267	909790600705	+73795734391	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	активный
73	Попов Дмитрий	г. Омск, ул. Лесная, д. 4	2270 565417	972389338544	+72608914036	{"email": "alex@example.com", "telegram": "@example"}	юридическое лицо	неактивный
74	Петров Иван	г. Ставрополь, ул. Ленина, д. 41	2562 546209	481020054839	+73177257243	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	активный
75	Кузнецов Сергей	г. Хабаровск, ул. Молодежная, д. 30	4455 168240	523731525517	+73658837688	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	активный
76	Попов Сергей	г. Ставрополь, ул. Советская, д. 40	6271 394553	404160065231	+72962627446	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	активный
77	Петров Сергей	г. Хабаровск, ул. Лесная, д. 56	6674 177318	322335373606	+76066775901	{"email": "alex@example.com", "telegram": "@example"}	физическое лицо	неактивный
78	Смирнов Владимир	г. Ставрополь, ул. Молодежная, д. 67	8531 496713	158881713020	+75309724519	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	неактивный
79	Попов Артем	г. Санкт-Петербург, ул. Лесная, д. 66	9036 320867	478668547058	+77294527769	{"email": "alex@example.com", "telegram": "@example"}	физическое лицо	активный
80	Михайлов Михаил	г. Санкт-Петербург, ул. Мира, д. 75	5951 143372	263291210373	+71341361193	{"email": "alex@example.com", "telegram": "@example"}	юридическое лицо	активный
81	Васильев Иван	г. Омск, ул. Школьная, д. 86	9471 606394	676114878154	+77450905759	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	активный
82	Морозов Дмитрий	г. Санкт-Петербург, ул. Центральная, д. 60	1201 868718	749790202077	+76915918251	{"email": "dmitry@example.com", "telegram": "@example"}	юридическое лицо	активный
83	Иванов Алексей	г. Хабаровск, ул. Центральная, д. 28	9574 785583	196009906849	+71968451458	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	активный
84	Михайлов Владимир	г. Санкт-Петербург, ул. Молодежная, д. 90	4011 280207	217665650915	+79337821365	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	активный
85	Михайлов Александр	г. Ставрополь, ул. Лесная, д. 85	6841 225937	964072361966	+77172972603	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	активный
86	Федоров Артем	г. Омск, ул. Садовая, д. 43	5566 788273	516699913071	+74460703199	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	неактивный
87	Попов Иван	г. Омск, ул. Гагарина, д. 25	9544 533662	880279837499	+71116901069	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	неактивный
88	Смирнов Павел	г. Хабаровск, ул. Новая, д. 39	8838 917831	226876507542	+75286708932	{"email": "sergey@example.com", "telegram": "@example"}	физическое лицо	активный
89	Морозов Иван	г. Санкт-Петербург, ул. Мира, д. 15	4361 885822	812596773409	+73314207237	{"email": "alex@example.com", "telegram": "@example"}	физическое лицо	активный
90	Смирнов Павел	г. Хабаровск, ул. Гагарина, д. 69	2913 871570	514441375563	+78897004753	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	активный
91	Кузнецов Алексей	г. Хабаровск, ул. Лесная, д. 54	6680 417020	242200500767	+75590169632	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	неактивный
92	Морозов Иван	г. Ставрополь, ул. Школьная, д. 87	3956 818392	790273953600	+77766736589	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
93	Соколов Артем	г. Омск, ул. Школьная, д. 97	3179 830566	390949956213	+75021445434	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	активный
94	Попов Сергей	г. Ставрополь, ул. Ленина, д. 90	2854 167807	407079211474	+72173116538	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	активный
95	Смирнов Павел	г. Ставрополь, ул. Школьная, д. 6	6448 576308	947023887332	+77308186388	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	неактивный
96	Васильев Алексей	г. Санкт-Петербург, ул. Садовая, д. 91	3471 142446	200853795014	+71844558292	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	активный
97	Морозов Владимир	г. Омск, ул. Центральная, д. 87	7375 510597	177581668714	+72756121897	{"email": "ivan@example.com", "telegram": "@example"}	физическое лицо	неактивный
98	Иванов Алексей	г. Санкт-Петербург, ул. Лесная, д. 76	2852 218648	112868056647	+74309062198	{"email": "sergey@example.com", "telegram": "@example"}	юридическое лицо	активный
99	Иванов Сергей	г. Москва, ул. Лесная, д. 43	5711 132924	469132223213	+76076907406	{"email": "ivan@example.com", "telegram": "@example"}	юридическое лицо	активный
100	Иванов Алексей	г. Ставрополь, ул. Новая, д. 51	2426 109588	716193683879	+71006945776	{"email": "dmitry@example.com", "telegram": "@example"}	физическое лицо	неактивный
\.


--
-- Data for Name: daily_rates; Type: TABLE DATA; Schema: bank; Owner: postgres
--

COPY bank.daily_rates (cur_id, date, cur_name, rate_source, rate) FROM stdin;
156	2023-01-01	CNY	CBR	9.954054
356	2023-01-01	INR	CBR	0.584650
398	2023-01-01	KZT	CBR	0.106675
840	2023-01-01	USD	CBR	59.833670
978	2023-01-01	EUR	CBR	70.318873
643	2023-01-01	RUB	CBR	1.000000
156	2023-01-02	CNY	CBR	9.151119
356	2023-01-02	INR	CBR	0.469318
398	2023-01-02	KZT	CBR	0.070000
840	2023-01-02	USD	CBR	59.552093
978	2023-01-02	EUR	CBR	69.703925
643	2023-01-02	RUB	CBR	1.000000
156	2023-01-03	CNY	CBR	9.972728
356	2023-01-03	INR	CBR	1.137375
398	2023-01-03	KZT	CBR	0.511607
840	2023-01-03	USD	CBR	59.702990
978	2023-01-03	EUR	CBR	70.009934
643	2023-01-03	RUB	CBR	1.000000
156	2023-01-04	CNY	CBR	9.844039
356	2023-01-04	INR	CBR	1.238272
398	2023-01-04	KZT	CBR	0.103824
840	2023-01-04	USD	CBR	59.650204
978	2023-01-04	EUR	CBR	70.287703
643	2023-01-04	RUB	CBR	1.000000
156	2023-01-05	CNY	CBR	9.787308
356	2023-01-05	INR	CBR	0.569690
398	2023-01-05	KZT	CBR	0.070000
840	2023-01-05	USD	CBR	59.509028
978	2023-01-05	EUR	CBR	70.043332
643	2023-01-05	RUB	CBR	1.000000
156	2023-01-06	CNY	CBR	9.904001
356	2023-01-06	INR	CBR	1.321758
398	2023-01-06	KZT	CBR	0.070000
840	2023-01-06	USD	CBR	59.811589
978	2023-01-06	EUR	CBR	69.645307
643	2023-01-06	RUB	CBR	1.000000
156	2023-01-07	CNY	CBR	9.410146
356	2023-01-07	INR	CBR	1.218101
398	2023-01-07	KZT	CBR	0.231558
840	2023-01-07	USD	CBR	59.689511
978	2023-01-07	EUR	CBR	69.837992
643	2023-01-07	RUB	CBR	1.000000
156	2023-01-08	CNY	CBR	9.180147
356	2023-01-08	INR	CBR	0.860623
398	2023-01-08	KZT	CBR	0.070000
840	2023-01-08	USD	CBR	60.418293
978	2023-01-08	EUR	CBR	70.242098
643	2023-01-08	RUB	CBR	1.000000
156	2023-01-09	CNY	CBR	9.423872
356	2023-01-09	INR	CBR	0.659261
398	2023-01-09	KZT	CBR	0.522093
840	2023-01-09	USD	CBR	59.766419
978	2023-01-09	EUR	CBR	69.531606
643	2023-01-09	RUB	CBR	1.000000
156	2023-01-10	CNY	CBR	9.283861
356	2023-01-10	INR	CBR	0.820797
398	2023-01-10	KZT	CBR	0.379085
840	2023-01-10	USD	CBR	59.908953
978	2023-01-10	EUR	CBR	69.958649
643	2023-01-10	RUB	CBR	1.000000
156	2023-01-11	CNY	CBR	9.203229
356	2023-01-11	INR	CBR	0.953395
398	2023-01-11	KZT	CBR	0.228322
840	2023-01-11	USD	CBR	59.568762
978	2023-01-11	EUR	CBR	69.744619
643	2023-01-11	RUB	CBR	1.000000
156	2023-01-12	CNY	CBR	9.752184
356	2023-01-12	INR	CBR	1.085220
398	2023-01-12	KZT	CBR	0.112159
840	2023-01-12	USD	CBR	59.886340
978	2023-01-12	EUR	CBR	70.146872
643	2023-01-12	RUB	CBR	1.000000
156	2023-01-13	CNY	CBR	9.274268
356	2023-01-13	INR	CBR	0.448865
398	2023-01-13	KZT	CBR	0.437479
840	2023-01-13	USD	CBR	59.675001
978	2023-01-13	EUR	CBR	70.217465
643	2023-01-13	RUB	CBR	1.000000
156	2023-01-14	CNY	CBR	9.675751
356	2023-01-14	INR	CBR	0.468454
398	2023-01-14	KZT	CBR	0.070000
840	2023-01-14	USD	CBR	59.540592
978	2023-01-14	EUR	CBR	69.934084
643	2023-01-14	RUB	CBR	1.000000
156	2023-01-15	CNY	CBR	9.893163
356	2023-01-15	INR	CBR	0.675849
398	2023-01-15	KZT	CBR	0.343537
840	2023-01-15	USD	CBR	60.423964
978	2023-01-15	EUR	CBR	70.069482
643	2023-01-15	RUB	CBR	1.000000
156	2023-01-16	CNY	CBR	9.384485
356	2023-01-16	INR	CBR	1.341943
398	2023-01-16	KZT	CBR	0.070000
840	2023-01-16	USD	CBR	60.039443
978	2023-01-16	EUR	CBR	70.460352
643	2023-01-16	RUB	CBR	1.000000
156	2023-01-17	CNY	CBR	9.161483
356	2023-01-17	INR	CBR	1.136759
398	2023-01-17	KZT	CBR	0.070000
840	2023-01-17	USD	CBR	60.392892
978	2023-01-17	EUR	CBR	70.439594
643	2023-01-17	RUB	CBR	1.000000
156	2023-01-18	CNY	CBR	9.692671
356	2023-01-18	INR	CBR	0.769107
398	2023-01-18	KZT	CBR	0.070000
840	2023-01-18	USD	CBR	59.606179
978	2023-01-18	EUR	CBR	69.630925
643	2023-01-18	RUB	CBR	1.000000
156	2023-01-19	CNY	CBR	9.682986
356	2023-01-19	INR	CBR	0.897662
398	2023-01-19	KZT	CBR	0.070000
840	2023-01-19	USD	CBR	60.078144
978	2023-01-19	EUR	CBR	70.123120
643	2023-01-19	RUB	CBR	1.000000
156	2023-01-20	CNY	CBR	9.917316
356	2023-01-20	INR	CBR	1.289758
398	2023-01-20	KZT	CBR	0.070000
840	2023-01-20	USD	CBR	60.239676
978	2023-01-20	EUR	CBR	70.317846
643	2023-01-20	RUB	CBR	1.000000
156	2023-01-21	CNY	CBR	9.237396
356	2023-01-21	INR	CBR	0.605007
398	2023-01-21	KZT	CBR	0.391133
840	2023-01-21	USD	CBR	60.250766
978	2023-01-21	EUR	CBR	70.298949
643	2023-01-21	RUB	CBR	1.000000
156	2023-01-22	CNY	CBR	9.697706
356	2023-01-22	INR	CBR	0.459013
398	2023-01-22	KZT	CBR	0.399422
840	2023-01-22	USD	CBR	60.293437
978	2023-01-22	EUR	CBR	70.251530
643	2023-01-22	RUB	CBR	1.000000
156	2023-01-23	CNY	CBR	9.979648
356	2023-01-23	INR	CBR	0.606493
398	2023-01-23	KZT	CBR	0.125983
840	2023-01-23	USD	CBR	60.056638
978	2023-01-23	EUR	CBR	70.266497
643	2023-01-23	RUB	CBR	1.000000
156	2023-01-24	CNY	CBR	9.691614
356	2023-01-24	INR	CBR	0.615952
398	2023-01-24	KZT	CBR	0.335632
840	2023-01-24	USD	CBR	59.667409
978	2023-01-24	EUR	CBR	70.237981
643	2023-01-24	RUB	CBR	1.000000
156	2023-01-25	CNY	CBR	9.994145
356	2023-01-25	INR	CBR	1.151513
398	2023-01-25	KZT	CBR	0.109261
840	2023-01-25	USD	CBR	59.805282
978	2023-01-25	EUR	CBR	70.091973
643	2023-01-25	RUB	CBR	1.000000
156	2023-01-26	CNY	CBR	9.764373
356	2023-01-26	INR	CBR	1.232156
398	2023-01-26	KZT	CBR	0.625369
840	2023-01-26	USD	CBR	59.776193
978	2023-01-26	EUR	CBR	69.928218
643	2023-01-26	RUB	CBR	1.000000
156	2023-01-27	CNY	CBR	9.498752
356	2023-01-27	INR	CBR	0.942013
398	2023-01-27	KZT	CBR	0.216243
840	2023-01-27	USD	CBR	60.011328
978	2023-01-27	EUR	CBR	70.316984
643	2023-01-27	RUB	CBR	1.000000
156	2023-01-28	CNY	CBR	9.066267
356	2023-01-28	INR	CBR	0.548267
398	2023-01-28	KZT	CBR	0.114227
840	2023-01-28	USD	CBR	59.637860
978	2023-01-28	EUR	CBR	70.098860
643	2023-01-28	RUB	CBR	1.000000
156	2023-01-29	CNY	CBR	9.854515
356	2023-01-29	INR	CBR	1.040811
398	2023-01-29	KZT	CBR	0.527875
840	2023-01-29	USD	CBR	59.829966
978	2023-01-29	EUR	CBR	70.273644
643	2023-01-29	RUB	CBR	1.000000
156	2023-01-30	CNY	CBR	9.090249
356	2023-01-30	INR	CBR	1.023925
398	2023-01-30	KZT	CBR	0.070000
840	2023-01-30	USD	CBR	59.673142
978	2023-01-30	EUR	CBR	69.610123
643	2023-01-30	RUB	CBR	1.000000
156	2023-01-31	CNY	CBR	9.871451
356	2023-01-31	INR	CBR	0.900034
398	2023-01-31	KZT	CBR	0.070000
840	2023-01-31	USD	CBR	60.314952
978	2023-01-31	EUR	CBR	70.365960
643	2023-01-31	RUB	CBR	1.000000
156	2023-02-01	CNY	CBR	9.120310
356	2023-02-01	INR	CBR	0.807545
398	2023-02-01	KZT	CBR	0.070000
840	2023-02-01	USD	CBR	60.237003
978	2023-02-01	EUR	CBR	69.889167
643	2023-02-01	RUB	CBR	1.000000
156	2023-02-02	CNY	CBR	9.616269
356	2023-02-02	INR	CBR	1.177605
398	2023-02-02	KZT	CBR	0.350306
840	2023-02-02	USD	CBR	60.144806
978	2023-02-02	EUR	CBR	69.986038
643	2023-02-02	RUB	CBR	1.000000
156	2023-02-03	CNY	CBR	9.413319
356	2023-02-03	INR	CBR	0.582791
398	2023-02-03	KZT	CBR	0.110691
840	2023-02-03	USD	CBR	60.437039
978	2023-02-03	EUR	CBR	69.850709
643	2023-02-03	RUB	CBR	1.000000
156	2023-02-04	CNY	CBR	9.212271
356	2023-02-04	INR	CBR	0.690961
398	2023-02-04	KZT	CBR	0.070000
840	2023-02-04	USD	CBR	60.234566
978	2023-02-04	EUR	CBR	70.079035
643	2023-02-04	RUB	CBR	1.000000
156	2023-02-05	CNY	CBR	9.758973
356	2023-02-05	INR	CBR	0.833883
398	2023-02-05	KZT	CBR	0.320028
840	2023-02-05	USD	CBR	60.318827
978	2023-02-05	EUR	CBR	70.000077
643	2023-02-05	RUB	CBR	1.000000
156	2023-02-06	CNY	CBR	9.508651
356	2023-02-06	INR	CBR	0.805891
398	2023-02-06	KZT	CBR	0.070000
840	2023-02-06	USD	CBR	60.290272
978	2023-02-06	EUR	CBR	70.414497
643	2023-02-06	RUB	CBR	1.000000
156	2023-02-07	CNY	CBR	9.384986
356	2023-02-07	INR	CBR	1.013657
398	2023-02-07	KZT	CBR	0.070000
840	2023-02-07	USD	CBR	59.531220
978	2023-02-07	EUR	CBR	70.046655
643	2023-02-07	RUB	CBR	1.000000
156	2023-02-08	CNY	CBR	9.733704
356	2023-02-08	INR	CBR	0.823386
398	2023-02-08	KZT	CBR	0.610509
840	2023-02-08	USD	CBR	60.377753
978	2023-02-08	EUR	CBR	69.917629
643	2023-02-08	RUB	CBR	1.000000
156	2023-02-09	CNY	CBR	9.118107
356	2023-02-09	INR	CBR	1.069803
398	2023-02-09	KZT	CBR	0.070000
840	2023-02-09	USD	CBR	60.017091
978	2023-02-09	EUR	CBR	70.276984
643	2023-02-09	RUB	CBR	1.000000
156	2023-02-10	CNY	CBR	9.542752
356	2023-02-10	INR	CBR	0.463148
398	2023-02-10	KZT	CBR	0.070000
840	2023-02-10	USD	CBR	60.060138
978	2023-02-10	EUR	CBR	69.831377
643	2023-02-10	RUB	CBR	1.000000
156	2023-02-11	CNY	CBR	9.743263
356	2023-02-11	INR	CBR	0.530620
398	2023-02-11	KZT	CBR	0.070000
840	2023-02-11	USD	CBR	60.244611
978	2023-02-11	EUR	CBR	69.980573
643	2023-02-11	RUB	CBR	1.000000
156	2023-02-12	CNY	CBR	9.906050
356	2023-02-12	INR	CBR	0.501036
398	2023-02-12	KZT	CBR	0.070000
840	2023-02-12	USD	CBR	60.347126
978	2023-02-12	EUR	CBR	69.704327
643	2023-02-12	RUB	CBR	1.000000
156	2023-02-13	CNY	CBR	9.724567
356	2023-02-13	INR	CBR	0.557199
398	2023-02-13	KZT	CBR	0.070000
840	2023-02-13	USD	CBR	59.841345
978	2023-02-13	EUR	CBR	69.661953
643	2023-02-13	RUB	CBR	1.000000
156	2023-02-14	CNY	CBR	9.158365
356	2023-02-14	INR	CBR	0.405374
398	2023-02-14	KZT	CBR	0.581650
840	2023-02-14	USD	CBR	60.135240
978	2023-02-14	EUR	CBR	70.497291
643	2023-02-14	RUB	CBR	1.000000
156	2023-02-15	CNY	CBR	9.715969
356	2023-02-15	INR	CBR	1.133175
398	2023-02-15	KZT	CBR	0.285426
840	2023-02-15	USD	CBR	60.144883
978	2023-02-15	EUR	CBR	70.124914
643	2023-02-15	RUB	CBR	1.000000
156	2023-02-16	CNY	CBR	9.520444
356	2023-02-16	INR	CBR	1.002427
398	2023-02-16	KZT	CBR	0.070000
840	2023-02-16	USD	CBR	60.232026
978	2023-02-16	EUR	CBR	70.307327
643	2023-02-16	RUB	CBR	1.000000
156	2023-02-17	CNY	CBR	9.209241
356	2023-02-17	INR	CBR	0.665256
398	2023-02-17	KZT	CBR	0.480199
840	2023-02-17	USD	CBR	59.981247
978	2023-02-17	EUR	CBR	70.400853
643	2023-02-17	RUB	CBR	1.000000
156	2023-02-18	CNY	CBR	9.689511
356	2023-02-18	INR	CBR	0.765319
398	2023-02-18	KZT	CBR	0.623105
840	2023-02-18	USD	CBR	59.636427
978	2023-02-18	EUR	CBR	70.137222
643	2023-02-18	RUB	CBR	1.000000
156	2023-02-19	CNY	CBR	9.145985
356	2023-02-19	INR	CBR	0.812087
398	2023-02-19	KZT	CBR	0.627798
840	2023-02-19	USD	CBR	59.720932
978	2023-02-19	EUR	CBR	69.733042
643	2023-02-19	RUB	CBR	1.000000
156	2023-02-20	CNY	CBR	9.524429
356	2023-02-20	INR	CBR	0.643456
398	2023-02-20	KZT	CBR	0.070000
840	2023-02-20	USD	CBR	59.857660
978	2023-02-20	EUR	CBR	70.234434
643	2023-02-20	RUB	CBR	1.000000
156	2023-02-21	CNY	CBR	9.790958
356	2023-02-21	INR	CBR	0.971782
398	2023-02-21	KZT	CBR	0.526923
840	2023-02-21	USD	CBR	59.536265
978	2023-02-21	EUR	CBR	69.778846
643	2023-02-21	RUB	CBR	1.000000
156	2023-02-22	CNY	CBR	9.687161
356	2023-02-22	INR	CBR	0.898607
398	2023-02-22	KZT	CBR	0.389565
840	2023-02-22	USD	CBR	60.482077
978	2023-02-22	EUR	CBR	70.085177
643	2023-02-22	RUB	CBR	1.000000
156	2023-02-23	CNY	CBR	9.392935
356	2023-02-23	INR	CBR	0.539771
398	2023-02-23	KZT	CBR	0.070000
840	2023-02-23	USD	CBR	59.613091
978	2023-02-23	EUR	CBR	69.766964
643	2023-02-23	RUB	CBR	1.000000
156	2023-02-24	CNY	CBR	9.638172
356	2023-02-24	INR	CBR	1.327763
398	2023-02-24	KZT	CBR	0.070000
840	2023-02-24	USD	CBR	59.520692
978	2023-02-24	EUR	CBR	69.816727
643	2023-02-24	RUB	CBR	1.000000
156	2023-02-25	CNY	CBR	9.415029
356	2023-02-25	INR	CBR	0.815205
398	2023-02-25	KZT	CBR	0.199055
840	2023-02-25	USD	CBR	59.548446
978	2023-02-25	EUR	CBR	70.442058
643	2023-02-25	RUB	CBR	1.000000
156	2023-02-26	CNY	CBR	9.934795
356	2023-02-26	INR	CBR	0.486498
398	2023-02-26	KZT	CBR	0.198644
840	2023-02-26	USD	CBR	59.667823
978	2023-02-26	EUR	CBR	70.216015
643	2023-02-26	RUB	CBR	1.000000
156	2023-02-27	CNY	CBR	9.616530
356	2023-02-27	INR	CBR	1.352431
398	2023-02-27	KZT	CBR	0.558326
840	2023-02-27	USD	CBR	60.148790
978	2023-02-27	EUR	CBR	69.557994
643	2023-02-27	RUB	CBR	1.000000
156	2023-02-28	CNY	CBR	9.507868
356	2023-02-28	INR	CBR	0.894141
398	2023-02-28	KZT	CBR	0.628242
840	2023-02-28	USD	CBR	59.961429
978	2023-02-28	EUR	CBR	70.176145
643	2023-02-28	RUB	CBR	1.000000
156	2023-03-01	CNY	CBR	9.562637
356	2023-03-01	INR	CBR	0.887099
398	2023-03-01	KZT	CBR	0.284714
840	2023-03-01	USD	CBR	59.747146
978	2023-03-01	EUR	CBR	70.185359
643	2023-03-01	RUB	CBR	1.000000
156	2023-03-02	CNY	CBR	9.102458
356	2023-03-02	INR	CBR	0.948262
398	2023-03-02	KZT	CBR	0.070000
840	2023-03-02	USD	CBR	60.472336
978	2023-03-02	EUR	CBR	69.713366
643	2023-03-02	RUB	CBR	1.000000
156	2023-03-03	CNY	CBR	9.806864
356	2023-03-03	INR	CBR	0.836678
398	2023-03-03	KZT	CBR	0.070000
840	2023-03-03	USD	CBR	59.755809
978	2023-03-03	EUR	CBR	70.310670
643	2023-03-03	RUB	CBR	1.000000
156	2023-03-04	CNY	CBR	9.955279
356	2023-03-04	INR	CBR	1.067847
398	2023-03-04	KZT	CBR	0.070000
840	2023-03-04	USD	CBR	60.077639
978	2023-03-04	EUR	CBR	70.238835
643	2023-03-04	RUB	CBR	1.000000
156	2023-03-05	CNY	CBR	9.827074
356	2023-03-05	INR	CBR	1.349027
398	2023-03-05	KZT	CBR	0.204515
840	2023-03-05	USD	CBR	60.473753
978	2023-03-05	EUR	CBR	69.589383
643	2023-03-05	RUB	CBR	1.000000
156	2023-03-06	CNY	CBR	9.913523
356	2023-03-06	INR	CBR	0.676185
398	2023-03-06	KZT	CBR	0.070000
840	2023-03-06	USD	CBR	59.846108
978	2023-03-06	EUR	CBR	70.142423
643	2023-03-06	RUB	CBR	1.000000
156	2023-03-07	CNY	CBR	9.177794
356	2023-03-07	INR	CBR	0.935360
398	2023-03-07	KZT	CBR	0.070000
840	2023-03-07	USD	CBR	60.400076
978	2023-03-07	EUR	CBR	70.175644
643	2023-03-07	RUB	CBR	1.000000
156	2023-03-08	CNY	CBR	9.689732
356	2023-03-08	INR	CBR	0.564114
398	2023-03-08	KZT	CBR	0.565798
840	2023-03-08	USD	CBR	59.697853
978	2023-03-08	EUR	CBR	70.194371
643	2023-03-08	RUB	CBR	1.000000
156	2023-03-09	CNY	CBR	9.831366
356	2023-03-09	INR	CBR	0.732900
398	2023-03-09	KZT	CBR	0.252583
840	2023-03-09	USD	CBR	59.736793
978	2023-03-09	EUR	CBR	69.746448
643	2023-03-09	RUB	CBR	1.000000
156	2023-03-10	CNY	CBR	9.916519
356	2023-03-10	INR	CBR	0.738796
398	2023-03-10	KZT	CBR	0.070000
840	2023-03-10	USD	CBR	60.246792
978	2023-03-10	EUR	CBR	70.215914
643	2023-03-10	RUB	CBR	1.000000
156	2023-03-11	CNY	CBR	9.010493
356	2023-03-11	INR	CBR	1.083587
398	2023-03-11	KZT	CBR	0.105740
840	2023-03-11	USD	CBR	59.593809
978	2023-03-11	EUR	CBR	70.299854
643	2023-03-11	RUB	CBR	1.000000
156	2023-03-12	CNY	CBR	9.911480
356	2023-03-12	INR	CBR	1.120638
398	2023-03-12	KZT	CBR	0.205245
840	2023-03-12	USD	CBR	59.789170
978	2023-03-12	EUR	CBR	70.382434
643	2023-03-12	RUB	CBR	1.000000
156	2023-03-13	CNY	CBR	9.300952
356	2023-03-13	INR	CBR	0.517894
398	2023-03-13	KZT	CBR	0.070000
840	2023-03-13	USD	CBR	59.622149
978	2023-03-13	EUR	CBR	70.329309
643	2023-03-13	RUB	CBR	1.000000
156	2023-03-14	CNY	CBR	9.970185
356	2023-03-14	INR	CBR	0.410997
398	2023-03-14	KZT	CBR	0.409423
840	2023-03-14	USD	CBR	59.974922
978	2023-03-14	EUR	CBR	69.792758
643	2023-03-14	RUB	CBR	1.000000
156	2023-03-15	CNY	CBR	9.648294
356	2023-03-15	INR	CBR	0.778885
398	2023-03-15	KZT	CBR	0.592524
840	2023-03-15	USD	CBR	59.880910
978	2023-03-15	EUR	CBR	70.427295
643	2023-03-15	RUB	CBR	1.000000
156	2023-03-16	CNY	CBR	9.064725
356	2023-03-16	INR	CBR	1.071374
398	2023-03-16	KZT	CBR	0.202316
840	2023-03-16	USD	CBR	60.351405
978	2023-03-16	EUR	CBR	69.729968
643	2023-03-16	RUB	CBR	1.000000
156	2023-03-17	CNY	CBR	9.815398
356	2023-03-17	INR	CBR	0.652304
398	2023-03-17	KZT	CBR	0.143209
840	2023-03-17	USD	CBR	59.707128
978	2023-03-17	EUR	CBR	69.576910
643	2023-03-17	RUB	CBR	1.000000
156	2023-03-18	CNY	CBR	9.178456
356	2023-03-18	INR	CBR	0.544366
398	2023-03-18	KZT	CBR	0.070000
840	2023-03-18	USD	CBR	59.676769
978	2023-03-18	EUR	CBR	69.939326
643	2023-03-18	RUB	CBR	1.000000
156	2023-03-19	CNY	CBR	9.688564
356	2023-03-19	INR	CBR	1.087459
398	2023-03-19	KZT	CBR	0.325819
840	2023-03-19	USD	CBR	60.320527
978	2023-03-19	EUR	CBR	70.032419
643	2023-03-19	RUB	CBR	1.000000
156	2023-03-20	CNY	CBR	9.963638
356	2023-03-20	INR	CBR	1.272831
398	2023-03-20	KZT	CBR	0.070000
840	2023-03-20	USD	CBR	60.021100
978	2023-03-20	EUR	CBR	69.531596
643	2023-03-20	RUB	CBR	1.000000
156	2023-03-21	CNY	CBR	9.732781
356	2023-03-21	INR	CBR	0.529636
398	2023-03-21	KZT	CBR	0.422486
840	2023-03-21	USD	CBR	59.550234
978	2023-03-21	EUR	CBR	69.550452
643	2023-03-21	RUB	CBR	1.000000
156	2023-03-22	CNY	CBR	9.624872
356	2023-03-22	INR	CBR	0.618008
398	2023-03-22	KZT	CBR	0.120917
840	2023-03-22	USD	CBR	59.881925
978	2023-03-22	EUR	CBR	69.872406
643	2023-03-22	RUB	CBR	1.000000
156	2023-03-23	CNY	CBR	9.302305
356	2023-03-23	INR	CBR	0.656263
398	2023-03-23	KZT	CBR	0.070000
840	2023-03-23	USD	CBR	60.446617
978	2023-03-23	EUR	CBR	70.360253
643	2023-03-23	RUB	CBR	1.000000
156	2023-03-24	CNY	CBR	9.890270
356	2023-03-24	INR	CBR	0.756774
398	2023-03-24	KZT	CBR	0.201764
840	2023-03-24	USD	CBR	59.666690
978	2023-03-24	EUR	CBR	70.471577
643	2023-03-24	RUB	CBR	1.000000
156	2023-03-25	CNY	CBR	9.082889
356	2023-03-25	INR	CBR	0.768918
398	2023-03-25	KZT	CBR	0.468522
840	2023-03-25	USD	CBR	60.102299
978	2023-03-25	EUR	CBR	69.838583
643	2023-03-25	RUB	CBR	1.000000
156	2023-03-26	CNY	CBR	9.390176
356	2023-03-26	INR	CBR	1.219945
398	2023-03-26	KZT	CBR	0.549198
840	2023-03-26	USD	CBR	59.596727
978	2023-03-26	EUR	CBR	69.735919
643	2023-03-26	RUB	CBR	1.000000
156	2023-03-27	CNY	CBR	9.698074
356	2023-03-27	INR	CBR	0.746541
398	2023-03-27	KZT	CBR	0.070000
840	2023-03-27	USD	CBR	59.691361
978	2023-03-27	EUR	CBR	69.987777
643	2023-03-27	RUB	CBR	1.000000
156	2023-03-28	CNY	CBR	9.953407
356	2023-03-28	INR	CBR	1.022247
398	2023-03-28	KZT	CBR	0.456982
840	2023-03-28	USD	CBR	59.867564
978	2023-03-28	EUR	CBR	69.993402
643	2023-03-28	RUB	CBR	1.000000
156	2023-03-29	CNY	CBR	9.661767
356	2023-03-29	INR	CBR	1.057859
398	2023-03-29	KZT	CBR	0.481661
840	2023-03-29	USD	CBR	60.030222
978	2023-03-29	EUR	CBR	69.829603
643	2023-03-29	RUB	CBR	1.000000
156	2023-03-30	CNY	CBR	9.648637
356	2023-03-30	INR	CBR	0.561387
398	2023-03-30	KZT	CBR	0.070000
840	2023-03-30	USD	CBR	59.939853
978	2023-03-30	EUR	CBR	69.701501
643	2023-03-30	RUB	CBR	1.000000
156	2023-03-31	CNY	CBR	9.318824
356	2023-03-31	INR	CBR	0.572989
398	2023-03-31	KZT	CBR	0.335863
840	2023-03-31	USD	CBR	60.120309
978	2023-03-31	EUR	CBR	70.303887
643	2023-03-31	RUB	CBR	1.000000
156	2023-04-01	CNY	CBR	9.053565
356	2023-04-01	INR	CBR	0.910956
398	2023-04-01	KZT	CBR	0.070000
840	2023-04-01	USD	CBR	60.199973
978	2023-04-01	EUR	CBR	69.975842
643	2023-04-01	RUB	CBR	1.000000
156	2023-04-02	CNY	CBR	9.555394
356	2023-04-02	INR	CBR	0.686825
398	2023-04-02	KZT	CBR	0.595009
840	2023-04-02	USD	CBR	59.589428
978	2023-04-02	EUR	CBR	70.145062
643	2023-04-02	RUB	CBR	1.000000
156	2023-04-03	CNY	CBR	9.163804
356	2023-04-03	INR	CBR	0.528650
398	2023-04-03	KZT	CBR	0.070000
840	2023-04-03	USD	CBR	59.658487
978	2023-04-03	EUR	CBR	69.684422
643	2023-04-03	RUB	CBR	1.000000
156	2023-04-04	CNY	CBR	9.998566
356	2023-04-04	INR	CBR	1.245476
398	2023-04-04	KZT	CBR	0.070000
840	2023-04-04	USD	CBR	59.913499
978	2023-04-04	EUR	CBR	70.299696
643	2023-04-04	RUB	CBR	1.000000
156	2023-04-05	CNY	CBR	9.375063
356	2023-04-05	INR	CBR	0.883679
398	2023-04-05	KZT	CBR	0.074645
840	2023-04-05	USD	CBR	59.536417
978	2023-04-05	EUR	CBR	70.489884
643	2023-04-05	RUB	CBR	1.000000
156	2023-04-06	CNY	CBR	9.027608
356	2023-04-06	INR	CBR	1.091062
398	2023-04-06	KZT	CBR	0.104321
840	2023-04-06	USD	CBR	60.435688
978	2023-04-06	EUR	CBR	69.828173
643	2023-04-06	RUB	CBR	1.000000
156	2023-04-07	CNY	CBR	9.688388
356	2023-04-07	INR	CBR	1.208507
398	2023-04-07	KZT	CBR	0.460683
840	2023-04-07	USD	CBR	60.229441
978	2023-04-07	EUR	CBR	69.674735
643	2023-04-07	RUB	CBR	1.000000
156	2023-04-08	CNY	CBR	9.252696
356	2023-04-08	INR	CBR	0.438381
398	2023-04-08	KZT	CBR	0.574544
840	2023-04-08	USD	CBR	59.831950
978	2023-04-08	EUR	CBR	69.846864
643	2023-04-08	RUB	CBR	1.000000
156	2023-04-09	CNY	CBR	9.684456
356	2023-04-09	INR	CBR	0.977644
398	2023-04-09	KZT	CBR	0.070000
840	2023-04-09	USD	CBR	60.466203
978	2023-04-09	EUR	CBR	70.001687
643	2023-04-09	RUB	CBR	1.000000
156	2023-04-10	CNY	CBR	9.137124
356	2023-04-10	INR	CBR	1.312026
398	2023-04-10	KZT	CBR	0.301774
840	2023-04-10	USD	CBR	59.918809
978	2023-04-10	EUR	CBR	69.576687
643	2023-04-10	RUB	CBR	1.000000
156	2023-04-11	CNY	CBR	9.303855
356	2023-04-11	INR	CBR	0.854826
398	2023-04-11	KZT	CBR	0.070000
840	2023-04-11	USD	CBR	59.679965
978	2023-04-11	EUR	CBR	69.786184
643	2023-04-11	RUB	CBR	1.000000
156	2023-04-12	CNY	CBR	9.248093
356	2023-04-12	INR	CBR	1.134623
398	2023-04-12	KZT	CBR	0.320215
840	2023-04-12	USD	CBR	60.191534
978	2023-04-12	EUR	CBR	70.074224
643	2023-04-12	RUB	CBR	1.000000
156	2023-04-13	CNY	CBR	9.906275
356	2023-04-13	INR	CBR	0.427763
398	2023-04-13	KZT	CBR	0.423141
840	2023-04-13	USD	CBR	59.790261
978	2023-04-13	EUR	CBR	70.228798
643	2023-04-13	RUB	CBR	1.000000
156	2023-04-14	CNY	CBR	9.535960
356	2023-04-14	INR	CBR	0.610055
398	2023-04-14	KZT	CBR	0.070000
840	2023-04-14	USD	CBR	60.027434
978	2023-04-14	EUR	CBR	69.561468
643	2023-04-14	RUB	CBR	1.000000
156	2023-04-15	CNY	CBR	9.666391
356	2023-04-15	INR	CBR	1.313494
398	2023-04-15	KZT	CBR	0.471847
840	2023-04-15	USD	CBR	60.261115
978	2023-04-15	EUR	CBR	70.213054
643	2023-04-15	RUB	CBR	1.000000
156	2023-04-16	CNY	CBR	9.789117
356	2023-04-16	INR	CBR	1.046360
398	2023-04-16	KZT	CBR	0.326298
840	2023-04-16	USD	CBR	60.104703
978	2023-04-16	EUR	CBR	69.735945
643	2023-04-16	RUB	CBR	1.000000
156	2023-04-17	CNY	CBR	9.845093
356	2023-04-17	INR	CBR	0.928159
398	2023-04-17	KZT	CBR	0.577283
840	2023-04-17	USD	CBR	59.839777
978	2023-04-17	EUR	CBR	70.087020
643	2023-04-17	RUB	CBR	1.000000
156	2023-04-18	CNY	CBR	9.948443
356	2023-04-18	INR	CBR	0.778906
398	2023-04-18	KZT	CBR	0.107487
840	2023-04-18	USD	CBR	59.976089
978	2023-04-18	EUR	CBR	69.904611
643	2023-04-18	RUB	CBR	1.000000
156	2023-04-19	CNY	CBR	9.185270
356	2023-04-19	INR	CBR	0.741774
398	2023-04-19	KZT	CBR	0.323360
840	2023-04-19	USD	CBR	59.832245
978	2023-04-19	EUR	CBR	69.585639
643	2023-04-19	RUB	CBR	1.000000
156	2023-04-20	CNY	CBR	9.295779
356	2023-04-20	INR	CBR	0.694873
398	2023-04-20	KZT	CBR	0.070000
840	2023-04-20	USD	CBR	59.738787
978	2023-04-20	EUR	CBR	70.328620
643	2023-04-20	RUB	CBR	1.000000
156	2023-04-21	CNY	CBR	9.609742
356	2023-04-21	INR	CBR	0.790917
398	2023-04-21	KZT	CBR	0.070000
840	2023-04-21	USD	CBR	59.759507
978	2023-04-21	EUR	CBR	69.783938
643	2023-04-21	RUB	CBR	1.000000
156	2023-04-22	CNY	CBR	9.623320
356	2023-04-22	INR	CBR	0.918316
398	2023-04-22	KZT	CBR	0.070000
840	2023-04-22	USD	CBR	60.237733
978	2023-04-22	EUR	CBR	70.104147
643	2023-04-22	RUB	CBR	1.000000
156	2023-04-23	CNY	CBR	9.949144
356	2023-04-23	INR	CBR	0.701280
398	2023-04-23	KZT	CBR	0.070000
840	2023-04-23	USD	CBR	60.451216
978	2023-04-23	EUR	CBR	70.093275
643	2023-04-23	RUB	CBR	1.000000
156	2023-04-24	CNY	CBR	9.187374
356	2023-04-24	INR	CBR	1.224190
398	2023-04-24	KZT	CBR	0.070000
840	2023-04-24	USD	CBR	59.693103
978	2023-04-24	EUR	CBR	69.568534
643	2023-04-24	RUB	CBR	1.000000
156	2023-04-25	CNY	CBR	9.278447
356	2023-04-25	INR	CBR	1.027957
398	2023-04-25	KZT	CBR	0.359430
840	2023-04-25	USD	CBR	60.186459
978	2023-04-25	EUR	CBR	69.501805
643	2023-04-25	RUB	CBR	1.000000
156	2023-04-26	CNY	CBR	9.915811
356	2023-04-26	INR	CBR	0.709883
398	2023-04-26	KZT	CBR	0.132489
840	2023-04-26	USD	CBR	59.950886
978	2023-04-26	EUR	CBR	69.742277
643	2023-04-26	RUB	CBR	1.000000
156	2023-04-27	CNY	CBR	9.479669
356	2023-04-27	INR	CBR	0.568721
398	2023-04-27	KZT	CBR	0.070000
840	2023-04-27	USD	CBR	59.767367
978	2023-04-27	EUR	CBR	70.399612
643	2023-04-27	RUB	CBR	1.000000
156	2023-04-28	CNY	CBR	9.672992
356	2023-04-28	INR	CBR	1.298772
398	2023-04-28	KZT	CBR	0.223791
840	2023-04-28	USD	CBR	60.177574
978	2023-04-28	EUR	CBR	70.340703
643	2023-04-28	RUB	CBR	1.000000
156	2023-04-29	CNY	CBR	9.537467
356	2023-04-29	INR	CBR	0.502118
398	2023-04-29	KZT	CBR	0.070000
840	2023-04-29	USD	CBR	59.787113
978	2023-04-29	EUR	CBR	70.225694
643	2023-04-29	RUB	CBR	1.000000
156	2023-04-30	CNY	CBR	9.654175
356	2023-04-30	INR	CBR	0.805507
398	2023-04-30	KZT	CBR	0.070000
840	2023-04-30	USD	CBR	59.779227
978	2023-04-30	EUR	CBR	70.290888
643	2023-04-30	RUB	CBR	1.000000
156	2023-05-01	CNY	CBR	9.387801
356	2023-05-01	INR	CBR	0.419689
398	2023-05-01	KZT	CBR	0.504343
840	2023-05-01	USD	CBR	59.742768
978	2023-05-01	EUR	CBR	69.678127
643	2023-05-01	RUB	CBR	1.000000
156	2023-05-02	CNY	CBR	9.924460
356	2023-05-02	INR	CBR	0.578612
398	2023-05-02	KZT	CBR	0.558948
840	2023-05-02	USD	CBR	60.426718
978	2023-05-02	EUR	CBR	69.952684
643	2023-05-02	RUB	CBR	1.000000
156	2023-05-03	CNY	CBR	9.973190
356	2023-05-03	INR	CBR	0.594080
398	2023-05-03	KZT	CBR	0.522787
840	2023-05-03	USD	CBR	59.923865
978	2023-05-03	EUR	CBR	69.575067
643	2023-05-03	RUB	CBR	1.000000
156	2023-05-04	CNY	CBR	9.518183
356	2023-05-04	INR	CBR	0.866660
398	2023-05-04	KZT	CBR	0.172677
840	2023-05-04	USD	CBR	59.999863
978	2023-05-04	EUR	CBR	70.459268
643	2023-05-04	RUB	CBR	1.000000
156	2023-05-05	CNY	CBR	9.830981
356	2023-05-05	INR	CBR	1.090500
398	2023-05-05	KZT	CBR	0.070000
840	2023-05-05	USD	CBR	59.523723
978	2023-05-05	EUR	CBR	69.957931
643	2023-05-05	RUB	CBR	1.000000
156	2023-05-06	CNY	CBR	9.017382
356	2023-05-06	INR	CBR	0.650430
398	2023-05-06	KZT	CBR	0.160749
840	2023-05-06	USD	CBR	60.012692
978	2023-05-06	EUR	CBR	70.037049
643	2023-05-06	RUB	CBR	1.000000
156	2023-05-07	CNY	CBR	9.930287
356	2023-05-07	INR	CBR	0.413292
398	2023-05-07	KZT	CBR	0.070000
840	2023-05-07	USD	CBR	60.171741
978	2023-05-07	EUR	CBR	69.961732
643	2023-05-07	RUB	CBR	1.000000
156	2023-05-08	CNY	CBR	9.520947
356	2023-05-08	INR	CBR	1.294410
398	2023-05-08	KZT	CBR	0.070000
840	2023-05-08	USD	CBR	59.698456
978	2023-05-08	EUR	CBR	70.074675
643	2023-05-08	RUB	CBR	1.000000
156	2023-05-09	CNY	CBR	9.653809
356	2023-05-09	INR	CBR	0.418365
398	2023-05-09	KZT	CBR	0.624047
840	2023-05-09	USD	CBR	60.483741
978	2023-05-09	EUR	CBR	69.551063
643	2023-05-09	RUB	CBR	1.000000
156	2023-05-10	CNY	CBR	9.458773
356	2023-05-10	INR	CBR	0.660454
398	2023-05-10	KZT	CBR	0.130684
840	2023-05-10	USD	CBR	59.947513
978	2023-05-10	EUR	CBR	70.143738
643	2023-05-10	RUB	CBR	1.000000
156	2023-05-11	CNY	CBR	9.905244
356	2023-05-11	INR	CBR	0.488183
398	2023-05-11	KZT	CBR	0.070000
840	2023-05-11	USD	CBR	59.582792
978	2023-05-11	EUR	CBR	70.000179
643	2023-05-11	RUB	CBR	1.000000
156	2023-05-12	CNY	CBR	9.541019
356	2023-05-12	INR	CBR	1.311758
398	2023-05-12	KZT	CBR	0.070000
840	2023-05-12	USD	CBR	60.335623
978	2023-05-12	EUR	CBR	69.588697
643	2023-05-12	RUB	CBR	1.000000
156	2023-05-13	CNY	CBR	9.269001
356	2023-05-13	INR	CBR	0.897319
398	2023-05-13	KZT	CBR	0.298516
840	2023-05-13	USD	CBR	60.414456
978	2023-05-13	EUR	CBR	70.445086
643	2023-05-13	RUB	CBR	1.000000
156	2023-05-14	CNY	CBR	9.403489
356	2023-05-14	INR	CBR	0.969977
398	2023-05-14	KZT	CBR	0.211892
840	2023-05-14	USD	CBR	60.025486
978	2023-05-14	EUR	CBR	69.946627
643	2023-05-14	RUB	CBR	1.000000
156	2023-05-15	CNY	CBR	9.501605
356	2023-05-15	INR	CBR	1.389563
398	2023-05-15	KZT	CBR	0.110082
840	2023-05-15	USD	CBR	60.213094
978	2023-05-15	EUR	CBR	70.261437
643	2023-05-15	RUB	CBR	1.000000
156	2023-05-16	CNY	CBR	9.261172
356	2023-05-16	INR	CBR	0.556406
398	2023-05-16	KZT	CBR	0.070000
840	2023-05-16	USD	CBR	59.801535
978	2023-05-16	EUR	CBR	69.781587
643	2023-05-16	RUB	CBR	1.000000
156	2023-05-17	CNY	CBR	9.404454
356	2023-05-17	INR	CBR	1.001194
398	2023-05-17	KZT	CBR	0.070000
840	2023-05-17	USD	CBR	60.227667
978	2023-05-17	EUR	CBR	69.886216
643	2023-05-17	RUB	CBR	1.000000
156	2023-05-18	CNY	CBR	9.555554
356	2023-05-18	INR	CBR	1.137037
398	2023-05-18	KZT	CBR	0.070000
840	2023-05-18	USD	CBR	60.382268
978	2023-05-18	EUR	CBR	70.023551
643	2023-05-18	RUB	CBR	1.000000
156	2023-05-19	CNY	CBR	9.103441
356	2023-05-19	INR	CBR	1.024392
398	2023-05-19	KZT	CBR	0.325458
840	2023-05-19	USD	CBR	60.211688
978	2023-05-19	EUR	CBR	69.871256
643	2023-05-19	RUB	CBR	1.000000
156	2023-05-20	CNY	CBR	9.612926
356	2023-05-20	INR	CBR	0.447897
398	2023-05-20	KZT	CBR	0.437844
840	2023-05-20	USD	CBR	59.804790
978	2023-05-20	EUR	CBR	69.635928
643	2023-05-20	RUB	CBR	1.000000
156	2023-05-21	CNY	CBR	9.301272
356	2023-05-21	INR	CBR	0.737716
398	2023-05-21	KZT	CBR	0.070000
840	2023-05-21	USD	CBR	59.894485
978	2023-05-21	EUR	CBR	70.175223
643	2023-05-21	RUB	CBR	1.000000
156	2023-05-22	CNY	CBR	9.533004
356	2023-05-22	INR	CBR	0.605408
398	2023-05-22	KZT	CBR	0.070000
840	2023-05-22	USD	CBR	59.831871
978	2023-05-22	EUR	CBR	69.729191
643	2023-05-22	RUB	CBR	1.000000
156	2023-05-23	CNY	CBR	9.427800
356	2023-05-23	INR	CBR	0.449577
398	2023-05-23	KZT	CBR	0.174001
840	2023-05-23	USD	CBR	59.679724
978	2023-05-23	EUR	CBR	69.970249
643	2023-05-23	RUB	CBR	1.000000
156	2023-05-24	CNY	CBR	9.959606
356	2023-05-24	INR	CBR	0.462142
398	2023-05-24	KZT	CBR	0.252672
840	2023-05-24	USD	CBR	60.139966
978	2023-05-24	EUR	CBR	69.583795
643	2023-05-24	RUB	CBR	1.000000
156	2023-05-25	CNY	CBR	9.498322
356	2023-05-25	INR	CBR	0.701917
398	2023-05-25	KZT	CBR	0.103175
840	2023-05-25	USD	CBR	60.271271
978	2023-05-25	EUR	CBR	69.681430
643	2023-05-25	RUB	CBR	1.000000
156	2023-05-26	CNY	CBR	9.455761
356	2023-05-26	INR	CBR	0.790698
398	2023-05-26	KZT	CBR	0.070000
840	2023-05-26	USD	CBR	60.216647
978	2023-05-26	EUR	CBR	69.636862
643	2023-05-26	RUB	CBR	1.000000
156	2023-05-27	CNY	CBR	9.132498
356	2023-05-27	INR	CBR	0.856525
398	2023-05-27	KZT	CBR	0.336220
840	2023-05-27	USD	CBR	59.784793
978	2023-05-27	EUR	CBR	70.046673
643	2023-05-27	RUB	CBR	1.000000
156	2023-05-28	CNY	CBR	9.020396
356	2023-05-28	INR	CBR	1.383248
398	2023-05-28	KZT	CBR	0.322185
840	2023-05-28	USD	CBR	60.408515
978	2023-05-28	EUR	CBR	70.303715
643	2023-05-28	RUB	CBR	1.000000
156	2023-05-29	CNY	CBR	9.810384
356	2023-05-29	INR	CBR	0.973088
398	2023-05-29	KZT	CBR	0.092611
840	2023-05-29	USD	CBR	60.455537
978	2023-05-29	EUR	CBR	70.339916
643	2023-05-29	RUB	CBR	1.000000
156	2023-05-30	CNY	CBR	9.746681
356	2023-05-30	INR	CBR	1.161465
398	2023-05-30	KZT	CBR	0.633925
840	2023-05-30	USD	CBR	59.558859
978	2023-05-30	EUR	CBR	69.928926
643	2023-05-30	RUB	CBR	1.000000
156	2023-05-31	CNY	CBR	9.130407
356	2023-05-31	INR	CBR	0.798062
398	2023-05-31	KZT	CBR	0.514355
840	2023-05-31	USD	CBR	59.934958
978	2023-05-31	EUR	CBR	69.944427
643	2023-05-31	RUB	CBR	1.000000
156	2023-06-01	CNY	CBR	9.015386
356	2023-06-01	INR	CBR	1.083744
398	2023-06-01	KZT	CBR	0.351497
840	2023-06-01	USD	CBR	60.339616
978	2023-06-01	EUR	CBR	70.369193
643	2023-06-01	RUB	CBR	1.000000
156	2023-06-02	CNY	CBR	9.755529
356	2023-06-02	INR	CBR	0.523657
398	2023-06-02	KZT	CBR	0.616346
840	2023-06-02	USD	CBR	59.835700
978	2023-06-02	EUR	CBR	69.616766
643	2023-06-02	RUB	CBR	1.000000
156	2023-06-03	CNY	CBR	9.067934
356	2023-06-03	INR	CBR	0.703789
398	2023-06-03	KZT	CBR	0.070000
840	2023-06-03	USD	CBR	60.439868
978	2023-06-03	EUR	CBR	69.806566
643	2023-06-03	RUB	CBR	1.000000
156	2023-06-04	CNY	CBR	9.444466
356	2023-06-04	INR	CBR	0.581193
398	2023-06-04	KZT	CBR	0.566263
840	2023-06-04	USD	CBR	60.090990
978	2023-06-04	EUR	CBR	70.004278
643	2023-06-04	RUB	CBR	1.000000
156	2023-06-05	CNY	CBR	9.165192
356	2023-06-05	INR	CBR	1.080597
398	2023-06-05	KZT	CBR	0.070000
840	2023-06-05	USD	CBR	60.291552
978	2023-06-05	EUR	CBR	70.197249
643	2023-06-05	RUB	CBR	1.000000
156	2023-06-06	CNY	CBR	9.306421
356	2023-06-06	INR	CBR	1.169441
398	2023-06-06	KZT	CBR	0.070000
840	2023-06-06	USD	CBR	59.526708
978	2023-06-06	EUR	CBR	69.905245
643	2023-06-06	RUB	CBR	1.000000
156	2023-06-07	CNY	CBR	9.211884
356	2023-06-07	INR	CBR	0.653529
398	2023-06-07	KZT	CBR	0.070000
840	2023-06-07	USD	CBR	60.456207
978	2023-06-07	EUR	CBR	69.563685
643	2023-06-07	RUB	CBR	1.000000
156	2023-06-08	CNY	CBR	9.833951
356	2023-06-08	INR	CBR	1.171769
398	2023-06-08	KZT	CBR	0.070000
840	2023-06-08	USD	CBR	59.776048
978	2023-06-08	EUR	CBR	70.283845
643	2023-06-08	RUB	CBR	1.000000
156	2023-06-09	CNY	CBR	9.258889
356	2023-06-09	INR	CBR	1.384999
398	2023-06-09	KZT	CBR	0.070000
840	2023-06-09	USD	CBR	59.579601
978	2023-06-09	EUR	CBR	69.594559
643	2023-06-09	RUB	CBR	1.000000
156	2023-06-10	CNY	CBR	9.076549
356	2023-06-10	INR	CBR	0.801667
398	2023-06-10	KZT	CBR	0.070000
840	2023-06-10	USD	CBR	60.333652
978	2023-06-10	EUR	CBR	70.479705
643	2023-06-10	RUB	CBR	1.000000
156	2023-06-11	CNY	CBR	9.426555
356	2023-06-11	INR	CBR	0.671332
398	2023-06-11	KZT	CBR	0.150443
840	2023-06-11	USD	CBR	59.920094
978	2023-06-11	EUR	CBR	70.288980
643	2023-06-11	RUB	CBR	1.000000
156	2023-06-12	CNY	CBR	9.214209
356	2023-06-12	INR	CBR	0.661349
398	2023-06-12	KZT	CBR	0.531514
840	2023-06-12	USD	CBR	59.787367
978	2023-06-12	EUR	CBR	69.792793
643	2023-06-12	RUB	CBR	1.000000
156	2023-06-13	CNY	CBR	9.805244
356	2023-06-13	INR	CBR	1.294628
398	2023-06-13	KZT	CBR	0.289312
840	2023-06-13	USD	CBR	60.480962
978	2023-06-13	EUR	CBR	70.342476
643	2023-06-13	RUB	CBR	1.000000
156	2023-06-14	CNY	CBR	9.100423
356	2023-06-14	INR	CBR	1.124649
398	2023-06-14	KZT	CBR	0.070000
840	2023-06-14	USD	CBR	59.625160
978	2023-06-14	EUR	CBR	69.838303
643	2023-06-14	RUB	CBR	1.000000
156	2023-06-15	CNY	CBR	9.293720
356	2023-06-15	INR	CBR	1.224330
398	2023-06-15	KZT	CBR	0.527898
840	2023-06-15	USD	CBR	60.488949
978	2023-06-15	EUR	CBR	69.510359
643	2023-06-15	RUB	CBR	1.000000
156	2023-06-16	CNY	CBR	9.649342
356	2023-06-16	INR	CBR	0.751797
398	2023-06-16	KZT	CBR	0.499746
840	2023-06-16	USD	CBR	60.301774
978	2023-06-16	EUR	CBR	70.083452
643	2023-06-16	RUB	CBR	1.000000
156	2023-06-17	CNY	CBR	9.638339
356	2023-06-17	INR	CBR	0.545204
398	2023-06-17	KZT	CBR	0.413103
840	2023-06-17	USD	CBR	60.424340
978	2023-06-17	EUR	CBR	69.559482
643	2023-06-17	RUB	CBR	1.000000
156	2023-06-18	CNY	CBR	9.572439
356	2023-06-18	INR	CBR	1.207738
398	2023-06-18	KZT	CBR	0.534899
840	2023-06-18	USD	CBR	60.315133
978	2023-06-18	EUR	CBR	69.854291
643	2023-06-18	RUB	CBR	1.000000
156	2023-06-19	CNY	CBR	9.938366
356	2023-06-19	INR	CBR	0.511637
398	2023-06-19	KZT	CBR	0.070000
840	2023-06-19	USD	CBR	59.587186
978	2023-06-19	EUR	CBR	69.927122
643	2023-06-19	RUB	CBR	1.000000
156	2023-06-20	CNY	CBR	9.732890
356	2023-06-20	INR	CBR	0.544278
398	2023-06-20	KZT	CBR	0.436467
840	2023-06-20	USD	CBR	60.015997
978	2023-06-20	EUR	CBR	70.023512
643	2023-06-20	RUB	CBR	1.000000
156	2023-06-21	CNY	CBR	9.978859
356	2023-06-21	INR	CBR	0.588415
398	2023-06-21	KZT	CBR	0.070000
840	2023-06-21	USD	CBR	60.090741
978	2023-06-21	EUR	CBR	69.699903
643	2023-06-21	RUB	CBR	1.000000
156	2023-06-22	CNY	CBR	9.932414
356	2023-06-22	INR	CBR	0.815925
398	2023-06-22	KZT	CBR	0.596208
840	2023-06-22	USD	CBR	59.993512
978	2023-06-22	EUR	CBR	70.049192
643	2023-06-22	RUB	CBR	1.000000
156	2023-06-23	CNY	CBR	9.226762
356	2023-06-23	INR	CBR	0.784931
398	2023-06-23	KZT	CBR	0.203336
840	2023-06-23	USD	CBR	60.319934
978	2023-06-23	EUR	CBR	69.992023
643	2023-06-23	RUB	CBR	1.000000
156	2023-06-24	CNY	CBR	9.637504
356	2023-06-24	INR	CBR	1.018299
398	2023-06-24	KZT	CBR	0.484543
840	2023-06-24	USD	CBR	59.640273
978	2023-06-24	EUR	CBR	69.895839
643	2023-06-24	RUB	CBR	1.000000
156	2023-06-25	CNY	CBR	9.084884
356	2023-06-25	INR	CBR	1.155440
398	2023-06-25	KZT	CBR	0.474219
840	2023-06-25	USD	CBR	60.339260
978	2023-06-25	EUR	CBR	69.938083
643	2023-06-25	RUB	CBR	1.000000
156	2023-06-26	CNY	CBR	9.804089
356	2023-06-26	INR	CBR	0.498521
398	2023-06-26	KZT	CBR	0.070000
840	2023-06-26	USD	CBR	60.063081
978	2023-06-26	EUR	CBR	70.346180
643	2023-06-26	RUB	CBR	1.000000
156	2023-06-27	CNY	CBR	9.338215
356	2023-06-27	INR	CBR	0.909296
398	2023-06-27	KZT	CBR	0.303801
840	2023-06-27	USD	CBR	60.122114
978	2023-06-27	EUR	CBR	69.807651
643	2023-06-27	RUB	CBR	1.000000
156	2023-06-28	CNY	CBR	9.834042
356	2023-06-28	INR	CBR	1.109928
398	2023-06-28	KZT	CBR	0.070000
840	2023-06-28	USD	CBR	59.548011
978	2023-06-28	EUR	CBR	70.429297
643	2023-06-28	RUB	CBR	1.000000
156	2023-06-29	CNY	CBR	9.148073
356	2023-06-29	INR	CBR	1.094704
398	2023-06-29	KZT	CBR	0.462349
840	2023-06-29	USD	CBR	60.025706
978	2023-06-29	EUR	CBR	70.261068
643	2023-06-29	RUB	CBR	1.000000
156	2023-06-30	CNY	CBR	9.020594
356	2023-06-30	INR	CBR	0.633643
398	2023-06-30	KZT	CBR	0.160652
840	2023-06-30	USD	CBR	59.883523
978	2023-06-30	EUR	CBR	70.256106
643	2023-06-30	RUB	CBR	1.000000
156	2023-07-01	CNY	CBR	9.761247
356	2023-07-01	INR	CBR	0.983476
398	2023-07-01	KZT	CBR	0.242543
840	2023-07-01	USD	CBR	59.817291
978	2023-07-01	EUR	CBR	69.973382
643	2023-07-01	RUB	CBR	1.000000
156	2023-07-02	CNY	CBR	9.639287
356	2023-07-02	INR	CBR	1.047136
398	2023-07-02	KZT	CBR	0.138361
840	2023-07-02	USD	CBR	59.597229
978	2023-07-02	EUR	CBR	69.636184
643	2023-07-02	RUB	CBR	1.000000
156	2023-07-03	CNY	CBR	9.529436
356	2023-07-03	INR	CBR	0.755962
398	2023-07-03	KZT	CBR	0.452172
840	2023-07-03	USD	CBR	60.459021
978	2023-07-03	EUR	CBR	69.855982
643	2023-07-03	RUB	CBR	1.000000
156	2023-07-04	CNY	CBR	9.747366
356	2023-07-04	INR	CBR	1.074763
398	2023-07-04	KZT	CBR	0.444464
840	2023-07-04	USD	CBR	59.755669
978	2023-07-04	EUR	CBR	69.960972
643	2023-07-04	RUB	CBR	1.000000
156	2023-07-05	CNY	CBR	9.762457
356	2023-07-05	INR	CBR	1.185260
398	2023-07-05	KZT	CBR	0.391512
840	2023-07-05	USD	CBR	60.395779
978	2023-07-05	EUR	CBR	69.612307
643	2023-07-05	RUB	CBR	1.000000
156	2023-07-06	CNY	CBR	9.994908
356	2023-07-06	INR	CBR	1.394572
398	2023-07-06	KZT	CBR	0.070000
840	2023-07-06	USD	CBR	59.586969
978	2023-07-06	EUR	CBR	70.148812
643	2023-07-06	RUB	CBR	1.000000
156	2023-07-07	CNY	CBR	9.811197
356	2023-07-07	INR	CBR	1.331732
398	2023-07-07	KZT	CBR	0.519536
840	2023-07-07	USD	CBR	59.634478
978	2023-07-07	EUR	CBR	70.138547
643	2023-07-07	RUB	CBR	1.000000
156	2023-07-08	CNY	CBR	9.032335
356	2023-07-08	INR	CBR	0.599438
398	2023-07-08	KZT	CBR	0.466844
840	2023-07-08	USD	CBR	60.284120
978	2023-07-08	EUR	CBR	69.799747
643	2023-07-08	RUB	CBR	1.000000
156	2023-07-09	CNY	CBR	9.865766
356	2023-07-09	INR	CBR	1.109382
398	2023-07-09	KZT	CBR	0.294748
840	2023-07-09	USD	CBR	59.818475
978	2023-07-09	EUR	CBR	70.024768
643	2023-07-09	RUB	CBR	1.000000
156	2023-07-10	CNY	CBR	9.726272
356	2023-07-10	INR	CBR	0.553133
398	2023-07-10	KZT	CBR	0.305247
840	2023-07-10	USD	CBR	60.469737
978	2023-07-10	EUR	CBR	70.070316
643	2023-07-10	RUB	CBR	1.000000
156	2023-07-11	CNY	CBR	9.660987
356	2023-07-11	INR	CBR	0.416004
398	2023-07-11	KZT	CBR	0.614298
840	2023-07-11	USD	CBR	59.613828
978	2023-07-11	EUR	CBR	69.833406
643	2023-07-11	RUB	CBR	1.000000
156	2023-07-12	CNY	CBR	9.121131
356	2023-07-12	INR	CBR	0.567062
398	2023-07-12	KZT	CBR	0.450835
840	2023-07-12	USD	CBR	60.458799
978	2023-07-12	EUR	CBR	69.739290
643	2023-07-12	RUB	CBR	1.000000
156	2023-07-13	CNY	CBR	9.026797
356	2023-07-13	INR	CBR	1.342572
398	2023-07-13	KZT	CBR	0.070000
840	2023-07-13	USD	CBR	60.151316
978	2023-07-13	EUR	CBR	69.920837
643	2023-07-13	RUB	CBR	1.000000
156	2023-07-14	CNY	CBR	9.491697
356	2023-07-14	INR	CBR	0.794202
398	2023-07-14	KZT	CBR	0.070000
840	2023-07-14	USD	CBR	59.719838
978	2023-07-14	EUR	CBR	70.367698
643	2023-07-14	RUB	CBR	1.000000
156	2023-07-15	CNY	CBR	9.825214
356	2023-07-15	INR	CBR	0.762362
398	2023-07-15	KZT	CBR	0.107664
840	2023-07-15	USD	CBR	60.399625
978	2023-07-15	EUR	CBR	69.548643
643	2023-07-15	RUB	CBR	1.000000
156	2023-07-16	CNY	CBR	9.921562
356	2023-07-16	INR	CBR	0.509213
398	2023-07-16	KZT	CBR	0.070000
840	2023-07-16	USD	CBR	60.371069
978	2023-07-16	EUR	CBR	70.398518
643	2023-07-16	RUB	CBR	1.000000
156	2023-07-17	CNY	CBR	9.843593
356	2023-07-17	INR	CBR	1.166815
398	2023-07-17	KZT	CBR	0.252133
840	2023-07-17	USD	CBR	59.584534
978	2023-07-17	EUR	CBR	69.828016
643	2023-07-17	RUB	CBR	1.000000
156	2023-07-18	CNY	CBR	9.978793
356	2023-07-18	INR	CBR	0.937015
398	2023-07-18	KZT	CBR	0.302155
840	2023-07-18	USD	CBR	59.804899
978	2023-07-18	EUR	CBR	70.378001
643	2023-07-18	RUB	CBR	1.000000
156	2023-07-19	CNY	CBR	9.467078
356	2023-07-19	INR	CBR	0.810549
398	2023-07-19	KZT	CBR	0.070000
840	2023-07-19	USD	CBR	59.659847
978	2023-07-19	EUR	CBR	69.899435
643	2023-07-19	RUB	CBR	1.000000
156	2023-07-20	CNY	CBR	9.846114
356	2023-07-20	INR	CBR	0.952220
398	2023-07-20	KZT	CBR	0.070000
840	2023-07-20	USD	CBR	60.426380
978	2023-07-20	EUR	CBR	69.556859
643	2023-07-20	RUB	CBR	1.000000
156	2023-07-21	CNY	CBR	9.480697
356	2023-07-21	INR	CBR	1.194732
398	2023-07-21	KZT	CBR	0.331261
840	2023-07-21	USD	CBR	59.897058
978	2023-07-21	EUR	CBR	69.534984
643	2023-07-21	RUB	CBR	1.000000
156	2023-07-22	CNY	CBR	9.757542
356	2023-07-22	INR	CBR	0.713847
398	2023-07-22	KZT	CBR	0.070000
840	2023-07-22	USD	CBR	60.128872
978	2023-07-22	EUR	CBR	70.165879
643	2023-07-22	RUB	CBR	1.000000
156	2023-07-23	CNY	CBR	9.523892
356	2023-07-23	INR	CBR	1.231108
398	2023-07-23	KZT	CBR	0.590992
840	2023-07-23	USD	CBR	59.649089
978	2023-07-23	EUR	CBR	69.912298
643	2023-07-23	RUB	CBR	1.000000
156	2023-07-24	CNY	CBR	9.340925
356	2023-07-24	INR	CBR	1.379664
398	2023-07-24	KZT	CBR	0.594723
840	2023-07-24	USD	CBR	59.729247
978	2023-07-24	EUR	CBR	69.662283
643	2023-07-24	RUB	CBR	1.000000
156	2023-07-25	CNY	CBR	9.768520
356	2023-07-25	INR	CBR	0.729577
398	2023-07-25	KZT	CBR	0.070000
840	2023-07-25	USD	CBR	60.077483
978	2023-07-25	EUR	CBR	69.916476
643	2023-07-25	RUB	CBR	1.000000
156	2023-07-26	CNY	CBR	9.735755
356	2023-07-26	INR	CBR	1.026018
398	2023-07-26	KZT	CBR	0.070000
840	2023-07-26	USD	CBR	59.808944
978	2023-07-26	EUR	CBR	70.087083
643	2023-07-26	RUB	CBR	1.000000
156	2023-07-27	CNY	CBR	9.325107
356	2023-07-27	INR	CBR	0.420415
398	2023-07-27	KZT	CBR	0.629061
840	2023-07-27	USD	CBR	60.037052
978	2023-07-27	EUR	CBR	70.229017
643	2023-07-27	RUB	CBR	1.000000
156	2023-07-28	CNY	CBR	9.506429
356	2023-07-28	INR	CBR	0.555275
398	2023-07-28	KZT	CBR	0.441356
840	2023-07-28	USD	CBR	60.065742
978	2023-07-28	EUR	CBR	70.102591
643	2023-07-28	RUB	CBR	1.000000
156	2023-07-29	CNY	CBR	9.349937
356	2023-07-29	INR	CBR	1.291683
398	2023-07-29	KZT	CBR	0.555663
840	2023-07-29	USD	CBR	60.372989
978	2023-07-29	EUR	CBR	69.804837
643	2023-07-29	RUB	CBR	1.000000
156	2023-07-30	CNY	CBR	9.081967
356	2023-07-30	INR	CBR	0.801906
398	2023-07-30	KZT	CBR	0.070000
840	2023-07-30	USD	CBR	60.268345
978	2023-07-30	EUR	CBR	69.951745
643	2023-07-30	RUB	CBR	1.000000
156	2023-07-31	CNY	CBR	9.854707
356	2023-07-31	INR	CBR	0.709029
398	2023-07-31	KZT	CBR	0.201968
840	2023-07-31	USD	CBR	60.431069
978	2023-07-31	EUR	CBR	70.269906
643	2023-07-31	RUB	CBR	1.000000
156	2023-08-01	CNY	CBR	9.183346
356	2023-08-01	INR	CBR	0.448435
398	2023-08-01	KZT	CBR	0.191026
840	2023-08-01	USD	CBR	59.678770
978	2023-08-01	EUR	CBR	70.412772
643	2023-08-01	RUB	CBR	1.000000
156	2023-08-02	CNY	CBR	9.957773
356	2023-08-02	INR	CBR	1.198016
398	2023-08-02	KZT	CBR	0.070000
840	2023-08-02	USD	CBR	60.393337
978	2023-08-02	EUR	CBR	69.751640
643	2023-08-02	RUB	CBR	1.000000
156	2023-08-03	CNY	CBR	9.300512
356	2023-08-03	INR	CBR	1.237491
398	2023-08-03	KZT	CBR	0.222352
840	2023-08-03	USD	CBR	60.227810
978	2023-08-03	EUR	CBR	70.053515
643	2023-08-03	RUB	CBR	1.000000
156	2023-08-04	CNY	CBR	9.365556
356	2023-08-04	INR	CBR	0.880660
398	2023-08-04	KZT	CBR	0.612325
840	2023-08-04	USD	CBR	60.140245
978	2023-08-04	EUR	CBR	69.685138
643	2023-08-04	RUB	CBR	1.000000
156	2023-08-05	CNY	CBR	9.263208
356	2023-08-05	INR	CBR	0.874407
398	2023-08-05	KZT	CBR	0.070000
840	2023-08-05	USD	CBR	59.661502
978	2023-08-05	EUR	CBR	70.287920
643	2023-08-05	RUB	CBR	1.000000
156	2023-08-06	CNY	CBR	9.720590
356	2023-08-06	INR	CBR	1.151763
398	2023-08-06	KZT	CBR	0.070000
840	2023-08-06	USD	CBR	59.805420
978	2023-08-06	EUR	CBR	70.170380
643	2023-08-06	RUB	CBR	1.000000
156	2023-08-07	CNY	CBR	9.344648
356	2023-08-07	INR	CBR	0.618905
398	2023-08-07	KZT	CBR	0.231210
840	2023-08-07	USD	CBR	59.910676
978	2023-08-07	EUR	CBR	69.919304
643	2023-08-07	RUB	CBR	1.000000
156	2023-08-08	CNY	CBR	9.251819
356	2023-08-08	INR	CBR	1.318437
398	2023-08-08	KZT	CBR	0.070000
840	2023-08-08	USD	CBR	60.009729
978	2023-08-08	EUR	CBR	69.882100
643	2023-08-08	RUB	CBR	1.000000
156	2023-08-09	CNY	CBR	9.355183
356	2023-08-09	INR	CBR	0.789236
398	2023-08-09	KZT	CBR	0.070000
840	2023-08-09	USD	CBR	60.475248
978	2023-08-09	EUR	CBR	70.131911
643	2023-08-09	RUB	CBR	1.000000
156	2023-08-10	CNY	CBR	9.985975
356	2023-08-10	INR	CBR	1.196607
398	2023-08-10	KZT	CBR	0.070000
840	2023-08-10	USD	CBR	60.105440
978	2023-08-10	EUR	CBR	70.045971
643	2023-08-10	RUB	CBR	1.000000
156	2023-08-11	CNY	CBR	9.820120
356	2023-08-11	INR	CBR	0.632188
398	2023-08-11	KZT	CBR	0.070000
840	2023-08-11	USD	CBR	59.602178
978	2023-08-11	EUR	CBR	70.342577
643	2023-08-11	RUB	CBR	1.000000
156	2023-08-12	CNY	CBR	9.901404
356	2023-08-12	INR	CBR	0.665720
398	2023-08-12	KZT	CBR	0.351107
840	2023-08-12	USD	CBR	59.500650
978	2023-08-12	EUR	CBR	69.896840
643	2023-08-12	RUB	CBR	1.000000
156	2023-08-13	CNY	CBR	9.900547
356	2023-08-13	INR	CBR	0.890681
398	2023-08-13	KZT	CBR	0.595796
840	2023-08-13	USD	CBR	59.874187
978	2023-08-13	EUR	CBR	70.329581
643	2023-08-13	RUB	CBR	1.000000
156	2023-08-14	CNY	CBR	9.810026
356	2023-08-14	INR	CBR	0.791815
398	2023-08-14	KZT	CBR	0.273385
840	2023-08-14	USD	CBR	60.394389
978	2023-08-14	EUR	CBR	70.401175
643	2023-08-14	RUB	CBR	1.000000
156	2023-08-15	CNY	CBR	9.716790
356	2023-08-15	INR	CBR	0.439509
398	2023-08-15	KZT	CBR	0.070000
840	2023-08-15	USD	CBR	60.443010
978	2023-08-15	EUR	CBR	70.217190
643	2023-08-15	RUB	CBR	1.000000
156	2023-08-16	CNY	CBR	9.908751
356	2023-08-16	INR	CBR	1.393261
398	2023-08-16	KZT	CBR	0.070000
840	2023-08-16	USD	CBR	60.424179
978	2023-08-16	EUR	CBR	70.030033
643	2023-08-16	RUB	CBR	1.000000
156	2023-08-17	CNY	CBR	9.141650
356	2023-08-17	INR	CBR	0.921450
398	2023-08-17	KZT	CBR	0.406281
840	2023-08-17	USD	CBR	60.289887
978	2023-08-17	EUR	CBR	69.616499
643	2023-08-17	RUB	CBR	1.000000
156	2023-08-18	CNY	CBR	9.298252
356	2023-08-18	INR	CBR	0.654195
398	2023-08-18	KZT	CBR	0.199294
840	2023-08-18	USD	CBR	60.356931
978	2023-08-18	EUR	CBR	70.038593
643	2023-08-18	RUB	CBR	1.000000
156	2023-08-19	CNY	CBR	9.000543
356	2023-08-19	INR	CBR	0.435541
398	2023-08-19	KZT	CBR	0.070000
840	2023-08-19	USD	CBR	59.872175
978	2023-08-19	EUR	CBR	70.374387
643	2023-08-19	RUB	CBR	1.000000
156	2023-08-20	CNY	CBR	9.987583
356	2023-08-20	INR	CBR	1.360399
398	2023-08-20	KZT	CBR	0.098592
840	2023-08-20	USD	CBR	60.207985
978	2023-08-20	EUR	CBR	69.969913
643	2023-08-20	RUB	CBR	1.000000
156	2023-08-21	CNY	CBR	9.003904
356	2023-08-21	INR	CBR	0.819775
398	2023-08-21	KZT	CBR	0.423936
840	2023-08-21	USD	CBR	59.712149
978	2023-08-21	EUR	CBR	69.899122
643	2023-08-21	RUB	CBR	1.000000
156	2023-08-22	CNY	CBR	9.845887
356	2023-08-22	INR	CBR	1.009106
398	2023-08-22	KZT	CBR	0.070000
840	2023-08-22	USD	CBR	59.561880
978	2023-08-22	EUR	CBR	70.411587
643	2023-08-22	RUB	CBR	1.000000
156	2023-08-23	CNY	CBR	9.614132
356	2023-08-23	INR	CBR	0.434220
398	2023-08-23	KZT	CBR	0.596854
840	2023-08-23	USD	CBR	60.028194
978	2023-08-23	EUR	CBR	69.904497
643	2023-08-23	RUB	CBR	1.000000
156	2023-08-24	CNY	CBR	9.534771
356	2023-08-24	INR	CBR	0.663479
398	2023-08-24	KZT	CBR	0.551372
840	2023-08-24	USD	CBR	60.010170
978	2023-08-24	EUR	CBR	70.353125
643	2023-08-24	RUB	CBR	1.000000
156	2023-08-25	CNY	CBR	9.838839
356	2023-08-25	INR	CBR	0.989305
398	2023-08-25	KZT	CBR	0.404196
840	2023-08-25	USD	CBR	60.456736
978	2023-08-25	EUR	CBR	70.411220
643	2023-08-25	RUB	CBR	1.000000
156	2023-08-26	CNY	CBR	9.415318
356	2023-08-26	INR	CBR	0.621502
398	2023-08-26	KZT	CBR	0.070000
840	2023-08-26	USD	CBR	59.503580
978	2023-08-26	EUR	CBR	70.092474
643	2023-08-26	RUB	CBR	1.000000
156	2023-08-27	CNY	CBR	9.361092
356	2023-08-27	INR	CBR	0.726855
398	2023-08-27	KZT	CBR	0.070000
840	2023-08-27	USD	CBR	59.713601
978	2023-08-27	EUR	CBR	69.615128
643	2023-08-27	RUB	CBR	1.000000
156	2023-08-28	CNY	CBR	9.748932
356	2023-08-28	INR	CBR	0.464240
398	2023-08-28	KZT	CBR	0.070000
840	2023-08-28	USD	CBR	60.474235
978	2023-08-28	EUR	CBR	70.203120
643	2023-08-28	RUB	CBR	1.000000
156	2023-08-29	CNY	CBR	9.446334
356	2023-08-29	INR	CBR	0.837409
398	2023-08-29	KZT	CBR	0.070000
840	2023-08-29	USD	CBR	59.959498
978	2023-08-29	EUR	CBR	69.650452
643	2023-08-29	RUB	CBR	1.000000
156	2023-08-30	CNY	CBR	9.651706
356	2023-08-30	INR	CBR	0.571871
398	2023-08-30	KZT	CBR	0.492997
840	2023-08-30	USD	CBR	60.138649
978	2023-08-30	EUR	CBR	69.737253
643	2023-08-30	RUB	CBR	1.000000
156	2023-08-31	CNY	CBR	9.816080
356	2023-08-31	INR	CBR	1.370858
398	2023-08-31	KZT	CBR	0.070000
840	2023-08-31	USD	CBR	60.299281
978	2023-08-31	EUR	CBR	69.649134
643	2023-08-31	RUB	CBR	1.000000
156	2023-09-01	CNY	CBR	9.124522
356	2023-09-01	INR	CBR	0.736766
398	2023-09-01	KZT	CBR	0.070000
840	2023-09-01	USD	CBR	60.313339
978	2023-09-01	EUR	CBR	69.877062
643	2023-09-01	RUB	CBR	1.000000
156	2023-09-02	CNY	CBR	9.549254
356	2023-09-02	INR	CBR	0.757195
398	2023-09-02	KZT	CBR	0.070000
840	2023-09-02	USD	CBR	59.806231
978	2023-09-02	EUR	CBR	69.938360
643	2023-09-02	RUB	CBR	1.000000
156	2023-09-03	CNY	CBR	9.562841
356	2023-09-03	INR	CBR	0.742702
398	2023-09-03	KZT	CBR	0.070000
840	2023-09-03	USD	CBR	59.766498
978	2023-09-03	EUR	CBR	69.727827
643	2023-09-03	RUB	CBR	1.000000
156	2023-09-04	CNY	CBR	9.700337
356	2023-09-04	INR	CBR	1.132275
398	2023-09-04	KZT	CBR	0.070000
840	2023-09-04	USD	CBR	59.994192
978	2023-09-04	EUR	CBR	69.817542
643	2023-09-04	RUB	CBR	1.000000
156	2023-09-05	CNY	CBR	9.081945
356	2023-09-05	INR	CBR	0.589815
398	2023-09-05	KZT	CBR	0.070000
840	2023-09-05	USD	CBR	60.014577
978	2023-09-05	EUR	CBR	70.108689
643	2023-09-05	RUB	CBR	1.000000
156	2023-09-06	CNY	CBR	9.509065
356	2023-09-06	INR	CBR	0.966332
398	2023-09-06	KZT	CBR	0.348674
840	2023-09-06	USD	CBR	60.391288
978	2023-09-06	EUR	CBR	69.704115
643	2023-09-06	RUB	CBR	1.000000
156	2023-09-07	CNY	CBR	9.053597
356	2023-09-07	INR	CBR	0.462937
398	2023-09-07	KZT	CBR	0.173761
840	2023-09-07	USD	CBR	59.520354
978	2023-09-07	EUR	CBR	70.472445
643	2023-09-07	RUB	CBR	1.000000
156	2023-09-08	CNY	CBR	9.197576
356	2023-09-08	INR	CBR	0.825999
398	2023-09-08	KZT	CBR	0.496568
840	2023-09-08	USD	CBR	59.977897
978	2023-09-08	EUR	CBR	70.317851
643	2023-09-08	RUB	CBR	1.000000
156	2023-09-09	CNY	CBR	9.396589
356	2023-09-09	INR	CBR	1.060798
398	2023-09-09	KZT	CBR	0.070000
840	2023-09-09	USD	CBR	60.200425
978	2023-09-09	EUR	CBR	69.699087
643	2023-09-09	RUB	CBR	1.000000
156	2023-09-10	CNY	CBR	9.150484
356	2023-09-10	INR	CBR	0.720294
398	2023-09-10	KZT	CBR	0.070000
840	2023-09-10	USD	CBR	59.665443
978	2023-09-10	EUR	CBR	70.091551
643	2023-09-10	RUB	CBR	1.000000
156	2023-09-11	CNY	CBR	9.845774
356	2023-09-11	INR	CBR	1.138256
398	2023-09-11	KZT	CBR	0.114509
840	2023-09-11	USD	CBR	60.074129
978	2023-09-11	EUR	CBR	69.614473
643	2023-09-11	RUB	CBR	1.000000
156	2023-09-12	CNY	CBR	9.673294
356	2023-09-12	INR	CBR	0.650546
398	2023-09-12	KZT	CBR	0.629940
840	2023-09-12	USD	CBR	60.048978
978	2023-09-12	EUR	CBR	70.218651
643	2023-09-12	RUB	CBR	1.000000
156	2023-09-13	CNY	CBR	9.112563
356	2023-09-13	INR	CBR	0.544889
398	2023-09-13	KZT	CBR	0.593584
840	2023-09-13	USD	CBR	59.508879
978	2023-09-13	EUR	CBR	70.303037
643	2023-09-13	RUB	CBR	1.000000
156	2023-09-14	CNY	CBR	9.040674
356	2023-09-14	INR	CBR	0.470516
398	2023-09-14	KZT	CBR	0.602828
840	2023-09-14	USD	CBR	60.097987
978	2023-09-14	EUR	CBR	70.094328
643	2023-09-14	RUB	CBR	1.000000
156	2023-09-15	CNY	CBR	9.110963
356	2023-09-15	INR	CBR	0.638595
398	2023-09-15	KZT	CBR	0.070000
840	2023-09-15	USD	CBR	59.791271
978	2023-09-15	EUR	CBR	69.531997
643	2023-09-15	RUB	CBR	1.000000
156	2023-09-16	CNY	CBR	9.347182
356	2023-09-16	INR	CBR	0.655735
398	2023-09-16	KZT	CBR	0.455957
840	2023-09-16	USD	CBR	60.034371
978	2023-09-16	EUR	CBR	70.030997
643	2023-09-16	RUB	CBR	1.000000
156	2023-09-17	CNY	CBR	9.310345
356	2023-09-17	INR	CBR	1.278820
398	2023-09-17	KZT	CBR	0.420094
840	2023-09-17	USD	CBR	59.899002
978	2023-09-17	EUR	CBR	69.873991
643	2023-09-17	RUB	CBR	1.000000
156	2023-09-18	CNY	CBR	9.570181
356	2023-09-18	INR	CBR	1.103730
398	2023-09-18	KZT	CBR	0.561195
840	2023-09-18	USD	CBR	60.457193
978	2023-09-18	EUR	CBR	70.444597
643	2023-09-18	RUB	CBR	1.000000
156	2023-09-19	CNY	CBR	9.063232
356	2023-09-19	INR	CBR	1.022967
398	2023-09-19	KZT	CBR	0.070000
840	2023-09-19	USD	CBR	60.418914
978	2023-09-19	EUR	CBR	69.981837
643	2023-09-19	RUB	CBR	1.000000
156	2023-09-20	CNY	CBR	9.200548
356	2023-09-20	INR	CBR	1.310255
398	2023-09-20	KZT	CBR	0.070000
840	2023-09-20	USD	CBR	60.366844
978	2023-09-20	EUR	CBR	69.590679
643	2023-09-20	RUB	CBR	1.000000
156	2023-09-21	CNY	CBR	9.920399
356	2023-09-21	INR	CBR	1.045371
398	2023-09-21	KZT	CBR	0.221270
840	2023-09-21	USD	CBR	60.317165
978	2023-09-21	EUR	CBR	69.930834
643	2023-09-21	RUB	CBR	1.000000
156	2023-09-22	CNY	CBR	9.313838
356	2023-09-22	INR	CBR	0.899979
398	2023-09-22	KZT	CBR	0.131504
840	2023-09-22	USD	CBR	60.172676
978	2023-09-22	EUR	CBR	69.699368
643	2023-09-22	RUB	CBR	1.000000
156	2023-09-23	CNY	CBR	9.538756
356	2023-09-23	INR	CBR	0.407460
398	2023-09-23	KZT	CBR	0.070000
840	2023-09-23	USD	CBR	60.190963
978	2023-09-23	EUR	CBR	70.113277
643	2023-09-23	RUB	CBR	1.000000
156	2023-09-24	CNY	CBR	9.811176
356	2023-09-24	INR	CBR	0.708997
398	2023-09-24	KZT	CBR	0.070000
840	2023-09-24	USD	CBR	60.178530
978	2023-09-24	EUR	CBR	70.291994
643	2023-09-24	RUB	CBR	1.000000
156	2023-09-25	CNY	CBR	9.292882
356	2023-09-25	INR	CBR	0.982644
398	2023-09-25	KZT	CBR	0.228022
840	2023-09-25	USD	CBR	60.056885
978	2023-09-25	EUR	CBR	69.650260
643	2023-09-25	RUB	CBR	1.000000
156	2023-09-26	CNY	CBR	9.978194
356	2023-09-26	INR	CBR	1.290348
398	2023-09-26	KZT	CBR	0.197522
840	2023-09-26	USD	CBR	59.652175
978	2023-09-26	EUR	CBR	70.367037
643	2023-09-26	RUB	CBR	1.000000
156	2023-09-27	CNY	CBR	9.823007
356	2023-09-27	INR	CBR	0.987711
398	2023-09-27	KZT	CBR	0.475710
840	2023-09-27	USD	CBR	60.020416
978	2023-09-27	EUR	CBR	69.644529
643	2023-09-27	RUB	CBR	1.000000
156	2023-09-28	CNY	CBR	9.156654
356	2023-09-28	INR	CBR	0.438503
398	2023-09-28	KZT	CBR	0.532023
840	2023-09-28	USD	CBR	59.916145
978	2023-09-28	EUR	CBR	69.864797
643	2023-09-28	RUB	CBR	1.000000
156	2023-09-29	CNY	CBR	9.386406
356	2023-09-29	INR	CBR	1.179258
398	2023-09-29	KZT	CBR	0.070000
840	2023-09-29	USD	CBR	60.345677
978	2023-09-29	EUR	CBR	70.215268
643	2023-09-29	RUB	CBR	1.000000
156	2023-09-30	CNY	CBR	9.338830
356	2023-09-30	INR	CBR	1.391955
398	2023-09-30	KZT	CBR	0.095019
840	2023-09-30	USD	CBR	60.252256
978	2023-09-30	EUR	CBR	70.118229
643	2023-09-30	RUB	CBR	1.000000
156	2023-10-01	CNY	CBR	9.913801
356	2023-10-01	INR	CBR	1.233510
398	2023-10-01	KZT	CBR	0.592854
840	2023-10-01	USD	CBR	59.966989
978	2023-10-01	EUR	CBR	69.678671
643	2023-10-01	RUB	CBR	1.000000
156	2023-10-02	CNY	CBR	9.331452
356	2023-10-02	INR	CBR	0.786380
398	2023-10-02	KZT	CBR	0.545184
840	2023-10-02	USD	CBR	59.890231
978	2023-10-02	EUR	CBR	69.713505
643	2023-10-02	RUB	CBR	1.000000
156	2023-10-03	CNY	CBR	9.287029
356	2023-10-03	INR	CBR	1.045098
398	2023-10-03	KZT	CBR	0.111291
840	2023-10-03	USD	CBR	60.416836
978	2023-10-03	EUR	CBR	69.659814
643	2023-10-03	RUB	CBR	1.000000
156	2023-10-04	CNY	CBR	9.739718
356	2023-10-04	INR	CBR	1.351840
398	2023-10-04	KZT	CBR	0.070000
840	2023-10-04	USD	CBR	59.636712
978	2023-10-04	EUR	CBR	70.474600
643	2023-10-04	RUB	CBR	1.000000
156	2023-10-05	CNY	CBR	9.177029
356	2023-10-05	INR	CBR	0.536530
398	2023-10-05	KZT	CBR	0.278985
840	2023-10-05	USD	CBR	60.362147
978	2023-10-05	EUR	CBR	70.282017
643	2023-10-05	RUB	CBR	1.000000
156	2023-10-06	CNY	CBR	9.310497
356	2023-10-06	INR	CBR	0.895252
398	2023-10-06	KZT	CBR	0.623994
840	2023-10-06	USD	CBR	59.679602
978	2023-10-06	EUR	CBR	69.534534
643	2023-10-06	RUB	CBR	1.000000
156	2023-10-07	CNY	CBR	9.915156
356	2023-10-07	INR	CBR	1.062384
398	2023-10-07	KZT	CBR	0.070000
840	2023-10-07	USD	CBR	60.341042
978	2023-10-07	EUR	CBR	70.494585
643	2023-10-07	RUB	CBR	1.000000
156	2023-10-08	CNY	CBR	9.591279
356	2023-10-08	INR	CBR	1.086926
398	2023-10-08	KZT	CBR	0.426517
840	2023-10-08	USD	CBR	60.249531
978	2023-10-08	EUR	CBR	69.962701
643	2023-10-08	RUB	CBR	1.000000
156	2023-10-09	CNY	CBR	9.094066
356	2023-10-09	INR	CBR	1.101603
398	2023-10-09	KZT	CBR	0.070000
840	2023-10-09	USD	CBR	60.078281
978	2023-10-09	EUR	CBR	70.312542
643	2023-10-09	RUB	CBR	1.000000
156	2023-10-10	CNY	CBR	9.616242
356	2023-10-10	INR	CBR	1.000456
398	2023-10-10	KZT	CBR	0.160609
840	2023-10-10	USD	CBR	60.340837
978	2023-10-10	EUR	CBR	70.250322
643	2023-10-10	RUB	CBR	1.000000
156	2023-10-11	CNY	CBR	9.938599
356	2023-10-11	INR	CBR	0.609717
398	2023-10-11	KZT	CBR	0.375798
840	2023-10-11	USD	CBR	59.971453
978	2023-10-11	EUR	CBR	69.998365
643	2023-10-11	RUB	CBR	1.000000
156	2023-10-12	CNY	CBR	9.435353
356	2023-10-12	INR	CBR	0.566861
398	2023-10-12	KZT	CBR	0.173659
840	2023-10-12	USD	CBR	60.498262
978	2023-10-12	EUR	CBR	70.303350
643	2023-10-12	RUB	CBR	1.000000
156	2023-10-13	CNY	CBR	9.861511
356	2023-10-13	INR	CBR	0.762435
398	2023-10-13	KZT	CBR	0.213507
840	2023-10-13	USD	CBR	60.260106
978	2023-10-13	EUR	CBR	70.218163
643	2023-10-13	RUB	CBR	1.000000
156	2023-10-14	CNY	CBR	9.306968
356	2023-10-14	INR	CBR	0.763808
398	2023-10-14	KZT	CBR	0.070000
840	2023-10-14	USD	CBR	60.451460
978	2023-10-14	EUR	CBR	70.319487
643	2023-10-14	RUB	CBR	1.000000
156	2023-10-15	CNY	CBR	9.657109
356	2023-10-15	INR	CBR	0.956428
398	2023-10-15	KZT	CBR	0.070000
840	2023-10-15	USD	CBR	60.067753
978	2023-10-15	EUR	CBR	69.594654
643	2023-10-15	RUB	CBR	1.000000
156	2023-10-16	CNY	CBR	9.611408
356	2023-10-16	INR	CBR	0.417439
398	2023-10-16	KZT	CBR	0.070000
840	2023-10-16	USD	CBR	59.567205
978	2023-10-16	EUR	CBR	70.169702
643	2023-10-16	RUB	CBR	1.000000
156	2023-10-17	CNY	CBR	9.965166
356	2023-10-17	INR	CBR	0.635379
398	2023-10-17	KZT	CBR	0.227500
840	2023-10-17	USD	CBR	60.050086
978	2023-10-17	EUR	CBR	70.223223
643	2023-10-17	RUB	CBR	1.000000
156	2023-10-18	CNY	CBR	9.262260
356	2023-10-18	INR	CBR	0.746024
398	2023-10-18	KZT	CBR	0.429760
840	2023-10-18	USD	CBR	60.112204
978	2023-10-18	EUR	CBR	70.192167
643	2023-10-18	RUB	CBR	1.000000
156	2023-10-19	CNY	CBR	9.118273
356	2023-10-19	INR	CBR	1.120158
398	2023-10-19	KZT	CBR	0.116481
840	2023-10-19	USD	CBR	60.014075
978	2023-10-19	EUR	CBR	69.620353
643	2023-10-19	RUB	CBR	1.000000
156	2023-10-20	CNY	CBR	9.561576
356	2023-10-20	INR	CBR	0.559203
398	2023-10-20	KZT	CBR	0.070000
840	2023-10-20	USD	CBR	60.036305
978	2023-10-20	EUR	CBR	69.758899
643	2023-10-20	RUB	CBR	1.000000
156	2023-10-21	CNY	CBR	9.687344
356	2023-10-21	INR	CBR	1.190004
398	2023-10-21	KZT	CBR	0.451248
840	2023-10-21	USD	CBR	60.335552
978	2023-10-21	EUR	CBR	70.481920
643	2023-10-21	RUB	CBR	1.000000
156	2023-10-22	CNY	CBR	9.029287
356	2023-10-22	INR	CBR	0.598270
398	2023-10-22	KZT	CBR	0.070000
840	2023-10-22	USD	CBR	60.290424
978	2023-10-22	EUR	CBR	69.896201
643	2023-10-22	RUB	CBR	1.000000
156	2023-10-23	CNY	CBR	9.704095
356	2023-10-23	INR	CBR	0.682678
398	2023-10-23	KZT	CBR	0.101841
840	2023-10-23	USD	CBR	59.923597
978	2023-10-23	EUR	CBR	70.494986
643	2023-10-23	RUB	CBR	1.000000
156	2023-10-24	CNY	CBR	9.596159
356	2023-10-24	INR	CBR	1.391788
398	2023-10-24	KZT	CBR	0.070000
840	2023-10-24	USD	CBR	60.270148
978	2023-10-24	EUR	CBR	70.471458
643	2023-10-24	RUB	CBR	1.000000
156	2023-10-25	CNY	CBR	9.036739
356	2023-10-25	INR	CBR	0.445852
398	2023-10-25	KZT	CBR	0.277254
840	2023-10-25	USD	CBR	60.320820
978	2023-10-25	EUR	CBR	70.359631
643	2023-10-25	RUB	CBR	1.000000
156	2023-10-26	CNY	CBR	9.874766
356	2023-10-26	INR	CBR	0.651640
398	2023-10-26	KZT	CBR	0.436668
840	2023-10-26	USD	CBR	59.731688
978	2023-10-26	EUR	CBR	69.764771
643	2023-10-26	RUB	CBR	1.000000
156	2023-10-27	CNY	CBR	9.517028
356	2023-10-27	INR	CBR	0.747427
398	2023-10-27	KZT	CBR	0.287896
840	2023-10-27	USD	CBR	59.839926
978	2023-10-27	EUR	CBR	69.657810
643	2023-10-27	RUB	CBR	1.000000
156	2023-10-28	CNY	CBR	9.596903
356	2023-10-28	INR	CBR	1.198958
398	2023-10-28	KZT	CBR	0.076076
840	2023-10-28	USD	CBR	60.468536
978	2023-10-28	EUR	CBR	69.669457
643	2023-10-28	RUB	CBR	1.000000
156	2023-10-29	CNY	CBR	9.100964
356	2023-10-29	INR	CBR	1.340541
398	2023-10-29	KZT	CBR	0.070000
840	2023-10-29	USD	CBR	60.223891
978	2023-10-29	EUR	CBR	69.785257
643	2023-10-29	RUB	CBR	1.000000
156	2023-10-30	CNY	CBR	9.586202
356	2023-10-30	INR	CBR	1.290557
398	2023-10-30	KZT	CBR	0.070000
840	2023-10-30	USD	CBR	59.579142
978	2023-10-30	EUR	CBR	70.161704
643	2023-10-30	RUB	CBR	1.000000
156	2023-10-31	CNY	CBR	9.091983
356	2023-10-31	INR	CBR	0.785008
398	2023-10-31	KZT	CBR	0.070000
840	2023-10-31	USD	CBR	59.929509
978	2023-10-31	EUR	CBR	70.145279
643	2023-10-31	RUB	CBR	1.000000
156	2023-11-01	CNY	CBR	9.694204
356	2023-11-01	INR	CBR	1.309993
398	2023-11-01	KZT	CBR	0.424514
840	2023-11-01	USD	CBR	59.633709
978	2023-11-01	EUR	CBR	69.622975
643	2023-11-01	RUB	CBR	1.000000
156	2023-11-02	CNY	CBR	9.418372
356	2023-11-02	INR	CBR	1.014983
398	2023-11-02	KZT	CBR	0.402952
840	2023-11-02	USD	CBR	60.214491
978	2023-11-02	EUR	CBR	69.633372
643	2023-11-02	RUB	CBR	1.000000
156	2023-11-03	CNY	CBR	9.594627
356	2023-11-03	INR	CBR	0.457133
398	2023-11-03	KZT	CBR	0.371085
840	2023-11-03	USD	CBR	59.642455
978	2023-11-03	EUR	CBR	69.728347
643	2023-11-03	RUB	CBR	1.000000
156	2023-11-04	CNY	CBR	9.343989
356	2023-11-04	INR	CBR	1.128968
398	2023-11-04	KZT	CBR	0.070000
840	2023-11-04	USD	CBR	60.293082
978	2023-11-04	EUR	CBR	70.291883
643	2023-11-04	RUB	CBR	1.000000
156	2023-11-05	CNY	CBR	9.354104
356	2023-11-05	INR	CBR	1.323115
398	2023-11-05	KZT	CBR	0.070000
840	2023-11-05	USD	CBR	60.413988
978	2023-11-05	EUR	CBR	70.055795
643	2023-11-05	RUB	CBR	1.000000
156	2023-11-06	CNY	CBR	9.868735
356	2023-11-06	INR	CBR	1.114253
398	2023-11-06	KZT	CBR	0.070000
840	2023-11-06	USD	CBR	59.721615
978	2023-11-06	EUR	CBR	70.213081
643	2023-11-06	RUB	CBR	1.000000
156	2023-11-07	CNY	CBR	9.356740
356	2023-11-07	INR	CBR	1.031615
398	2023-11-07	KZT	CBR	0.083658
840	2023-11-07	USD	CBR	59.661208
978	2023-11-07	EUR	CBR	70.071178
643	2023-11-07	RUB	CBR	1.000000
156	2023-11-08	CNY	CBR	9.983266
356	2023-11-08	INR	CBR	0.900051
398	2023-11-08	KZT	CBR	0.355009
840	2023-11-08	USD	CBR	59.703179
978	2023-11-08	EUR	CBR	69.704506
643	2023-11-08	RUB	CBR	1.000000
156	2023-11-09	CNY	CBR	9.869205
356	2023-11-09	INR	CBR	1.302367
398	2023-11-09	KZT	CBR	0.070000
840	2023-11-09	USD	CBR	60.320883
978	2023-11-09	EUR	CBR	69.852550
643	2023-11-09	RUB	CBR	1.000000
156	2023-11-10	CNY	CBR	9.114427
356	2023-11-10	INR	CBR	1.248176
398	2023-11-10	KZT	CBR	0.070000
840	2023-11-10	USD	CBR	60.302663
978	2023-11-10	EUR	CBR	70.201562
643	2023-11-10	RUB	CBR	1.000000
156	2023-11-11	CNY	CBR	9.404806
356	2023-11-11	INR	CBR	0.934955
398	2023-11-11	KZT	CBR	0.445691
840	2023-11-11	USD	CBR	60.036088
978	2023-11-11	EUR	CBR	70.209132
643	2023-11-11	RUB	CBR	1.000000
156	2023-11-12	CNY	CBR	9.874481
356	2023-11-12	INR	CBR	1.360592
398	2023-11-12	KZT	CBR	0.198943
840	2023-11-12	USD	CBR	59.867292
978	2023-11-12	EUR	CBR	70.068335
643	2023-11-12	RUB	CBR	1.000000
156	2023-11-13	CNY	CBR	9.519263
356	2023-11-13	INR	CBR	1.001095
398	2023-11-13	KZT	CBR	0.070000
840	2023-11-13	USD	CBR	60.164225
978	2023-11-13	EUR	CBR	69.920215
643	2023-11-13	RUB	CBR	1.000000
156	2023-11-14	CNY	CBR	9.618446
356	2023-11-14	INR	CBR	0.411777
398	2023-11-14	KZT	CBR	0.070000
840	2023-11-14	USD	CBR	60.282639
978	2023-11-14	EUR	CBR	69.626141
643	2023-11-14	RUB	CBR	1.000000
156	2023-11-15	CNY	CBR	9.083442
356	2023-11-15	INR	CBR	0.585423
398	2023-11-15	KZT	CBR	0.468688
840	2023-11-15	USD	CBR	59.742205
978	2023-11-15	EUR	CBR	70.231647
643	2023-11-15	RUB	CBR	1.000000
156	2023-11-16	CNY	CBR	9.621962
356	2023-11-16	INR	CBR	1.238715
398	2023-11-16	KZT	CBR	0.451187
840	2023-11-16	USD	CBR	60.275585
978	2023-11-16	EUR	CBR	69.568292
643	2023-11-16	RUB	CBR	1.000000
156	2023-11-17	CNY	CBR	9.386113
356	2023-11-17	INR	CBR	1.365608
398	2023-11-17	KZT	CBR	0.245950
840	2023-11-17	USD	CBR	60.070633
978	2023-11-17	EUR	CBR	69.548359
643	2023-11-17	RUB	CBR	1.000000
156	2023-11-18	CNY	CBR	9.322931
356	2023-11-18	INR	CBR	0.735427
398	2023-11-18	KZT	CBR	0.070000
840	2023-11-18	USD	CBR	60.411074
978	2023-11-18	EUR	CBR	69.500632
643	2023-11-18	RUB	CBR	1.000000
156	2023-11-19	CNY	CBR	9.148917
356	2023-11-19	INR	CBR	0.606100
398	2023-11-19	KZT	CBR	0.298479
840	2023-11-19	USD	CBR	59.635459
978	2023-11-19	EUR	CBR	70.310748
643	2023-11-19	RUB	CBR	1.000000
156	2023-11-20	CNY	CBR	9.349666
356	2023-11-20	INR	CBR	0.620129
398	2023-11-20	KZT	CBR	0.070000
840	2023-11-20	USD	CBR	60.118908
978	2023-11-20	EUR	CBR	70.483249
643	2023-11-20	RUB	CBR	1.000000
156	2023-11-21	CNY	CBR	9.821545
356	2023-11-21	INR	CBR	0.988633
398	2023-11-21	KZT	CBR	0.070000
840	2023-11-21	USD	CBR	60.410581
978	2023-11-21	EUR	CBR	69.893700
643	2023-11-21	RUB	CBR	1.000000
156	2023-11-22	CNY	CBR	9.819286
356	2023-11-22	INR	CBR	0.977136
398	2023-11-22	KZT	CBR	0.070000
840	2023-11-22	USD	CBR	59.628778
978	2023-11-22	EUR	CBR	69.940562
643	2023-11-22	RUB	CBR	1.000000
156	2023-11-23	CNY	CBR	9.926651
356	2023-11-23	INR	CBR	1.332095
398	2023-11-23	KZT	CBR	0.220791
840	2023-11-23	USD	CBR	60.457491
978	2023-11-23	EUR	CBR	70.364017
643	2023-11-23	RUB	CBR	1.000000
156	2023-11-24	CNY	CBR	9.551541
356	2023-11-24	INR	CBR	1.006061
398	2023-11-24	KZT	CBR	0.605981
840	2023-11-24	USD	CBR	59.937616
978	2023-11-24	EUR	CBR	69.720027
643	2023-11-24	RUB	CBR	1.000000
156	2023-11-25	CNY	CBR	9.649320
356	2023-11-25	INR	CBR	0.460364
398	2023-11-25	KZT	CBR	0.070000
840	2023-11-25	USD	CBR	59.763742
978	2023-11-25	EUR	CBR	70.479495
643	2023-11-25	RUB	CBR	1.000000
156	2023-11-26	CNY	CBR	9.911234
356	2023-11-26	INR	CBR	1.123214
398	2023-11-26	KZT	CBR	0.070000
840	2023-11-26	USD	CBR	60.174290
978	2023-11-26	EUR	CBR	70.473905
643	2023-11-26	RUB	CBR	1.000000
156	2023-11-27	CNY	CBR	9.807492
356	2023-11-27	INR	CBR	0.994275
398	2023-11-27	KZT	CBR	0.259997
840	2023-11-27	USD	CBR	60.127109
978	2023-11-27	EUR	CBR	70.185956
643	2023-11-27	RUB	CBR	1.000000
156	2023-11-28	CNY	CBR	9.981089
356	2023-11-28	INR	CBR	1.315168
398	2023-11-28	KZT	CBR	0.339402
840	2023-11-28	USD	CBR	59.740244
978	2023-11-28	EUR	CBR	70.376914
643	2023-11-28	RUB	CBR	1.000000
156	2023-11-29	CNY	CBR	9.744017
356	2023-11-29	INR	CBR	0.532341
398	2023-11-29	KZT	CBR	0.165370
840	2023-11-29	USD	CBR	59.531519
978	2023-11-29	EUR	CBR	70.067694
643	2023-11-29	RUB	CBR	1.000000
156	2023-11-30	CNY	CBR	9.664558
356	2023-11-30	INR	CBR	0.484099
398	2023-11-30	KZT	CBR	0.090524
840	2023-11-30	USD	CBR	59.731944
978	2023-11-30	EUR	CBR	69.869397
643	2023-11-30	RUB	CBR	1.000000
156	2023-12-01	CNY	CBR	9.459701
356	2023-12-01	INR	CBR	0.722799
398	2023-12-01	KZT	CBR	0.070000
840	2023-12-01	USD	CBR	59.892006
978	2023-12-01	EUR	CBR	69.818341
643	2023-12-01	RUB	CBR	1.000000
156	2023-12-02	CNY	CBR	9.951166
356	2023-12-02	INR	CBR	1.089414
398	2023-12-02	KZT	CBR	0.070000
840	2023-12-02	USD	CBR	60.291782
978	2023-12-02	EUR	CBR	70.139543
643	2023-12-02	RUB	CBR	1.000000
156	2023-12-03	CNY	CBR	9.655304
356	2023-12-03	INR	CBR	0.905100
398	2023-12-03	KZT	CBR	0.474373
840	2023-12-03	USD	CBR	60.320128
978	2023-12-03	EUR	CBR	70.245999
643	2023-12-03	RUB	CBR	1.000000
156	2023-12-04	CNY	CBR	9.085260
356	2023-12-04	INR	CBR	1.291785
398	2023-12-04	KZT	CBR	0.141509
840	2023-12-04	USD	CBR	60.138821
978	2023-12-04	EUR	CBR	70.408212
643	2023-12-04	RUB	CBR	1.000000
156	2023-12-05	CNY	CBR	9.885588
356	2023-12-05	INR	CBR	0.537071
398	2023-12-05	KZT	CBR	0.328589
840	2023-12-05	USD	CBR	60.183105
978	2023-12-05	EUR	CBR	70.118230
643	2023-12-05	RUB	CBR	1.000000
156	2023-12-06	CNY	CBR	9.238575
356	2023-12-06	INR	CBR	1.184769
398	2023-12-06	KZT	CBR	0.194783
840	2023-12-06	USD	CBR	59.534986
978	2023-12-06	EUR	CBR	70.070449
643	2023-12-06	RUB	CBR	1.000000
156	2023-12-07	CNY	CBR	9.373124
356	2023-12-07	INR	CBR	1.329331
398	2023-12-07	KZT	CBR	0.070000
840	2023-12-07	USD	CBR	59.725928
978	2023-12-07	EUR	CBR	69.979444
643	2023-12-07	RUB	CBR	1.000000
156	2023-12-08	CNY	CBR	9.072951
356	2023-12-08	INR	CBR	0.696495
398	2023-12-08	KZT	CBR	0.309820
840	2023-12-08	USD	CBR	59.947507
978	2023-12-08	EUR	CBR	70.302372
643	2023-12-08	RUB	CBR	1.000000
156	2023-12-09	CNY	CBR	9.919745
356	2023-12-09	INR	CBR	0.514582
398	2023-12-09	KZT	CBR	0.604517
840	2023-12-09	USD	CBR	59.709688
978	2023-12-09	EUR	CBR	70.197641
643	2023-12-09	RUB	CBR	1.000000
156	2023-12-10	CNY	CBR	9.761467
356	2023-12-10	INR	CBR	0.449360
398	2023-12-10	KZT	CBR	0.192767
840	2023-12-10	USD	CBR	59.730405
978	2023-12-10	EUR	CBR	69.894294
643	2023-12-10	RUB	CBR	1.000000
156	2023-12-11	CNY	CBR	9.204640
356	2023-12-11	INR	CBR	0.873125
398	2023-12-11	KZT	CBR	0.396552
840	2023-12-11	USD	CBR	60.136284
978	2023-12-11	EUR	CBR	69.633504
643	2023-12-11	RUB	CBR	1.000000
156	2023-12-12	CNY	CBR	9.776467
356	2023-12-12	INR	CBR	0.690951
398	2023-12-12	KZT	CBR	0.216666
840	2023-12-12	USD	CBR	59.541501
978	2023-12-12	EUR	CBR	70.425030
643	2023-12-12	RUB	CBR	1.000000
156	2023-12-13	CNY	CBR	9.639538
356	2023-12-13	INR	CBR	0.541866
398	2023-12-13	KZT	CBR	0.260382
840	2023-12-13	USD	CBR	59.737288
978	2023-12-13	EUR	CBR	69.503488
643	2023-12-13	RUB	CBR	1.000000
156	2023-12-14	CNY	CBR	9.175411
356	2023-12-14	INR	CBR	1.355402
398	2023-12-14	KZT	CBR	0.070000
840	2023-12-14	USD	CBR	60.120888
978	2023-12-14	EUR	CBR	70.079924
643	2023-12-14	RUB	CBR	1.000000
156	2023-12-15	CNY	CBR	9.468752
356	2023-12-15	INR	CBR	0.409567
398	2023-12-15	KZT	CBR	0.494683
840	2023-12-15	USD	CBR	59.533927
978	2023-12-15	EUR	CBR	70.445637
643	2023-12-15	RUB	CBR	1.000000
156	2023-12-16	CNY	CBR	9.703517
356	2023-12-16	INR	CBR	1.141923
398	2023-12-16	KZT	CBR	0.070000
840	2023-12-16	USD	CBR	60.045669
978	2023-12-16	EUR	CBR	69.769302
643	2023-12-16	RUB	CBR	1.000000
156	2023-12-17	CNY	CBR	9.443931
356	2023-12-17	INR	CBR	1.014843
398	2023-12-17	KZT	CBR	0.155992
840	2023-12-17	USD	CBR	60.492122
978	2023-12-17	EUR	CBR	69.521309
643	2023-12-17	RUB	CBR	1.000000
156	2023-12-18	CNY	CBR	9.130171
356	2023-12-18	INR	CBR	0.901287
398	2023-12-18	KZT	CBR	0.490099
840	2023-12-18	USD	CBR	59.802137
978	2023-12-18	EUR	CBR	69.567067
643	2023-12-18	RUB	CBR	1.000000
156	2023-12-19	CNY	CBR	9.079620
356	2023-12-19	INR	CBR	0.748731
398	2023-12-19	KZT	CBR	0.070000
840	2023-12-19	USD	CBR	60.197135
978	2023-12-19	EUR	CBR	69.641122
643	2023-12-19	RUB	CBR	1.000000
156	2023-12-20	CNY	CBR	9.722804
356	2023-12-20	INR	CBR	0.846907
398	2023-12-20	KZT	CBR	0.194719
840	2023-12-20	USD	CBR	59.934374
978	2023-12-20	EUR	CBR	69.535994
643	2023-12-20	RUB	CBR	1.000000
156	2023-12-21	CNY	CBR	9.402081
356	2023-12-21	INR	CBR	0.644840
398	2023-12-21	KZT	CBR	0.071745
840	2023-12-21	USD	CBR	59.612928
978	2023-12-21	EUR	CBR	70.196423
643	2023-12-21	RUB	CBR	1.000000
156	2023-12-22	CNY	CBR	9.011687
356	2023-12-22	INR	CBR	1.196338
398	2023-12-22	KZT	CBR	0.367842
840	2023-12-22	USD	CBR	60.138251
978	2023-12-22	EUR	CBR	70.134518
643	2023-12-22	RUB	CBR	1.000000
156	2023-12-23	CNY	CBR	9.002963
356	2023-12-23	INR	CBR	1.248390
398	2023-12-23	KZT	CBR	0.500986
840	2023-12-23	USD	CBR	60.458499
978	2023-12-23	EUR	CBR	70.103749
643	2023-12-23	RUB	CBR	1.000000
156	2023-12-24	CNY	CBR	9.668291
356	2023-12-24	INR	CBR	0.558529
398	2023-12-24	KZT	CBR	0.622267
840	2023-12-24	USD	CBR	60.050584
978	2023-12-24	EUR	CBR	69.740818
643	2023-12-24	RUB	CBR	1.000000
156	2023-12-25	CNY	CBR	9.465731
356	2023-12-25	INR	CBR	0.414065
398	2023-12-25	KZT	CBR	0.070000
840	2023-12-25	USD	CBR	59.940243
978	2023-12-25	EUR	CBR	70.268530
643	2023-12-25	RUB	CBR	1.000000
\.


--
-- Data for Name: deposits; Type: TABLE DATA; Schema: bank; Owner: postgres
--

COPY bank.deposits (deposit_id, client_id, cur_id, issue_date, amount, interest_rate, maturity_date, status) FROM stdin;
1	69	643	2023-02-03	5763463.1242	10.744797	2023-09-17	закрыт
2	7	978	2023-06-21	9307137.3901	0.964178	2024-02-21	активен
3	10	643	2023-12-12	8159124.0488	9.129527	2024-01-18	активен
4	43	840	2023-03-25	3047380.4462	1.013483	2024-03-16	активен
5	38	156	2023-07-10	6637754.6148	0.932354	2024-01-04	активен
6	30	643	2023-03-25	5980611.7131	10.878555	2023-08-29	закрыт
7	38	398	2023-05-26	668449.3500	1.091125	2023-11-25	закрыт
8	80	356	2023-09-30	6838586.1262	0.939589	2024-05-24	активен
9	54	398	2023-09-27	1914835.1936	1.084251	2023-12-15	закрыт
10	16	156	2023-06-04	6172814.9020	1.067287	2024-03-15	активен
11	15	840	2023-10-03	7491063.3772	1.002788	2024-06-28	активен
12	57	398	2023-10-11	4329104.1846	1.072588	2024-05-18	активен
13	78	978	2023-04-30	5295506.7706	0.994176	2023-08-02	закрыт
14	43	643	2023-07-29	7063035.5692	10.582469	2024-03-06	активен
15	47	156	2023-01-27	2882135.4201	1.040069	2023-08-24	закрыт
16	62	398	2023-10-15	6289024.3982	1.008972	2023-12-23	закрыт
17	12	643	2023-07-14	1549743.6387	10.046948	2024-06-01	активен
18	72	398	2023-01-14	6680106.9922	1.033145	2023-02-16	закрыт
19	14	156	2023-03-16	3474374.7105	1.003912	2024-01-01	активен
20	83	840	2023-02-09	8217179.9900	1.031197	2023-10-27	закрыт
21	16	156	2023-09-13	8639142.1763	1.060035	2024-07-19	активен
22	61	156	2023-06-01	2701056.2305	1.061619	2023-07-09	закрыт
23	76	643	2023-01-25	6309454.5329	9.258934	2023-08-06	закрыт
24	67	156	2023-01-24	774253.8433	0.947100	2023-12-08	закрыт
25	32	398	2023-12-13	4888601.8653	1.004950	2024-01-24	активен
26	92	156	2023-02-08	8630851.9662	0.986703	2023-07-25	закрыт
27	18	356	2023-02-10	788474.4234	0.909331	2023-12-10	закрыт
28	46	356	2023-01-06	533488.0141	0.939939	2023-11-15	закрыт
29	64	156	2023-10-15	5486241.1802	0.962659	2024-11-07	активен
30	35	156	2023-09-12	3221188.3495	1.092106	2023-12-09	закрыт
31	89	643	2023-07-31	7619716.6607	9.895165	2024-02-13	активен
32	48	978	2023-11-11	6487080.8345	1.012523	2024-06-28	активен
33	32	398	2023-07-02	7171986.4885	0.991594	2024-06-29	активен
34	6	643	2023-11-17	2672668.6965	10.516958	2024-08-02	активен
35	63	398	2023-11-28	1027230.3572	1.032810	2023-12-30	активен
36	71	356	2023-06-10	1482997.8671	0.924643	2024-02-21	активен
37	37	356	2023-02-01	7005823.7412	1.043377	2023-05-27	закрыт
38	5	643	2023-09-22	9030237.7275	9.805067	2024-10-20	активен
39	73	398	2023-05-06	7551480.3744	1.028742	2023-06-11	закрыт
40	67	398	2023-03-27	4242880.1086	0.987731	2023-10-15	закрыт
41	87	840	2023-06-10	3556512.0919	0.951568	2023-07-29	закрыт
42	3	840	2023-07-20	9536929.2847	0.908500	2023-11-19	закрыт
43	8	156	2023-03-13	2423781.3352	1.088666	2023-09-25	закрыт
44	56	643	2023-07-09	9624399.3597	10.399729	2024-02-23	активен
45	54	398	2023-04-13	6525701.7042	1.037182	2023-12-14	закрыт
46	96	643	2023-06-24	6987792.2417	9.530458	2024-02-14	активен
47	60	398	2023-12-04	8181632.9958	0.914210	2024-06-14	активен
48	59	398	2023-11-12	6775510.8001	1.050099	2023-12-14	закрыт
49	23	978	2023-02-07	2194993.2562	1.086957	2023-04-05	закрыт
50	39	978	2023-08-28	997226.5109	0.941482	2024-07-03	активен
51	89	840	2023-10-17	1086225.6940	1.068265	2024-06-11	активен
52	4	398	2023-12-18	313754.6552	0.912871	2024-05-06	активен
53	60	398	2023-10-03	7088707.6137	0.928594	2024-06-05	активен
54	1	840	2023-08-21	9700472.8609	0.912555	2024-04-18	активен
55	35	840	2023-04-08	1849650.5084	1.070718	2024-03-15	активен
56	53	643	2023-10-20	5509755.7033	9.739132	2023-12-07	закрыт
57	26	156	2023-09-14	8299787.3609	1.044995	2024-05-11	активен
58	76	156	2023-10-29	8794795.9572	0.963294	2024-07-12	активен
59	100	356	2023-01-24	3286307.0876	0.944447	2024-01-25	активен
60	58	398	2023-08-25	1594238.9747	0.985033	2024-01-05	активен
61	48	643	2023-10-01	4542721.3578	9.867770	2024-03-17	активен
62	91	398	2023-05-06	3573048.2563	0.942757	2024-01-27	активен
63	81	643	2023-11-25	8061157.7272	9.477954	2024-11-17	активен
64	42	978	2023-10-07	8020955.1163	1.003916	2024-07-22	активен
65	93	643	2023-11-21	5825996.1127	9.191750	2024-03-13	активен
66	66	840	2023-10-13	9238169.0135	1.055340	2024-10-19	активен
67	28	398	2023-02-17	2698132.7929	0.946343	2024-03-10	активен
68	80	643	2023-04-18	5229588.7974	10.015964	2023-06-25	закрыт
69	69	643	2023-08-20	3425633.5154	9.462165	2024-04-11	активен
70	97	978	2023-04-20	1891438.9096	1.080648	2023-07-09	закрыт
71	32	978	2023-11-08	4078985.5506	1.069152	2024-01-19	активен
72	74	978	2023-12-18	8870421.0624	1.074538	2024-05-24	активен
73	74	398	2023-09-16	7221477.9376	0.902162	2024-02-24	активен
74	19	643	2023-07-14	8852859.3820	10.382850	2023-12-23	закрыт
75	58	398	2023-12-19	2913013.8386	1.036529	2024-11-01	активен
76	48	356	2023-09-08	3058242.0352	0.942946	2024-06-04	активен
77	61	156	2023-03-09	8030856.8779	1.092465	2024-03-30	активен
78	43	398	2023-05-09	6883937.4644	1.037372	2024-05-31	активен
79	78	356	2023-03-29	1134626.6840	1.077552	2024-03-26	активен
80	72	356	2023-08-01	4053670.2523	1.045710	2024-07-06	активен
81	47	978	2023-06-26	5332564.9220	0.913430	2024-03-08	активен
82	37	356	2023-06-18	7768429.6113	0.946506	2023-12-15	закрыт
83	44	840	2023-11-13	4367651.4721	1.034485	2024-03-05	активен
84	39	643	2023-04-19	7799980.3996	10.694586	2024-03-03	активен
85	99	156	2023-07-23	1886673.6300	1.061649	2024-05-13	активен
86	16	356	2023-10-03	2578496.9255	0.950327	2023-11-23	закрыт
87	62	643	2023-09-22	8245642.0245	10.254994	2024-09-08	активен
88	70	840	2023-02-15	3698081.7728	0.977007	2023-09-30	закрыт
89	60	978	2023-02-22	7126649.6752	1.030037	2023-06-13	закрыт
90	76	356	2023-08-28	8923138.6303	1.065579	2024-03-14	активен
91	84	840	2023-12-08	7468152.7606	0.946174	2024-06-18	активен
92	20	840	2023-05-04	3874244.3415	1.043722	2023-10-12	закрыт
93	20	356	2023-03-17	3938805.9912	0.917992	2023-06-09	закрыт
94	51	356	2023-10-04	4104997.9920	0.993553	2024-06-11	активен
95	89	398	2023-12-22	6531196.2857	1.045477	2024-11-29	активен
96	62	156	2023-09-09	4246886.8669	0.950439	2024-02-09	активен
97	68	978	2023-11-22	7382044.1995	1.079412	2024-05-01	активен
98	71	156	2023-02-23	6866065.4900	0.973482	2023-03-25	закрыт
99	77	840	2023-08-16	5347766.1353	0.909763	2024-08-26	активен
100	17	156	2023-05-05	5907433.2209	0.994851	2023-11-19	закрыт
101	81	156	2023-07-30	2451790.2169	1.002826	2023-10-10	закрыт
102	54	840	2023-09-08	8743815.3688	1.030401	2024-06-05	активен
103	96	156	2023-04-15	4803377.6411	1.074014	2024-01-19	активен
104	74	978	2023-09-27	3306491.4526	0.973206	2024-08-07	активен
105	63	978	2023-12-22	3456771.3675	0.972083	2025-01-13	активен
106	4	156	2023-12-05	6330333.4438	1.060073	2025-01-01	активен
107	39	978	2023-12-07	7032883.0367	1.020418	2024-07-23	активен
108	37	643	2023-05-25	9972013.4871	10.825836	2023-08-09	закрыт
109	91	840	2023-04-27	6584224.8347	0.936730	2024-04-28	активен
110	1	398	2023-05-07	3708643.3584	0.960114	2024-02-12	активен
111	56	978	2023-03-17	7417299.7617	0.985339	2024-01-10	активен
112	8	840	2023-03-12	2401459.4387	0.906824	2023-04-21	закрыт
113	94	840	2023-01-12	275341.9902	1.036465	2023-11-18	закрыт
114	91	356	2023-12-19	7255110.1128	0.943761	2024-02-29	активен
115	51	356	2023-10-01	9537901.4901	0.941037	2024-05-21	активен
116	27	643	2023-04-14	1498093.5057	9.683752	2024-04-27	активен
117	85	156	2023-04-18	6081302.8820	1.040245	2024-02-02	активен
118	28	398	2023-05-27	7366468.9274	0.920364	2024-04-08	активен
119	1	840	2023-11-14	679842.4435	1.091718	2024-08-07	активен
120	53	356	2023-06-26	6673225.4418	1.049961	2023-09-12	закрыт
121	69	156	2023-11-17	2232845.1244	0.921006	2024-05-16	активен
122	92	398	2023-04-02	2228655.2518	1.018243	2024-02-23	активен
123	13	840	2023-01-10	6948963.0375	1.012149	2023-06-28	закрыт
124	41	356	2023-10-13	2313605.3036	0.948127	2024-08-26	активен
125	85	978	2023-05-06	1145424.4456	1.002725	2024-02-02	активен
126	6	978	2023-04-12	5125122.4858	0.980739	2023-09-15	закрыт
127	14	398	2023-11-22	4307515.6880	1.047315	2024-06-11	активен
128	27	643	2023-12-18	4205943.6451	10.540096	2024-02-25	активен
129	11	978	2023-07-24	9660906.4756	0.950614	2023-08-31	закрыт
130	35	643	2023-10-10	991757.0859	9.717753	2024-10-17	активен
131	28	156	2023-11-06	6984108.4191	1.083127	2024-06-11	активен
132	81	356	2023-02-27	5704831.3955	0.911735	2023-07-18	закрыт
133	48	356	2023-05-04	3347428.6245	1.081475	2023-06-03	закрыт
134	66	156	2023-04-28	2889479.6524	0.993302	2024-04-25	активен
135	5	978	2023-11-06	4651814.1515	0.925030	2024-05-01	активен
136	46	840	2023-06-09	1311566.2765	1.099795	2024-04-14	активен
137	2	156	2023-01-18	5407383.8575	0.913938	2023-08-26	закрыт
138	68	156	2023-10-22	8588558.4764	1.050585	2023-12-22	закрыт
139	86	356	2023-02-10	4931052.8362	0.929340	2023-04-26	закрыт
140	95	978	2023-09-15	8312142.5478	0.951649	2024-05-29	активен
141	32	356	2023-06-15	9354030.7768	0.954711	2023-10-12	закрыт
142	20	356	2023-04-12	5268349.1333	1.094137	2023-05-23	закрыт
143	89	356	2023-11-25	9755479.9577	0.920285	2024-10-13	активен
144	67	356	2023-05-16	8417891.9136	0.911465	2024-06-02	активен
145	96	356	2023-06-20	8151566.1866	0.983191	2023-12-31	активен
146	7	356	2023-07-13	760548.3841	0.930829	2024-01-22	активен
147	53	840	2023-05-25	4899768.3917	1.082313	2023-11-25	закрыт
148	52	978	2023-03-26	9085615.9930	1.046072	2023-06-15	закрыт
149	2	978	2023-12-19	9030649.2247	0.935336	2024-10-06	активен
150	90	356	2023-06-17	7660729.8124	0.969212	2024-06-22	активен
151	43	840	2023-03-08	8159562.9573	1.084009	2023-08-25	закрыт
152	30	356	2023-10-11	2262092.1726	0.924941	2024-10-05	активен
153	97	840	2023-02-26	3276585.9941	0.949629	2023-09-14	закрыт
154	15	156	2023-06-26	2300904.0978	1.036641	2024-05-19	активен
155	28	840	2023-03-14	9316474.5257	0.981103	2023-11-20	закрыт
156	14	978	2023-08-01	8840194.6949	1.093138	2023-09-01	закрыт
157	21	156	2023-01-16	9721084.2602	0.944436	2023-11-21	закрыт
158	95	398	2023-10-23	7447131.4715	0.938738	2023-12-09	закрыт
159	69	398	2023-10-29	9627945.6900	0.980140	2024-07-31	активен
160	84	156	2023-06-24	2893335.3068	0.950778	2024-05-02	активен
161	90	398	2023-10-27	5924383.7117	1.022529	2024-01-22	активен
162	92	643	2023-02-04	7569141.1819	9.286953	2023-08-29	закрыт
163	65	840	2023-12-15	6748097.6404	1.072323	2024-12-28	активен
164	82	978	2023-06-27	8749890.8079	1.077302	2023-11-05	закрыт
165	81	356	2023-09-06	4083653.9944	0.990648	2024-03-16	активен
166	38	840	2023-07-07	8372385.2185	0.996918	2024-07-17	активен
167	27	978	2023-02-17	8650272.0098	1.023857	2023-11-10	закрыт
168	8	643	2023-08-03	4815590.9010	9.517085	2024-04-22	активен
169	26	398	2023-12-01	4090488.2155	1.055622	2024-11-26	активен
170	98	840	2023-01-29	3826688.0709	1.074737	2023-12-14	закрыт
171	57	398	2023-02-23	3490208.5866	1.033150	2024-01-11	активен
172	41	156	2023-02-24	9974029.5017	1.053138	2024-01-19	активен
173	98	398	2023-11-24	2489142.8107	1.049196	2024-06-01	активен
174	63	978	2023-09-15	2908590.0345	0.942009	2024-05-12	активен
175	33	356	2023-04-27	4817198.2635	0.942083	2023-09-20	закрыт
176	24	398	2023-11-25	1157514.8495	1.074932	2024-08-26	активен
177	97	840	2023-01-29	113375.9999	1.028334	2023-04-15	закрыт
178	95	840	2023-03-25	4453103.1292	1.031571	2023-11-23	закрыт
179	24	978	2023-12-10	381424.8955	0.940885	2024-09-28	активен
180	90	156	2023-08-09	3875546.6600	1.013456	2023-11-20	закрыт
181	45	978	2023-02-05	3585413.4151	0.960027	2023-07-12	закрыт
182	98	156	2023-07-08	2147629.4252	0.987546	2024-03-30	активен
183	11	840	2023-04-01	7086229.5896	0.960943	2023-12-04	закрыт
184	75	356	2023-08-16	9555236.4063	0.965922	2024-03-26	активен
185	10	978	2023-08-09	6634646.1994	1.062985	2023-09-30	закрыт
186	63	978	2023-07-25	9890714.0639	1.052838	2024-08-11	активен
187	59	978	2023-12-07	2247542.2903	1.081128	2024-06-28	активен
188	55	156	2023-08-22	6729377.2864	1.045589	2024-04-21	активен
189	80	356	2023-12-19	4393006.4339	0.978673	2024-02-04	активен
190	16	356	2023-02-14	8808570.0219	0.997824	2024-02-19	активен
191	49	978	2023-04-21	3336680.4156	1.026767	2023-08-13	закрыт
192	68	356	2023-11-07	1851008.9038	1.051612	2024-06-01	активен
193	11	978	2023-03-03	8260390.4384	0.964054	2023-07-13	закрыт
194	36	978	2023-12-01	9443584.0647	0.987963	2024-04-30	активен
195	12	398	2023-03-25	2099020.6204	0.932252	2024-04-16	активен
196	59	356	2023-05-16	3715864.9914	0.922512	2024-06-11	активен
197	5	156	2023-01-14	9295277.7273	0.931069	2023-12-17	закрыт
198	91	643	2023-04-18	5308983.3808	9.382612	2024-04-21	активен
199	8	356	2023-09-23	9907039.6173	1.043401	2024-04-14	активен
200	71	840	2023-01-02	6783627.5721	0.998959	2023-02-07	закрыт
201	42	356	2023-01-16	8382287.7779	1.013313	2023-12-11	закрыт
202	93	356	2023-11-17	1334571.9178	1.082444	2024-10-23	активен
203	58	978	2023-10-07	7553782.8267	0.918365	2024-08-11	активен
204	49	398	2023-02-17	2683544.0815	0.929785	2023-05-23	закрыт
205	39	356	2023-03-15	9408515.7993	1.059417	2023-05-08	закрыт
206	48	840	2023-01-19	1977560.6540	0.962651	2024-02-07	активен
207	60	978	2023-01-13	934122.9125	1.026992	2023-07-13	закрыт
208	88	156	2023-07-01	1742869.7470	0.989303	2024-07-26	активен
209	11	156	2023-05-09	7674804.2144	0.945912	2024-01-12	активен
210	77	398	2023-08-28	1100148.8463	1.077821	2023-11-02	закрыт
211	2	156	2023-08-29	2486288.9118	0.959030	2024-04-13	активен
212	50	356	2023-12-19	7621850.0936	1.036831	2024-05-11	активен
213	45	643	2023-09-05	7905238.6160	9.032397	2024-07-14	активен
214	59	156	2023-10-26	3089638.5801	1.017238	2024-01-20	активен
215	83	398	2023-06-11	5362315.4124	0.911835	2024-06-02	активен
216	9	978	2023-05-27	6641935.8296	0.946213	2023-09-19	закрыт
217	59	356	2023-01-11	2028706.8132	0.909420	2023-11-09	закрыт
218	33	398	2023-03-12	5690564.4544	0.910698	2023-05-20	закрыт
219	99	840	2023-09-15	7736390.3032	0.935800	2024-09-02	активен
220	5	840	2023-09-18	8650296.4062	1.054063	2024-10-09	активен
221	45	156	2023-08-18	6729634.6281	0.901193	2023-12-26	активен
222	13	840	2023-10-30	5687030.3749	1.074933	2023-11-30	закрыт
223	64	978	2023-08-31	5162500.4288	0.901540	2023-11-25	закрыт
224	48	398	2023-11-08	3939487.2318	0.972342	2024-06-01	активен
225	26	978	2023-12-22	3155518.2149	1.050814	2024-07-25	активен
226	34	840	2023-10-27	790182.7306	0.939040	2024-01-12	активен
227	52	156	2023-02-03	538079.8214	1.056271	2023-07-21	закрыт
228	20	356	2023-10-21	5443874.8758	1.027071	2024-03-14	активен
229	30	156	2023-06-07	5330847.0230	0.989837	2024-03-01	активен
230	45	978	2023-11-24	253868.2748	1.001368	2024-08-31	активен
231	38	978	2023-06-22	7188265.3528	0.992356	2024-06-05	активен
232	24	643	2023-10-28	8965989.2153	10.868475	2024-06-02	активен
233	17	356	2023-09-05	6548974.1048	0.976783	2024-01-25	активен
234	28	156	2023-01-24	4512117.6590	1.079787	2023-12-06	закрыт
235	56	398	2023-05-26	9862780.8313	0.950629	2024-04-23	активен
236	16	356	2023-04-17	5355587.4311	1.083699	2024-03-12	активен
237	14	840	2023-05-21	8337363.7106	1.072611	2024-02-10	активен
238	82	356	2023-03-21	6058928.4621	0.918394	2023-10-13	закрыт
239	39	978	2023-05-03	3779403.6058	0.968476	2023-06-17	закрыт
240	23	643	2023-05-06	5725981.6228	10.168436	2023-08-16	закрыт
241	45	978	2023-05-11	2800144.2493	1.046842	2023-09-18	закрыт
242	77	356	2023-04-23	7066348.0979	0.939166	2024-04-09	активен
243	93	356	2023-02-09	8728012.7054	1.073638	2024-02-28	активен
244	22	156	2023-09-15	1530963.1699	0.981837	2024-10-10	активен
245	43	840	2023-09-17	8516819.9310	1.077236	2024-03-31	активен
246	48	398	2023-12-03	9121847.1415	1.076998	2024-09-17	активен
247	93	156	2023-05-09	6932278.9800	0.904986	2023-09-25	закрыт
248	59	643	2023-03-21	6891720.2655	9.196965	2023-12-10	закрыт
249	43	643	2023-09-22	3159332.3558	9.574713	2023-10-25	закрыт
250	77	356	2023-05-13	1967191.3216	0.981586	2023-07-18	закрыт
251	91	643	2023-08-26	9671930.2635	9.023356	2024-09-09	активен
252	43	643	2023-08-28	2485599.3266	10.406954	2024-08-04	активен
253	17	398	2023-08-27	799139.4163	0.967645	2023-11-28	закрыт
254	91	840	2023-04-21	4345915.9430	1.059309	2024-05-10	активен
255	31	356	2023-11-08	6479659.4135	0.940814	2024-10-09	активен
256	42	156	2023-12-06	9317208.7404	0.910537	2024-04-20	активен
257	86	840	2023-04-02	731661.4156	0.997550	2023-09-23	закрыт
258	42	156	2023-02-16	9132105.1186	0.995865	2023-04-30	закрыт
259	68	978	2023-02-27	5280883.9143	0.989676	2023-12-12	закрыт
260	9	398	2023-11-26	66047.5026	1.032175	2024-07-23	активен
261	59	156	2023-01-13	7127969.8455	0.973647	2023-07-07	закрыт
262	17	978	2023-04-30	985979.1923	1.030874	2023-08-15	закрыт
263	6	840	2023-07-14	1523755.1086	0.979036	2024-01-22	активен
264	12	643	2023-12-12	6813010.6289	9.721937	2024-10-12	активен
265	34	156	2023-07-17	5778090.4828	1.010324	2023-12-31	активен
266	44	156	2023-06-21	7199179.0384	1.097791	2024-05-04	активен
267	83	398	2023-03-31	885551.1746	1.004817	2023-11-08	закрыт
268	92	978	2023-01-10	4939026.9656	0.927232	2023-10-02	закрыт
269	23	156	2023-02-16	2800628.1678	0.945546	2023-09-09	закрыт
270	69	398	2023-09-24	3933604.0123	1.034975	2024-04-08	активен
271	48	156	2023-04-29	9324666.6830	1.089170	2024-02-10	активен
272	31	978	2023-11-12	5449917.0262	0.902044	2024-02-27	активен
273	54	840	2023-08-10	1032761.1324	0.996465	2024-06-05	активен
274	89	978	2023-12-13	1361243.1299	0.925366	2024-02-19	активен
275	48	398	2023-05-22	8769586.0440	0.923325	2024-02-03	активен
276	9	643	2023-03-02	7731280.2207	9.445651	2023-07-10	закрыт
277	11	840	2023-11-05	8293359.4052	1.023784	2024-07-24	активен
278	96	398	2023-08-21	9418660.2238	0.999022	2023-11-20	закрыт
279	56	398	2023-10-13	3214517.6090	0.936107	2024-05-09	активен
280	83	356	2023-01-21	1998996.0836	1.060659	2023-10-10	закрыт
281	10	356	2023-04-12	5468079.2788	0.903023	2023-05-14	закрыт
282	34	978	2023-09-13	2939882.7501	0.940935	2024-09-11	активен
283	82	978	2023-03-20	6586925.8373	0.983781	2023-05-31	закрыт
284	62	398	2023-06-06	2889699.4694	0.951796	2024-03-13	активен
285	75	356	2023-02-09	9748913.6683	1.033294	2023-08-17	закрыт
286	38	356	2023-10-19	8315091.7141	1.058715	2024-04-20	активен
287	11	156	2023-09-11	8115854.3683	1.083789	2024-05-09	активен
288	6	978	2023-05-03	4539289.6566	0.954911	2023-06-30	закрыт
289	58	356	2023-06-03	1959427.1037	0.952908	2023-09-07	закрыт
290	40	643	2023-06-20	477193.6589	9.773242	2023-12-06	закрыт
291	77	156	2023-11-30	8159265.5392	0.952016	2024-08-31	активен
292	25	156	2023-03-10	9310524.9523	1.011656	2023-10-03	закрыт
293	30	643	2023-11-03	8777239.1643	10.661773	2024-07-24	активен
294	3	643	2023-02-22	8409492.3548	9.272314	2023-05-07	закрыт
295	56	156	2023-04-17	1125925.4736	1.027823	2023-06-01	закрыт
296	70	156	2023-10-27	9629166.8059	1.039421	2023-12-02	закрыт
297	76	643	2023-03-10	2209110.5753	10.538071	2023-04-12	закрыт
298	57	356	2023-11-16	3756663.1765	1.016076	2024-02-13	активен
299	19	978	2023-01-26	76038.9896	1.072083	2023-12-01	закрыт
300	54	156	2023-02-21	9394093.4240	1.078275	2024-01-27	активен
301	53	840	2023-06-03	3770809.7581	1.030036	2024-04-29	активен
302	86	643	2023-02-08	8726375.8461	9.157770	2023-07-04	закрыт
303	68	840	2023-04-21	2685981.1640	0.978768	2023-11-16	закрыт
304	78	978	2023-09-28	1364404.5635	0.967708	2024-10-25	активен
305	65	356	2023-01-26	8043021.8127	0.945454	2024-02-05	активен
306	26	398	2023-08-26	4166440.9787	0.933216	2024-01-11	активен
307	19	356	2023-12-06	8179146.2691	0.957886	2024-10-09	активен
308	98	643	2023-04-30	2766337.6274	9.045453	2024-03-13	активен
309	35	978	2023-02-23	4218065.2677	1.023334	2023-10-30	закрыт
310	99	643	2023-05-08	4276326.7020	10.889462	2023-07-31	закрыт
311	62	398	2023-03-25	6574169.9074	1.097030	2023-06-21	закрыт
312	17	643	2023-03-07	5715237.1583	9.463051	2023-10-08	закрыт
313	31	840	2023-08-23	5404571.7955	1.029598	2024-01-20	активен
314	35	978	2023-01-15	8672715.1526	0.911154	2023-04-18	закрыт
315	49	978	2023-03-10	123334.1852	1.076001	2024-01-19	активен
316	87	840	2023-12-23	5802115.4487	0.939893	2024-02-23	активен
317	79	156	2023-06-30	9212111.0156	0.992413	2023-09-02	закрыт
318	5	978	2023-05-22	396462.9685	0.940392	2023-11-10	закрыт
319	14	156	2023-09-27	5336510.3812	0.919851	2023-12-28	активен
320	34	978	2023-01-19	7567363.9113	1.075943	2023-09-22	закрыт
321	22	643	2023-04-20	3275965.7739	9.461714	2023-07-19	закрыт
322	81	156	2023-11-23	9600282.2212	0.912039	2024-03-11	активен
323	7	840	2023-11-08	8178329.8856	1.029466	2024-05-27	активен
324	73	356	2023-09-15	8001010.3643	1.020147	2024-04-07	активен
325	74	356	2023-01-01	9539537.4100	1.032361	2023-06-29	закрыт
326	42	398	2023-01-30	1886960.7521	0.900381	2023-12-13	закрыт
327	27	840	2023-02-10	2132376.1226	1.047960	2023-09-25	закрыт
328	67	356	2023-04-15	3473478.7229	0.915724	2023-10-15	закрыт
329	14	398	2023-02-03	3459911.7332	0.994108	2024-01-21	активен
330	82	978	2023-03-04	4149742.3060	0.965220	2024-03-15	активен
331	50	356	2023-01-30	2178179.1493	0.903480	2023-08-02	закрыт
332	83	156	2023-11-20	8476588.9990	1.005406	2024-02-25	активен
333	17	643	2023-12-02	2093197.8269	10.245730	2024-01-10	активен
334	20	978	2023-02-19	5438449.9079	0.902968	2023-07-02	закрыт
335	55	840	2023-08-24	266274.5135	0.901289	2024-02-15	активен
336	51	978	2023-05-17	5346581.1280	1.027390	2023-09-26	закрыт
337	9	156	2023-06-24	3334311.0283	1.039151	2024-06-06	активен
338	45	643	2023-09-18	960770.2985	10.192752	2024-03-19	активен
339	24	398	2023-08-28	8756077.5243	1.026086	2024-04-06	активен
340	28	156	2023-09-19	74196.7403	0.978049	2024-03-12	активен
341	84	840	2023-08-11	1468514.2520	0.992654	2024-08-18	активен
342	9	978	2023-06-11	2650506.9744	1.031847	2023-11-06	закрыт
343	36	398	2023-07-13	4300530.7870	0.950056	2024-06-09	активен
344	94	156	2023-12-01	2121595.5722	0.981088	2024-01-10	активен
345	31	398	2023-05-15	7391222.9177	1.010014	2023-11-16	закрыт
346	33	356	2023-01-20	119621.1774	1.051804	2023-11-29	закрыт
347	88	356	2023-06-24	2263461.6634	0.996018	2024-01-17	активен
348	61	978	2023-09-15	4403231.0836	1.079405	2024-09-01	активен
349	14	356	2023-11-11	4009790.9112	0.920027	2024-06-11	активен
350	91	840	2023-04-09	632362.4870	0.903593	2024-03-23	активен
351	33	398	2023-10-17	2100241.1099	0.909423	2024-10-28	активен
352	15	156	2023-06-15	6543789.4447	0.949009	2024-06-18	активен
353	45	840	2023-05-17	7882211.8550	0.990403	2023-11-17	закрыт
354	28	840	2023-09-28	7649182.4725	0.996260	2024-10-22	активен
355	60	840	2023-02-25	2183220.5008	0.999210	2023-06-05	закрыт
356	8	643	2023-12-08	646398.2925	10.891520	2024-06-12	активен
357	6	398	2023-10-18	7918886.1322	1.097095	2024-08-17	активен
358	57	356	2023-05-06	3215554.7492	1.038854	2024-02-18	активен
359	92	840	2023-10-11	7268421.7820	1.048165	2024-03-22	активен
360	59	398	2023-10-12	6458777.6201	0.934334	2023-12-07	закрыт
361	4	398	2023-08-14	8182321.3969	0.997906	2024-08-15	активен
362	85	356	2023-08-16	8179546.4297	1.025477	2024-08-31	активен
363	79	643	2023-12-20	1447088.5540	9.821304	2024-12-26	активен
364	7	840	2023-03-15	808956.5123	1.062898	2023-10-03	закрыт
365	85	398	2023-06-11	9166331.4954	0.987798	2023-10-03	закрыт
366	74	643	2023-10-29	9995942.3289	10.829558	2024-04-10	активен
367	71	156	2023-09-21	6812201.7361	0.915614	2024-03-14	активен
368	3	978	2023-12-24	2450466.4759	0.993650	2024-02-17	активен
369	72	398	2023-05-31	373033.1295	0.946272	2023-10-21	закрыт
370	52	840	2023-01-11	1404986.3279	0.939148	2023-02-12	закрыт
371	78	398	2023-03-30	3065136.1325	1.087470	2023-07-05	закрыт
372	61	398	2023-01-08	4953728.3735	1.055122	2023-02-11	закрыт
373	37	356	2023-07-07	3114004.9845	1.075919	2024-06-04	активен
374	90	156	2023-07-13	5777704.3083	0.974331	2024-06-01	активен
375	31	356	2023-07-14	3423051.2443	0.970505	2023-09-01	закрыт
376	99	840	2023-07-06	8435466.2031	0.988542	2023-09-05	закрыт
377	27	398	2023-04-22	9234589.5660	0.912182	2024-05-06	активен
378	42	978	2023-01-02	5251253.2874	1.023640	2023-03-28	закрыт
379	78	840	2023-03-01	8530843.8127	0.965052	2023-12-02	закрыт
380	60	156	2023-09-10	9831717.8437	1.022903	2023-12-08	закрыт
381	67	356	2023-07-02	3223172.7954	0.920746	2024-02-16	активен
382	33	398	2023-11-22	5351122.1508	0.911605	2024-09-01	активен
383	97	356	2023-11-28	3297756.6346	0.906754	2024-02-15	активен
384	90	398	2023-02-18	8608510.0875	0.936774	2024-01-31	активен
385	27	156	2023-07-21	5342490.6293	0.977180	2023-10-01	закрыт
386	24	356	2023-01-18	513805.4399	0.931966	2023-06-17	закрыт
387	51	398	2023-09-09	802358.1285	0.963195	2024-08-18	активен
388	19	156	2023-07-28	7583853.0101	0.919230	2023-10-17	закрыт
389	11	978	2023-02-14	728266.8460	1.027563	2023-11-14	закрыт
390	50	356	2023-06-04	1832265.4357	1.011311	2024-04-02	активен
391	9	398	2023-05-25	6142326.3290	0.911830	2023-09-04	закрыт
392	88	840	2023-09-02	5758459.3827	1.014369	2024-02-17	активен
393	17	978	2023-05-06	2640667.8363	1.000796	2023-11-03	закрыт
394	22	978	2023-11-29	6449710.4468	0.990285	2024-01-22	активен
395	60	356	2023-04-18	205132.3142	0.978223	2024-03-04	активен
396	94	643	2023-02-11	3445881.0975	10.624635	2023-06-16	закрыт
397	61	978	2023-10-26	1549894.5826	0.907269	2024-05-12	активен
398	97	840	2023-12-23	835447.0465	0.961334	2024-08-14	активен
399	26	156	2023-09-09	4288427.5523	0.951492	2024-07-16	активен
400	24	356	2023-07-09	6005875.8636	1.050058	2024-02-14	активен
401	95	356	2023-08-18	8796233.9732	1.057880	2024-09-12	активен
402	28	840	2023-02-14	2871485.5510	0.911893	2023-08-15	закрыт
403	47	978	2023-05-08	6285324.3032	1.023525	2024-02-19	активен
404	82	978	2023-01-31	2692766.9239	0.968901	2023-04-13	закрыт
405	93	156	2023-05-08	5495264.7691	0.941393	2024-05-07	активен
406	37	840	2023-12-16	6266235.8088	1.077399	2024-05-30	активен
407	13	643	2023-03-06	8281270.1170	10.089077	2024-03-10	активен
408	96	356	2023-09-09	7190565.8234	1.083256	2024-03-22	активен
409	83	643	2023-08-09	1994912.5224	10.875495	2023-12-03	закрыт
410	83	978	2023-03-26	4397631.9005	1.094763	2023-05-31	закрыт
411	77	643	2023-05-10	1683378.9216	9.016679	2024-05-08	активен
412	53	840	2023-01-21	7950411.3251	1.097946	2024-02-08	активен
413	58	398	2023-10-25	2727683.5818	1.055256	2023-12-04	закрыт
414	51	978	2023-09-15	641755.8764	0.924015	2024-04-15	активен
415	14	398	2023-09-28	5463624.9734	1.024195	2024-07-15	активен
416	3	156	2023-01-23	8071868.8023	0.921409	2023-12-14	закрыт
417	95	978	2023-07-01	4323075.6326	1.052950	2024-03-01	активен
418	29	156	2023-10-07	6971869.5330	0.982282	2023-11-09	закрыт
419	52	156	2023-09-24	5753062.2083	1.088293	2024-06-28	активен
420	40	356	2023-04-17	4052639.2830	1.042566	2024-05-01	активен
421	34	840	2023-09-06	9686238.5736	1.020629	2024-02-09	активен
422	43	978	2023-07-07	4270239.6900	1.090482	2023-09-27	закрыт
423	73	978	2023-07-01	1950714.7139	0.963938	2024-03-20	активен
424	5	156	2023-05-06	9908782.4684	1.044468	2024-04-21	активен
425	65	356	2023-02-03	6851708.8189	1.039117	2023-08-09	закрыт
426	32	156	2023-08-31	9492443.8502	1.067647	2024-08-23	активен
427	73	978	2023-03-22	9083114.8669	0.916179	2023-11-26	закрыт
428	34	398	2023-11-12	5392264.2251	1.091776	2024-04-27	активен
429	6	978	2023-04-27	1381375.2095	0.961560	2023-09-26	закрыт
430	26	356	2023-07-25	8743489.5321	0.977003	2024-04-22	активен
431	77	978	2023-09-29	1057126.8436	1.087082	2024-01-28	активен
432	13	643	2023-12-14	7516090.6027	10.094743	2024-01-19	активен
433	98	643	2023-03-30	8544465.5409	10.951606	2023-06-01	закрыт
434	60	643	2023-03-20	5854199.6457	9.365295	2023-08-25	закрыт
435	47	156	2023-06-16	7823276.5429	0.919186	2024-04-12	активен
436	59	356	2023-03-27	281603.1330	1.033105	2023-11-11	закрыт
437	82	356	2023-04-26	4565236.1517	0.992209	2023-07-09	закрыт
438	38	840	2023-10-20	5952874.3414	0.901121	2024-08-31	активен
439	52	643	2023-09-07	2651505.9473	10.884343	2024-03-29	активен
440	51	643	2023-02-15	776324.5616	9.930107	2023-06-10	закрыт
441	65	156	2023-07-04	2371190.4731	1.040034	2024-05-21	активен
442	91	156	2023-07-05	7284664.3864	1.027104	2023-11-05	закрыт
443	26	156	2023-12-21	4632450.7384	0.959231	2024-12-12	активен
444	92	356	2023-08-07	5656942.4525	0.957917	2023-10-22	закрыт
445	62	643	2023-07-22	4269157.7038	10.270987	2024-03-31	активен
446	48	356	2023-11-02	5154987.2805	0.952425	2024-11-06	активен
447	87	156	2023-11-19	7972562.7353	1.034892	2024-07-07	активен
448	80	840	2023-12-15	5606983.3939	1.000013	2024-07-14	активен
449	62	398	2023-01-18	6193936.7831	0.969584	2023-05-15	закрыт
450	33	356	2023-05-29	8139742.7329	1.085028	2023-08-20	закрыт
451	58	356	2023-04-03	2076221.0639	0.937669	2023-12-23	закрыт
452	37	398	2023-10-09	1761741.7673	1.093557	2024-10-30	активен
453	99	978	2023-09-10	6993086.4825	1.073204	2024-07-31	активен
454	49	398	2023-10-17	4897259.0017	0.989202	2024-05-31	активен
455	27	840	2023-07-23	1818409.3051	1.023895	2023-10-12	закрыт
456	92	840	2023-10-22	2625234.8314	0.941887	2024-02-25	активен
457	61	643	2023-08-10	4767415.0526	10.579680	2023-09-28	закрыт
458	36	156	2023-06-03	2212546.0597	1.075096	2024-04-21	активен
459	10	840	2023-01-30	1106090.6194	0.997226	2023-06-19	закрыт
460	16	643	2023-08-28	2773695.5713	9.790548	2023-11-08	закрыт
461	78	978	2023-11-25	6627964.1474	0.972762	2024-04-29	активен
462	86	398	2023-08-12	1306268.9886	1.006609	2023-10-15	закрыт
463	53	643	2023-08-06	6511328.0280	10.095067	2024-04-12	активен
464	26	398	2023-07-03	3715124.7289	0.932493	2024-06-22	активен
465	45	398	2023-09-02	3287267.8086	1.000270	2024-03-01	активен
466	25	156	2023-10-16	6685638.4187	0.902984	2024-08-17	активен
467	43	643	2023-01-01	4543098.6443	9.212070	2023-12-24	закрыт
468	32	643	2023-10-17	411988.9347	10.714898	2024-08-03	активен
469	15	156	2023-03-25	9147548.0059	1.021769	2023-08-29	закрыт
470	74	978	2023-02-28	1329411.0316	1.043657	2024-01-30	активен
471	11	156	2023-01-21	2470946.7465	1.096721	2023-11-05	закрыт
472	52	840	2023-08-04	4824802.0420	1.099152	2024-07-19	активен
473	20	978	2023-04-07	3140170.0163	0.926483	2024-01-07	активен
474	66	978	2023-03-03	3038361.6955	0.961828	2023-06-16	закрыт
475	48	156	2023-01-21	4139019.4077	1.033533	2023-08-18	закрыт
476	74	356	2023-06-24	6778142.6211	1.081332	2024-05-03	активен
477	52	356	2023-04-29	2328535.3649	0.988000	2023-09-25	закрыт
478	94	398	2023-10-10	8802531.1648	0.928762	2024-09-29	активен
479	95	643	2023-04-27	8731145.9504	10.803609	2024-03-09	активен
480	74	840	2023-05-17	6683464.8927	1.038129	2023-11-05	закрыт
481	3	156	2023-02-13	4973275.5656	1.041535	2023-03-28	закрыт
482	10	356	2023-12-15	8060146.1994	0.989632	2024-12-19	активен
483	86	978	2023-07-04	2268154.5660	0.983942	2024-02-21	активен
484	27	978	2023-07-19	2186322.7289	0.966723	2024-05-16	активен
485	30	398	2023-02-08	5126310.8842	1.096503	2023-12-07	закрыт
486	15	840	2023-02-03	6460895.3076	0.946974	2023-11-29	закрыт
487	85	840	2023-04-16	4788373.1177	0.929607	2023-10-10	закрыт
488	86	156	2023-01-05	3465274.2500	0.925849	2024-01-14	активен
489	44	156	2023-10-17	3607776.3134	1.077904	2024-02-27	активен
490	82	840	2023-08-23	5143625.7288	0.925839	2024-06-05	активен
491	63	356	2023-03-31	8694806.1640	1.092809	2024-02-07	активен
492	38	840	2023-10-22	3110582.4471	0.960389	2024-04-29	активен
493	29	978	2023-04-13	5821289.8998	0.910200	2024-01-16	активен
494	77	156	2023-05-28	1829562.9605	1.044142	2024-05-07	активен
495	53	156	2023-05-30	6498993.9552	1.017117	2024-01-27	активен
496	47	643	2023-01-20	6297771.1382	9.375273	2023-04-26	закрыт
497	57	356	2023-11-12	3570138.4087	1.012542	2024-05-08	активен
498	16	840	2023-03-12	9558443.1423	0.973780	2024-01-20	активен
499	70	398	2023-03-20	1640822.5022	1.076487	2023-06-22	закрыт
500	7	978	2023-05-13	6612586.5860	0.980899	2024-02-23	активен
\.


--
-- Data for Name: loans; Type: TABLE DATA; Schema: bank; Owner: postgres
--

COPY bank.loans (loan_id, client_id, amount, interest_rate, issue_date, maturity_date, status, terms) FROM stdin;
1	87	3538630.4385	15.686464	2023-08-02	2024-04-28	просрочен	\N
2	25	3381231.7212	12.209392	2023-04-27	2023-10-03	активен	\N
3	9	1215607.6032	5.456227	2023-11-09	2024-02-19	активен	\N
4	29	163352.4946	26.909482	2023-10-12	2024-08-04	закрыт	Целевой кредит на приобретение автомобиля
5	3	2924987.7893	19.356951	2023-12-07	2024-05-31	просрочен	\N
6	27	3711866.3745	25.677374	2023-07-18	2023-09-17	закрыт	\N
7	34	2969966.1996	21.441455	2023-04-15	2023-11-02	активен	\N
8	54	1251805.3803	21.361145	2023-02-17	2024-02-14	закрыт	\N
9	12	1141804.6018	10.558803	2023-03-09	2024-01-23	просрочен	\N
10	56	2499743.6762	14.855714	2023-10-01	2024-04-29	просрочен	\N
11	42	2369042.4424	13.161551	2023-07-11	2024-05-13	активен	Кредит на развитие бизнеса
12	75	1643021.1157	23.232594	2023-06-07	2023-12-26	просрочен	\N
13	65	4662514.4239	19.494972	2023-06-24	2023-12-07	закрыт	Ипотечный кредит на покупку жилья
14	41	2212109.6812	22.272687	2023-08-20	2023-10-15	закрыт	\N
15	88	2100271.5472	32.807147	2023-12-16	2024-12-09	активен	Потребительский кредит на образование
16	10	4491159.0999	6.901556	2023-01-01	2023-10-25	активен	\N
17	42	236432.1102	5.926183	2023-01-31	2023-08-25	просрочен	\N
18	23	1650984.8850	14.348161	2023-07-19	2024-01-08	закрыт	\N
19	85	1763539.8192	12.024416	2023-11-12	2024-05-09	закрыт	\N
20	73	3110198.2925	24.823851	2023-01-17	2023-09-26	закрыт	Потребительский кредит на образование
21	26	656694.1740	17.858621	2023-06-11	2024-07-08	активен	Потребительский кредит на образование
22	22	3284361.3648	7.340438	2023-11-19	2024-08-23	просрочен	Целевой кредит на приобретение автомобиля
23	77	3781120.3800	15.666354	2023-02-15	2023-06-17	просрочен	Целевой кредит на приобретение автомобиля
24	84	278146.7858	14.380439	2023-09-07	2023-11-11	просрочен	\N
25	25	612620.5153	27.259176	2023-12-10	2024-04-17	закрыт	\N
26	16	1835847.4050	16.950741	2023-05-13	2024-05-30	активен	\N
27	32	1962710.3163	31.391128	2023-12-19	2024-04-23	закрыт	Кредит на развитие бизнеса
28	78	1513939.7434	7.726097	2023-09-01	2024-02-07	активен	\N
29	89	4134965.3481	29.303078	2023-08-04	2024-04-25	просрочен	\N
30	28	3552254.1493	17.066238	2023-02-25	2024-01-03	просрочен	\N
31	36	1407631.2102	15.391019	2023-02-17	2023-08-01	просрочен	Кредит на ремонт
32	51	3698984.1424	12.954347	2023-04-13	2023-08-20	активен	\N
33	64	1776125.1415	9.429430	2023-01-04	2023-12-29	просрочен	\N
34	80	1410665.2607	21.625302	2023-10-04	2024-10-15	просрочен	\N
35	100	664700.1444	26.022420	2023-02-13	2023-07-10	закрыт	\N
36	23	3641085.2061	28.378436	2023-08-06	2023-09-05	закрыт	\N
37	34	4639452.3061	28.350531	2023-06-25	2024-06-02	активен	\N
38	15	1897709.4160	28.826133	2023-03-23	2023-07-25	просрочен	\N
39	64	3408548.2060	15.220785	2023-03-03	2023-12-16	активен	\N
40	28	3599993.1533	15.516226	2023-04-12	2023-08-11	закрыт	Кредит на ремонт
41	91	4098647.3337	14.703119	2023-04-02	2024-01-07	активен	\N
42	21	156098.0871	19.198579	2023-10-19	2024-11-03	просрочен	\N
43	56	2743574.5607	12.619204	2023-09-29	2024-10-25	просрочен	\N
44	2	1106909.5606	5.491136	2023-01-11	2023-05-30	активен	\N
45	99	4703343.1996	18.480564	2023-01-17	2023-11-08	просрочен	Потребительский кредит на образование
46	76	402551.7569	32.795529	2023-06-16	2024-03-09	закрыт	\N
47	64	2311974.0966	18.170669	2023-12-07	2024-08-17	активен	\N
48	100	2909457.9053	8.830078	2023-07-28	2024-05-23	активен	\N
49	44	89780.4690	24.340926	2023-01-07	2023-02-16	просрочен	\N
50	31	2674352.9666	17.699161	2023-06-11	2024-02-21	закрыт	Кредит на ремонт
51	16	1073168.5708	14.090608	2023-07-05	2024-02-02	просрочен	Целевой кредит на приобретение автомобиля
52	83	185375.1307	8.430370	2023-08-25	2024-08-02	закрыт	\N
53	62	307840.2250	5.269715	2023-11-22	2024-09-07	активен	\N
54	60	3397722.8814	20.724031	2023-06-20	2023-10-02	закрыт	\N
55	51	2453940.8236	16.148295	2023-01-08	2023-06-16	активен	\N
56	19	497278.1087	11.258422	2023-06-27	2023-08-05	просрочен	\N
57	34	4325758.6799	18.984708	2023-07-22	2024-03-08	закрыт	\N
58	75	2459785.9395	13.180936	2023-02-13	2023-07-26	активен	\N
59	58	1313927.3030	16.298474	2023-09-24	2024-08-09	просрочен	\N
60	16	1808656.1329	12.139857	2023-04-05	2023-11-19	активен	\N
61	90	4332856.8518	5.604493	2023-12-05	2024-02-13	закрыт	Потребительский кредит на образование
62	35	1649330.5251	8.997646	2023-10-18	2024-07-14	просрочен	\N
63	45	4083845.4058	27.348731	2023-10-06	2024-06-26	просрочен	\N
64	94	168716.2554	6.095793	2023-05-26	2023-08-06	закрыт	\N
65	35	1345466.8562	28.699627	2023-01-04	2023-08-04	активен	\N
66	55	4998234.6845	28.050956	2023-08-15	2024-07-30	просрочен	\N
67	95	4077384.5244	12.762731	2023-09-18	2024-04-27	закрыт	\N
68	10	3308416.7056	30.317431	2023-06-03	2024-01-05	активен	\N
69	63	1663339.8142	27.809970	2023-03-15	2023-07-28	закрыт	Потребительский кредит на образование
70	20	1416935.2269	26.863753	2023-08-20	2023-11-02	активен	\N
71	1	3074689.4001	17.546661	2023-03-04	2023-08-11	закрыт	\N
72	38	2624392.6361	16.451978	2023-01-14	2023-11-16	закрыт	\N
73	58	4800699.6058	31.619814	2023-04-14	2024-01-30	просрочен	\N
74	16	3787408.2804	11.444790	2023-05-30	2024-03-31	просрочен	Кредит на развитие бизнеса
75	98	1434636.3173	17.379353	2023-05-19	2023-07-10	активен	\N
76	24	844973.2128	12.986538	2023-02-05	2024-03-01	закрыт	\N
77	26	4092251.1457	10.965036	2023-12-24	2025-01-22	закрыт	\N
78	72	1327164.4388	20.021644	2023-08-03	2024-03-11	закрыт	\N
79	4	3507482.2205	25.887228	2023-10-15	2024-02-11	активен	\N
80	22	3148414.1645	19.374015	2023-11-02	2024-03-03	закрыт	\N
81	24	2775814.6653	27.627766	2023-08-08	2024-06-21	активен	\N
82	95	2842294.7192	26.847126	2023-06-24	2023-08-17	активен	\N
83	13	4790455.7597	30.448653	2023-04-06	2023-05-10	закрыт	Кредит на развитие бизнеса
84	19	2351643.1276	12.599230	2023-07-05	2024-07-07	просрочен	\N
85	33	642479.8933	20.587292	2023-11-07	2024-07-14	закрыт	\N
86	58	1374736.7381	32.362775	2023-11-30	2024-02-08	закрыт	\N
87	1	202631.4936	12.372146	2023-04-24	2024-01-16	активен	\N
88	23	3774010.5830	6.723419	2023-02-13	2023-05-06	закрыт	\N
89	48	3309591.9060	5.471594	2023-02-21	2023-05-25	активен	\N
90	77	92212.3219	20.771643	2023-11-19	2024-06-16	активен	\N
91	74	2197691.9492	14.758201	2023-06-24	2024-07-23	просрочен	\N
92	44	802160.0727	20.224100	2023-08-29	2024-02-29	просрочен	\N
93	49	163122.8380	25.506412	2023-01-07	2024-01-16	закрыт	\N
94	66	1377232.4912	23.631539	2023-02-06	2023-05-19	просрочен	\N
95	68	344189.5977	8.083593	2023-10-02	2024-09-26	активен	\N
96	30	3682367.9463	18.303659	2023-08-30	2024-06-24	просрочен	\N
97	81	80262.1072	11.877019	2023-01-17	2023-10-28	просрочен	Потребительский кредит на образование
98	47	3803413.9411	12.882280	2023-11-07	2024-08-01	закрыт	\N
99	50	929912.3034	32.370663	2023-02-20	2023-10-13	активен	\N
100	62	3164977.8277	23.472762	2023-02-19	2023-05-24	просрочен	Кредит на ремонт
101	6	3757410.0064	23.916217	2023-12-01	2024-10-01	закрыт	\N
102	92	4721618.3645	26.450370	2023-04-15	2023-09-06	активен	\N
103	78	634115.7549	17.474963	2023-06-27	2023-12-08	просрочен	\N
104	57	1412028.2599	17.212048	2023-05-17	2023-09-23	просрочен	\N
105	53	3512846.0486	8.686632	2023-01-10	2023-03-10	закрыт	Ипотечный кредит на покупку жилья
106	38	653629.4992	22.146530	2023-08-28	2024-05-30	просрочен	\N
107	71	2580747.2932	28.349962	2023-12-07	2024-02-04	закрыт	\N
108	46	2839792.3932	18.825998	2023-01-07	2023-06-16	закрыт	\N
109	90	1084699.9792	32.062366	2023-11-01	2024-08-25	закрыт	\N
110	58	1044605.1122	5.066384	2023-09-09	2024-05-08	активен	Потребительский кредит на образование
111	12	1611621.3472	26.521913	2023-05-24	2023-12-18	просрочен	\N
112	66	4269439.1252	12.827048	2023-11-19	2024-03-01	активен	\N
113	21	2141516.3651	20.516091	2023-08-26	2024-02-07	активен	\N
114	79	2901839.2614	14.888967	2023-01-13	2023-11-23	закрыт	\N
115	79	3034578.5789	32.916786	2023-05-10	2024-03-18	просрочен	\N
116	20	4224496.1773	22.917316	2023-04-25	2023-06-25	просрочен	\N
117	3	2100054.8877	28.570915	2023-04-25	2023-10-03	закрыт	Целевой кредит на приобретение автомобиля
118	93	756954.9226	10.477048	2023-06-15	2024-05-10	активен	Потребительский кредит на образование
119	45	3687494.6651	12.095080	2023-10-30	2024-07-24	закрыт	\N
120	92	4361026.3841	27.904032	2023-10-20	2024-04-13	закрыт	\N
121	11	2650576.0939	16.121140	2023-05-16	2023-12-23	активен	\N
122	98	61954.4748	14.924387	2023-11-18	2024-02-04	закрыт	\N
123	6	180914.9240	30.166447	2023-11-09	2024-07-23	активен	\N
124	62	937283.7832	8.762625	2023-12-08	2024-12-16	закрыт	\N
125	61	2542691.2270	27.825386	2023-04-25	2023-07-10	просрочен	\N
126	9	3078332.8422	32.410419	2023-01-04	2023-10-26	закрыт	\N
127	32	3555889.0411	10.541611	2023-06-26	2024-03-22	просрочен	\N
128	46	4823796.0598	29.875572	2023-08-17	2024-02-13	закрыт	\N
129	3	3245940.3259	23.730385	2023-09-22	2024-08-20	просрочен	\N
130	7	3276934.3930	28.180901	2023-09-10	2024-09-06	просрочен	\N
131	18	1502634.3866	17.871198	2023-10-17	2024-09-15	закрыт	\N
132	81	4734520.8666	26.065020	2023-04-19	2023-07-07	закрыт	\N
133	78	2222589.9302	24.855471	2023-07-03	2024-04-18	просрочен	\N
134	36	4699664.9377	29.192815	2023-09-14	2024-04-07	просрочен	Целевой кредит на приобретение автомобиля
135	58	3242529.3246	24.699104	2023-01-02	2023-07-13	активен	\N
136	65	4121014.4389	32.417451	2023-05-16	2023-10-07	просрочен	Кредит на развитие бизнеса
137	36	3392595.1840	7.365439	2023-03-02	2023-08-10	закрыт	\N
138	56	2886640.6505	32.965292	2023-05-11	2023-12-17	закрыт	\N
139	10	3858451.6553	30.150556	2023-03-16	2023-08-13	просрочен	\N
140	67	496697.7177	24.836464	2023-01-06	2023-07-04	просрочен	Кредит на развитие бизнеса
141	92	693665.6663	11.786612	2023-01-25	2023-06-09	просрочен	\N
142	89	1146878.8764	29.335618	2023-04-10	2023-05-10	активен	\N
143	85	3874238.9357	14.839513	2023-10-13	2024-07-15	активен	Кредит на ремонт
144	76	2452124.1847	20.031191	2023-12-02	2024-11-05	просрочен	\N
145	78	3807288.6488	6.190270	2023-03-29	2023-08-24	закрыт	\N
146	30	4183880.2061	10.324975	2023-03-02	2023-07-14	просрочен	\N
147	73	3018801.1661	22.371679	2023-04-02	2023-10-14	активен	\N
148	67	1216039.0626	12.880272	2023-09-01	2023-11-08	закрыт	\N
149	17	2686738.2971	30.052997	2023-01-19	2023-08-04	закрыт	\N
150	14	3555674.1900	10.444169	2023-12-06	2024-09-05	активен	\N
151	85	3201785.9146	28.295238	2023-01-26	2024-01-21	просрочен	\N
152	29	1531388.0729	18.374701	2023-10-22	2024-06-14	просрочен	\N
153	51	1388778.8362	6.677165	2023-09-11	2024-04-27	просрочен	\N
154	97	1892348.3607	8.583705	2023-07-18	2024-01-15	активен	\N
155	75	4229392.6943	32.070505	2023-01-08	2023-11-11	просрочен	\N
156	71	2863780.6512	27.684018	2023-06-23	2023-10-21	просрочен	\N
157	59	4541909.3084	19.820505	2023-12-12	2024-09-16	просрочен	\N
158	82	4121768.6262	26.979448	2023-08-25	2024-09-15	просрочен	Потребительский кредит на образование
159	15	2225738.1444	22.125302	2023-06-17	2023-10-07	закрыт	\N
160	71	247484.5416	28.918295	2023-11-19	2024-09-06	просрочен	\N
161	8	1391169.5226	11.866584	2023-05-23	2024-04-03	просрочен	\N
162	34	1566642.5911	18.197552	2023-02-18	2023-05-15	закрыт	\N
163	98	1987062.9712	9.911435	2023-03-05	2023-08-31	закрыт	Целевой кредит на приобретение автомобиля
164	6	1092913.7934	16.446151	2023-04-11	2023-07-13	активен	\N
165	84	1514875.9265	29.366364	2023-09-11	2024-08-24	просрочен	\N
166	77	3910384.3286	14.771908	2023-12-04	2024-04-30	просрочен	\N
167	46	2150621.5533	8.182640	2023-10-23	2024-05-10	просрочен	Кредит на ремонт
168	65	3794659.0613	30.149830	2023-07-10	2023-10-06	просрочен	\N
169	35	831817.8488	17.594989	2023-03-06	2023-09-18	закрыт	\N
170	88	181693.8209	27.880150	2023-07-11	2023-12-13	активен	\N
171	81	1803735.1905	18.763439	2023-04-21	2023-07-10	активен	Ипотечный кредит на покупку жилья
172	89	3794126.1774	10.058570	2023-08-30	2023-10-08	просрочен	\N
173	64	3885081.2627	12.978120	2023-12-23	2024-03-13	активен	\N
174	70	3535071.0125	6.881808	2023-12-18	2024-07-28	закрыт	\N
175	83	438774.5862	13.897461	2023-05-17	2024-06-09	закрыт	\N
176	25	608766.7878	24.924180	2023-03-21	2024-02-05	закрыт	Целевой кредит на приобретение автомобиля
177	2	2610153.9012	10.886499	2023-10-01	2023-11-25	активен	\N
178	21	654269.7180	21.066719	2023-02-20	2023-05-12	просрочен	\N
179	55	4544290.0518	5.554645	2023-04-03	2023-12-24	просрочен	\N
180	94	904424.7089	14.156065	2023-07-22	2024-04-06	закрыт	\N
181	37	3916611.8663	18.321084	2023-05-07	2024-02-25	просрочен	Кредит на ремонт
182	68	1260506.1163	22.313681	2023-08-31	2023-12-27	закрыт	\N
183	77	1056611.4882	13.958411	2023-06-15	2024-05-22	активен	\N
184	22	1092731.1597	31.928986	2023-09-23	2024-08-16	закрыт	\N
185	12	1888021.2636	6.749631	2023-07-04	2023-08-07	просрочен	Ипотечный кредит на покупку жилья
186	32	1515327.7227	15.386595	2023-04-05	2024-02-11	просрочен	\N
187	37	4076348.8468	17.335879	2023-04-03	2023-08-25	просрочен	\N
188	86	3231971.4407	27.295058	2023-08-21	2023-11-13	просрочен	Кредит на ремонт
189	50	1035010.1334	12.394625	2023-06-02	2023-11-05	просрочен	\N
190	32	4824297.2399	18.348399	2023-01-16	2023-03-23	закрыт	\N
191	46	645032.8079	6.592589	2023-03-15	2023-08-31	закрыт	Кредит на развитие бизнеса
192	65	4739662.9574	31.548961	2023-10-07	2024-09-01	просрочен	\N
193	8	1694784.3121	12.166228	2023-04-02	2023-06-21	активен	\N
194	21	3759478.2535	29.843583	2023-12-09	2024-05-06	просрочен	\N
195	13	632002.4040	31.894415	2023-11-07	2024-03-13	закрыт	\N
196	69	742834.9647	9.519978	2023-05-28	2024-01-22	закрыт	\N
197	17	465006.3029	29.200487	2023-07-11	2023-09-16	просрочен	Целевой кредит на приобретение автомобиля
198	4	3839424.0524	22.699183	2023-11-22	2024-11-20	закрыт	\N
199	96	2797438.6610	29.451081	2023-08-24	2024-08-26	просрочен	\N
200	96	799079.0582	27.156547	2023-04-20	2023-10-28	просрочен	\N
201	18	940274.3744	22.513514	2023-07-23	2024-07-17	активен	Целевой кредит на приобретение автомобиля
202	25	2578106.0502	7.317878	2023-12-17	2024-09-18	активен	Потребительский кредит на образование
203	42	3535528.0183	17.931206	2023-07-20	2023-11-03	закрыт	\N
204	62	3964734.0701	16.276125	2023-06-19	2023-09-18	просрочен	\N
205	77	1888135.0823	23.105150	2023-12-11	2024-05-16	просрочен	\N
206	3	2096718.5166	24.881771	2023-07-30	2024-08-19	активен	\N
207	51	2565872.6770	19.213255	2023-02-03	2023-05-26	просрочен	\N
208	21	1551604.3240	20.607622	2023-02-17	2023-12-14	просрочен	\N
209	38	487774.9356	13.748056	2023-06-01	2023-09-06	активен	\N
210	88	831161.0454	23.362792	2023-11-17	2024-04-07	активен	\N
211	81	1692709.6594	19.434554	2023-12-17	2024-02-04	активен	\N
212	70	4434452.6808	19.144498	2023-11-12	2024-09-24	просрочен	\N
213	49	4140642.3538	10.491598	2023-08-12	2024-01-15	просрочен	\N
214	93	4897722.4573	9.343540	2023-09-29	2024-02-05	просрочен	\N
215	45	2589885.9107	19.921390	2023-07-02	2024-06-28	закрыт	\N
216	52	2188113.0756	7.567616	2023-01-04	2023-04-01	активен	\N
217	16	3478682.0760	24.358702	2023-06-07	2024-06-27	активен	Кредит на ремонт
218	36	4133129.1530	28.478022	2023-08-02	2024-02-03	закрыт	\N
219	89	4500721.8500	17.240907	2023-06-18	2024-04-01	закрыт	\N
220	61	1555704.8848	7.426151	2023-05-01	2023-06-14	закрыт	\N
221	89	1483213.2398	10.640234	2023-02-02	2023-12-09	активен	\N
222	67	1720735.3441	14.821491	2023-06-10	2024-03-26	закрыт	\N
223	63	4193011.0867	10.269916	2023-06-12	2023-12-04	просрочен	\N
224	52	871797.0969	12.520472	2023-01-03	2023-09-07	активен	\N
225	45	1410988.9936	15.104781	2023-02-09	2023-07-31	закрыт	\N
226	67	1302706.9163	18.297420	2023-06-19	2023-09-21	просрочен	\N
227	71	1432036.2160	23.936145	2023-04-27	2023-11-18	просрочен	\N
228	25	2024150.8481	12.950995	2023-05-03	2023-09-03	закрыт	Целевой кредит на приобретение автомобиля
229	95	710131.7445	8.041801	2023-01-02	2023-11-11	активен	\N
230	48	3376902.2287	17.001878	2023-07-12	2024-03-16	закрыт	\N
231	27	226711.9211	13.640419	2023-06-17	2023-08-29	активен	\N
232	58	1488102.0593	13.991265	2023-11-29	2024-11-06	закрыт	\N
233	9	4969655.0149	12.324384	2023-06-29	2024-06-13	закрыт	\N
234	12	515641.1245	11.982845	2023-11-23	2024-12-02	просрочен	\N
235	15	447429.9085	5.485750	2023-11-03	2024-05-11	просрочен	Кредит на ремонт
236	64	886714.2586	18.789096	2023-04-01	2024-04-07	закрыт	\N
237	63	1882866.8105	7.298064	2023-07-22	2024-02-24	активен	\N
238	43	4923634.1181	30.449330	2023-02-05	2023-04-13	просрочен	Кредит на ремонт
239	89	1273137.8473	12.975400	2023-10-26	2024-08-30	закрыт	\N
240	15	2448999.9872	21.071766	2023-09-23	2024-06-01	закрыт	\N
241	33	4055475.6770	18.029506	2023-01-27	2023-11-19	активен	Целевой кредит на приобретение автомобиля
242	17	276202.0858	9.305796	2023-03-31	2024-02-19	просрочен	\N
243	61	3105101.8096	25.506663	2023-12-21	2024-12-23	просрочен	\N
244	18	3594053.1145	21.729437	2023-02-25	2024-02-18	активен	\N
245	71	4817025.2405	30.521859	2023-08-30	2024-04-09	закрыт	\N
246	10	4732269.2146	17.756183	2023-08-02	2023-11-19	просрочен	\N
247	85	601139.7819	13.167462	2023-09-03	2023-10-23	активен	Кредит на развитие бизнеса
248	55	2496068.4207	25.567867	2023-05-12	2024-06-04	закрыт	\N
249	13	2747390.2131	30.914121	2023-08-22	2023-11-05	активен	\N
250	19	2087493.9417	23.237127	2023-09-06	2024-08-25	активен	Кредит на ремонт
251	52	1417744.7481	7.003888	2023-09-17	2024-01-17	активен	Кредит на ремонт
252	11	4293683.2622	18.552616	2023-05-31	2024-04-14	просрочен	Целевой кредит на приобретение автомобиля
253	96	2899932.8000	9.212835	2023-12-12	2024-08-11	закрыт	\N
254	65	3207037.7908	22.361458	2023-09-16	2024-03-16	активен	\N
255	56	1041839.3436	23.744904	2023-07-05	2023-08-28	активен	Кредит на ремонт
256	2	2837252.2378	20.878700	2023-10-26	2024-05-01	активен	\N
257	57	4797530.9981	18.215920	2023-01-08	2023-06-09	закрыт	\N
258	42	1359894.2967	15.586156	2023-04-12	2023-09-02	закрыт	\N
259	48	4983961.4961	11.939440	2023-01-20	2023-12-14	просрочен	\N
260	66	4151058.2279	16.519064	2023-01-30	2023-09-04	просрочен	Потребительский кредит на образование
261	17	892243.3980	7.190260	2023-10-04	2024-10-16	просрочен	\N
262	73	3856112.7896	32.558509	2023-05-29	2024-06-08	просрочен	\N
263	45	2060723.1446	30.737030	2023-04-04	2023-12-18	закрыт	\N
264	55	3595969.4023	29.010473	2023-07-01	2023-08-30	закрыт	\N
265	77	2219917.9175	20.385889	2023-02-09	2023-08-02	активен	\N
266	34	794447.2069	8.074043	2023-07-13	2023-11-15	закрыт	\N
267	10	1106893.1326	13.855425	2023-01-26	2023-12-11	активен	\N
268	32	1156268.8649	11.313282	2023-01-03	2023-04-16	просрочен	Ипотечный кредит на покупку жилья
269	44	676106.9961	27.626897	2023-04-14	2024-02-26	просрочен	\N
270	26	4317091.3165	8.425553	2023-10-02	2024-04-14	просрочен	\N
271	21	1457278.3786	32.630020	2023-05-05	2023-09-27	активен	\N
272	38	1658963.4250	27.169274	2023-11-23	2024-05-20	просрочен	Кредит на ремонт
273	50	1703335.0073	23.688038	2023-08-19	2023-09-29	просрочен	Ипотечный кредит на покупку жилья
274	59	2808135.6377	21.606063	2023-01-24	2023-12-09	активен	\N
275	100	2267737.0120	12.175710	2023-03-19	2024-01-18	закрыт	\N
276	15	2543623.2979	13.523839	2023-09-26	2023-11-16	просрочен	\N
277	45	719271.4668	30.750621	2023-09-20	2023-12-29	просрочен	\N
278	55	224163.5250	12.631037	2023-09-14	2024-09-13	активен	\N
279	10	2401388.8875	18.816581	2023-03-31	2023-11-17	закрыт	\N
280	54	1073545.3012	22.302139	2023-02-15	2023-04-24	активен	\N
281	73	162159.5242	31.864649	2023-10-24	2023-12-15	активен	\N
282	19	3703838.0516	28.395056	2023-07-23	2024-02-18	активен	\N
283	15	4297013.2615	6.516181	2023-01-26	2023-12-17	закрыт	Целевой кредит на приобретение автомобиля
284	25	1718070.5161	30.633341	2023-04-13	2023-11-11	активен	\N
285	49	3973112.8782	27.132878	2023-07-16	2024-06-30	активен	\N
286	96	1866484.6472	5.919185	2023-07-10	2023-11-03	закрыт	\N
287	68	3422130.0328	25.043712	2023-08-28	2024-08-03	активен	Кредит на развитие бизнеса
288	45	3317538.4316	14.035402	2023-09-14	2023-12-22	просрочен	Потребительский кредит на образование
289	69	4146646.7633	8.872808	2023-06-11	2023-08-02	активен	\N
290	39	1543648.0766	32.197571	2023-06-21	2024-02-18	просрочен	\N
291	46	4524355.9211	30.570058	2023-02-08	2023-08-04	закрыт	\N
292	83	300333.4856	27.510671	2023-07-02	2024-04-25	просрочен	\N
293	54	3208462.5125	5.790851	2023-08-10	2024-03-05	закрыт	\N
294	78	2152511.6542	17.791815	2023-10-02	2024-08-23	активен	\N
295	54	3132419.9486	25.243507	2023-03-05	2024-01-29	активен	Ипотечный кредит на покупку жилья
296	6	3604317.0843	12.562650	2023-08-29	2024-06-21	активен	\N
297	45	3609446.6493	16.717666	2023-05-23	2023-12-11	закрыт	Целевой кредит на приобретение автомобиля
298	61	3854826.1760	12.937375	2023-09-12	2023-10-30	активен	\N
299	19	4379424.6447	18.651913	2023-01-24	2023-03-12	просрочен	\N
300	14	2924808.3412	6.518001	2023-02-04	2023-07-16	просрочен	\N
301	24	257377.3755	11.675360	2023-02-08	2023-06-19	закрыт	\N
302	82	961220.4352	9.746351	2023-10-04	2024-08-21	активен	\N
303	85	548765.8958	21.900155	2023-07-11	2024-06-14	активен	\N
304	1	3718417.7956	12.867487	2023-03-20	2023-07-05	просрочен	\N
305	34	1020198.9587	29.649090	2023-04-20	2023-08-23	закрыт	\N
306	94	1815572.0756	8.003350	2023-04-06	2023-08-18	закрыт	\N
307	38	3845704.2154	22.997939	2023-09-11	2024-01-21	просрочен	\N
308	67	1650074.8653	6.716258	2023-10-05	2023-11-15	просрочен	Потребительский кредит на образование
309	44	1764881.4996	18.855879	2023-04-12	2023-07-03	просрочен	\N
310	61	4233894.3026	6.415411	2023-01-15	2023-04-04	просрочен	\N
311	21	1984604.0629	27.703723	2023-09-23	2024-06-21	просрочен	\N
312	42	3275106.6634	9.507586	2023-01-09	2023-04-29	активен	\N
313	12	1688959.0131	27.938867	2023-09-18	2024-06-23	просрочен	\N
314	51	412456.5272	12.046982	2023-02-16	2024-01-29	закрыт	\N
315	69	2868818.1054	19.958024	2023-08-04	2024-02-12	закрыт	\N
316	3	723503.8760	18.129687	2023-04-16	2024-04-15	закрыт	\N
317	56	3924620.6655	25.876946	2023-11-15	2024-03-28	просрочен	\N
318	33	3379102.1827	24.078143	2023-09-07	2024-04-30	просрочен	\N
319	92	2562503.4998	8.120416	2023-07-30	2024-01-22	закрыт	Ипотечный кредит на покупку жилья
320	23	157404.8584	32.127528	2023-09-28	2024-03-04	просрочен	\N
321	18	1717384.6821	28.363326	2023-10-05	2024-02-03	просрочен	\N
322	96	3292926.6640	20.987166	2023-03-29	2023-07-17	закрыт	Кредит на развитие бизнеса
323	87	3560103.9483	12.791735	2023-11-16	2024-06-17	просрочен	\N
324	52	1135222.3891	27.262156	2023-11-01	2024-09-15	закрыт	\N
325	6	2837328.1247	8.790404	2023-12-19	2024-04-28	закрыт	\N
326	90	1115743.4737	10.840753	2023-04-23	2023-10-22	закрыт	\N
327	75	567097.6815	11.623941	2023-09-29	2024-08-30	закрыт	\N
328	71	3305355.4927	25.000460	2023-10-30	2024-01-13	просрочен	Ипотечный кредит на покупку жилья
329	85	2615460.7536	11.714131	2023-02-14	2023-08-15	активен	\N
330	27	497693.3887	18.165655	2023-11-21	2024-12-05	активен	\N
331	95	4452935.5001	18.972402	2023-12-04	2024-02-01	активен	\N
332	2	3385996.6968	17.159783	2023-03-02	2023-10-27	закрыт	\N
333	62	4863452.8167	8.092775	2023-05-13	2024-04-12	закрыт	\N
334	42	66966.9978	32.652552	2023-10-01	2024-02-15	просрочен	\N
335	48	2846464.5276	27.638786	2023-02-18	2023-10-11	закрыт	\N
336	53	1741086.6339	18.071352	2023-02-28	2024-02-11	активен	\N
337	43	2835825.9227	8.644571	2023-05-10	2024-05-28	закрыт	\N
338	71	4576562.0976	13.607222	2023-01-07	2023-10-08	активен	\N
339	19	3616267.8044	21.983935	2023-08-29	2024-04-13	просрочен	\N
340	57	897019.0518	30.119711	2023-03-29	2023-06-09	закрыт	\N
341	13	614607.4086	25.021405	2023-10-03	2023-11-27	активен	\N
342	61	4936462.9469	30.457257	2023-04-19	2023-12-22	закрыт	Кредит на ремонт
343	76	1124056.6010	10.068943	2023-01-02	2023-06-13	активен	\N
344	46	609473.5959	25.318509	2023-11-13	2024-07-21	активен	\N
345	96	4280495.7541	13.238737	2023-03-27	2024-03-14	закрыт	\N
346	26	2152291.4061	27.908807	2023-08-18	2024-09-12	закрыт	\N
347	43	1765484.3567	10.357200	2023-01-10	2023-11-19	просрочен	\N
348	57	538750.2699	20.672101	2023-08-06	2024-08-28	просрочен	\N
349	47	2391146.3866	15.570711	2023-09-01	2024-03-04	просрочен	Ипотечный кредит на покупку жилья
350	90	1406586.1445	30.353576	2023-08-06	2023-11-06	просрочен	\N
351	47	995284.8065	12.261301	2023-09-28	2024-03-01	активен	Кредит на ремонт
352	22	2534688.0371	11.311319	2023-04-05	2024-04-07	просрочен	\N
353	38	4511948.7286	32.693461	2023-05-12	2024-01-24	просрочен	\N
354	80	4950614.6710	15.898262	2023-01-15	2023-04-11	активен	\N
355	46	2055115.3654	11.888392	2023-05-20	2023-12-22	просрочен	\N
356	34	3745758.1826	31.628043	2023-06-13	2023-10-24	активен	\N
357	30	3577301.4877	20.540478	2023-04-19	2024-04-04	закрыт	\N
358	28	427888.5792	23.133054	2023-11-30	2024-07-27	просрочен	Кредит на развитие бизнеса
359	47	3709318.9675	28.439305	2023-02-05	2023-09-02	активен	\N
360	96	4232725.1817	7.899161	2023-10-14	2023-12-25	закрыт	Потребительский кредит на образование
361	10	3796098.0585	31.717970	2023-10-06	2024-05-30	активен	Потребительский кредит на образование
362	2	2761176.1208	28.692197	2023-07-03	2024-02-16	просрочен	\N
363	54	4938306.9225	12.893577	2023-08-29	2024-01-25	закрыт	\N
364	10	1615420.5680	20.279625	2023-09-16	2024-03-24	активен	\N
365	58	848871.7826	18.767385	2023-10-01	2024-01-05	просрочен	\N
366	75	1250335.8519	21.423690	2023-04-10	2023-06-03	закрыт	\N
367	60	2206994.8529	23.646487	2023-10-17	2024-06-09	активен	Потребительский кредит на образование
368	72	1240150.1506	6.263187	2023-11-03	2024-01-18	активен	\N
369	43	2570170.9150	30.309099	2023-09-09	2024-01-07	просрочен	\N
370	49	3073092.1306	28.263556	2023-06-15	2023-12-08	активен	\N
371	57	2315755.3473	7.836526	2023-07-20	2024-02-02	просрочен	\N
372	30	2129064.2721	5.951785	2023-02-10	2024-01-21	активен	\N
373	39	2053895.0519	14.952474	2023-09-24	2024-07-21	просрочен	\N
374	10	2733257.8342	21.941734	2023-09-27	2024-05-27	закрыт	\N
375	42	3834775.1070	17.981777	2023-07-18	2024-08-10	активен	\N
376	37	4679266.9827	6.059268	2023-03-20	2023-08-08	просрочен	\N
377	31	2403400.5313	28.871580	2023-11-27	2024-09-26	просрочен	\N
378	74	2916298.4248	25.952723	2023-10-03	2024-03-26	закрыт	\N
379	90	4045194.6967	17.139961	2023-12-19	2024-08-16	активен	\N
380	4	3328999.9056	22.666790	2023-03-20	2023-11-28	активен	\N
381	54	1353552.6718	32.606674	2023-12-14	2024-08-25	активен	\N
382	62	1426151.3771	30.824684	2023-05-17	2024-04-15	активен	\N
383	85	2623250.2171	26.078672	2023-08-02	2024-08-31	просрочен	\N
384	72	3779086.4676	22.634936	2023-10-24	2024-07-12	активен	\N
385	73	3783753.6306	8.236952	2023-08-20	2023-11-26	закрыт	\N
386	14	3068391.1763	17.048238	2023-11-18	2024-08-24	закрыт	\N
387	57	4722074.8626	9.055690	2023-10-14	2024-06-12	закрыт	\N
388	64	436353.3249	14.329002	2023-08-12	2024-09-10	активен	\N
389	34	4115390.3666	23.715940	2023-06-03	2023-07-10	активен	Потребительский кредит на образование
390	70	3489700.1034	8.120164	2023-03-10	2023-04-10	просрочен	\N
391	92	2729235.4127	8.009231	2023-07-31	2024-08-09	закрыт	Целевой кредит на приобретение автомобиля
392	51	1792639.1092	8.320663	2023-03-14	2023-07-28	просрочен	\N
393	69	4111500.7423	25.663702	2023-02-02	2023-10-08	просрочен	Кредит на ремонт
394	29	4792975.5871	6.093682	2023-08-30	2023-10-03	просрочен	\N
395	17	1252489.8178	15.700821	2023-04-22	2024-04-29	закрыт	\N
396	60	4162712.6362	32.780756	2023-03-18	2024-03-25	закрыт	\N
397	34	1281031.1738	22.036611	2023-11-14	2024-01-05	активен	\N
398	46	2691693.1156	13.023549	2023-05-15	2024-05-07	закрыт	\N
399	11	986054.1825	21.698910	2023-01-08	2023-08-27	закрыт	Целевой кредит на приобретение автомобиля
400	54	546216.3558	5.737634	2023-01-15	2023-09-30	активен	\N
401	7	1442535.0736	16.476118	2023-02-11	2023-09-21	просрочен	\N
402	76	3346072.5496	25.868592	2023-02-05	2023-09-24	активен	\N
403	47	722426.3432	15.320569	2023-02-25	2024-01-09	активен	\N
404	65	3352198.4578	5.856152	2023-03-17	2023-08-27	закрыт	\N
405	25	2094958.1903	6.818767	2023-06-09	2024-06-19	просрочен	\N
406	87	491931.3837	8.593969	2023-02-05	2023-05-10	закрыт	\N
407	44	2963885.6022	19.336360	2023-09-29	2024-03-04	закрыт	Кредит на развитие бизнеса
408	74	3860168.8059	21.040685	2023-07-09	2024-03-09	активен	Потребительский кредит на образование
409	75	3945878.6714	25.532759	2023-03-30	2024-04-06	закрыт	\N
410	72	1707933.7776	28.310730	2023-09-18	2024-08-17	закрыт	Ипотечный кредит на покупку жилья
411	70	2292064.0999	11.077094	2023-02-17	2023-06-28	просрочен	\N
412	70	4251346.9983	6.082457	2023-01-23	2023-04-30	просрочен	Потребительский кредит на образование
413	13	4325170.2906	32.084536	2023-01-19	2023-08-01	закрыт	\N
414	86	1333644.7311	20.381249	2023-08-13	2024-02-07	активен	\N
415	21	3302714.2218	6.536972	2023-06-06	2024-01-15	закрыт	\N
416	80	2928972.9021	23.330749	2023-08-08	2024-08-06	закрыт	Целевой кредит на приобретение автомобиля
417	97	3385987.8365	25.180022	2023-09-27	2024-06-18	просрочен	Потребительский кредит на образование
418	41	4674366.5154	9.496995	2023-06-10	2024-04-03	активен	\N
419	66	4748412.9384	24.340557	2023-01-19	2023-06-17	просрочен	\N
420	47	3052949.0269	10.049597	2023-01-03	2023-07-14	просрочен	\N
421	96	904378.9845	6.624671	2023-08-08	2024-05-19	просрочен	\N
422	95	2623048.2019	27.152938	2023-01-24	2023-07-14	закрыт	\N
423	54	704887.0238	17.036185	2023-02-14	2024-02-08	просрочен	\N
424	64	1964934.2562	29.135429	2023-03-26	2024-03-31	просрочен	\N
425	50	1609708.9094	14.524100	2023-08-23	2023-12-10	закрыт	\N
426	46	269725.4185	28.017605	2023-03-28	2024-04-25	просрочен	\N
427	10	4387923.6241	19.677415	2023-05-08	2023-06-21	закрыт	Потребительский кредит на образование
428	85	1165415.7535	23.068270	2023-05-24	2023-12-01	закрыт	\N
429	29	129400.0521	24.696900	2023-07-19	2023-09-21	закрыт	Целевой кредит на приобретение автомобиля
430	33	2015210.3931	8.234492	2023-10-21	2024-03-25	просрочен	Кредит на развитие бизнеса
431	36	3792895.5118	28.742430	2023-05-16	2023-11-19	активен	\N
432	74	2874617.0624	29.228933	2023-10-10	2023-12-24	просрочен	\N
433	46	605841.2745	13.032257	2023-09-27	2024-10-07	закрыт	\N
434	28	284290.3808	25.924698	2023-11-22	2024-06-21	просрочен	\N
435	8	1347747.5362	32.313122	2023-11-21	2024-04-26	закрыт	\N
436	32	3745848.8274	28.578145	2023-07-31	2024-07-06	активен	\N
437	46	1615380.8899	19.424517	2023-05-05	2024-04-14	активен	Ипотечный кредит на покупку жилья
438	83	891209.8050	18.050395	2023-09-20	2024-01-22	активен	\N
439	26	3750177.9830	21.678834	2023-11-05	2024-11-30	активен	\N
440	13	936805.1080	14.597796	2023-07-12	2024-07-24	активен	\N
441	30	3262230.7168	26.487212	2023-11-03	2024-03-29	просрочен	\N
442	64	4847128.2770	7.450393	2023-02-04	2023-07-01	просрочен	\N
443	16	1950843.8132	31.819483	2023-04-13	2023-08-25	активен	\N
444	31	1714184.0620	14.429693	2023-11-20	2024-11-26	активен	Потребительский кредит на образование
445	66	3921452.6515	5.618375	2023-02-05	2023-11-28	активен	\N
446	24	2597856.9249	26.224250	2023-03-21	2023-05-31	активен	\N
447	66	257979.9179	6.775847	2023-06-28	2024-07-03	просрочен	\N
448	13	157712.3371	8.064196	2023-08-25	2023-10-17	закрыт	\N
449	49	4580381.4977	11.844382	2023-03-07	2023-05-15	активен	\N
450	37	2378777.5486	19.941359	2023-03-25	2023-12-18	просрочен	\N
451	58	1205164.6556	13.898653	2023-06-27	2024-07-15	просрочен	Потребительский кредит на образование
452	100	3331249.8938	20.758675	2023-06-11	2024-03-01	активен	\N
453	60	2413096.0265	22.912869	2023-06-04	2024-02-15	просрочен	\N
454	16	1007051.8069	12.465784	2023-08-07	2024-02-28	активен	\N
455	58	3264156.4729	31.936429	2023-01-05	2023-05-03	активен	\N
456	86	164264.1849	6.695129	2023-06-30	2024-06-26	просрочен	\N
457	54	4412148.6834	11.467407	2023-04-18	2024-01-01	просрочен	\N
458	4	79191.6234	14.521073	2023-02-11	2023-11-24	просрочен	\N
459	13	2481586.5894	23.423635	2023-05-05	2023-11-07	просрочен	\N
460	55	3907178.9370	12.115657	2023-05-09	2024-03-30	закрыт	\N
461	87	3673708.8966	21.255406	2023-08-02	2024-05-19	просрочен	\N
462	60	3638334.3005	10.753080	2023-01-20	2023-12-30	активен	\N
463	97	1841283.2854	14.615319	2023-03-17	2023-06-19	просрочен	Кредит на развитие бизнеса
464	48	2739229.2446	32.847419	2023-05-10	2024-04-15	активен	\N
465	93	1816366.0771	9.602851	2023-03-25	2024-01-03	активен	\N
466	17	2477419.6881	21.241368	2023-03-01	2023-05-18	закрыт	\N
467	56	2431684.0644	8.154286	2023-07-22	2023-11-27	активен	\N
468	82	3414974.5981	6.257329	2023-05-28	2024-03-04	закрыт	\N
469	36	2554615.9784	6.186866	2023-07-19	2023-09-11	закрыт	Ипотечный кредит на покупку жилья
470	13	4530002.4460	30.477384	2023-08-01	2024-05-12	просрочен	Потребительский кредит на образование
471	24	3540695.2173	13.601436	2023-08-25	2024-03-17	активен	\N
472	21	1532869.0888	23.840973	2023-07-17	2024-03-20	активен	\N
473	22	2988816.6126	11.349954	2023-06-12	2023-07-18	закрыт	\N
474	35	4739440.0930	11.863591	2023-09-01	2023-11-27	закрыт	\N
475	71	3986852.4231	7.945480	2023-05-19	2024-02-28	активен	Кредит на развитие бизнеса
476	14	3059497.0907	28.481470	2023-09-19	2023-12-04	просрочен	\N
477	12	4171431.8592	12.021080	2023-10-31	2024-10-09	просрочен	\N
478	25	4628745.8358	5.149703	2023-01-03	2023-09-26	просрочен	\N
479	63	3353824.6941	17.667673	2023-09-18	2024-04-19	активен	Целевой кредит на приобретение автомобиля
480	76	3045208.6316	25.624883	2023-03-10	2023-12-28	просрочен	\N
481	62	2698165.7958	27.223880	2023-01-14	2023-06-17	просрочен	Потребительский кредит на образование
482	62	2843648.4660	8.811973	2023-09-08	2023-11-04	закрыт	\N
483	55	3831979.5808	24.838423	2023-08-08	2024-01-11	просрочен	\N
484	40	547778.7384	6.072286	2023-04-28	2024-01-24	просрочен	\N
485	70	1227413.0533	19.195731	2023-09-06	2024-04-25	просрочен	\N
486	40	96573.8756	8.727438	2023-01-02	2023-04-23	закрыт	\N
487	98	2843024.3181	32.894343	2023-09-20	2024-01-10	закрыт	\N
488	59	4617285.8019	12.535317	2023-09-06	2024-06-18	просрочен	Кредит на ремонт
489	39	4137265.2827	11.729646	2023-03-11	2024-02-21	активен	\N
490	65	1559289.5165	17.231342	2023-08-09	2024-06-06	просрочен	Ипотечный кредит на покупку жилья
491	88	4930555.7405	9.803767	2023-04-01	2023-10-29	активен	\N
492	52	258215.7521	6.046930	2023-10-30	2023-12-30	просрочен	\N
493	82	737789.4660	8.102390	2023-08-01	2023-11-25	просрочен	\N
494	38	2923082.9106	19.917104	2023-06-17	2023-08-19	активен	Ипотечный кредит на покупку жилья
495	18	3996011.1659	10.734654	2023-08-06	2024-05-24	закрыт	\N
496	39	3516282.8093	27.134159	2023-09-12	2024-07-22	просрочен	\N
497	3	2295974.2239	29.374156	2023-06-24	2023-08-12	просрочен	\N
498	22	3557565.1023	19.021908	2023-12-06	2024-09-08	закрыт	\N
499	91	4162735.2481	31.984038	2023-02-02	2023-09-25	просрочен	\N
500	80	2077899.3758	24.787090	2023-03-24	2024-01-03	закрыт	\N
\.


--
-- Data for Name: personnel; Type: TABLE DATA; Schema: bank; Owner: postgres
--

COPY bank.personnel (employee_id, branch_id, name, "position", contact_info, salary) FROM stdin;
1	11	Анна Соколова	Аналитик	{"email": "alexei@bank.ru", "phone": "+79809592805", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	91710.78
2	9	Дмитрий Кузнецова	Программист	{"email": "ivan@bank.ru", "phone": "+79920307860", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	125987.88
3	13	Сергей Васильева	Программист	{"email": "sergey@bank.ru", "phone": "+79905602844", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	151105.66
4	10	Алексей Васильева	Программист	{"email": "alexei@bank.ru", "phone": "+79682662473", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	188595.00
5	1	Татьяна Васильева	Программист	{"email": "elena@bank.ru", "phone": "+79622032200", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	59893.34
6	21	Иван Михайлова	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79590298404", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	148596.69
7	19	Анна Соколова	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79282470480", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	67086.30
8	15	Сергей Петров	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79137601413", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	59432.15
9	14	Елена Попова	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79566555041", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	180373.12
10	11	Татьяна Федорова	Программист	{"email": "ivan@bank.ru", "phone": "+79487236716", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	199016.47
11	10	Иван Михайлова	Аналитик	{"email": "alexei@bank.ru", "phone": "+79516509866", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	187801.37
12	13	Алексей Иванов	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79593735517", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	161097.43
13	24	Ольга Сидоров	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79701689158", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	83778.61
14	13	Михаил Петров	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79693269510", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	133737.12
15	7	Сергей Сидоров	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79838019993", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	66107.23
16	18	Сергей Васильева	Программист	{"email": "alexei@bank.ru", "phone": "+79863524468", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	183741.84
17	15	Алексей Соколова	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79799980334", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	108157.04
18	8	Дмитрий Попова	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79906150955", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	104458.83
19	13	Ольга Смирнова	Программист	{"email": "elena@bank.ru", "phone": "+79618796630", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	91317.42
20	21	Татьяна Смирнова	Менеджер по работе с клиентами	{"email": "sergey@bank.ru", "phone": "+79829467828", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	114163.36
21	21	Иван Смирнова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79273330845", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	163597.36
22	18	Елена Сидоров	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79412452961", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	182618.73
23	11	Ольга Иванов	Аналитик	{"email": "ivan@bank.ru", "phone": "+79480294586", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	82829.81
24	15	Елена Васильева	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79889342724", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	74250.71
25	11	Ольга Иванов	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79387734065", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	165139.88
26	18	Дмитрий Михайлова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79175055247", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	182574.95
27	9	Наталья Иванов	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79379380818", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	115958.25
28	7	Наталья Петров	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79480986971", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	103821.63
29	1	Сергей Попова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79768688259", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	80580.57
30	15	Ольга Федорова	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79718484166", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	182466.17
31	10	Михаил Петров	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79040187282", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	109484.47
32	1	Дмитрий Сидоров	Руководитель отдела	{"email": "elena@bank.ru", "phone": "+79971227004", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	86289.64
33	13	Елена Смирнова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79765268642", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	143406.28
34	20	Сергей Смирнова	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79468749777", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	157515.23
35	16	Анна Федорова	Программист	{"email": "alexei@bank.ru", "phone": "+79964532616", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	101731.69
36	21	Алексей Сидоров	Аналитик	{"email": "sergey@bank.ru", "phone": "+79877408063", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	50241.97
37	17	Анна Федорова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79997780964", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	117665.03
38	8	Наталья Иванов	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79458425790", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	159111.12
39	9	Наталья Смирнова	Руководитель отдела	{"email": "sergey@bank.ru", "phone": "+79545239362", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	87561.05
40	21	Наталья Иванов	Аналитик	{"email": "sergey@bank.ru", "phone": "+79858370507", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	175246.28
41	9	Елена Кузнецова	Продуктовый менеджер	{"email": "alexei@bank.ru", "phone": "+79763770586", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	132370.37
42	17	Татьяна Соколова	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79113745280", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	182811.28
43	20	Иван Петров	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79288749329", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	107728.11
44	12	Алексей Сидоров	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79786725437", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	83736.83
45	4	Анна Кузнецова	Руководитель отдела	{"email": "elena@bank.ru", "phone": "+79197653477", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	191167.22
46	16	Дмитрий Васильева	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79821250445", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	143452.96
47	11	Михаил Иванов	Программист	{"email": "ivan@bank.ru", "phone": "+79768435723", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	65687.18
48	17	Дмитрий Попова	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79018569521", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	166251.72
49	5	Сергей Васильева	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79804620911", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	80298.05
50	2	Ольга Смирнова	Аналитик	{"email": "sergey@bank.ru", "phone": "+79301849213", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	171933.85
51	15	Елена Соколова	Программист	{"email": "elena@bank.ru", "phone": "+79354838873", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	88065.35
52	8	Ольга Михайлова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79885773086", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	157232.95
53	11	Анна Михайлова	Аналитик	{"email": "sergey@bank.ru", "phone": "+79203462891", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	88260.39
54	24	Дмитрий Соколова	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79575521223", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	199384.67
55	1	Дмитрий Кузнецова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79036324759", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	72344.50
56	12	Сергей Смирнова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79340791297", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	99708.57
57	3	Михаил Михайлова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79640964282", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	60150.48
58	24	Дмитрий Петров	Аналитик	{"email": "alexei@bank.ru", "phone": "+79836389559", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	177051.45
59	22	Сергей Петров	Аналитик	{"email": "elena@bank.ru", "phone": "+79835136980", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	155367.79
60	10	Наталья Кузнецова	Продуктовый менеджер	{"email": "sergey@bank.ru", "phone": "+79202225576", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	51479.19
61	3	Елена Кузнецова	Программист	{"email": "sergey@bank.ru", "phone": "+79432359697", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	164176.97
62	11	Ольга Федорова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79491712318", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	141718.40
63	3	Анна Кузнецова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79369583461", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	136421.26
64	5	Сергей Соколова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79581506344", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	167235.66
65	21	Иван Васильева	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79377968187", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	197341.42
66	0	Михаил Сидоров	Программист	{"email": "ivan@bank.ru", "phone": "+79953893827", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	139561.40
67	2	Михаил Васильева	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79284853960", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	97804.49
68	6	Иван Федорова	Аналитик	{"email": "elena@bank.ru", "phone": "+79708120147", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	153856.33
69	21	Сергей Федорова	Программист	{"email": "alexei@bank.ru", "phone": "+79887517613", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	52618.97
70	8	Иван Михайлова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79723091618", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	114014.25
141	15	Елена Сидоров	Аналитик	{"email": "alexei@bank.ru", "phone": "+79023465918", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	124971.52
71	12	Сергей Соколова	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79813838901", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	64469.96
72	16	Ольга Сидоров	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79266619534", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	196824.70
73	2	Иван Петров	Программист	{"email": "sergey@bank.ru", "phone": "+79844685742", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	182308.74
74	11	Наталья Смирнова	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79275916510", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	198513.92
75	14	Татьяна Сидоров	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79512036607", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	86978.45
76	6	Иван Васильева	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79969416986", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	83433.79
77	20	Дмитрий Иванов	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79296602854", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	173650.07
78	0	Михаил Сидоров	Аналитик	{"email": "ivan@bank.ru", "phone": "+79269269809", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	130794.81
79	16	Елена Михайлова	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79518159357", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	55568.91
80	15	Наталья Михайлова	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79602983913", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	182736.29
81	10	Татьяна Петров	Программист	{"email": "sergey@bank.ru", "phone": "+79614520055", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	66859.41
82	4	Михаил Кузнецова	Аналитик	{"email": "elena@bank.ru", "phone": "+79233154779", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	193594.35
83	13	Елена Сидоров	Программист	{"email": "alexei@bank.ru", "phone": "+79324377617", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	129770.93
84	0	Сергей Соколова	Программист	{"email": "elena@bank.ru", "phone": "+79849619449", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	81563.13
85	16	Михаил Кузнецова	Аналитик	{"email": "alexei@bank.ru", "phone": "+79578212472", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	73679.97
86	19	Иван Соколова	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79515661418", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	88827.93
87	19	Дмитрий Иванов	Аналитик	{"email": "elena@bank.ru", "phone": "+79421119586", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	118153.26
88	16	Сергей Иванов	Программист	{"email": "sergey@bank.ru", "phone": "+79888723311", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	136233.58
89	22	Михаил Петров	Менеджер по работе с клиентами	{"email": "sergey@bank.ru", "phone": "+79874658310", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	55125.31
90	15	Алексей Попова	Программист	{"email": "elena@bank.ru", "phone": "+79719758973", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	192836.72
91	22	Татьяна Смирнова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79233982129", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	183024.81
92	23	Елена Федорова	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79539839090", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	139873.19
93	1	Дмитрий Соколова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79429344059", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	175832.58
94	9	Елена Федорова	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79601627185", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	164172.35
95	20	Сергей Петров	Программист	{"email": "alexei@bank.ru", "phone": "+79552439634", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	105640.47
96	9	Татьяна Федорова	Продуктовый менеджер	{"email": "alexei@bank.ru", "phone": "+79208980754", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	182089.95
97	11	Ольга Васильева	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79197521417", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	130744.72
98	20	Алексей Сидоров	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79487416201", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	129994.37
99	11	Ольга Попова	Руководитель отдела	{"email": "elena@bank.ru", "phone": "+79817595336", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	107978.66
100	7	Анна Соколова	Руководитель отдела	{"email": "sergey@bank.ru", "phone": "+79472798034", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	166950.50
101	17	Елена Иванов	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79852473216", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	176036.67
102	3	Татьяна Васильева	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79979369666", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	64052.70
103	23	Татьяна Федорова	Программист	{"email": "ivan@bank.ru", "phone": "+79959118372", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	140470.21
104	1	Татьяна Кузнецова	Продуктовый менеджер	{"email": "alexei@bank.ru", "phone": "+79391001670", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	127539.56
105	11	Ольга Васильева	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79968095803", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	125345.65
106	10	Наталья Сидоров	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79661068551", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	174451.61
107	6	Татьяна Попова	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79935875118", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	130974.93
108	5	Татьяна Михайлова	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79967941900", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	158321.50
109	19	Анна Иванов	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79715730491", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	108350.49
110	8	Дмитрий Михайлова	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79798820515", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	56515.93
111	24	Наталья Смирнова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79566473166", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	116714.73
112	19	Алексей Петров	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79683423807", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	75966.88
113	3	Михаил Иванов	Аналитик	{"email": "elena@bank.ru", "phone": "+79128023422", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	68915.44
114	12	Дмитрий Иванов	Программист	{"email": "sergey@bank.ru", "phone": "+79468388756", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	145606.17
115	16	Татьяна Кузнецова	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79013601677", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	192389.18
116	15	Михаил Кузнецова	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79405289576", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	189364.85
117	19	Дмитрий Федорова	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79096440436", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	130452.21
118	5	Иван Иванов	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79642463757", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	111256.57
119	15	Наталья Васильева	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79530655527", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	61570.06
120	7	Дмитрий Федорова	Программист	{"email": "alexei@bank.ru", "phone": "+79916703301", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	123808.82
121	1	Ольга Кузнецова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79513412904", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	191415.63
122	22	Алексей Сидоров	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79612426459", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	134115.77
123	1	Татьяна Соколова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79225286230", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	190141.83
124	15	Иван Соколова	Программист	{"email": "elena@bank.ru", "phone": "+79541441931", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	56654.88
125	23	Иван Сидоров	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79776461893", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	53598.98
126	7	Дмитрий Сидоров	Руководитель отдела	{"email": "elena@bank.ru", "phone": "+79829929437", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	68013.26
127	6	Анна Соколова	Руководитель отдела	{"email": "elena@bank.ru", "phone": "+79946768314", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	150399.53
128	24	Сергей Смирнова	Программист	{"email": "ivan@bank.ru", "phone": "+79502340857", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	133967.15
129	9	Анна Соколова	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79806862239", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	150121.71
130	17	Ольга Федорова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79084522637", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	110539.03
131	9	Алексей Михайлова	Аналитик	{"email": "alexei@bank.ru", "phone": "+79003863302", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	57499.27
132	3	Алексей Федорова	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79647523321", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	196624.20
133	10	Сергей Иванов	Руководитель отдела	{"email": "sergey@bank.ru", "phone": "+79129617355", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	140144.09
134	0	Дмитрий Федорова	Программист	{"email": "ivan@bank.ru", "phone": "+79575042494", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	95325.56
135	5	Михаил Попова	Продуктовый менеджер	{"email": "alexei@bank.ru", "phone": "+79476312209", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	54813.64
136	15	Ольга Васильева	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79613334687", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	95560.64
137	1	Ольга Васильева	Аналитик	{"email": "sergey@bank.ru", "phone": "+79410099258", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	108947.18
138	24	Анна Федорова	Менеджер по работе с клиентами	{"email": "sergey@bank.ru", "phone": "+79597909849", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	173360.61
139	0	Наталья Федорова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79672247573", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	80463.52
140	5	Анна Соколова	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79644358962", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	59353.40
142	3	Наталья Иванов	Программист	{"email": "alexei@bank.ru", "phone": "+79322227241", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	92614.18
143	12	Ольга Попова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79040320143", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	143763.74
144	17	Татьяна Васильева	Аналитик	{"email": "alexei@bank.ru", "phone": "+79811142600", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	89595.91
145	9	Татьяна Соколова	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79356212831", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	125306.26
146	7	Елена Соколова	Программист	{"email": "ivan@bank.ru", "phone": "+79876857195", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	90517.56
147	24	Алексей Смирнова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79077201811", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	154244.34
148	18	Сергей Федорова	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79945549695", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	76850.85
149	1	Елена Соколова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79217972331", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	147550.09
150	5	Елена Михайлова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79289281641", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	144587.02
151	7	Сергей Иванов	Аналитик	{"email": "alexei@bank.ru", "phone": "+79597394277", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	64192.81
152	23	Елена Иванов	Программист	{"email": "elena@bank.ru", "phone": "+79997838356", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	70329.51
153	12	Дмитрий Соколова	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79619222648", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	109360.10
154	2	Дмитрий Михайлова	Программист	{"email": "alexei@bank.ru", "phone": "+79956098648", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	84762.39
155	18	Дмитрий Михайлова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79674739813", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	198837.40
156	8	Анна Кузнецова	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79948684672", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	63009.03
157	16	Елена Федорова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79537502162", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	114348.61
158	22	Алексей Кузнецова	Программист	{"email": "alexei@bank.ru", "phone": "+79036978939", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	166609.45
159	24	Елена Соколова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79412571717", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	146802.65
160	0	Елена Васильева	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79069369169", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	182659.56
161	5	Алексей Смирнова	Аналитик	{"email": "elena@bank.ru", "phone": "+79915323874", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	102812.07
162	24	Михаил Смирнова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79809450454", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	65740.70
163	1	Наталья Смирнова	Аналитик	{"email": "sergey@bank.ru", "phone": "+79432999869", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	54385.78
164	20	Михаил Федорова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79588771800", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	52813.04
165	5	Елена Михайлова	Аналитик	{"email": "elena@bank.ru", "phone": "+79255537138", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	139611.59
166	22	Алексей Попова	Программист	{"email": "ivan@bank.ru", "phone": "+79501743477", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	113313.13
167	11	Дмитрий Иванов	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79579309572", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	99065.89
168	18	Алексей Попова	Программист	{"email": "elena@bank.ru", "phone": "+79878188417", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	157801.35
169	18	Дмитрий Попова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79061661085", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	135805.74
170	11	Алексей Васильева	Продуктовый менеджер	{"email": "alexei@bank.ru", "phone": "+79503510835", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	52536.85
171	3	Анна Соколова	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79049906051", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	176272.72
172	20	Елена Попова	Аналитик	{"email": "sergey@bank.ru", "phone": "+79199066575", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	181429.92
173	15	Михаил Смирнова	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79251062221", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	68675.61
174	18	Наталья Михайлова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79557964498", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	187006.88
175	13	Ольга Кузнецова	Менеджер по работе с клиентами	{"email": "sergey@bank.ru", "phone": "+79510533113", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	169478.03
176	18	Сергей Смирнова	Продуктовый менеджер	{"email": "alexei@bank.ru", "phone": "+79454234936", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	141365.70
177	11	Ольга Соколова	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79877580270", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	52662.18
178	19	Иван Федорова	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79961178627", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	145008.30
179	19	Алексей Михайлова	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79836810118", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	143692.54
180	6	Сергей Кузнецова	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79069803142", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	175611.82
181	24	Ольга Кузнецова	Аналитик	{"email": "sergey@bank.ru", "phone": "+79538906540", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	69865.63
182	6	Алексей Васильева	Продуктовый менеджер	{"email": "sergey@bank.ru", "phone": "+79015569314", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	54002.15
183	14	Алексей Иванов	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79318973157", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	84318.32
184	17	Дмитрий Михайлова	Программист	{"email": "sergey@bank.ru", "phone": "+79713875619", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	120379.57
185	23	Ольга Васильева	Аналитик	{"email": "sergey@bank.ru", "phone": "+79145655307", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	149385.47
186	15	Сергей Смирнова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79137652436", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	148348.71
187	12	Дмитрий Васильева	Программист	{"email": "ivan@bank.ru", "phone": "+79090466177", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	134728.03
188	18	Дмитрий Попова	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79261385657", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	111396.76
189	2	Алексей Михайлова	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79627627937", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	113007.34
190	22	Иван Петров	Программист	{"email": "alexei@bank.ru", "phone": "+79846405016", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	121122.53
191	13	Алексей Соколова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79705224441", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	126880.24
192	16	Елена Попова	Продуктовый менеджер	{"email": "sergey@bank.ru", "phone": "+79282634883", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	183303.54
193	5	Михаил Петров	Аналитик	{"email": "sergey@bank.ru", "phone": "+79462760953", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	154807.70
194	9	Елена Смирнова	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79919212729", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	95276.53
195	10	Алексей Попова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79312432387", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	113925.70
196	19	Наталья Федорова	Программист	{"email": "alexei@bank.ru", "phone": "+79926659558", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	87188.73
197	21	Наталья Петров	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79359863353", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	152179.17
198	11	Алексей Федорова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79751367042", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	82368.06
199	13	Анна Кузнецова	Программист	{"email": "alexei@bank.ru", "phone": "+79738779092", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	164143.88
200	0	Елена Федорова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79803682544", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	153019.85
201	9	Иван Михайлова	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79461466909", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	64762.62
202	20	Алексей Соколова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79238410039", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	109664.49
203	19	Елена Иванов	Руководитель отдела	{"email": "elena@bank.ru", "phone": "+79309541132", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	122198.46
204	13	Сергей Кузнецова	Продуктовый менеджер	{"email": "sergey@bank.ru", "phone": "+79974630233", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	155061.65
205	16	Иван Соколова	Программист	{"email": "elena@bank.ru", "phone": "+79489243567", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	74950.50
206	7	Сергей Иванов	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79933358481", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	71274.77
207	15	Сергей Петров	Аналитик	{"email": "alexei@bank.ru", "phone": "+79517562135", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	94972.00
208	5	Татьяна Соколова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79292728176", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	161915.59
209	4	Дмитрий Иванов	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79288164594", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	163803.92
210	4	Иван Сидоров	Аналитик	{"email": "alexei@bank.ru", "phone": "+79388263311", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	190043.53
211	15	Дмитрий Соколова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79559143628", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	97956.72
212	18	Елена Васильева	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79247233294", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	118110.34
213	2	Ольга Попова	Программист	{"email": "sergey@bank.ru", "phone": "+79266484908", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	190521.40
214	15	Иван Соколова	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79664450306", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	100268.60
215	4	Татьяна Иванов	Менеджер по работе с клиентами	{"email": "sergey@bank.ru", "phone": "+79265559057", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	67841.43
216	22	Ольга Смирнова	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79024508130", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	108614.24
217	0	Сергей Соколова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79759521638", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	97829.10
218	19	Татьяна Соколова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79533167077", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	127955.13
219	23	Иван Сидоров	Программист	{"email": "ivan@bank.ru", "phone": "+79939605222", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	179635.25
220	20	Анна Васильева	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79122400964", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	172484.54
221	6	Елена Иванов	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79201191528", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	163201.24
222	22	Наталья Соколова	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79846182121", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	88396.33
223	3	Анна Соколова	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79965608409", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	96027.52
224	9	Татьяна Кузнецова	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79074919710", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	199615.75
225	12	Иван Петров	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79621256682", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	62407.08
226	16	Дмитрий Васильева	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79721414173", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	193477.70
227	10	Иван Смирнова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79662925349", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	129967.20
228	1	Наталья Кузнецова	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79234557376", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	111665.28
229	24	Ольга Иванов	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79687654634", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	135397.40
230	19	Татьяна Кузнецова	Менеджер по работе с клиентами	{"email": "sergey@bank.ru", "phone": "+79722201087", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	182323.66
231	6	Иван Соколова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79107043274", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	70719.86
232	24	Татьяна Иванов	Программист	{"email": "elena@bank.ru", "phone": "+79339009701", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	165331.14
233	18	Дмитрий Петров	Руководитель отдела	{"email": "ivan@bank.ru", "phone": "+79221140807", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	90617.15
234	22	Ольга Соколова	Программист	{"email": "elena@bank.ru", "phone": "+79787990956", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	119127.34
235	15	Дмитрий Смирнова	Аналитик	{"email": "alexei@bank.ru", "phone": "+79106631948", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	56098.90
236	24	Михаил Попова	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79057994069", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	82662.41
237	11	Елена Иванов	Аналитик	{"email": "alexei@bank.ru", "phone": "+79633327265", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	109276.69
238	3	Дмитрий Соколова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79896377027", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	144328.02
239	17	Анна Васильева	Руководитель отдела	{"email": "elena@bank.ru", "phone": "+79778946881", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	57263.24
240	22	Наталья Сидоров	Аналитик	{"email": "ivan@bank.ru", "phone": "+79125833693", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	106727.40
241	16	Дмитрий Соколова	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79244913137", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	131040.12
242	13	Михаил Васильева	Руководитель отдела	{"email": "sergey@bank.ru", "phone": "+79571881901", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	161485.08
243	4	Анна Сидоров	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79286518629", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	115893.71
244	18	Алексей Смирнова	Руководитель отдела	{"email": "sergey@bank.ru", "phone": "+79969232341", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	83744.00
245	21	Наталья Петров	Программист	{"email": "elena@bank.ru", "phone": "+79924516061", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	132306.27
246	5	Сергей Михайлова	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79171375227", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	51524.17
247	15	Татьяна Михайлова	Программист	{"email": "alexei@bank.ru", "phone": "+79101283103", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	184521.43
248	23	Наталья Попова	Продуктовый менеджер	{"email": "elena@bank.ru", "phone": "+79877757686", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	128150.55
249	11	Ольга Федорова	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79753010464", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	177008.45
250	18	Сергей Федорова	Программист	{"email": "sergey@bank.ru", "phone": "+79642816128", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	86231.72
251	2	Михаил Михайлова	Программист	{"email": "elena@bank.ru", "phone": "+79464438496", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	185308.60
252	4	Анна Иванов	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79787716214", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	166240.03
253	18	Татьяна Михайлова	Программист	{"email": "elena@bank.ru", "phone": "+79955579784", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	62894.76
254	14	Ольга Попова	Аналитик	{"email": "elena@bank.ru", "phone": "+79657608092", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	158100.53
255	10	Дмитрий Михайлова	Аналитик	{"email": "ivan@bank.ru", "phone": "+79889663846", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	139675.31
256	11	Дмитрий Сидоров	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79653441904", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	50329.30
257	13	Иван Сидоров	Аналитик	{"email": "elena@bank.ru", "phone": "+79906141871", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	122903.76
258	16	Сергей Петров	Менеджер по работе с клиентами	{"email": "sergey@bank.ru", "phone": "+79149767713", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	130352.04
259	9	Наталья Васильева	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79421579986", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	197770.46
260	17	Сергей Смирнова	Аналитик	{"email": "elena@bank.ru", "phone": "+79118875085", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	54961.59
261	2	Елена Соколова	Программист	{"email": "ivan@bank.ru", "phone": "+79559695779", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	197196.71
262	6	Ольга Кузнецова	Программист	{"email": "ivan@bank.ru", "phone": "+79459642464", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	133148.83
263	17	Елена Сидоров	Специалист по безопасности	{"email": "alexei@bank.ru", "phone": "+79549805396", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	127082.87
264	3	Анна Смирнова	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79835688134", "linkedin": "linkedin.com/in/elena", "telegram": "@alexei"}	199770.32
265	22	Дмитрий Соколова	Аналитик	{"email": "sergey@bank.ru", "phone": "+79276129355", "linkedin": "linkedin.com/in/elena", "telegram": "@elena"}	131389.15
266	1	Иван Попова	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79318225835", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	180294.20
267	8	Сергей Федорова	Аналитик	{"email": "alexei@bank.ru", "phone": "+79799756645", "linkedin": "linkedin.com/in/sergey", "telegram": "@alexei"}	108415.55
268	7	Михаил Смирнова	Продуктовый менеджер	{"email": "sergey@bank.ru", "phone": "+79026908372", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	195261.39
269	6	Анна Петров	Специалист по безопасности	{"email": "ivan@bank.ru", "phone": "+79380567792", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	63630.51
270	16	Ольга Петров	Программист	{"email": "elena@bank.ru", "phone": "+79961755835", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	103230.33
271	2	Анна Васильева	Аналитик	{"email": "ivan@bank.ru", "phone": "+79848263572", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	144992.24
272	6	Иван Петров	Аналитик	{"email": "elena@bank.ru", "phone": "+79906092794", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	63257.05
273	23	Наталья Васильева	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79997051534", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	126944.82
274	16	Иван Смирнова	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79129749037", "linkedin": "linkedin.com/in/alexei", "telegram": "@alexei"}	94594.91
275	17	Михаил Иванов	Аналитик	{"email": "ivan@bank.ru", "phone": "+79072730502", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	96372.77
276	17	Сергей Иванов	Программист	{"email": "alexei@bank.ru", "phone": "+79943911115", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	136565.14
277	12	Иван Кузнецова	Аналитик	{"email": "alexei@bank.ru", "phone": "+79405146402", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	197921.36
278	11	Алексей Сидоров	Менеджер по работе с клиентами	{"email": "ivan@bank.ru", "phone": "+79847521089", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	142794.82
279	1	Иван Сидоров	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79735846005", "linkedin": "linkedin.com/in/alexei", "telegram": "@elena"}	124092.67
280	1	Дмитрий Иванов	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79595099461", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	196349.08
281	3	Елена Кузнецова	Менеджер по работе с клиентами	{"email": "sergey@bank.ru", "phone": "+79726618822", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	102922.79
282	16	Елена Попова	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79905321340", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	129627.09
283	2	Наталья Петров	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79232049665", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	105338.73
284	10	Анна Петров	Руководитель отдела	{"email": "elena@bank.ru", "phone": "+79728475267", "linkedin": "linkedin.com/in/alexei", "telegram": "@ivan"}	74016.74
285	15	Алексей Иванов	Руководитель отдела	{"email": "alexei@bank.ru", "phone": "+79182109717", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	78189.27
286	23	Дмитрий Федорова	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79771094675", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	167865.78
287	6	Анна Смирнова	Менеджер по работе с клиентами	{"email": "alexei@bank.ru", "phone": "+79029565295", "linkedin": "linkedin.com/in/ivan", "telegram": "@sergey"}	162776.29
288	10	Татьяна Сидоров	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79769291943", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	197712.07
289	4	Иван Соколова	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79113620001", "linkedin": "linkedin.com/in/sergey", "telegram": "@elena"}	145176.53
290	11	Татьяна Васильева	Продуктовый менеджер	{"email": "sergey@bank.ru", "phone": "+79182571043", "linkedin": "linkedin.com/in/ivan", "telegram": "@elena"}	113480.57
291	24	Иван Попова	Программист	{"email": "alexei@bank.ru", "phone": "+79066978458", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	108175.18
292	13	Наталья Смирнова	Продуктовый менеджер	{"email": "ivan@bank.ru", "phone": "+79935206719", "linkedin": "linkedin.com/in/sergey", "telegram": "@ivan"}	50036.85
293	14	Анна Сидоров	Специалист по безопасности	{"email": "elena@bank.ru", "phone": "+79626495745", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	90786.32
294	11	Наталья Смирнова	Программист	{"email": "alexei@bank.ru", "phone": "+79812714180", "linkedin": "linkedin.com/in/elena", "telegram": "@sergey"}	52343.67
295	12	Иван Васильева	Руководитель отдела	{"email": "sergey@bank.ru", "phone": "+79262678133", "linkedin": "linkedin.com/in/ivan", "telegram": "@ivan"}	185469.70
296	7	Наталья Сидоров	Аналитик	{"email": "elena@bank.ru", "phone": "+79236996586", "linkedin": "linkedin.com/in/elena", "telegram": "@ivan"}	162525.26
297	14	Татьяна Васильева	Руководитель отдела	{"email": "sergey@bank.ru", "phone": "+79748808265", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	158498.38
298	13	Татьяна Кузнецова	Программист	{"email": "ivan@bank.ru", "phone": "+79137968442", "linkedin": "linkedin.com/in/alexei", "telegram": "@sergey"}	199779.44
299	23	Татьяна Сидоров	Менеджер по работе с клиентами	{"email": "elena@bank.ru", "phone": "+79138798910", "linkedin": "linkedin.com/in/sergey", "telegram": "@sergey"}	56980.10
300	0	Анна Соколова	Специалист по безопасности	{"email": "sergey@bank.ru", "phone": "+79467593898", "linkedin": "linkedin.com/in/ivan", "telegram": "@alexei"}	76530.06
\.


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: bank; Owner: postgres
--

COPY bank.transactions (transaction_id, prpl_account_num, cur_id, date, bene_account_num, type, amount, commission, status, bank_cor_swift) FROM stdin;
1	RU7283803436565335970635584506660	978	2023-07-15	RU4283803436512174946847064448344	внутренняя	6730757.7317	538.9122	отправлена	\N
2	RU8983803436545494349013660032430	156	2023-03-18	VN1755942333420907812700444	международная	7176337.0626	45.5557	доставлена	BKCHCNBJ
3	RU9783803436566819882292917709885	156	2023-10-31	RU9783803436586848496167067081204	внутренняя	2884198.1433	721.6469	отменена	\N
4	RU1983803436510686315036595318873	398	2023-12-13	IN6078081799361430808610855	международная	4658534.4141	616.7564	отменена	CASPKZKAXXX
5	RU7383803436515152831562897371432	398	2023-02-25	VN2122973241854683230820591	международная	2964714.4085	749.3082	отменена	CASPKZKAXXX
6	RU8183803436564595439284009293487	156	2023-01-03	ES6158994081103756439164678	международная	8649848.9369	333.2735	доставлена	BKCHCNBJ
7	RU7183803436546875767014611813689	356	2023-05-24	RU9083803436548965374028188380728	внутренняя	3651809.9642	561.4046	отменена	\N
8	RU5583803436516539388298963058164	356	2023-02-26	RU8583803436529401978461350257287	внутренняя	6186909.4173	391.6366	доставлена	\N
9	RU6683803436546559918630563560759	398	2023-05-02	DE6177566101869372342214644	международная	7130923.2687	64.3263	отправлена	CASPKZKAXXX
10	RU8183803436584325139466333599286	840	2023-12-03	VN6399230512086753926797713	международная	242832.0436	718.4369	отменена	CHASUS33
11	RU8583803436553386257766521949981	356	2023-04-17	ES2452398876777739747135418	международная	4261243.9461	206.8972	отправлена	SBININBBXXX
12	RU5283803436570838144716210841495	156	2023-04-20	BY3799375099674290915111832	международная	7704582.3531	94.9404	отправлена	BKCHCNBJ
13	RU3183803436564747839620735247465	156	2023-04-26	RU6583803436552414284054924599360	внутренняя	3624281.2903	98.3910	отправлена	\N
14	RU4483803436537144245226352938256	840	2023-01-18	RU4383803436559640804885433764330	внутренняя	7411769.3186	95.2434	отменена	\N
15	RU3683803436542925451475324573982	356	2023-08-13	AD1499063669159700900038752	международная	3269981.0851	830.0535	отменена	SBININBBXXX
16	RU8183803436546948351691601253240	356	2023-01-02	RU2583803436510413813910694958748	внутренняя	1304142.1233	785.3993	отменена	\N
17	RU8983803436518961229187913059129	356	2023-02-13	RU1983803436574962372646294489745	внутренняя	1535925.3430	766.9604	отменена	\N
18	RU6683803436546559918630563560759	978	2023-02-19	KZ4536733653583251943715955	международная	9292092.1024	508.2076	отменена	SOGEFRPP
19	RU5683803436573106663960342062340	643	2023-08-20	BY2457719446676758127047492	внутренняя	4653012.1121	43.9810	доставлена	\N
20	RU8983803436513229118545499417330	840	2023-10-24	RU2883803436510195395163379960366	внутренняя	6097681.5850	461.5989	доставлена	\N
21	RU2983803436572678251629055132350	156	2023-07-13	VN8329352784711906631725944	международная	8285342.4693	334.9709	доставлена	BKCHCNBJ
22	RU2583803436569716293278278112122	398	2023-09-23	RU1683803436549082108439124677076	внутренняя	7514664.8563	515.4095	отправлена	\N
23	RU2583803436510413813910694958748	156	2023-01-10	KZ6378213696314819085344385	международная	1369742.1311	972.8375	отменена	BKCHCNBJ
24	RU6583803436592149423686806465410	398	2023-01-11	RU8483803436576032684947735830335	внутренняя	3246514.6314	309.0786	доставлена	\N
25	RU8483803436583598027317615125571	156	2023-07-09	RU5396713566656856226616710	внутренняя	5495748.1669	117.8777	отправлена	\N
26	RU8183803436555934243334630961587	840	2023-12-07	RU5883803436571013870275428717873	внутренняя	5418612.6258	953.3611	отправлена	\N
27	RU2683803436532775565489898182986	156	2023-10-26	AL7683155744685593423481064	международная	9617519.0721	123.7866	отправлена	BKCHCNBJ
28	RU2483803436559904294875702128517	643	2022-12-30	RU3583803436531844714480494060517	внутренняя	5629538.6916	654.4104	доставлена	\N
29	RU3083803436518573891716312234719	978	2023-10-06	BY3542560132104152305398680	международная	2170124.4675	382.7678	отменена	DEUTDEFFXXX
30	RU7183803436551143317683635788042	398	2023-01-21	RU7483803436595027677837710467368	внутренняя	1569364.4470	681.9505	доставлена	\N
31	RU4183803436575456526806163894045	156	2023-09-26	RU9783803436586848496167067081204	внутренняя	3356464.3900	129.4068	доставлена	\N
32	RU6983803436557684576294868357987	840	2023-02-07	BY9086628822254040711240232	международная	2094856.7375	353.3169	доставлена	CHASUS33
33	RU8183803436532187852215520403243	156	2023-10-05	PT7172966322483499769054955	международная	6136081.8508	384.1879	отправлена	BKCHCNBJ
34	RU4483803436531766422461159975910	840	2023-01-31	AD6270854488900653311802506	международная	7156742.2546	932.1706	отменена	CHASUS33
35	RU1683803436543683792461716245841	643	2023-02-25	RU7583803436545511345420608427589	внутренняя	4089655.0562	144.2616	доставлена	\N
36	RU4083803436526038486689011711230	356	2023-03-06	RU7583803436593274051968042799324	внутренняя	5570805.6037	978.2029	доставлена	\N
37	RU7283803436551671539996901196859	978	2023-04-19	RU1683803436536773128968824249362	внутренняя	8107644.4874	461.4488	доставлена	\N
38	RU6483803436513432249664452306210	356	2023-05-24	RU4083803436561171626967381260937	внутренняя	5999095.3983	946.5234	доставлена	\N
39	RU5983803436558435772787343054218	356	2023-09-18	ES4164919077532301252312243	международная	7516743.0028	375.1541	отменена	SBININBBXXX
40	RU7183803436578006903833632767386	356	2023-01-30	RU1683803436543683792461716245841	внутренняя	4485305.2653	507.9461	отменена	\N
41	RU1983803436549890414007715363567	156	2023-01-29	RU8383803436583878629872361871714	внутренняя	8240368.2563	599.2116	отменена	\N
42	RU6783803436582018660242960957244	398	2023-03-18	RU1983803436592911874717339237016	внутренняя	9976624.3832	200.9996	отправлена	\N
43	RU8483803436517523304653033637180	840	2023-08-29	VN7875954784481949479118377	международная	4400783.6619	866.0777	отправлена	IRVTUS3NXXX
44	RU6983803436580831999013679742086	356	2023-11-05	AL2471045741784661076191741	международная	5382695.7785	286.9370	отменена	SBININBBXXX
45	RU8983803436519227550175732694863	978	2023-04-01	DE1861086769299941799976871	международная	7462465.3964	499.2141	отправлена	DEUTDEFFXXX
46	RU2483803436537933507280624045523	978	2023-06-15	RU9283803436564588409350021574669	внутренняя	1556610.4017	675.3567	доставлена	\N
2515	RU1483803436556765140449291811625	643	2023-06-20	KZ9963237365653910458824486	внутренняя	3393328.4057	411.6557	отменена	\N
47	RU5283803436570838144716210841495	156	2023-08-01	BY1051530167910277907640555	международная	9088196.5841	385.7298	отправлена	BKCHCNBJ
48	RU7783803436520045957277741704368	978	2023-05-17	RU3149724976193130028766982	внутренняя	4236027.7035	617.0397	отменена	\N
49	RU3083803436556733352794187735054	156	2023-02-19	ES7339431625666467335105627	международная	433872.0288	241.9153	отправлена	BKCHCNBJ
50	RU9683803436597203099828784600586	643	2023-10-15	RU4583803436571583967013936520660	внутренняя	957877.0104	271.9980	отправлена	\N
51	RU2983803436530272226005609138408	156	2023-04-16	KZ2768988519131246871465586	международная	1753102.2244	0.0000	доставлена	BKCHCNBJ
52	RU5183803436599553165549416662045	156	2023-08-07	ES2595835638371157705491261	международная	1793783.3339	273.9915	доставлена	BKCHCNBJ
53	RU9983803436563015974445739907644	643	2023-10-24	RU7483803436591068390387769478580	внутренняя	5641321.9590	657.8141	доставлена	\N
54	RU8983803436530366335955653516096	156	2023-05-31	RU2583803436525056668985275863842	внутренняя	9877003.1887	550.5558	отменена	\N
55	RU5883803436551017474710608700284	643	2023-02-25	BY8177498206478461165839059	внутренняя	4165876.2034	906.8854	отправлена	\N
56	RU1983803436549890414007715363567	156	2023-10-11	RU4083803436523112590591409946049	внутренняя	8541689.4242	993.7614	отменена	\N
57	RU1583803436533479152204865778047	398	2023-04-13	ES5386897762133099122221235	международная	5459779.0746	168.5549	отправлена	CASPKZKAXXX
58	RU5683803436573106663960342062340	978	2022-12-30	RU6083803436569163727288631654599	внутренняя	2893110.7417	88.7734	отправлена	\N
59	RU8683803436511417676206561932357	978	2023-02-27	RU8483803436552375991404578719285	внутренняя	4043448.2902	904.3092	отправлена	\N
60	RU6483803436531317735484528392559	643	2023-08-02	RU2676302007057717421820290	внутренняя	2964415.6763	428.6556	доставлена	\N
61	RU8483803436552375991404578719285	398	2023-07-09	ES4351021797289183492248741	международная	2175115.9278	448.6472	доставлена	CASPKZKAXXX
62	RU5483803436559214869633349674125	840	2023-03-29	RU8483803436583598027317615125571	внутренняя	4593270.9594	10.1132	отправлена	\N
63	RU5083803436563140090168469536649	978	2023-09-13	RU3483803436537283842522563725379	внутренняя	5263988.7370	634.3844	доставлена	\N
64	RU6983803436582618731634671628237	643	2023-09-30	RU4057045822729855845265707	внутренняя	6723371.4406	199.3689	доставлена	\N
65	RU1283803436545193525808988988532	643	2023-07-30	RU2783803436512588965300606208370	внутренняя	6104993.2649	276.3911	отправлена	\N
66	RU8083803436548053884024737088236	643	2023-06-12	RU9483803436522220035875117822565	внутренняя	6653085.8302	734.8042	отправлена	\N
67	RU3883803436515226766320509995235	356	2023-11-14	AD1869663908015311448731294	международная	4016180.4337	680.5412	доставлена	SBININBBXXX
68	RU2683803436512319317744369021772	398	2023-01-18	RU2183803436535230801413319305895	внутренняя	1315488.4077	174.6739	доставлена	\N
69	RU8483803436583598027317615125571	978	2023-03-27	PT4238665008286422394500246	международная	7652604.6129	573.4736	отправлена	SOGEFRPP
70	RU3083803436518573891716312234719	840	2023-02-11	ES5899152553817982187046368	международная	443176.8742	522.6400	отменена	CHASUS33
71	RU2083803436593214630941740939011	978	2023-02-07	ES6473772991554255982967380	международная	6306616.5708	680.1113	отправлена	RZBAATWW
72	RU1583803436578714315409224923820	356	2023-01-26	RU5583803436533254773648721597711	внутренняя	3708457.1200	746.0027	доставлена	\N
73	RU3783803436559423561964096195262	356	2023-05-26	BY3686736183924175217322312	международная	3875038.9492	652.3652	доставлена	SBININBBXXX
74	RU9483803436588743613330942629999	356	2023-11-10	RU1983803436518034161993382946183	внутренняя	2624040.8372	82.5903	отправлена	\N
75	RU8583803436598717986670697262250	978	2023-09-20	AD1988503593453094493475329	международная	3396600.3911	528.9982	отменена	DEUTDEFFXXX
76	RU8183803436532187852215520403243	978	2023-08-11	RU2583803436586349630493889324094	внутренняя	27842.9586	989.9786	отправлена	\N
77	RU4883803436510661666911089208306	643	2022-12-28	RU5483803436547543071206231343471	внутренняя	5603604.7252	528.8582	отменена	\N
78	RU8483803436528403655778834568144	356	2023-06-25	AL1743893735540934031116551	международная	4568481.1899	0.0000	доставлена	SBININBBXXX
79	RU4383803436586323329892508459044	356	2023-08-03	RU9883803436559947701649293062119	внутренняя	6330419.4161	280.3208	доставлена	\N
80	RU4783803436576956010684046744289	978	2023-03-28	ES6693290356974917919550603	международная	7834066.6597	930.4720	отменена	SOGEFRPP
81	RU7383803436585863943754594310819	356	2023-06-09	IN7169716627954529839243474	международная	5981012.6163	413.7323	доставлена	SBININBBXXX
82	RU5783803436568341660520010753753	156	2023-04-20	ES1169052896892083484226716	международная	480781.6806	471.4546	отменена	BKCHCNBJ
83	RU4783803436576956010684046744289	978	2023-12-24	RU7483803436595528340078834029783	внутренняя	6781389.2536	897.7139	доставлена	\N
84	RU3083803436556733352794187735054	978	2023-12-24	ES6473052935594229352650891	международная	2456683.9238	251.5305	отменена	DEUTDEFFXXX
85	RU5183803436531460410872953149827	978	2023-02-07	RU8183803436576334203563049364101	внутренняя	9649294.3105	605.8648	отправлена	\N
86	RU6783803436527708547728704282997	156	2023-04-29	RU2683803436575198696607383546599	внутренняя	1446796.0982	172.1540	отменена	\N
87	RU9483803436588743613330942629999	398	2023-09-11	RU8683803436511417676206561932357	внутренняя	5448011.4410	924.9937	отменена	\N
88	RU3183803436545750333950215053352	840	2023-03-04	KZ1721606894322323145682651	международная	611498.5441	968.6042	доставлена	IRVTUS3NXXX
89	RU5983803436565674700991182664479	643	2023-11-06	RU3183803436564747839620735247465	внутренняя	8956065.2672	938.2490	отправлена	\N
90	RU6483803436595566817980742907742	398	2023-10-10	RU5083803436521160540176223483455	внутренняя	3298526.7232	668.5757	доставлена	\N
91	RU7183803436596080848426828093950	643	2023-04-08	RU7683803436589524723383129532286	внутренняя	3021998.2502	255.8953	отменена	\N
92	RU7883803436577262824038798840088	398	2023-01-28	RU5483803436547543071206231343471	внутренняя	502287.8392	127.1535	отправлена	\N
3121	RU5783803436598085342824416355658	356	2023-12-20	RU3050397979375921801704305	внутренняя	9260105.4696	121.7493	отменена	\N
93	RU1283803436521770311179326367954	978	2023-12-18	BY5149414885353725340564990	международная	671381.1957	949.9302	доставлена	RZBAATWW
94	RU2283803436588289284937975921944	356	2023-08-29	KZ6448596136905335851726168	международная	725592.1931	967.3488	отменена	SBININBBXXX
95	RU8683803436511417676206561932357	356	2023-06-17	RU5683803436575772290627280121203	внутренняя	3219620.7638	997.0850	отправлена	\N
96	RU8983803436545494349013660032430	156	2023-07-31	RU9883803436596118671708861810646	внутренняя	7688562.0552	466.8800	доставлена	\N
97	RU4083803436530357399673623809331	398	2023-08-21	RU5383803436532276110708298062956	внутренняя	8786023.1080	935.9644	доставлена	\N
98	RU9283803436564588409350021574669	156	2023-10-18	RU8983803436545494349013660032430	внутренняя	8017920.8224	121.1340	отправлена	\N
99	RU6183803436547326038705936576601	356	2022-12-27	RU6783803436582018660242960957244	внутренняя	7947444.6640	948.8801	отменена	\N
100	RU4583803436535138140020222748384	643	2023-02-11	RU2083803436573246597416370413406	внутренняя	4157397.7592	542.4065	отправлена	\N
101	RU4083803436530357399673623809331	156	2023-09-22	AL5963375669802935905250817	международная	8914288.7879	946.9841	отправлена	BKCHCNBJ
102	RU4383803436557380827011382643653	398	2023-05-03	PT4071302888553700664913113	международная	2464927.7071	340.7902	доставлена	CASPKZKAXXX
103	RU9783803436566819882292917709885	978	2023-04-11	BY8334909207291969965241896	международная	127450.6084	291.3998	отменена	SOGEFRPP
104	RU8383803436557193853878723819444	840	2023-07-22	RU9883803436596118671708861810646	внутренняя	7996859.4596	648.5421	отменена	\N
105	RU2283803436521727957364583057084	978	2023-09-07	IN7465943825497687940577654	международная	9931991.7740	915.6553	отправлена	SOGEFRPP
106	RU9683803436524115739172828059349	356	2023-01-15	RU4383803436594641659799774635872	внутренняя	6284190.7726	947.8592	отменена	\N
107	RU2183803436586747579379810386651	643	2023-05-21	AL4060593394376594372854611	внутренняя	375415.6729	288.9173	отправлена	\N
108	RU2283803436555228451424548337941	978	2023-01-18	RU4083803436523112590591409946049	внутренняя	1883441.6844	604.6848	доставлена	\N
109	RU4083803436561171626967381260937	156	2023-11-20	DE9642606682675930507558643	международная	2063679.3766	319.0180	отменена	BKCHCNBJ
110	RU7783803436529059332090835348557	398	2023-06-02	RU8790890463137243268738399	внутренняя	6156076.3498	624.6672	отменена	\N
111	RU6783803436582018660242960957244	840	2023-04-14	AL6373145834179696282945149	международная	6867005.5403	540.4453	доставлена	IRVTUS3NXXX
112	RU4383803436557380827011382643653	156	2023-11-03	RU8183803436513368239655842198331	внутренняя	8231068.0325	435.8412	отменена	\N
113	RU2983803436597155052344917689453	156	2023-03-04	BY8181011722726681029426906	международная	2737766.8186	454.4233	доставлена	BKCHCNBJ
114	RU8483803436528403655778834568144	156	2023-12-27	IN8639751429431008391541477	международная	8867598.0101	716.8041	отменена	BKCHCNBJ
115	RU6583803436547384322379422553840	978	2023-05-01	RU9683803436511276549947859990709	внутренняя	8256008.9618	344.8590	отменена	\N
116	RU7283803436583841985241060182740	156	2023-01-30	RU5183803436523181844916432548416	внутренняя	1659900.7599	728.4751	отправлена	\N
117	RU1983803436592911874717339237016	398	2023-08-16	RU1983803436510712914540451632365	внутренняя	7776678.4015	141.0339	отправлена	\N
118	RU4183803436598422593606583773593	356	2023-11-08	RU6183803436555838927651384339574	внутренняя	3702366.8729	299.9187	отменена	\N
119	RU1083803436563162471160560931522	356	2023-06-26	PT3054174861634305767353263	международная	3602888.2940	535.0555	доставлена	SBININBBXXX
120	RU4483803436534969190676238532628	156	2023-12-15	RU4983803436534576819154749347962	внутренняя	3173573.5583	757.7942	доставлена	\N
121	RU1583803436597114679330016317094	840	2023-09-01	RU3983803436562540544761068231244	внутренняя	4061375.0137	329.8340	отменена	\N
122	RU1883803436537462946976236392804	398	2023-02-11	RU3383803436527231938190662146888	внутренняя	291009.9407	318.2704	отменена	\N
123	RU8283803436517214496879594083501	156	2023-02-12	RU4083803436537218400436107027314	внутренняя	7518208.2260	364.8813	отменена	\N
124	RU8783803436544746989208687599320	840	2023-05-03	RU1883803436562141776165180370424	внутренняя	7804752.5227	116.1162	отправлена	\N
125	RU1583803436592948110594062864167	156	2023-10-18	RU8283803436593409912626065485368	внутренняя	1061113.1361	546.3437	доставлена	\N
126	RU4983803436534576819154749347962	978	2023-12-18	RU9283803436529032721317031749293	внутренняя	4608905.4394	731.4462	доставлена	\N
127	RU9083803436513364676730542126445	978	2023-11-16	RU6983803436551969328605594993446	внутренняя	2447249.9334	759.9102	доставлена	\N
128	RU9983803436588442958405952112241	840	2023-05-11	RU1883803436562141776165180370424	внутренняя	4242732.7501	59.8394	доставлена	\N
129	RU7583803436597888322431139189153	356	2023-11-16	KZ5288932079419002662051069	международная	8091311.5549	235.9223	отменена	SBININBBXXX
130	RU3783803436559423561964096195262	643	2023-06-06	RU4583803436544769415444430855700	внутренняя	6418223.6410	294.8819	отправлена	\N
131	RU8583803436529401978461350257287	840	2023-09-18	RU2883803436538134433783624054557	внутренняя	3750457.7663	614.3404	отменена	\N
132	RU9483803436522220035875117822565	398	2023-02-06	RU5183803436523181844916432548416	внутренняя	9333143.7954	744.1781	отправлена	\N
133	RU1983803436568263609873115174417	643	2023-03-26	RU7083803436575256167282941443393	внутренняя	2891989.2053	145.2171	доставлена	\N
134	RU4383803436535637847836978327691	978	2023-11-07	RU5883803436512174556620785995683	внутренняя	84410.7319	204.8708	отменена	\N
135	RU2083803436573246597416370413406	356	2023-07-02	RU2883803436538134433783624054557	внутренняя	3639738.8739	871.5394	доставлена	\N
136	RU3383803436530100232705488681423	978	2023-01-02	RU6183803436555838927651384339574	внутренняя	3526217.8247	62.4895	отправлена	\N
137	RU1183803436513944372774322746458	978	2023-08-16	DE1465273788168707741134015	международная	8114216.5178	304.6309	доставлена	SOGEFRPP
138	RU3683803436526413764026311806751	398	2023-10-05	RU7783803436529059332090835348557	внутренняя	4267733.9854	582.0136	отменена	\N
139	RU5983803436533405804846460378377	356	2023-01-14	ES5092359308735889408433544	международная	5832945.0047	454.1074	отправлена	SBININBBXXX
140	RU5683803436539120556194350818141	156	2023-08-07	BY4670698845139924493874280	международная	2903826.0321	713.4336	отменена	BKCHCNBJ
141	RU5983803436561671607015303339932	156	2023-01-01	AD9728856449685551378079227	международная	9421208.6516	267.1933	отменена	BKCHCNBJ
142	RU1683803436536773128968824249362	156	2023-12-23	ES1517035472483522313794957	международная	5279984.5825	133.2973	отправлена	BKCHCNBJ
143	RU9883803436580908913943520973504	156	2023-12-05	AL2639186751357709285035077	международная	2978510.9951	571.1226	отменена	BKCHCNBJ
144	RU2883803436512412400998624231254	398	2023-02-03	DE7788352916333914952679250	международная	475797.4796	860.4801	отменена	CASPKZKAXXX
145	RU6083803436583599210196850890015	840	2023-02-21	IN1740321561929355549320035	международная	667062.2895	45.9682	отменена	CHASUS33
146	RU3783803436585191546282680625888	643	2023-04-19	RU3183803436556325220643083039724	внутренняя	5115283.7023	722.2675	отправлена	\N
147	RU6683803436563942598707878107815	643	2023-04-18	RU1083803436588429797000364388942	внутренняя	3192819.9680	723.2526	отменена	\N
148	RU4083803436530357399673623809331	398	2023-02-18	PT3261337924159548519589395	международная	1190107.6110	600.9954	доставлена	CASPKZKAXXX
149	RU2483803436559904294875702128517	643	2023-11-03	RU9083803436513364676730542126445	внутренняя	7032551.1174	485.5769	отправлена	\N
150	RU1283803436513390712190126736747	156	2023-03-02	IN6475629795856717651450407	международная	3834731.1885	575.3738	отправлена	BKCHCNBJ
151	RU6283803436541447099313442593938	978	2023-10-25	AD5892224322251379990471610	международная	5621987.9709	874.8265	отменена	RZBAATWW
152	RU6583803436592149423686806465410	398	2023-02-13	RU5438260805049173276300310	внутренняя	3931827.3851	16.5122	отменена	\N
153	RU3783803436585191546282680625888	840	2023-03-15	PT9659350766017641309749831	международная	5678618.9678	229.2410	доставлена	IRVTUS3NXXX
154	RU5683803436522754650880470438385	398	2023-03-05	IN6696058526812735926504898	международная	6019708.6801	430.3096	доставлена	CASPKZKAXXX
155	RU6383803436541953279771793851240	840	2023-05-12	RU9883803436597607312145326011401	внутренняя	3980463.8559	382.9731	отправлена	\N
156	RU3783803436562091905141244310726	978	2023-04-26	RU9345040854509310858406535	внутренняя	7189647.2762	127.5135	доставлена	\N
157	RU7183803436513501317784267991188	156	2023-01-20	RU9583803436589245078784775619456	внутренняя	9888414.9021	78.3949	отправлена	\N
158	RU1683803436549082108439124677076	356	2023-04-07	RU4483803436531766422461159975910	внутренняя	6943935.7098	445.8518	отправлена	\N
159	RU3483803436534657689181631833463	398	2023-11-22	ES4230035735433950743955326	международная	1003676.8262	740.2880	отменена	CASPKZKAXXX
160	RU8183803436513368239655842198331	356	2023-11-12	BY5745275955074665382922444	международная	3261135.8896	388.6635	отправлена	SBININBBXXX
161	RU6883803436524866655852609791727	978	2023-04-06	RU1983803436510686315036595318873	внутренняя	9978283.8706	516.6922	доставлена	\N
162	RU1283803436521770311179326367954	356	2022-12-28	ES6999049084966744046625226	международная	9248873.8674	575.6404	доставлена	SBININBBXXX
163	RU5583803436581992686445972740236	643	2023-04-09	IN2097455047985640820297724	внутренняя	8466233.9874	864.7498	доставлена	\N
164	RU1983803436549890414007715363567	840	2023-12-03	RU9483803436570307762028951954874	внутренняя	2685373.7905	325.6231	доставлена	\N
165	RU7483803436591068390387769478580	840	2023-02-24	AD9350364079939937331156729	международная	4316571.7778	670.4044	отправлена	IRVTUS3NXXX
166	RU5183803436585063037953141711870	978	2023-12-04	RU6983803436580831999013679742086	внутренняя	7384493.2116	58.1203	доставлена	\N
167	RU2283803436527235231809863175226	643	2023-05-21	VN8042336468314007692659296	внутренняя	5201206.7430	498.0702	отменена	\N
168	RU7783803436585076163513647706071	643	2023-08-22	AD5632944205149304749772533	внутренняя	8608643.3942	926.0714	отменена	\N
169	RU5883803436537252361294139722938	978	2023-06-14	RU5983803436513359014201161572816	внутренняя	8872358.0614	981.8839	доставлена	\N
170	RU6583803436588261503476787515721	978	2023-08-07	KZ1548859673366095790593204	международная	4262646.5857	686.6462	отправлена	DEUTDEFFXXX
171	RU3583803436580986023375789999847	398	2023-10-05	RU2283803436577856579987093576845	внутренняя	312485.2631	917.4751	доставлена	\N
172	RU8683803436571821829992754282142	840	2023-04-10	RU6483803436599929208547720213297	внутренняя	2596594.1241	781.0836	доставлена	\N
173	RU8583803436590890149305918634043	156	2023-06-02	RU3183803436538368625987340316428	внутренняя	2071781.9233	79.0940	доставлена	\N
174	RU1183803436536239647096212180861	643	2023-05-30	RU1983803436592911874717339237016	внутренняя	4446802.2957	613.0838	отправлена	\N
175	RU6683803436546559918630563560759	840	2023-04-01	RU3183803436564747839620735247465	внутренняя	5157423.2979	593.2301	отменена	\N
176	RU7083803436565850801859363291526	356	2023-03-17	RU8483803436583598027317615125571	внутренняя	1689225.1098	413.9428	отправлена	\N
177	RU3883803436554504516286459147223	978	2023-10-15	RU8783803436522200736153030297680	внутренняя	1933211.5489	246.3507	отменена	\N
178	RU6583803436526807323529165700056	643	2023-06-11	RU2283803436551819000625747494652	внутренняя	6956200.1749	756.8649	отменена	\N
179	RU9583803436557636243711161422858	840	2023-03-11	RU2683803436575198696607383546599	внутренняя	3976817.3617	706.3014	доставлена	\N
180	RU6183803436555838927651384339574	643	2023-04-09	RU7783803436585076163513647706071	внутренняя	8099473.3483	713.9006	доставлена	\N
181	RU4183803436575456526806163894045	840	2023-01-20	RU8441598683940868929677590	внутренняя	1929360.0305	813.4104	доставлена	\N
182	RU9383803436546841675173507423577	356	2023-10-15	RU8883803436542351475891948314875	внутренняя	8217089.8103	613.6764	доставлена	\N
183	RU2083803436573246597416370413406	840	2023-07-19	AL2092057249242979059018122	международная	466063.3507	413.8538	отменена	IRVTUS3NXXX
184	RU2983803436597155052344917689453	156	2023-01-28	VN6367886134950519531133952	международная	4148277.4556	461.5045	отменена	BKCHCNBJ
185	RU7383803436534050516387288663509	356	2023-06-01	RU7383803436569356631218275502161	внутренняя	3475903.9209	286.3375	отменена	\N
186	RU7283803436565335970635584506660	840	2023-12-15	AD9777812884807704549240816	международная	2903558.0920	284.4552	отправлена	IRVTUS3NXXX
187	RU8783803436562772820294479967682	156	2023-04-04	AD8443723747196017010776529	международная	1616341.8953	854.7375	отменена	BKCHCNBJ
188	RU9683803436559214297350823715344	840	2023-09-09	RU5583803436533254773648721597711	внутренняя	7635056.6894	495.2189	отменена	\N
189	RU2983803436530272226005609138408	156	2023-12-13	RU1983803436574962372646294489745	внутренняя	5875664.9759	529.0474	доставлена	\N
190	RU6083803436569163727288631654599	156	2023-02-11	RU3529188006857676742103099	внутренняя	105182.0701	655.8274	отправлена	\N
191	RU7483803436595027677837710467368	840	2023-03-09	BY9799345729123909976507802	международная	7160690.6973	839.1893	отменена	IRVTUS3NXXX
192	RU2083803436518033160343253894367	840	2023-07-31	RU6483803436575827628326698282321	внутренняя	7402466.5884	616.0728	отправлена	\N
193	RU8483803436517523304653033637180	978	2023-01-15	RU1183803436512373318427988836252	внутренняя	1313516.4622	624.3627	отправлена	\N
194	RU1983803436592911874717339237016	398	2023-06-18	AL5560597889270045047555504	международная	4896977.5066	623.5117	доставлена	CASPKZKAXXX
195	RU4883803436563163057705977553405	356	2023-06-09	AL8210558089875865926631353	международная	2903817.9051	703.7348	отменена	SBININBBXXX
196	RU9183803436512467785925904841435	356	2023-06-03	KZ9055655971596926261151873	международная	660780.8150	140.6243	отменена	SBININBBXXX
197	RU3683803436533022850683714599602	978	2023-10-21	RU4283803436544879224116585983050	внутренняя	9075389.5315	193.1811	отправлена	\N
198	RU4283803436532641085536208083176	398	2023-02-13	IN6535147314973718724962925	международная	1409971.0971	687.0694	отменена	CASPKZKAXXX
199	RU7583803436545511345420608427589	398	2023-02-13	AD5741084777070956891410005	международная	2598873.8428	825.6058	отправлена	CASPKZKAXXX
200	RU4583803436544769415444430855700	156	2023-01-01	RU6583803436599318340096840026283	внутренняя	5772921.6488	84.9564	доставлена	\N
201	RU8483803436514025076841381077297	643	2023-11-18	ES4917632302147850703007019	внутренняя	6707321.2315	183.6925	доставлена	\N
202	RU9583803436547610609904791788853	356	2023-06-22	RU2083803436536025786076127901648	внутренняя	5965264.8145	62.2162	доставлена	\N
203	RU6983803436580831999013679742086	978	2023-02-08	RU2983803436588011593439328399453	внутренняя	6384987.2698	685.7300	отменена	\N
204	RU5983803436558435772787343054218	840	2023-08-17	RU1183803436547102061688733775669	внутренняя	114224.5457	69.1237	доставлена	\N
205	RU3583803436543438797337964557116	643	2023-02-24	PT7511085677870870897909762	внутренняя	8980068.9563	821.9389	отправлена	\N
206	RU8283803436517214496879594083501	156	2023-06-29	PT6871463999843625775056034	международная	3487275.3463	486.7817	отменена	BKCHCNBJ
207	RU4683803436584135461455281070651	840	2023-02-12	AD7554476096009771534352967	международная	2496646.6104	670.2734	доставлена	IRVTUS3NXXX
208	RU6483803436599929208547720213297	840	2023-08-12	RU3383803436530100232705488681423	внутренняя	45469.3978	837.7001	доставлена	\N
209	RU1383803436523658112524214881297	356	2023-07-13	RU9583803436562562119396535016715	внутренняя	5239393.6295	476.9195	доставлена	\N
210	RU2583803436525056668985275863842	643	2023-06-06	ES3199256394649344433114795	внутренняя	9642455.0697	311.4335	отменена	\N
211	RU6983803436551969328605594993446	156	2023-01-23	AL5499355153794782357265607	международная	9517870.5465	123.4296	отправлена	BKCHCNBJ
212	RU2983803436530272226005609138408	840	2023-08-11	RU2783803436512588965300606208370	внутренняя	5601434.0103	138.7398	доставлена	\N
213	RU1183803436569972795023903837949	398	2023-01-05	BY5824150377013739818909902	международная	5696451.2826	288.4098	отменена	CASPKZKAXXX
214	RU5083803436521160540176223483455	840	2023-09-09	KZ4325722084753209308329128	международная	821148.7855	199.4976	отправлена	IRVTUS3NXXX
215	RU6283803436541447099313442593938	398	2023-02-23	VN2677483464634963726695351	международная	5355441.2721	958.8509	отменена	CASPKZKAXXX
216	RU5183803436585063037953141711870	398	2023-03-25	RU2983803436530272226005609138408	внутренняя	4112302.1305	828.7036	отменена	\N
217	RU8183803436584325139466333599286	398	2023-01-10	RU5083803436556786327042016836549	внутренняя	7924865.8887	375.3535	доставлена	\N
218	RU1983803436568263609873115174417	398	2023-12-23	VN1195864129675051017398693	международная	3097266.4263	386.4231	отменена	CASPKZKAXXX
219	RU5083803436563140090168469536649	643	2023-04-23	RU8583803436580493050529274956761	внутренняя	9844408.7455	839.8676	отменена	\N
220	RU4183803436544525596730636267692	398	2023-04-25	BY8524659912825657328796252	международная	4756091.0449	747.5280	отправлена	CASPKZKAXXX
221	RU8183803436555934243334630961587	398	2023-01-15	RU7093424602733469748289848	внутренняя	153830.3037	725.9405	отменена	\N
222	RU5883803436551017474710608700284	156	2023-03-21	RU7783803436556242953974983768067	внутренняя	9134351.2645	804.5718	отправлена	\N
223	RU3083803436556733352794187735054	356	2023-11-06	AD9271678712839247186771649	международная	8289225.9916	895.9966	отправлена	SBININBBXXX
224	RU7183803436596080848426828093950	156	2023-03-21	VN6363675842881821172702595	международная	9839629.0023	470.6530	отправлена	BKCHCNBJ
225	RU7183803436584925378313266803439	156	2023-10-17	AD7438830574798177225899687	международная	3598191.5898	306.4487	отправлена	BKCHCNBJ
226	RU2283803436521727957364583057084	356	2023-07-20	RU5883803436549838724600410631189	внутренняя	8923679.9890	133.6972	доставлена	\N
227	RU4083803436530357399673623809331	356	2023-06-25	BY5384496923011109434874917	международная	5970503.7445	932.3984	доставлена	SBININBBXXX
228	RU8683803436511417676206561932357	398	2023-01-22	VN2718624027587655131728369	международная	7373677.3027	379.4401	доставлена	CASPKZKAXXX
229	RU7083803436565850801859363291526	978	2023-05-29	RU1583803436575905915250327615306	внутренняя	9878660.8218	133.7400	отменена	\N
230	RU8383803436583878629872361871714	840	2023-09-19	RU1983803436549890414007715363567	внутренняя	4446826.6470	357.5311	отменена	\N
231	RU2083803436536025786076127901648	356	2023-06-09	RU4283803436583191860084907222827	внутренняя	213577.4778	269.1763	отправлена	\N
232	RU8883803436542351475891948314875	643	2023-10-05	AD1570092584326854003041888	внутренняя	7660040.3781	834.0384	отменена	\N
233	RU3583803436543438797337964557116	398	2023-02-07	AD9080320275785579463357770	международная	6820660.6099	753.1218	отправлена	CASPKZKAXXX
234	RU4383803436535637847836978327691	978	2023-05-03	RU4183803436544525596730636267692	внутренняя	5969429.4633	868.0181	доставлена	\N
235	RU8183803436584325139466333599286	643	2023-08-21	BY8728783102870037517874576	внутренняя	3214124.8768	240.1191	отменена	\N
236	RU8583803436529401978461350257287	156	2023-02-01	RU2583803436525056668985275863842	внутренняя	1379063.5760	501.1642	отправлена	\N
237	RU3883803436554504516286459147223	978	2023-08-12	RU9383803436515318038329930627155	внутренняя	8117322.2098	560.0803	отправлена	\N
238	RU7183803436578006903833632767386	978	2023-01-24	AL5876479812880522027480072	международная	2883077.5906	724.2109	отменена	DEUTDEFFXXX
239	RU9583803436574471411467135718624	398	2023-02-21	RU6683803436563942598707878107815	внутренняя	9939617.0511	859.2136	отправлена	\N
240	RU3683803436526413764026311806751	356	2023-02-16	RU6583803436592149423686806465410	внутренняя	9151364.1341	387.1801	отправлена	\N
241	RU5683803436539120556194350818141	156	2023-03-07	RU2683803436575198696607383546599	внутренняя	5443162.9849	27.8148	отменена	\N
242	RU3983803436562540544761068231244	356	2023-07-20	PT7480494948198595822671768	международная	6065505.5057	807.6903	доставлена	SBININBBXXX
243	RU1583803436522600904788279282430	978	2023-07-30	DE8175477369911870501069357	международная	2351097.4373	345.1806	отменена	DEUTDEFFXXX
244	RU6583803436592149423686806465410	156	2023-03-14	RU2483803436580851808318436691458	внутренняя	8271121.5290	959.0063	отправлена	\N
245	RU4583803436576777630615652907536	978	2023-03-18	RU9383803436575688788160155647011	внутренняя	6316234.8565	638.2410	отменена	\N
246	RU7183803436535160662680026565691	356	2023-03-15	AD7679980455255440198613311	международная	8795726.1786	53.8843	отменена	SBININBBXXX
247	RU6983803436557684576294868357987	840	2023-09-09	KZ8186451883615842051914801	международная	8882516.0736	178.8959	доставлена	CHASUS33
248	RU4483803436593534887929979895004	840	2023-04-24	RU9834881473297024375530761	внутренняя	5480570.6913	153.6389	доставлена	\N
249	RU4383803436594641659799774635872	356	2023-03-23	PT1925661115780148253482428	международная	7941297.8344	17.1782	отменена	SBININBBXXX
250	RU8583803436586707949034749896750	978	2023-08-04	AL8062806407889128572533351	международная	5053152.2336	338.1003	доставлена	DEUTDEFFXXX
251	RU2583803436573489146610412814439	156	2023-10-11	AL6342981882134753601672129	международная	3429601.2649	144.8124	доставлена	BKCHCNBJ
252	RU6183803436555838927651384339574	156	2023-05-01	DE6245578061701682985496669	международная	934660.5872	864.7958	отправлена	BKCHCNBJ
253	RU1383803436565139777755041333233	978	2023-06-16	PT9470722748290080268414385	международная	9966094.2690	212.3916	доставлена	SOGEFRPP
254	RU8783803436519169154241731281817	356	2023-07-08	RU8383803436554622159366581134752	внутренняя	1000129.1577	423.8114	отправлена	\N
255	RU5583803436581992686445972740236	643	2023-01-13	BY8798819031465373977748991	внутренняя	6537113.1818	202.5804	доставлена	\N
256	RU2983803436588011593439328399453	978	2023-01-21	RU4283803436515276086545867508581	внутренняя	2315855.6819	578.6794	доставлена	\N
257	RU9483803436521022327823815694666	398	2023-11-20	RU1183803436536239647096212180861	внутренняя	3124688.6753	207.4938	отменена	\N
258	RU7483803436591068390387769478580	643	2023-01-23	AD9628796775235799563151530	внутренняя	7846673.5497	128.5663	отправлена	\N
259	RU4083803436519648806531502670697	643	2023-04-06	IN1244883553019811403483632	внутренняя	2427497.0008	708.8918	отправлена	\N
260	RU2183803436551906716086082339754	398	2023-03-24	RU6583803436565551879254347008316	внутренняя	3255634.3704	680.7870	отменена	\N
261	RU7283803436583841985241060182740	356	2023-01-10	RU7783803436578403910419087666263	внутренняя	5870236.7469	945.8126	отправлена	\N
262	RU2683803436566742853200336170327	840	2023-03-27	PT3094629712284782511628305	международная	4212937.7429	379.5908	доставлена	CHASUS33
263	RU6183803436571932790348770462135	643	2023-11-20	RU7583803436593274051968042799324	внутренняя	113304.0991	534.4308	отменена	\N
264	RU4283803436512174946847064448344	840	2023-11-14	RU8183803436584325139466333599286	внутренняя	1494491.9218	370.3867	доставлена	\N
265	RU5283803436570838144716210841495	840	2023-03-25	PT9812739968106916630422054	международная	163563.4527	606.9124	доставлена	CHASUS33
266	RU3383803436527231938190662146888	398	2023-02-19	RU6983803436548066705729944547736	внутренняя	2724391.0826	745.6398	доставлена	\N
267	RU5283803436570838144716210841495	840	2023-12-16	RU9683803436524115739172828059349	внутренняя	6971799.1548	148.5054	отменена	\N
268	RU3083803436572725983728902081378	643	2023-03-29	VN2239089285031011867980836	внутренняя	1228037.5357	806.9232	отправлена	\N
269	RU9283803436581282514241262822584	840	2023-12-12	IN7128807488822259207011825	международная	9946348.8212	693.9533	доставлена	IRVTUS3NXXX
270	RU9683803436524115739172828059349	978	2023-07-29	IN6525917178558221533027436	международная	3869446.9407	605.5284	отправлена	SOGEFRPP
271	RU2883803436581906276084692901201	398	2023-03-13	KZ6575800971651141648031269	международная	5403182.3244	657.4411	отменена	CASPKZKAXXX
272	RU6183803436571932790348770462135	840	2023-09-13	RU9883803436597607312145326011401	внутренняя	6769963.9765	89.6895	отменена	\N
273	RU4283803436532641085536208083176	398	2023-05-25	RU3924004929620407256479879	внутренняя	1158300.1896	927.4045	отправлена	\N
274	RU1583803436578714315409224923820	356	2023-04-19	RU5283803436570838144716210841495	внутренняя	2410433.2644	578.3447	доставлена	\N
275	RU3583803436543438797337964557116	840	2023-04-19	PT2566481879191072559089514	международная	4326619.5591	30.8187	доставлена	CHASUS33
276	RU2883803436564862346362051659673	840	2023-10-20	DE8150862744518035619203789	международная	4446444.1715	698.1126	отправлена	CHASUS33
277	RU8583803436529401978461350257287	356	2023-05-13	RU9283803436564588409350021574669	внутренняя	3834235.3357	111.9398	доставлена	\N
278	RU1883803436562141776165180370424	978	2023-02-04	RU3583803436597484588589933917343	внутренняя	8772422.1845	391.6390	отменена	\N
279	RU5683803436573106663960342062340	398	2023-05-22	BY2495549111010308962077375	международная	1798369.7018	511.9341	доставлена	CASPKZKAXXX
280	RU7383803436546512723534280739575	643	2023-07-17	AD8180610514623352240099361	внутренняя	4903439.3816	15.4092	доставлена	\N
281	RU1983803436549890414007715363567	156	2023-09-19	RU9883803436597607312145326011401	внутренняя	9726648.2718	273.5685	отправлена	\N
282	RU5183803436585063037953141711870	643	2023-04-16	KZ6874385515461722910635047	внутренняя	6872307.4423	734.1314	доставлена	\N
283	RU4683803436521950147450839996450	643	2023-08-23	RU7083803436595909521339223196614	внутренняя	6356312.1891	149.1010	отменена	\N
284	RU8483803436576032684947735830335	398	2023-03-11	VN5840480009209576471309561	международная	9351141.4496	573.4191	доставлена	CASPKZKAXXX
285	RU8983803436543970357311304848339	398	2023-01-27	RU2583803436525056668985275863842	внутренняя	1407457.2155	16.0205	доставлена	\N
286	RU2783803436529440294678710752920	840	2023-08-18	RU4683803436584135461455281070651	внутренняя	5599902.8779	0.0000	отменена	\N
287	RU2983803436510489846489627969282	643	2023-07-06	RU9383803436546841675173507423577	внутренняя	5790600.1222	976.5238	доставлена	\N
288	RU9083803436527710172880684864084	643	2023-02-13	RU5583803436525031727011657164177	внутренняя	1501067.5673	343.7790	доставлена	\N
289	RU1083803436563162471160560931522	840	2023-01-12	RU5983803436513359014201161572816	внутренняя	3699555.7509	531.3122	отправлена	\N
290	RU4683803436584135461455281070651	643	2023-01-15	RU9283803436529032721317031749293	внутренняя	6582944.6250	711.2363	отправлена	\N
291	RU3183803436522808312515599877028	643	2023-10-31	RU7383803436567535429961689788567	внутренняя	5167952.9426	843.5655	доставлена	\N
292	RU3883803436559428008275215914286	356	2023-05-26	AL8678296755380233754832338	международная	2423094.5372	291.8636	доставлена	SBININBBXXX
293	RU4383803436594641659799774635872	643	2023-08-31	RU7683803436578953117174553181317	внутренняя	2153548.6960	598.4731	доставлена	\N
294	RU5183803436599553165549416662045	156	2022-12-30	RU5783803436598085342824416355658	внутренняя	5076983.2850	909.4734	отменена	\N
295	RU5683803436575772290627280121203	356	2023-08-16	AD7818525477018194214327418	международная	529195.0335	233.2050	доставлена	SBININBBXXX
296	RU6683803436563942598707878107815	356	2023-05-03	DE5698222458123198621915986	международная	8556601.8025	448.1146	доставлена	SBININBBXXX
297	RU5183803436550941857646482749776	978	2023-01-02	KZ1471088524202366881322791	международная	6386004.9291	434.0448	доставлена	RZBAATWW
298	RU1983803436592911874717339237016	840	2023-08-10	RU5183803436573013692902081587761	внутренняя	826781.6611	302.0978	доставлена	\N
299	RU9183803436512467785925904841435	643	2023-09-24	RU5183803436573013692902081587761	внутренняя	8882110.7737	192.4164	доставлена	\N
300	RU2283803436555228451424548337941	356	2023-01-30	KZ3079715674503334246292810	международная	3923815.5345	972.0154	доставлена	SBININBBXXX
301	RU9483803436516702191580023603147	156	2023-04-19	RU3793370852292806853501114	внутренняя	9652330.0220	633.7877	отправлена	\N
302	RU9583803436547610609904791788853	643	2023-09-07	RU2983803436588011593439328399453	внутренняя	7033680.3940	89.5573	доставлена	\N
303	RU7083803436575256167282941443393	978	2023-01-09	RU1083803436588429797000364388942	внутренняя	6044208.5394	506.3550	доставлена	\N
304	RU2883803436564862346362051659673	398	2023-11-11	KZ5542976884287332077916352	международная	2835059.3531	0.0000	доставлена	CASPKZKAXXX
305	RU8083803436567877444686336475183	978	2023-01-29	RU6783803436583735354795738130605	внутренняя	7946472.1572	861.9651	отправлена	\N
306	RU3683803436533022850683714599602	643	2023-12-21	RU2961099193640937984473706	внутренняя	4558820.4679	819.9728	отменена	\N
307	RU4183803436555804329090528802664	156	2023-03-30	ES3330303158691790913716386	международная	886556.7991	160.7930	отправлена	BKCHCNBJ
308	RU7583803436593274051968042799324	840	2023-01-20	ES3830158105714490875815459	международная	5976099.8037	861.9657	отменена	IRVTUS3NXXX
309	RU6783803436582018660242960957244	978	2023-12-27	RU9583803436557636243711161422858	внутренняя	1139444.0762	126.9262	отменена	\N
310	RU9083803436513364676730542126445	978	2022-12-28	RU9983803436515137760640096699879	внутренняя	2458764.2886	320.3950	отменена	\N
311	RU1983803436574962372646294489745	978	2023-01-17	AL8232173819758596868827115	международная	1299300.7964	301.1605	отменена	SOGEFRPP
312	RU2383803436569895097903578030814	156	2023-12-17	RU2683803436556115738690945420927	внутренняя	5833828.1415	896.5574	доставлена	\N
313	RU6183803436571932790348770462135	356	2023-05-23	ES6679848866865830235341314	международная	3891421.8150	602.0521	доставлена	SBININBBXXX
314	RU6483803436575827628326698282321	978	2023-02-20	BY1939823343179484730671435	международная	8377554.3805	715.8826	доставлена	RZBAATWW
315	RU4983803436522833268295991391237	643	2023-06-03	BY7843617538495430823309040	внутренняя	1332489.1781	387.5907	доставлена	\N
316	RU3983803436554516084539411139147	978	2023-03-16	RU3383803436548623436381587682007	внутренняя	4283490.3328	932.8487	доставлена	\N
317	RU6983803436596433824452063468541	978	2023-04-05	RU5883803436537252361294139722938	внутренняя	6777426.5354	306.7032	доставлена	\N
318	RU6983803436542868245387240901621	356	2023-05-06	VN6422936898489523905472818	международная	1991546.6068	27.1836	отправлена	SBININBBXXX
319	RU8983803436550652073660555482382	643	2023-10-30	IN7490433067170602838043496	внутренняя	5789114.5353	301.5326	отправлена	\N
320	RU4083803436519648806531502670697	356	2023-10-04	AL8955755731597243972734536	международная	8423566.0062	705.4298	отменена	SBININBBXXX
321	RU4583803436571583967013936520660	356	2023-03-03	IN3559428964541285310844356	международная	6706631.5719	248.2608	отправлена	SBININBBXXX
322	RU4283803436532641085536208083176	643	2023-11-25	RU2983803436588011593439328399453	внутренняя	2190202.2410	875.2569	отправлена	\N
323	RU3583803436543438797337964557116	840	2023-03-11	AD3766299266004963686986854	международная	7609065.5306	328.0498	отменена	CHASUS33
324	RU7483803436591068390387769478580	978	2023-10-17	RU9747584836800290395888824	внутренняя	9712493.3196	571.1361	отменена	\N
325	RU8283803436536082355231514909614	643	2023-04-27	AL7487408759040864805116179	внутренняя	6003245.4354	526.0413	отменена	\N
326	RU4483803436537144245226352938256	398	2023-08-12	VN5236399737906459656220170	международная	9368462.2106	55.9287	отправлена	CASPKZKAXXX
327	RU9383803436515318038329930627155	156	2023-09-01	DE5539566184095272875723569	международная	7207554.6695	886.5690	отправлена	BKCHCNBJ
328	RU1983803436537997284898110055528	398	2023-03-11	RU5183803436531460410872953149827	внутренняя	5920883.9833	562.6774	отменена	\N
329	RU4583803436588661449801193641363	978	2023-08-19	PT6381941131833551593222930	международная	7465384.2930	941.0145	отменена	SOGEFRPP
330	RU8983803436551003507571679577910	398	2023-11-21	RU2649218192087432687084310	внутренняя	2086181.8990	0.0000	доставлена	\N
331	RU9483803436588743613330942629999	643	2023-11-22	RU4383803436583134155448910498762	внутренняя	6403531.7625	540.1757	отправлена	\N
332	RU6083803436582119843499506879640	840	2023-05-17	VN6827964309725027788410782	международная	303448.4863	375.6305	отправлена	IRVTUS3NXXX
333	RU5983803436565674700991182664479	643	2023-11-13	RU1883803436562141776165180370424	внутренняя	3443519.6582	590.2206	отменена	\N
334	RU1383803436598073263367823117200	643	2023-03-24	KZ6292216098225730042454100	внутренняя	3877358.4991	278.6345	доставлена	\N
335	RU7183803436596080848426828093950	978	2023-01-14	AL3680305771715027616842668	международная	6303716.8926	677.1420	отменена	SOGEFRPP
336	RU3683803436526413764026311806751	643	2023-07-03	RU6683803436575472065287991925682	внутренняя	6222924.2520	812.5728	отменена	\N
337	RU3683803436521305656177527242839	840	2023-11-03	VN7414894632351596537481159	международная	5217767.8455	169.9755	доставлена	IRVTUS3NXXX
338	RU9583803436515959194321808018014	398	2023-03-15	IN9624711642199497643531341	международная	8248634.1050	561.0075	отменена	CASPKZKAXXX
339	RU2583803436586349630493889324094	643	2023-05-12	RU3383803436533625475503259998648	внутренняя	9843823.4912	299.2342	доставлена	\N
340	RU9883803436510697875492928159959	356	2023-07-17	AL1710866882396614439478713	международная	9322337.5415	886.2702	доставлена	SBININBBXXX
341	RU5183803436588801456118987264753	643	2023-09-13	RU2083803436573246597416370413406	внутренняя	3947908.4499	338.1849	отменена	\N
342	RU8783803436562772820294479967682	398	2023-12-13	IN9028688218233255035089766	международная	8551403.1310	879.1330	отменена	CASPKZKAXXX
343	RU4083803436523112590591409946049	840	2023-12-16	IN4387683587369057159213869	международная	8909217.5704	947.1134	отменена	CHASUS33
344	RU9683803436597203099828784600586	840	2023-02-01	RU8324751215001085061540484	внутренняя	739896.8764	162.2934	доставлена	\N
345	RU2483803436550335144467075253432	398	2023-06-09	IN2750934665137366905935323	международная	9073872.1568	160.3764	доставлена	CASPKZKAXXX
346	RU6383803436599902939219818792376	356	2023-11-07	RU6483803436531317735484528392559	внутренняя	7409352.1843	303.7443	доставлена	\N
347	RU8483803436562780872181379760829	840	2023-05-15	RU4883803436510661666911089208306	внутренняя	1162865.8433	694.1456	отменена	\N
348	RU2783803436580745382811010865973	156	2023-04-24	PT8923275539511683749339083	международная	5373730.8671	41.2432	отправлена	BKCHCNBJ
349	RU6583803436547384322379422553840	398	2023-06-17	RU6183803436571932790348770462135	внутренняя	43727.3952	181.4191	отправлена	\N
350	RU1583803436597114679330016317094	643	2023-07-23	RU9583803436547610609904791788853	внутренняя	6828816.5325	542.5913	доставлена	\N
351	RU9383803436587347167184231490115	978	2023-12-04	RU1083803436516100547774990634896	внутренняя	6785518.0966	367.9806	отправлена	\N
352	RU8583803436593152008036708778596	156	2023-02-10	AD8569835364619676032484129	международная	3428334.2144	480.2804	доставлена	BKCHCNBJ
353	RU5183803436588801456118987264753	398	2023-02-21	AL8429377997116300078203174	международная	9975707.9175	539.2318	доставлена	CASPKZKAXXX
354	RU2083803436518033160343253894367	156	2023-08-16	RU8183803436546948351691601253240	внутренняя	6834775.1038	580.6395	отменена	\N
355	RU9883803436510697875492928159959	156	2023-06-23	RU1583803436522600904788279282430	внутренняя	6067458.2403	605.5912	отменена	\N
356	RU7483803436581386287039618321410	978	2023-12-10	RU1983803436518034161993382946183	внутренняя	2109820.9461	547.1947	доставлена	\N
357	RU7583803436545511345420608427589	840	2023-02-04	RU6483803436557881046066137062384	внутренняя	5879135.2780	667.4699	отменена	\N
358	RU9283803436581282514241262822584	156	2023-03-21	RU7010991918843296679861900	внутренняя	4678462.5325	182.2579	отправлена	\N
359	RU2183803436538160023828199079683	398	2023-05-06	PT7175326999926198560914090	международная	8050013.2659	861.2567	отправлена	CASPKZKAXXX
360	RU5683803436581377733469772235779	356	2023-08-25	RU5783803436598085342824416355658	внутренняя	4578801.2939	339.3919	отменена	\N
361	RU5983803436513359014201161572816	356	2023-07-28	BY9265220576078502626947986	международная	8738192.8481	329.9054	отправлена	SBININBBXXX
362	RU3783803436585191546282680625888	356	2023-06-05	RU7283803436565335970635584506660	внутренняя	9029777.7328	254.2201	отправлена	\N
363	RU8583803436598717986670697262250	978	2023-09-11	RU3583803436556382446278007957702	внутренняя	5305290.7108	409.7050	отменена	\N
364	RU2283803436577856579987093576845	840	2023-06-11	RU2983803436572636545308279163382	внутренняя	5829191.8280	149.5041	отменена	\N
365	RU2583803436569716293278278112122	978	2023-08-05	DE6563353061972948454277332	международная	6711863.0389	746.4027	отправлена	SOGEFRPP
366	RU6983803436542868245387240901621	156	2023-11-28	RU5530805448807440842596009	внутренняя	1290272.7217	498.1435	отправлена	\N
367	RU2483803436563361420871450061347	840	2023-01-22	RU8483803436562780872181379760829	внутренняя	7584413.8989	0.0000	отменена	\N
368	RU9483803436585469145832242711561	840	2023-12-21	DE2383322515063617186878084	международная	8264270.5890	718.9118	отменена	CHASUS33
369	RU4183803436512683300418013703414	156	2023-02-25	RU8083803436588746463552823930061	внутренняя	8643543.2163	697.4156	доставлена	\N
370	RU8883803436542351475891948314875	398	2023-10-01	ES7676358316998002578786575	международная	7660080.8694	348.3926	отменена	CASPKZKAXXX
371	RU9583803436557636243711161422858	840	2023-08-29	RU6286979935002014086083802	внутренняя	1591178.9969	547.2943	отправлена	\N
372	RU3983803436562540544761068231244	978	2023-10-13	VN8355301742049072862905233	международная	2117282.2231	456.3507	доставлена	SOGEFRPP
373	RU4383803436535637847836978327691	398	2023-01-18	RU2083803436571871160330810400191	внутренняя	9299859.3486	899.9025	отменена	\N
374	RU9283803436529032721317031749293	356	2023-09-20	AL2577207821154312598176227	международная	3348764.3809	856.5667	отправлена	SBININBBXXX
375	RU8483803436546395435496825405512	978	2023-03-18	RU9383803436515318038329930627155	внутренняя	6482140.1257	62.2034	доставлена	\N
376	RU8583803436586707949034749896750	643	2023-07-05	PT5815177863854686418559947	внутренняя	6448594.0135	929.8030	отменена	\N
377	RU3883803436571430516571621799878	840	2023-10-04	RU4083803436530357399673623809331	внутренняя	3451778.1542	947.3475	отправлена	\N
378	RU1983803436574962372646294489745	643	2023-01-10	KZ5287548382053624210885690	внутренняя	4207641.7117	678.7405	отменена	\N
379	RU9883803436510697875492928159959	643	2023-07-01	RU6183803436556503720110500069421	внутренняя	8041098.7485	641.5477	отправлена	\N
380	RU6383803436512605200896614597744	840	2023-02-22	VN6557905189510748678139317	международная	1131429.8802	675.7405	отправлена	CHASUS33
381	RU4583803436546993711061481413708	840	2023-07-21	BY3955412347211642490937174	международная	260797.8554	123.5113	отправлена	CHASUS33
382	RU1583803436575905915250327615306	840	2023-06-20	RU7583803436597888322431139189153	внутренняя	3206039.5029	272.9957	отменена	\N
383	RU5883803436512174556620785995683	840	2023-09-29	AL5564280626004180341799530	международная	7544531.6774	610.9147	отменена	IRVTUS3NXXX
384	RU4483803436593534887929979895004	356	2023-06-19	ES4177879431980335015767626	международная	4634374.4740	109.8743	отправлена	SBININBBXXX
385	RU8983803436518961229187913059129	978	2023-03-26	RU8483803436552375991404578719285	внутренняя	3144045.9575	700.3982	отменена	\N
386	RU1683803436583298094705869717304	978	2023-09-27	RU6983803436542868245387240901621	внутренняя	7858932.7762	754.1288	доставлена	\N
387	RU1383803436537041354890218533954	398	2023-01-28	AD9613989742600651940875887	международная	1673673.2595	885.8533	доставлена	CASPKZKAXXX
388	RU5983803436563752601230784661821	356	2023-08-28	VN3719996235689417973812064	международная	9977885.4160	847.3850	доставлена	SBININBBXXX
389	RU3383803436551883036237842733910	156	2023-07-21	ES6913881672498050479608971	международная	1109705.6119	929.2222	отменена	BKCHCNBJ
390	RU3883803436564256045508064629374	398	2023-07-20	AD4741243141219397487359995	международная	9076738.6414	390.5449	отменена	CASPKZKAXXX
391	RU9883803436559947701649293062119	398	2023-07-27	RU6683803436575472065287991925682	внутренняя	2295145.9236	968.3812	доставлена	\N
392	RU5583803436541779385547740767657	840	2023-04-08	BY9597872323564454701472525	международная	421581.6153	300.5373	отправлена	IRVTUS3NXXX
393	RU9883803436510697875492928159959	978	2023-03-15	DE7394751185167082566633789	международная	7946820.0673	789.9292	доставлена	DEUTDEFFXXX
394	RU1683803436536773128968824249362	840	2023-05-20	RU7183803436513501317784267991188	внутренняя	8356043.3891	449.1480	доставлена	\N
395	RU4083803436537218400436107027314	643	2023-02-25	RU5683803436522754650880470438385	внутренняя	522942.4515	693.2327	отправлена	\N
396	RU9383803436546841675173507423577	356	2023-12-09	AD9493014415399328318185643	международная	8746951.4237	537.3349	отменена	SBININBBXXX
397	RU1483803436556765140449291811625	643	2023-04-15	RU8983803436545494349013660032430	внутренняя	4013580.6201	191.2869	доставлена	\N
398	RU8983803436543970357311304848339	156	2023-06-05	RU2183803436586747579379810386651	внутренняя	5831505.6284	756.3778	отменена	\N
399	RU3683803436533022850683714599602	398	2023-09-29	RU1683803436510344781123537250392	внутренняя	6702556.6289	529.1382	отменена	\N
400	RU6283803436561107985248905256058	978	2023-09-21	RU7283803436583841985241060182740	внутренняя	5312720.4902	566.4205	отправлена	\N
401	RU7483803436544936047225386728318	840	2023-05-06	DE5596580364246118287910461	международная	7489533.9487	391.0953	отменена	CHASUS33
402	RU9283803436581282514241262822584	156	2023-03-24	DE9933331352901088585981761	международная	76600.5053	237.7669	отменена	BKCHCNBJ
403	RU5983803436585678890114061651314	840	2023-03-04	RU2883803436581906276084692901201	внутренняя	4289734.8128	940.6113	доставлена	\N
404	RU9983803436588442958405952112241	398	2023-01-17	VN5638577249196997645504269	международная	8958030.7972	750.5567	отправлена	CASPKZKAXXX
405	RU9383803436546841675173507423577	840	2023-03-25	KZ8870604132994803437133354	международная	3827502.2544	265.4345	отменена	IRVTUS3NXXX
406	RU8683803436520349379894661014091	398	2023-01-27	AL7522193265262675064262405	международная	6183725.0086	343.8801	отменена	CASPKZKAXXX
407	RU5983803436565674700991182664479	356	2023-05-21	RU9883803436597607312145326011401	внутренняя	3286644.9249	692.3894	доставлена	\N
408	RU6883803436524866655852609791727	398	2023-11-27	RU5583803436525031727011657164177	внутренняя	1675366.9262	812.4688	отправлена	\N
409	RU1083803436588429797000364388942	978	2023-01-08	KZ1384341619987367957909707	международная	3453007.7567	886.3308	отправлена	RZBAATWW
410	RU3683803436589669964829443545971	356	2023-08-04	RU3983803436554516084539411139147	внутренняя	4847378.6557	448.8775	отправлена	\N
411	RU6383803436599902939219818792376	156	2023-11-15	ES9512205243665159219200320	международная	928450.7296	581.5855	доставлена	BKCHCNBJ
412	RU1083803436516100547774990634896	156	2023-02-13	RU1183803436547102061688733775669	внутренняя	795916.3446	81.8279	отправлена	\N
413	RU7483803436560908970835757520521	356	2023-04-11	RU5983803436561671607015303339932	внутренняя	2169608.8132	669.9397	отменена	\N
414	RU1583803436575905915250327615306	978	2023-07-01	AD2394949793606119763864530	международная	3554577.5663	68.6781	отправлена	SOGEFRPP
415	RU5683803436564237501745383797829	643	2023-08-23	AL5894103035642924247156562	внутренняя	3230260.7275	648.3209	отправлена	\N
416	RU4283803436583191860084907222827	643	2023-04-01	DE7730315877636255204817115	внутренняя	2298723.8076	703.3742	отправлена	\N
417	RU7783803436536804517087406327796	643	2023-10-09	IN8974226084116482523313534	внутренняя	7228350.2506	298.3635	отменена	\N
418	RU8583803436580493050529274956761	840	2023-01-23	RU2783803436580745382811010865973	внутренняя	3908376.6633	337.8121	отправлена	\N
419	RU7583803436597888322431139189153	643	2023-07-18	KZ8914406172483379986139321	внутренняя	7548434.9913	792.5080	отменена	\N
420	RU6583803436565551879254347008316	643	2023-11-23	RU3083803436572725983728902081378	внутренняя	4717002.3866	472.9000	доставлена	\N
421	RU3983803436554516084539411139147	643	2023-08-31	RU2783803436580745382811010865973	внутренняя	5375686.0165	589.9375	доставлена	\N
422	RU6483803436575827628326698282321	156	2023-03-16	RU4483803436534969190676238532628	внутренняя	1247184.0944	387.7693	отменена	\N
423	RU2583803436586349630493889324094	643	2023-06-03	RU2383803436518501918755699207235	внутренняя	4194162.5610	793.8384	отправлена	\N
424	RU4183803436575456526806163894045	978	2023-12-07	PT5817085075040954756412037	международная	2545641.0543	617.7121	отправлена	DEUTDEFFXXX
425	RU8383803436554622159366581134752	978	2023-01-07	KZ6916320194795993106906082	международная	246783.5893	147.6872	отправлена	DEUTDEFFXXX
426	RU4483803436537144245226352938256	840	2023-04-08	RU8883803436592173067148862634991	внутренняя	6579024.1404	740.8385	отменена	\N
427	RU3983803436554516084539411139147	840	2023-11-10	RU4483803436593534887929979895004	внутренняя	8574933.5824	405.9453	отменена	\N
428	RU6183803436573612137819734816326	398	2023-11-12	BY5212903045761751746932551	международная	9843681.7938	264.9102	отменена	CASPKZKAXXX
429	RU8483803436552375991404578719285	840	2023-08-28	ES2774217451066562431572909	международная	6305635.2801	18.9239	отправлена	IRVTUS3NXXX
430	RU4983803436534576819154749347962	643	2023-03-28	IN3930250423904912954326567	внутренняя	2951708.0499	783.9548	отправлена	\N
431	RU5383803436532276110708298062956	398	2023-03-29	DE4656089164722859510204479	международная	9590316.9425	449.2855	отменена	CASPKZKAXXX
432	RU7083803436565850801859363291526	978	2023-08-27	VN7534988988658839902527952	международная	2418320.0624	852.9184	отменена	SOGEFRPP
433	RU4083803436523112590591409946049	156	2023-07-26	IN4722342551042546666949187	международная	5717501.5551	773.4757	отменена	BKCHCNBJ
434	RU9883803436559947701649293062119	978	2023-03-17	RU4183803436593654490331448399606	внутренняя	2010672.2145	779.4499	отправлена	\N
435	RU5783803436556321671762187197309	156	2023-11-09	RU6411867637353249851353649	внутренняя	9019219.9474	148.2730	отменена	\N
436	RU4383803436535637847836978327691	156	2023-03-20	RU6783803436583735354795738130605	внутренняя	2275616.6757	180.0614	отправлена	\N
437	RU7083803436569474567525801645267	643	2023-12-06	IN4970865393342906464574806	внутренняя	8073549.9985	195.7896	отправлена	\N
438	RU6183803436573612137819734816326	840	2023-07-12	IN6459484455093343473747352	международная	4289784.5282	914.8197	отменена	IRVTUS3NXXX
439	RU5083803436563140090168469536649	156	2023-04-11	RU8083803436567877444686336475183	внутренняя	5704440.1930	266.2683	отправлена	\N
440	RU3083803436556733352794187735054	156	2023-12-11	RU2983803436539974076802515756241	внутренняя	5899406.1205	78.2110	отправлена	\N
441	RU4083803436525661046500520760430	643	2023-07-01	RU9683803436579408636311341559980	внутренняя	2132291.1503	520.6280	отменена	\N
442	RU5783803436553735504938098098542	840	2023-07-03	RU8483803436517523304653033637180	внутренняя	3210451.6232	166.1622	отменена	\N
443	RU8483803436512925144599170278485	356	2023-10-18	RU4483803436593534887929979895004	внутренняя	3803892.4107	888.8556	доставлена	\N
444	RU5883803436576828712243252221562	978	2023-05-12	ES1424825535336160966782050	международная	9339176.4404	721.0658	отправлена	SOGEFRPP
445	RU5283803436570838144716210841495	398	2023-10-20	ES3755053773974620664680521	международная	3567558.9996	932.5717	отправлена	CASPKZKAXXX
446	RU6183803436556503720110500069421	398	2023-05-11	RU9583803436589245078784775619456	внутренняя	7948350.1158	885.0038	доставлена	\N
447	RU8583803436593152008036708778596	356	2023-07-02	RU4583803436546993711061481413708	внутренняя	4085143.1523	456.2969	отменена	\N
448	RU6583803436526807323529165700056	643	2023-09-05	ES3632894461147342986782636	внутренняя	6735467.3219	594.3772	отменена	\N
449	RU5783803436573951128453151787227	840	2023-09-18	VN8882329118149867363380105	международная	4719833.0166	903.5651	отправлена	CHASUS33
450	RU5883803436571013870275428717873	978	2023-01-30	RU2530315969135728382847917	внутренняя	3256763.8641	270.8679	доставлена	\N
451	RU1383803436523658112524214881297	156	2023-11-21	RU5983803436533405804846460378377	внутренняя	1700846.9320	687.1850	доставлена	\N
452	RU8183803436513368239655842198331	643	2023-01-05	PT6854308049550197389279838	внутренняя	4380841.1466	0.0000	отменена	\N
453	RU8283803436558421168306139201398	643	2023-03-31	RU8383803436557193853878723819444	внутренняя	9138572.9732	336.3335	доставлена	\N
454	RU4283803436583191860084907222827	398	2023-12-02	RU1283803436591782126481419856685	внутренняя	494175.7010	922.4759	доставлена	\N
455	RU4483803436534969190676238532628	978	2023-03-30	AL7568238149199170212434089	международная	3105218.7013	999.2265	отправлена	SOGEFRPP
456	RU3883803436564256045508064629374	398	2023-11-11	BY8021297703231709563017908	международная	3103192.4762	0.0000	отправлена	CASPKZKAXXX
457	RU7783803436556242953974983768067	156	2023-06-22	VN8150654473983870352940535	международная	7930288.7534	527.8627	отправлена	BKCHCNBJ
458	RU3383803436530100232705488681423	356	2023-06-16	AL5187550687061062241483517	международная	2731034.8830	44.8063	отправлена	SBININBBXXX
459	RU5283803436570838144716210841495	398	2023-10-25	RU6283803436577836700807681117407	внутренняя	2364715.6961	442.4924	отменена	\N
460	RU9383803436563463129216774786629	398	2023-02-24	RU6083803436569163727288631654599	внутренняя	9556020.8750	677.9927	отправлена	\N
461	RU6383803436599902939219818792376	978	2023-07-13	RU5297899134472104832550013	внутренняя	9774458.5503	0.0000	отменена	\N
462	RU6783803436510078136565817264354	398	2023-12-27	ES8822964543583282958240151	международная	9182354.9473	932.5774	отменена	CASPKZKAXXX
463	RU4583803436546993711061481413708	356	2023-04-11	IN1716251122016247275284700	международная	8425485.9520	198.4742	отправлена	SBININBBXXX
464	RU1583803436533479152204865778047	978	2023-01-20	RU5783803436553735504938098098542	внутренняя	8924459.7704	588.7110	доставлена	\N
465	RU6083803436583599210196850890015	840	2023-07-30	RU1983803436537997284898110055528	внутренняя	6674790.7659	857.3772	отменена	\N
466	RU8583803436548069379320039967893	398	2023-03-07	AD1578109161893175854703507	международная	3144258.4155	187.7698	отправлена	CASPKZKAXXX
467	RU9483803436588743613330942629999	978	2023-05-25	PT9914154075797679842802302	международная	5094447.2464	946.0500	отменена	RZBAATWW
468	RU2983803436588011593439328399453	156	2023-07-15	AL1014174415895614300832583	международная	8841988.7282	460.0660	отменена	BKCHCNBJ
469	RU9583803436547610609904791788853	398	2023-04-14	RU8683803436520349379894661014091	внутренняя	4422801.6715	761.7141	отменена	\N
470	RU7783803436585076163513647706071	156	2023-11-09	RU3783803436562091905141244310726	внутренняя	2379716.7660	149.3866	отправлена	\N
471	RU8483803436593374085227717891522	978	2023-04-03	KZ9961604558924537567077654	международная	3390543.1465	246.5322	отменена	RZBAATWW
472	RU1183803436587920364130887563809	398	2023-10-07	VN5066825685676214081794787	международная	2975118.4745	526.6664	отменена	CASPKZKAXXX
473	RU4183803436575456526806163894045	840	2023-03-07	KZ8828028176910011355437554	международная	7979485.4635	490.0264	доставлена	CHASUS33
474	RU1183803436569972795023903837949	978	2023-05-21	RU9683803436571883645805733128714	внутренняя	5801531.3477	266.1579	отменена	\N
475	RU9483803436570307762028951954874	356	2023-02-25	RU5983803436596779338391553657957	внутренняя	2345062.4800	668.5715	доставлена	\N
476	RU1083803436563162471160560931522	643	2023-06-20	RU5983803436558435772787343054218	внутренняя	2640336.3310	357.5459	доставлена	\N
477	RU5783803436568341660520010753753	978	2023-11-21	ES2558566447785859545090452	международная	8186885.7325	593.0519	отправлена	RZBAATWW
478	RU8383803436554622159366581134752	398	2023-12-26	DE3468354471695119188140837	международная	4462163.1397	431.9617	отправлена	CASPKZKAXXX
479	RU4383803436557380827011382643653	840	2023-12-09	AD6651695124559699540823269	международная	2925046.4779	601.1289	отменена	IRVTUS3NXXX
480	RU1483803436552189189819570176682	356	2023-04-15	KZ4549755043875765978022000	международная	2381614.9864	105.9794	отправлена	SBININBBXXX
481	RU2483803436537933507280624045523	643	2023-01-10	RU2883803436510195395163379960366	внутренняя	7508369.0997	707.7803	отправлена	\N
482	RU4083803436525661046500520760430	643	2023-10-31	BY3320704932344649737851270	внутренняя	4034016.0571	707.6125	отправлена	\N
483	RU7683803436565241249132549566386	978	2023-11-12	RU9779873668925027817926415	внутренняя	2331713.2863	543.0565	доставлена	\N
484	RU5583803436525031727011657164177	643	2023-11-12	ES6152603078627338473507614	внутренняя	5876947.9295	661.1072	доставлена	\N
485	RU8583803436593152008036708778596	398	2023-02-02	RU7583803436593274051968042799324	внутренняя	8876245.8256	408.1512	отменена	\N
486	RU2883803436512412400998624231254	356	2023-04-03	RU9683803436520170153501466272589	внутренняя	2285558.7903	46.6140	доставлена	\N
487	RU5783803436598085342824416355658	356	2023-01-06	RU4283803436515276086545867508581	внутренняя	3115580.0238	617.2108	доставлена	\N
488	RU6183803436551232797419519235346	156	2023-12-15	ES7189055751429418554187257	международная	4842539.0452	51.6831	отправлена	BKCHCNBJ
489	RU9983803436563015974445739907644	643	2023-03-28	RU6483803436557881046066137062384	внутренняя	7945734.0248	571.1171	отправлена	\N
490	RU8183803436559528710172368223769	978	2023-12-22	KZ9681458876800825524049717	международная	9757451.3281	608.5290	отправлена	RZBAATWW
491	RU4283803436544879224116585983050	398	2023-05-07	RU5183803436596697120047636808100	внутренняя	578191.7439	601.7286	доставлена	\N
492	RU1083803436588429797000364388942	156	2023-09-16	RU9683803436597203099828784600586	внутренняя	492873.8706	147.1068	доставлена	\N
493	RU6183803436573612137819734816326	978	2023-04-25	RU8383803436583878629872361871714	внутренняя	6013252.4387	792.1111	доставлена	\N
494	RU4583803436576777630615652907536	643	2023-04-07	RU3283803436579852018195047883736	внутренняя	6473326.8090	222.3675	доставлена	\N
495	RU6683803436547011171926119923803	643	2023-12-17	AL3291596356864924884438604	внутренняя	4973626.0539	683.1982	доставлена	\N
496	RU5583803436581992686445972740236	978	2023-03-29	RU5683803436575772290627280121203	внутренняя	5235442.9965	309.3787	доставлена	\N
497	RU9683803436524115739172828059349	156	2023-06-12	RU8283803436593409912626065485368	внутренняя	6518668.3181	300.3723	отменена	\N
498	RU8583803436593152008036708778596	840	2023-12-03	RU6662610464426417647045887	внутренняя	7829854.9950	328.1834	отменена	\N
499	RU1583803436533479152204865778047	156	2023-07-28	DE3977376332369784396939039	международная	45867.0430	946.4674	отправлена	BKCHCNBJ
500	RU5483803436551418630110242560620	398	2023-06-26	RU4983803436534576819154749347962	внутренняя	2856575.0654	0.0000	доставлена	\N
501	RU2783803436580745382811010865973	840	2023-08-26	RU1683803436536773128968824249362	внутренняя	4718611.0473	868.3331	доставлена	\N
502	RU2883803436538134433783624054557	840	2023-03-10	AD2197145059422738637171238	международная	2832319.7483	166.1797	доставлена	CHASUS33
503	RU2783803436580745382811010865973	840	2023-02-19	RU7583803436593274051968042799324	внутренняя	7631992.3071	365.2743	доставлена	\N
504	RU8483803436583598027317615125571	643	2023-01-13	AD3393496299694805230112285	внутренняя	5735212.8387	361.9395	отправлена	\N
505	RU9983803436515137760640096699879	840	2023-03-17	RU9683803436520170153501466272589	внутренняя	1883130.3593	667.1549	отправлена	\N
506	RU7483803436529598231033100377224	398	2023-04-18	DE3078055136254597269811416	международная	8566173.1408	648.1432	отменена	CASPKZKAXXX
507	RU9183803436512467785925904841435	356	2023-11-11	PT7780696387900033899494653	международная	5056188.2546	741.6649	отменена	SBININBBXXX
508	RU1383803436537041354890218533954	840	2023-03-21	VN3690336874444466518838167	международная	7296441.0473	199.5634	отправлена	IRVTUS3NXXX
509	RU2683803436575198696607383546599	398	2023-04-25	ES4416190431657608324047224	международная	604004.8989	905.8517	отменена	CASPKZKAXXX
510	RU5583803436541779385547740767657	356	2023-06-16	RU9583803436547610609904791788853	внутренняя	5027237.2365	897.1661	доставлена	\N
511	RU4983803436534576819154749347962	840	2023-04-20	ES2122068777303123670220538	международная	7770837.6765	320.8834	отменена	IRVTUS3NXXX
512	RU7183803436578006903833632767386	398	2023-04-05	RU6683803436546559918630563560759	внутренняя	6024791.3954	118.9553	доставлена	\N
513	RU3383803436540416635821116917223	398	2023-05-18	RU2483803436537933507280624045523	внутренняя	2828208.8192	656.6064	отменена	\N
514	RU6883803436521704893234788177503	643	2023-12-24	RU7483803436516612664745741202549	внутренняя	119505.5884	584.4694	доставлена	\N
515	RU3883803436515226766320509995235	398	2023-02-26	RU1583803436578714315409224923820	внутренняя	4645727.8779	383.6581	отменена	\N
516	RU4283803436538514172142523078432	643	2023-11-28	RU8483803436517523304653033637180	внутренняя	3427328.7524	232.2463	отправлена	\N
517	RU6183803436555838927651384339574	840	2023-07-10	BY7831639838115839029002746	международная	9955710.9715	490.4662	отменена	CHASUS33
518	RU6983803436550083462130199504453	356	2023-09-07	RU6983803436551969328605594993446	внутренняя	3858994.7281	797.6727	отменена	\N
519	RU6783803436583735354795738130605	643	2023-10-17	RU2983803436597155052344917689453	внутренняя	5910822.6721	811.4239	отправлена	\N
520	RU5783803436567884889437805923129	398	2023-05-28	RU1583803436513968949783488654583	внутренняя	6940244.4079	949.7665	отменена	\N
521	RU4483803436593534887929979895004	643	2023-09-28	AD1811366955983405357049320	внутренняя	9708721.0360	942.2938	отменена	\N
522	RU2183803436535230801413319305895	356	2023-01-04	RU9583803436547610609904791788853	внутренняя	8534068.7327	877.8270	доставлена	\N
523	RU6483803436527000884469712767990	156	2023-01-28	DE2727732524446333657382020	международная	9976090.8135	772.5837	доставлена	BKCHCNBJ
524	RU2883803436512412400998624231254	356	2023-08-29	RU5583803436581992686445972740236	внутренняя	4443620.5073	932.8259	отправлена	\N
525	RU8183803436559528710172368223769	398	2023-12-19	RU8783803436562772820294479967682	внутренняя	3180219.7865	585.3057	доставлена	\N
526	RU5883803436549838724600410631189	978	2023-02-25	RU5183803436573013692902081587761	внутренняя	1944347.0415	546.0745	отменена	\N
527	RU9883803436510697875492928159959	398	2023-11-23	RU5383803436532276110708298062956	внутренняя	1783510.0860	89.1277	отправлена	\N
528	RU7483803436595027677837710467368	840	2022-12-27	KZ9640626677665545783373580	международная	6374003.5773	61.1863	отменена	IRVTUS3NXXX
529	RU9883803436580908913943520973504	156	2023-02-17	RU9483803436570307762028951954874	внутренняя	5608574.0508	531.5165	отменена	\N
530	RU9683803436571883645805733128714	398	2023-03-21	KZ1399397944032766291080106	международная	7142282.4061	120.3732	отменена	CASPKZKAXXX
531	RU2483803436580851808318436691458	840	2023-01-07	KZ4954509141189477006889381	международная	7774615.2544	571.6272	доставлена	IRVTUS3NXXX
532	RU6183803436571932790348770462135	398	2023-06-28	AL5887862616378543481272350	международная	2204322.1526	54.8173	отправлена	CASPKZKAXXX
533	RU4883803436510661666911089208306	156	2023-01-20	AD1527532552439158777130081	международная	375543.4509	818.0295	доставлена	BKCHCNBJ
534	RU5483803436538988818998904026382	356	2023-04-01	RU8233426447247284692673870	внутренняя	6246645.1402	79.4394	отправлена	\N
535	RU2583803436569716293278278112122	156	2023-04-24	PT4074763777983059011910001	международная	3596281.7200	384.2683	отправлена	BKCHCNBJ
536	RU2683803436512319317744369021772	398	2023-07-17	RU4283803436530972916151822377436	внутренняя	6752694.4819	534.0983	отменена	\N
537	RU8283803436517214496879594083501	356	2023-08-10	RU3083803436548755847047281062638	внутренняя	6906998.9458	646.2634	отменена	\N
538	RU6983803436521001508692071958064	978	2023-12-01	AL4237557792119207806879469	международная	4013558.4559	945.2666	отменена	DEUTDEFFXXX
539	RU4083803436523112590591409946049	398	2023-06-01	RU2083803436518033160343253894367	внутренняя	4616088.5938	225.7962	отправлена	\N
540	RU1583803436575905915250327615306	643	2023-09-09	BY9886993969224604373850626	внутренняя	4415083.7122	999.4057	отправлена	\N
541	RU9483803436585469145832242711561	840	2023-05-01	DE3444104346665896943797388	международная	4686719.7164	979.9403	отправлена	IRVTUS3NXXX
542	RU8483803436593374085227717891522	156	2023-08-28	RU9283803436560888794155508079505	внутренняя	9283540.5523	110.7056	доставлена	\N
543	RU9783803436586848496167067081204	978	2023-02-01	VN7749999763323675054279978	международная	4631994.7258	958.4346	доставлена	DEUTDEFFXXX
544	RU1583803436533479152204865778047	398	2023-04-28	RU6183803436536163842184020816729	внутренняя	8234590.0450	226.8856	доставлена	\N
545	RU7483803436575212193030608824580	643	2023-10-18	RU1183803436541561390025398925839	внутренняя	2991004.3284	54.9936	отменена	\N
546	RU2983803436588011593439328399453	156	2023-07-29	DE8993007851037950297948776	международная	979151.3711	130.2384	отменена	BKCHCNBJ
547	RU4283803436512174946847064448344	156	2023-03-22	RU8983803436551003507571679577910	внутренняя	2919890.4141	685.7857	доставлена	\N
548	RU1283803436545193525808988988532	643	2023-08-31	PT6560632603412037281412042	внутренняя	8784958.2756	537.8323	отменена	\N
549	RU5683803436564237501745383797829	643	2023-11-07	RU2983803436572636545308279163382	внутренняя	4588012.5476	746.5146	доставлена	\N
550	RU7183803436551143317683635788042	356	2023-05-27	RU4695257143241656783530580	внутренняя	433060.0431	128.9429	отменена	\N
551	RU5283803436570838144716210841495	840	2023-11-12	DE8896783065665246604870911	международная	1847165.6172	206.1124	отправлена	IRVTUS3NXXX
552	RU8583803436593152008036708778596	840	2023-12-14	BY4245160096596121363884775	международная	2877575.4661	846.1190	отменена	IRVTUS3NXXX
553	RU6983803436551969328605594993446	840	2023-11-23	AD6670946582159267384479327	международная	1017700.7750	227.3061	отправлена	IRVTUS3NXXX
554	RU4183803436544525596730636267692	643	2023-05-21	DE7745051055495597173371194	внутренняя	8742145.3695	843.4063	доставлена	\N
555	RU4883803436540069564759439339493	643	2023-04-06	ES9953132076271404947962118	внутренняя	7308746.7777	996.1764	отменена	\N
556	RU5583803436555177704368963744222	978	2023-04-28	RU6183803436547326038705936576601	внутренняя	9023390.0673	523.7513	отменена	\N
557	RU8083803436548053884024737088236	978	2023-04-21	PT8720090029382982183046254	международная	8485325.6135	922.5853	доставлена	DEUTDEFFXXX
558	RU5683803436539120556194350818141	398	2023-06-20	RU4183803436512683300418013703414	внутренняя	2044019.8005	455.4715	доставлена	\N
559	RU1183803436541561390025398925839	156	2023-06-16	BY2294782464050800272104825	международная	6027453.4626	47.0310	отправлена	BKCHCNBJ
560	RU6883803436521704893234788177503	156	2023-04-13	IN8910016271684581417602089	международная	5546685.4241	372.7964	доставлена	BKCHCNBJ
561	RU5683803436564237501745383797829	643	2023-12-03	RU4683803436584135461455281070651	внутренняя	8983851.1627	72.8472	отменена	\N
562	RU9283803436581282514241262822584	156	2023-08-25	ES2134637045219177376048279	международная	3786159.7034	276.1334	доставлена	BKCHCNBJ
563	RU2783803436529440294678710752920	840	2023-02-13	AD5286298637908968835808377	международная	4111515.2206	922.7392	отправлена	CHASUS33
564	RU8383803436543267469021061769102	356	2023-08-25	PT2725223656950033930914670	международная	9965721.7717	485.1201	отменена	SBININBBXXX
565	RU9083803436548965374028188380728	643	2023-01-15	KZ9690893092425878253314454	внутренняя	3803530.3041	832.6361	отправлена	\N
566	RU3283803436586063041663029658571	643	2023-11-09	RU1683803436583298094705869717304	внутренняя	75119.5524	726.6326	доставлена	\N
567	RU3983803436583730529285495292571	643	2023-04-24	RU6983803436596433824452063468541	внутренняя	9671514.6366	424.5774	отправлена	\N
568	RU3183803436538368625987340316428	978	2023-11-23	AD7091827983869284210382119	международная	6469858.0742	191.5642	отменена	SOGEFRPP
569	RU1183803436587920364130887563809	643	2023-10-24	RU8183803436532187852215520403243	внутренняя	4001550.1454	600.2824	доставлена	\N
570	RU3383803436551883036237842733910	398	2023-07-31	RU9483803436588743613330942629999	внутренняя	1622944.5350	414.7686	отменена	\N
571	RU1283803436513390712190126736747	356	2023-08-17	KZ8419749925721658220570236	международная	7667965.6514	316.1780	доставлена	SBININBBXXX
572	RU6183803436547326038705936576601	978	2022-12-29	RU4683803436521950147450839996450	внутренняя	9853109.8156	139.2947	отменена	\N
573	RU1183803436541561390025398925839	840	2023-01-28	RU2883803436564862346362051659673	внутренняя	3333689.9049	729.9316	отправлена	\N
574	RU9683803436579408636311341559980	156	2023-01-18	RU2183803436535230801413319305895	внутренняя	8662778.6290	729.3309	отправлена	\N
575	RU6883803436521704893234788177503	398	2023-01-14	RU3683803436583826961336736431806	внутренняя	9664740.6896	550.3235	отменена	\N
576	RU8183803436576908594301902139271	156	2023-08-16	AL2878274485608612827846316	международная	959926.2124	573.2069	отменена	BKCHCNBJ
577	RU7783803436585076163513647706071	643	2023-12-01	RU4983803436548786021946522460624	внутренняя	3632621.6900	709.2117	отменена	\N
578	RU9383803436587347167184231490115	356	2023-07-10	RU3983803436569376600246742084811	внутренняя	5497820.8963	779.3557	отправлена	\N
579	RU4583803436546993711061481413708	840	2023-01-09	PT7796050968291515628332400	международная	8533458.7071	585.1307	доставлена	IRVTUS3NXXX
580	RU6583803436599318340096840026283	643	2023-05-17	ES2191538869336526020455437	внутренняя	7700819.2728	395.2828	отменена	\N
581	RU5983803436565674700991182664479	978	2023-02-15	RU9083803436513364676730542126445	внутренняя	539446.8592	262.0591	отменена	\N
582	RU7483803436512314763652680872976	398	2023-08-17	BY3596914871391223960526540	международная	2878712.4041	788.7189	отменена	CASPKZKAXXX
583	RU1383803436596151895061926683764	978	2023-11-14	RU8183803436576334203563049364101	внутренняя	3543228.6738	378.7187	отправлена	\N
584	RU6983803436557684576294868357987	356	2023-11-14	RU4583803436588661449801193641363	внутренняя	6119995.1233	857.1308	доставлена	\N
585	RU4583803436588661449801193641363	840	2023-04-02	IN9116076753177332416810585	международная	7038956.7676	940.4624	отправлена	CHASUS33
586	RU8183803436566794763466227027850	643	2023-10-28	IN1668586233450077299158463	внутренняя	3312590.3206	841.6462	отправлена	\N
587	RU7783803436536804517087406327796	356	2023-10-30	VN1211759957503886978231988	международная	4517617.1834	974.8884	доставлена	SBININBBXXX
588	RU8383803436583878629872361871714	978	2023-02-12	AL5837300748803886370833863	международная	1655488.7853	653.3337	отменена	SOGEFRPP
589	RU2783803436515955219320238454317	398	2023-08-25	RU4183803436512683300418013703414	внутренняя	3127775.3027	170.4645	отменена	\N
590	RU8283803436558421168306139201398	840	2023-12-22	RU1683803436583298094705869717304	внутренняя	8277361.5546	49.9057	доставлена	\N
591	RU1983803436537997284898110055528	356	2023-09-27	AD7149127427385142247642194	международная	8150419.0437	147.0052	доставлена	SBININBBXXX
592	RU8983803436550652073660555482382	840	2023-08-18	RU7383803436546512723534280739575	внутренняя	4215636.0769	120.4025	доставлена	\N
593	RU6183803436571932790348770462135	398	2023-04-26	RU8683803436511417676206561932357	внутренняя	2476244.2361	166.8758	отменена	\N
594	RU6183803436571932790348770462135	156	2023-10-16	RU6783803436527708547728704282997	внутренняя	4471914.0890	810.0623	отменена	\N
595	RU5583803436533254773648721597711	356	2023-07-09	RU6183803436571932790348770462135	внутренняя	3262338.7021	338.4021	отправлена	\N
596	RU8183803436576908594301902139271	398	2023-11-14	AD2446627376145922668596552	международная	4902224.9429	32.0128	отменена	CASPKZKAXXX
597	RU9083803436548965374028188380728	840	2023-04-16	KZ3818999151399249209025641	международная	6664887.1260	265.5247	доставлена	CHASUS33
598	RU8483803436586135450040789229889	978	2023-07-29	IN3414871485838220134469810	международная	4326908.7779	895.6540	отправлена	SOGEFRPP
599	RU2983803436530272226005609138408	156	2023-07-26	RU9383803436575688788160155647011	внутренняя	3311981.0047	851.4304	отправлена	\N
600	RU5583803436541779385547740767657	840	2023-01-01	RU1883803436537462946976236392804	внутренняя	1783427.9851	68.7957	отменена	\N
601	RU8183803436564595439284009293487	643	2023-03-18	IN4341251276722917959221506	внутренняя	4556247.3807	900.8638	отправлена	\N
602	RU9383803436563463129216774786629	978	2023-12-27	RU3583803436597484588589933917343	внутренняя	5637687.9684	646.5486	отправлена	\N
603	RU8483803436576032684947735830335	156	2023-01-31	ES5871791028461075228280521	международная	3775868.2077	452.5906	отменена	BKCHCNBJ
604	RU8483803436517523304653033637180	356	2023-03-10	RU5383803436532276110708298062956	внутренняя	9939642.3219	877.2589	отправлена	\N
605	RU3983803436562540544761068231244	398	2023-06-19	RU6983803436580831999013679742086	внутренняя	446868.4469	770.8774	доставлена	\N
606	RU3583803436556382446278007957702	643	2022-12-30	RU8683803436531608639655465618756	внутренняя	2006429.5527	188.7723	доставлена	\N
607	RU2983803436530272226005609138408	840	2023-08-03	ES6152406086133804122414032	международная	112209.9691	308.1881	доставлена	CHASUS33
608	RU4883803436583846522749125412438	643	2023-10-14	DE6530965256567770328840978	внутренняя	4399578.3941	233.7880	доставлена	\N
609	RU5983803436513359014201161572816	156	2023-05-02	RU5332319539176916663986289	внутренняя	4406576.7954	295.7991	доставлена	\N
610	RU1183803436536239647096212180861	978	2023-01-01	RU4183803436575456526806163894045	внутренняя	5532952.7514	824.8141	отправлена	\N
611	RU2083803436518033160343253894367	356	2023-03-07	VN6443786354339232240624648	международная	3643762.7399	353.4541	отменена	SBININBBXXX
612	RU9683803436531094862059243712475	398	2023-06-16	RU4583803436535138140020222748384	внутренняя	2790721.4857	60.6671	доставлена	\N
613	RU3283803436586063041663029658571	156	2023-04-03	VN5831220774317772300878140	международная	5365308.9302	672.0363	отменена	BKCHCNBJ
614	RU1383803436523658112524214881297	840	2023-11-26	RU9224830486892464554369146	внутренняя	1804918.2816	266.6216	отправлена	\N
615	RU9283803436581282514241262822584	156	2023-06-04	PT8816792436403094419482158	международная	1522072.5440	957.2670	отправлена	BKCHCNBJ
616	RU7383803436534050516387288663509	643	2023-11-26	RU2283803436594102552659582448178	внутренняя	3503976.4425	95.1310	отправлена	\N
617	RU3583803436597484588589933917343	840	2023-11-15	AL3723431016262374525768941	международная	8695151.9123	426.5373	отправлена	IRVTUS3NXXX
618	RU8583803436593152008036708778596	978	2023-06-02	RU6283803436577836700807681117407	внутренняя	8950383.0759	299.8700	доставлена	\N
619	RU2783803436580745382811010865973	398	2023-01-14	RU6683803436546559918630563560759	внутренняя	3194885.4922	344.0374	доставлена	\N
620	RU5983803436513359014201161572816	156	2023-04-23	KZ1721778515873068457765560	международная	6207496.5126	430.4413	доставлена	BKCHCNBJ
621	RU4283803436538514172142523078432	398	2023-03-30	RU6583803436573484995572407857396	внутренняя	5546149.7145	145.3898	отправлена	\N
622	RU7083803436595909521339223196614	840	2023-08-08	BY9751348726946749342106898	международная	1345777.5908	29.9996	отправлена	IRVTUS3NXXX
623	RU1883803436547883958852583813660	643	2023-09-04	RU9883803436559947701649293062119	внутренняя	1401353.2643	233.3694	отправлена	\N
624	RU7383803436515152831562897371432	156	2023-10-17	AL3933288427086285894455764	международная	541499.7220	274.4263	отправлена	BKCHCNBJ
625	RU6483803436527000884469712767990	398	2023-09-27	AD2679979739256592015639366	международная	5233326.6993	418.4123	отправлена	CASPKZKAXXX
626	RU3883803436519845868206132784952	840	2023-08-26	IN7091304078755956040921091	международная	6565939.0211	494.5878	доставлена	IRVTUS3NXXX
627	RU3183803436522808312515599877028	156	2023-03-16	PT2546736329398207115272839	международная	2546585.4128	22.7836	отправлена	BKCHCNBJ
628	RU6983803436542868245387240901621	156	2023-05-24	KZ7690441047762718440726834	международная	7602167.4496	401.5271	отменена	BKCHCNBJ
629	RU1383803436598073263367823117200	156	2023-04-06	VN6061946563151179901777217	международная	3249451.4458	581.4610	отправлена	BKCHCNBJ
630	RU2283803436551819000625747494652	643	2023-09-03	ES6582829775638684284156882	внутренняя	5509034.3435	761.8400	отменена	\N
631	RU9383803436587347167184231490115	398	2023-02-09	RU1483803436555535016685486735994	внутренняя	1663077.2087	651.4849	доставлена	\N
632	RU1583803436513968949783488654583	840	2023-12-26	RU2083803436571871160330810400191	внутренняя	5669032.0404	223.4733	доставлена	\N
633	RU9383803436515318038329930627155	840	2023-04-12	RU8483803436552375991404578719285	внутренняя	833448.2408	298.7841	доставлена	\N
634	RU2083803436571871160330810400191	356	2023-04-09	KZ8262575149463711608276268	международная	2994739.1218	88.6394	доставлена	SBININBBXXX
635	RU5983803436596779338391553657957	356	2023-09-26	IN3260447154807559482218470	международная	3032870.6108	530.0285	доставлена	SBININBBXXX
636	RU1883803436562141776165180370424	643	2023-01-15	VN8551786743005243717987482	внутренняя	8477349.0592	488.3651	отменена	\N
637	RU6483803436595566817980742907742	398	2023-11-27	AL8249889359137209088212586	международная	5130734.6277	644.0964	доставлена	CASPKZKAXXX
638	RU3683803436526413764026311806751	643	2023-07-05	RU4283803436512174946847064448344	внутренняя	5040001.6608	315.2426	доставлена	\N
639	RU1383803436523658112524214881297	978	2023-03-08	KZ6039939129093891558166842	международная	3961270.5850	604.1830	доставлена	RZBAATWW
640	RU8283803436517214496879594083501	643	2023-07-11	PT6294050017533594876050889	внутренняя	9787454.9199	978.1912	отменена	\N
641	RU4583803436546993711061481413708	356	2023-12-22	RU5183803436550941857646482749776	внутренняя	9792795.6561	587.1245	доставлена	\N
642	RU2383803436518501918755699207235	978	2023-09-13	RU1683803436596193217028081534610	внутренняя	5111697.4557	971.3454	отправлена	\N
643	RU6783803436527708547728704282997	978	2023-05-16	RU8283803436558421168306139201398	внутренняя	8036192.2236	894.1224	отменена	\N
644	RU3583803436597484588589933917343	643	2023-09-12	IN5717246168512907538359313	внутренняя	416682.5615	298.4831	отправлена	\N
645	RU8483803436552375991404578719285	978	2023-07-08	RU7183803436584925378313266803439	внутренняя	1284696.7219	87.4976	доставлена	\N
646	RU4383803436535637847836978327691	643	2023-06-01	RU6683803436575472065287991925682	внутренняя	79154.3934	978.2329	отменена	\N
647	RU4083803436534430125114460530795	156	2023-11-21	RU7413760003398388738857224	внутренняя	7425332.4045	363.6467	отправлена	\N
648	RU1383803436537041354890218533954	840	2023-08-13	BY5344904362584350093127063	международная	3788644.1072	31.9035	отменена	IRVTUS3NXXX
649	RU8483803436576032684947735830335	978	2023-06-03	RU5983803436561671607015303339932	внутренняя	2219397.8797	582.5223	доставлена	\N
650	RU5483803436559214869633349674125	840	2023-10-26	RU9683803436579408636311341559980	внутренняя	556639.3678	760.6774	отменена	\N
651	RU7483803436591068390387769478580	356	2023-05-24	RU6983803436542868245387240901621	внутренняя	2498871.4049	745.0060	отменена	\N
652	RU5683803436564237501745383797829	398	2023-08-17	RU9683803436524115739172828059349	внутренняя	2445423.4391	961.4334	доставлена	\N
653	RU6983803436518663051613263930888	840	2023-02-01	KZ8758012781425773663379958	международная	2697564.7621	621.4714	отменена	CHASUS33
654	RU3883803436519845868206132784952	398	2023-09-29	RU8983803436543970357311304848339	внутренняя	6139512.7875	377.5221	доставлена	\N
3590	RU1883803436562141776165180370424	643	2023-05-14	PT4048585266688810987242410	внутренняя	3667865.0217	460.6824	отменена	\N
655	RU2283803436551819000625747494652	398	2023-09-22	PT6195460157455912710238830	международная	7136525.7463	852.9235	отправлена	CASPKZKAXXX
656	RU4583803436588661449801193641363	156	2023-09-14	RU5983803436563752601230784661821	внутренняя	7475823.7639	284.9023	отменена	\N
657	RU5083803436556786327042016836549	356	2023-01-18	RU3183803436556325220643083039724	внутренняя	9775899.5148	630.5345	доставлена	\N
658	RU9983803436563015974445739907644	978	2023-03-06	AL1217853071362618882812420	международная	6524043.9660	225.4959	отправлена	SOGEFRPP
659	RU5883803436537252361294139722938	643	2023-11-14	RU3085867582583879200260904	внутренняя	3369294.2077	243.9135	доставлена	\N
660	RU5883803436576828712243252221562	356	2023-02-24	RU9583803436562562119396535016715	внутренняя	1239035.0611	700.7020	отправлена	\N
661	RU6383803436519000124215462920616	978	2023-08-25	DE6219987892343496523599236	международная	6597719.6250	300.8372	доставлена	DEUTDEFFXXX
662	RU5483803436559214869633349674125	840	2023-12-26	RU9883803436596118671708861810646	внутренняя	7139016.8576	110.6279	отправлена	\N
663	RU6583803436552414284054924599360	643	2023-08-07	BY5662741771030765916214731	внутренняя	8571481.9682	891.4199	доставлена	\N
664	RU7783803436578403910419087666263	398	2023-12-26	AL4329667644079588832723717	международная	7111671.1920	504.4110	отправлена	CASPKZKAXXX
665	RU2583803436586349630493889324094	978	2023-04-06	IN4491051926817497560492128	международная	3119887.0946	908.1614	отправлена	SOGEFRPP
666	RU8983803436518961229187913059129	398	2023-06-25	RU4083803436530357399673623809331	внутренняя	7415168.8608	792.0584	отменена	\N
667	RU9383803436515318038329930627155	643	2023-07-23	RU5583803436525031727011657164177	внутренняя	6471454.9974	754.9023	отменена	\N
668	RU2683803436532775565489898182986	156	2023-07-18	RU4583803436588661449801193641363	внутренняя	2502538.2276	66.7245	отправлена	\N
669	RU8183803436566794763466227027850	356	2023-07-27	IN2324612806984578961164589	международная	9736372.0230	231.0707	доставлена	SBININBBXXX
670	RU9583803436557636243711161422858	840	2023-02-23	RU8583803436586707949034749896750	внутренняя	3180446.7175	214.8632	доставлена	\N
671	RU9583803436557636243711161422858	643	2023-09-03	RU9030459999118287386616834	внутренняя	3373812.9722	620.0604	отменена	\N
672	RU5183803436531460410872953149827	840	2023-10-17	IN8460103014280585667515973	международная	1305520.4201	284.0315	доставлена	IRVTUS3NXXX
673	RU9183803436523189940915642395180	840	2023-08-27	RU6484469528627025565229564	внутренняя	2724221.5593	409.4968	отправлена	\N
674	RU6383803436512605200896614597744	643	2023-05-08	RU5583803436556151120487866130687	внутренняя	6320398.2415	807.7804	доставлена	\N
675	RU8983803436519227550175732694863	398	2023-01-25	RU1283803436591782126481419856685	внутренняя	3045698.1622	647.5999	отправлена	\N
676	RU7583803436593274051968042799324	356	2023-02-13	AD1865138717181676484073232	международная	9092650.4704	446.0688	отменена	SBININBBXXX
677	RU8283803436536082355231514909614	978	2023-05-07	DE4483686369279836628291183	международная	1722597.1458	653.4592	отменена	RZBAATWW
678	RU1083803436563162471160560931522	840	2023-03-07	RU1183803436587920364130887563809	внутренняя	397412.9400	884.9609	доставлена	\N
679	RU8183803436555934243334630961587	840	2023-11-18	PT2122696929056346242233185	международная	5148886.4385	912.8988	отправлена	CHASUS33
680	RU3883803436559428008275215914286	156	2023-05-14	AL8454718446626355396867650	международная	9036967.7803	605.3929	отправлена	BKCHCNBJ
681	RU7483803436529598231033100377224	356	2023-01-11	AL5628101515641325406550962	международная	5865296.1606	477.9512	отправлена	SBININBBXXX
682	RU4083803436530357399673623809331	643	2023-03-14	AL1538628865532919654532105	внутренняя	4370632.1558	629.2545	отменена	\N
683	RU8883803436592173067148862634991	156	2023-04-18	RU4483803436537144245226352938256	внутренняя	2364743.1774	900.3562	отправлена	\N
684	RU8483803436546395435496825405512	840	2023-07-23	IN3624235036320240083727147	международная	3813487.4891	444.0157	отменена	CHASUS33
685	RU1183803436547102061688733775669	398	2023-07-16	RU2983803436585384738431881857607	внутренняя	418850.2909	703.4685	отменена	\N
686	RU3283803436579852018195047883736	978	2023-05-19	RU6483803436575827628326698282321	внутренняя	3504501.2582	568.2477	доставлена	\N
687	RU6483803436599929208547720213297	643	2023-05-03	IN1448851913978788430584114	внутренняя	3442001.3044	28.8054	отменена	\N
688	RU5383803436532276110708298062956	978	2023-06-01	RU9683803436511276549947859990709	внутренняя	7956167.8336	649.0823	отменена	\N
689	RU7183803436513501317784267991188	356	2023-05-03	RU4083803436525661046500520760430	внутренняя	5085003.1552	29.7371	доставлена	\N
690	RU6783803436510078136565817264354	840	2023-11-20	RU1083803436563162471160560931522	внутренняя	2527159.5874	979.6573	доставлена	\N
691	RU5983803436558435772787343054218	978	2023-06-30	AD2527792768834533038375057	международная	9725697.6910	815.9382	отправлена	SOGEFRPP
692	RU4683803436584135461455281070651	840	2023-06-17	DE4322928611615005480534131	международная	2634544.0549	575.8250	отправлена	IRVTUS3NXXX
693	RU2483803436559904294875702128517	356	2023-05-01	BY4629644387003389508561205	международная	5231395.9993	332.1303	отменена	SBININBBXXX
694	RU4583803436535138140020222748384	643	2023-07-20	RU3183803436583121152517184662518	внутренняя	2624159.9587	336.2617	отменена	\N
695	RU6783803436527708547728704282997	978	2023-04-04	BY1210771228691008879965859	международная	5314781.7300	625.4627	доставлена	RZBAATWW
696	RU1483803436552189189819570176682	978	2023-05-23	IN1752793978021275210871602	международная	6496972.0777	408.8950	отправлена	SOGEFRPP
697	RU9783803436566819882292917709885	156	2023-12-20	RU8683803436511417676206561932357	внутренняя	7907448.2933	855.9703	доставлена	\N
698	RU5983803436513359014201161572816	356	2023-01-13	IN9694637876369894415421402	международная	9585269.4476	145.4401	отправлена	SBININBBXXX
699	RU2183803436555308456329784386702	643	2023-03-25	RU2183803436586747579379810386651	внутренняя	6672946.8276	954.4844	отправлена	\N
700	RU5983803436561671607015303339932	356	2023-10-08	RU9183803436512467785925904841435	внутренняя	4738108.1010	985.7001	отправлена	\N
701	RU2683803436575198696607383546599	840	2023-12-14	RU5783803436523742307313248220811	внутренняя	5122026.3089	107.2986	доставлена	\N
702	RU1083803436588429797000364388942	978	2023-05-19	RU3283803436586063041663029658571	внутренняя	3403885.7290	72.6224	отправлена	\N
703	RU7483803436591068390387769478580	398	2023-10-02	RU4914899261473747995419520	внутренняя	1289397.3671	874.1676	отправлена	\N
704	RU6483803436557881046066137062384	398	2023-09-27	RU1129587828170063772147831	внутренняя	4295773.8369	786.6988	доставлена	\N
705	RU9383803436568402663247236595753	840	2023-03-02	RU1683803436510344781123537250392	внутренняя	201532.7531	603.9449	доставлена	\N
706	RU3883803436564256045508064629374	398	2023-04-09	AD5912633605767854548282121	международная	3953016.9119	660.2227	отменена	CASPKZKAXXX
707	RU7383803436567535429961689788567	156	2023-05-12	RU8883803436592173067148862634991	внутренняя	9430027.4428	44.6593	доставлена	\N
708	RU6183803436571932790348770462135	398	2023-07-15	RU7083803436595909521339223196614	внутренняя	3905648.8556	249.1439	отменена	\N
709	RU2783803436512588965300606208370	840	2023-08-12	RU2683803436556115738690945420927	внутренняя	5166942.8578	15.0878	отменена	\N
710	RU3283803436586063041663029658571	978	2023-03-16	RU2783803436512588965300606208370	внутренняя	201193.2315	279.0458	отменена	\N
711	RU7383803436585863943754594310819	398	2023-06-26	BY8917733644506376060120153	международная	3566500.9113	541.5483	доставлена	CASPKZKAXXX
712	RU7183803436513501317784267991188	356	2023-09-26	RU7183803436596080848426828093950	внутренняя	6700490.1528	13.1622	отменена	\N
713	RU4483803436531766422461159975910	398	2022-12-27	RU9483803436522220035875117822565	внутренняя	9397063.4355	860.4990	отправлена	\N
714	RU5983803436596779338391553657957	978	2023-07-10	KZ5097360719543208356627294	международная	6488317.3309	47.7078	отправлена	SOGEFRPP
715	RU8483803436552375991404578719285	643	2023-06-27	RU2283803436521727957364583057084	внутренняя	5767008.3490	566.3693	доставлена	\N
716	RU6583803436573484995572407857396	356	2023-02-18	RU2983803436539974076802515756241	внутренняя	8955667.2301	980.4495	отменена	\N
717	RU5183803436523181844916432548416	398	2023-02-02	BY4342008944191067094331535	международная	6671022.4435	812.8675	отменена	CASPKZKAXXX
718	RU5983803436558435772787343054218	840	2023-04-19	RU2583803436511360000518303822185	внутренняя	8019576.8815	314.1692	доставлена	\N
719	RU5983803436585678890114061651314	978	2023-08-18	KZ2238514119538010775289640	международная	1186373.9297	812.8020	отменена	DEUTDEFFXXX
720	RU7483803436591068390387769478580	156	2023-03-18	RU5483803436559214869633349674125	внутренняя	8078857.7035	731.5544	доставлена	\N
721	RU6583803436556215016292535847892	398	2023-07-06	AD6146167611063230168554884	международная	708776.1538	783.4886	отменена	CASPKZKAXXX
722	RU1083803436532178175395898264605	398	2023-01-14	RU8183803436546948351691601253240	внутренняя	554436.6018	406.5520	отправлена	\N
723	RU7683803436578953117174553181317	643	2023-07-15	RU1383803436546084241558471107471	внутренняя	5347378.4420	18.3693	отправлена	\N
724	RU6783803436582018660242960957244	840	2023-02-20	VN8945483972752028887499559	международная	6689357.7886	793.7913	отменена	IRVTUS3NXXX
725	RU6083803436569163727288631654599	643	2023-08-28	IN9369016293750532799940417	внутренняя	3628275.4933	268.2208	доставлена	\N
726	RU8483803436597380246113206833117	840	2023-03-14	VN5141735543661505667401723	международная	9092468.0192	204.4399	отменена	CHASUS33
727	RU2883803436581906276084692901201	356	2022-12-30	RU7183803436596080848426828093950	внутренняя	1878596.2635	656.5737	отменена	\N
728	RU1383803436585969091171133733533	978	2023-04-21	RU9683803436511276549947859990709	внутренняя	6086032.5775	436.0017	отправлена	\N
729	RU8683803436531608639655465618756	978	2023-01-17	RU9683803436526786707929300961979	внутренняя	4526554.7017	818.4692	отменена	\N
730	RU7183803436596080848426828093950	356	2023-04-29	RU4883803436577275200947611443039	внутренняя	5391342.6444	465.3408	отменена	\N
731	RU6283803436541447099313442593938	643	2023-05-18	RU4183803436593654490331448399606	внутренняя	1829701.9876	406.1726	доставлена	\N
732	RU7283803436583841985241060182740	398	2023-03-25	VN9319550802502139077500276	международная	6257071.4332	871.3990	отправлена	CASPKZKAXXX
733	RU2983803436510489846489627969282	840	2023-06-23	AD8031979458031102886882793	международная	485153.9805	503.1969	доставлена	IRVTUS3NXXX
734	RU5683803436564237501745383797829	643	2023-07-31	KZ8590909851579256428392502	внутренняя	1424436.9580	855.1456	доставлена	\N
735	RU8783803436519169154241731281817	643	2023-01-28	BY6039164434051320037540065	внутренняя	1664025.2393	174.4750	доставлена	\N
736	RU5983803436596779338391553657957	643	2023-12-20	RU9683803436524115739172828059349	внутренняя	9932030.5276	106.3987	отправлена	\N
737	RU3383803436540416635821116917223	643	2023-01-25	AD4814570998105979752013101	внутренняя	5699101.0725	193.5661	отменена	\N
738	RU4083803436530357399673623809331	643	2023-09-15	RU8783803436544746989208687599320	внутренняя	2214522.8652	142.5364	отправлена	\N
739	RU7183803436584925378313266803439	156	2023-05-23	IN5226685563946150445820267	международная	7265437.4316	187.9983	доставлена	BKCHCNBJ
740	RU1383803436565139777755041333233	398	2023-03-27	IN4435649079180701128480007	международная	9363083.1908	493.8174	отменена	CASPKZKAXXX
741	RU2383803436569895097903578030814	156	2023-01-05	RU6983803436557684576294868357987	внутренняя	4948376.1112	478.0752	отменена	\N
742	RU8083803436548053884024737088236	156	2023-11-04	RU6983803436521001508692071958064	внутренняя	1993887.5237	929.0287	доставлена	\N
743	RU2683803436575198696607383546599	398	2023-06-13	RU7183803436596080848426828093950	внутренняя	7417852.9150	787.1254	отменена	\N
744	RU9683803436579408636311341559980	356	2023-09-20	RU5783803436567884889437805923129	внутренняя	5522335.6744	254.5174	доставлена	\N
745	RU1683803436549082108439124677076	156	2023-10-03	RU4370742255179016084307180	внутренняя	3287728.4388	442.3504	отправлена	\N
746	RU6883803436521704893234788177503	643	2023-04-21	RU7083803436595909521339223196614	внутренняя	53088.3373	832.6505	отменена	\N
747	RU1183803436512373318427988836252	978	2023-09-29	RU7683803436578953117174553181317	внутренняя	8466994.3758	213.4824	отправлена	\N
748	RU9883803436596118671708861810646	398	2023-11-13	RU8683803436557989786811096289958	внутренняя	2589321.5326	964.0368	отправлена	\N
749	RU2983803436585384738431881857607	398	2023-03-10	KZ4597799046192773968536074	международная	8967810.9708	888.7139	отменена	CASPKZKAXXX
750	RU4583803436544769415444430855700	643	2023-05-13	RU6983803436518663051613263930888	внутренняя	54487.0430	216.4398	доставлена	\N
751	RU3983803436580604058878329162478	840	2023-05-01	RU3783803436585191546282680625888	внутренняя	6236959.6713	746.0318	доставлена	\N
752	RU6183803436571932790348770462135	356	2023-04-16	AD2722299909157527571692812	международная	4629306.2920	440.7637	отменена	SBININBBXXX
753	RU6083803436582119843499506879640	643	2023-11-24	ES8484006671997463554035334	внутренняя	7192924.7017	786.0566	отправлена	\N
754	RU5183803436588801456118987264753	398	2023-07-21	AL2494560923714729941415961	международная	7178542.5077	237.1672	отменена	CASPKZKAXXX
755	RU8583803436590890149305918634043	398	2023-12-11	AD5445102704684377373214730	международная	442417.4746	693.1927	отправлена	CASPKZKAXXX
756	RU1383803436546084241558471107471	840	2023-12-23	IN9824514151922635006764877	международная	4971999.4541	701.1592	доставлена	IRVTUS3NXXX
757	RU2283803436555228451424548337941	840	2023-07-26	RU8983803436543970357311304848339	внутренняя	3508226.2906	236.6302	доставлена	\N
758	RU6183803436573612137819734816326	978	2023-04-02	AL2570731405045519848002106	международная	512381.3362	633.5214	доставлена	RZBAATWW
759	RU8183803436576908594301902139271	978	2023-10-08	DE4193657865349410241508073	международная	7183998.7336	952.6965	отправлена	RZBAATWW
760	RU3983803436583730529285495292571	840	2023-12-25	RU6483803436595566817980742907742	внутренняя	67975.3636	297.3506	отменена	\N
761	RU6083803436583599210196850890015	840	2023-04-14	BY2549714511688600292988186	международная	1151603.3147	666.3668	отменена	IRVTUS3NXXX
762	RU6383803436519000124215462920616	978	2023-01-04	RU8074925838312194695909262	внутренняя	4003693.8772	33.2399	доставлена	\N
763	RU8083803436548053884024737088236	156	2023-06-08	KZ3589695143336121416160254	международная	5360020.1319	812.5432	доставлена	BKCHCNBJ
764	RU2883803436564862346362051659673	156	2023-12-02	RU7867087147792414390106898	внутренняя	9354548.9189	663.7750	отправлена	\N
765	RU1983803436592911874717339237016	356	2023-11-10	DE8355375938002848716501902	международная	5337500.0940	270.4430	доставлена	SBININBBXXX
766	RU2283803436588289284937975921944	398	2023-04-17	BY4834371524238380269678926	международная	2631089.8911	131.1324	доставлена	CASPKZKAXXX
767	RU9083803436527710172880684864084	978	2023-04-19	RU1683803436536773128968824249362	внутренняя	4279162.3150	360.6399	отправлена	\N
768	RU4283803436544879224116585983050	356	2023-08-25	ES9838588397448651194599245	международная	6828433.4411	93.8405	доставлена	SBININBBXXX
769	RU6283803436561107985248905256058	156	2023-03-02	DE2392227623333442197078482	международная	245362.7532	489.3103	доставлена	BKCHCNBJ
770	RU1683803436530784164352439032526	840	2023-10-22	RU8483803436523751116997614384937	внутренняя	5678166.8719	911.0189	отменена	\N
771	RU5483803436549562102902686014927	978	2023-11-03	RU6983803436518663051613263930888	внутренняя	1495424.7754	877.5221	доставлена	\N
772	RU2083803436518033160343253894367	398	2023-05-31	RU1183803436512373318427988836252	внутренняя	7410264.7916	302.7354	отменена	\N
773	RU2783803436515955219320238454317	398	2023-02-09	RU5583803436556151120487866130687	внутренняя	5811374.1145	592.7940	доставлена	\N
774	RU9683803436526786707929300961979	398	2023-12-18	RU5583803436556151120487866130687	внутренняя	6055290.1962	688.2324	доставлена	\N
775	RU5783803436523742307313248220811	356	2023-04-08	RU9683803436541591047480784615833	внутренняя	404540.2153	34.6076	отправлена	\N
776	RU1683803436543683792461716245841	398	2023-06-12	IN9460932561376901402246810	международная	2642751.0459	736.8550	отменена	CASPKZKAXXX
777	RU5683803436575772290627280121203	978	2023-11-29	ES9222812941497738088823252	международная	808132.8495	147.5231	отправлена	RZBAATWW
778	RU3683803436529963181547651499120	643	2023-03-21	IN8667089128239839805312618	внутренняя	3032593.5960	269.4772	отправлена	\N
779	RU3183803436522808312515599877028	840	2023-07-08	AL1539996389337770055465873	международная	5987338.9627	919.7025	отменена	IRVTUS3NXXX
780	RU5583803436533254773648721597711	643	2023-04-05	RU8583803436590890149305918634043	внутренняя	4370405.7934	423.2920	отправлена	\N
781	RU4383803436597428452957764955765	156	2023-01-20	IN4411122894810869329853907	международная	8941968.6652	257.4230	отменена	BKCHCNBJ
782	RU9583803436589245078784775619456	978	2023-01-09	RU1683803436543683792461716245841	внутренняя	4980477.8084	786.0287	отправлена	\N
783	RU8183803436559528710172368223769	840	2023-12-25	RU7483803436512314763652680872976	внутренняя	9656701.1409	799.8257	отменена	\N
784	RU6783803436582018660242960957244	643	2023-02-10	RU3583803436580986023375789999847	внутренняя	7528553.3127	594.9559	отправлена	\N
785	RU3083803436518573891716312234719	978	2023-09-24	PT1744097948883983777324815	международная	3157766.3712	0.0000	отправлена	DEUTDEFFXXX
786	RU8183803436576334203563049364101	356	2023-11-23	RU5083803436521160540176223483455	внутренняя	4121591.4474	374.3594	отменена	\N
787	RU5283803436570838144716210841495	398	2023-11-06	RU6543181526182018692924726	внутренняя	6597369.9064	142.4000	отправлена	\N
788	RU1283803436591782126481419856685	398	2023-06-21	RU4941008718442782955278735	внутренняя	2508040.2987	353.9242	отменена	\N
789	RU4883803436561825246742556433732	643	2023-05-13	BY6984683237459646021993242	внутренняя	2203039.3991	874.0791	отправлена	\N
790	RU5583803436541779385547740767657	156	2023-01-11	RU5783803436573951128453151787227	внутренняя	8205406.3949	532.5743	доставлена	\N
791	RU5083803436556786327042016836549	840	2023-02-06	RU9883803436510697875492928159959	внутренняя	7585349.3737	978.4092	отменена	\N
792	RU4483803436593534887929979895004	643	2023-01-08	ES5484228731534499043057797	внутренняя	574843.0349	514.5912	отменена	\N
793	RU8883803436542351475891948314875	398	2023-01-20	BY2390025354805104423231677	международная	8334668.6437	456.2640	отменена	CASPKZKAXXX
794	RU4083803436530357399673623809331	978	2023-10-01	RU4583803436544769415444430855700	внутренняя	267446.6795	772.0857	доставлена	\N
795	RU1683803436530784164352439032526	398	2023-02-03	RU8083803436548053884024737088236	внутренняя	6615181.3268	554.1114	отправлена	\N
796	RU9383803436563463129216774786629	156	2023-09-13	AD9754681307406722435857769	международная	3688008.3321	489.1726	отправлена	BKCHCNBJ
797	RU3083803436518573891716312234719	398	2023-05-14	AD5071512994877191158873586	международная	2817326.4501	192.5057	отправлена	CASPKZKAXXX
798	RU7283803436528848493351990702937	356	2023-12-01	RU4383803436557380827011382643653	внутренняя	64646.8629	746.8155	доставлена	\N
799	RU3883803436559428008275215914286	356	2023-08-05	RU8583803436580493050529274956761	внутренняя	9846401.8188	26.4019	отправлена	\N
800	RU6983803436518663051613263930888	356	2023-12-24	ES3472636293653877696506253	международная	9649157.5472	917.7112	доставлена	SBININBBXXX
801	RU6183803436573612137819734816326	978	2023-12-11	RU2883803436564862346362051659673	внутренняя	5466427.7075	617.8742	отменена	\N
802	RU6883803436524866655852609791727	356	2023-07-30	VN3962529777410349804566435	международная	5844562.7392	763.7523	доставлена	SBININBBXXX
803	RU7383803436567535429961689788567	156	2023-06-14	PT8513911452398944837728375	международная	4397588.0779	897.5708	доставлена	BKCHCNBJ
804	RU9883803436580908913943520973504	840	2022-12-30	AD1953792681578797769307898	международная	2849369.9394	993.5100	доставлена	IRVTUS3NXXX
805	RU2883803436510195395163379960366	643	2023-09-25	RU9783803436566819882292917709885	внутренняя	3198274.5966	137.4877	отменена	\N
806	RU6483803436527000884469712767990	156	2023-07-04	VN1911636246621891817736536	международная	4823365.4821	358.2391	доставлена	BKCHCNBJ
807	RU4283803436515276086545867508581	978	2023-10-22	RU1183803436587920364130887563809	внутренняя	8380186.9395	224.8823	отправлена	\N
808	RU9683803436579408636311341559980	398	2023-06-07	IN8060984129302548400255699	международная	6844795.4288	925.8705	отправлена	CASPKZKAXXX
809	RU6383803436599902939219818792376	643	2023-01-04	RU3010393692072743412882452	внутренняя	6672192.6942	237.4031	доставлена	\N
810	RU5983803436518386216122030936247	840	2023-02-09	IN4718090039495688208311437	международная	6530671.5367	436.9677	отправлена	IRVTUS3NXXX
811	RU4383803436594641659799774635872	398	2023-05-17	DE8953889719846842525976842	международная	3246157.1940	576.5242	отменена	CASPKZKAXXX
812	RU4083803436530357399673623809331	156	2023-09-28	RU6883803436524866655852609791727	внутренняя	4483665.5124	627.4116	отправлена	\N
813	RU6083803436583599210196850890015	156	2023-10-15	RU8983803436519227550175732694863	внутренняя	5048786.7235	788.3225	отменена	\N
814	RU1583803436513968949783488654583	978	2023-06-03	ES3772456128301026880099131	международная	9850177.2142	211.6964	доставлена	SOGEFRPP
815	RU9683803436559214297350823715344	356	2023-06-10	DE8495545749747088095681576	международная	9525910.7226	204.6701	отправлена	SBININBBXXX
816	RU2983803436597155052344917689453	356	2023-06-03	VN3580855674356188802001635	международная	6986453.0755	782.8998	отправлена	SBININBBXXX
817	RU8183803436513368239655842198331	840	2023-01-04	RU7183803436596080848426828093950	внутренняя	5782758.3615	947.3149	отменена	\N
818	RU7483803436581386287039618321410	643	2023-07-06	RU4583803436546993711061481413708	внутренняя	1753322.5032	493.2930	отменена	\N
819	RU2983803436596711612246779730808	643	2023-12-17	RU9983803436515137760640096699879	внутренняя	7241301.5376	380.1027	отправлена	\N
820	RU5983803436585678890114061651314	398	2023-03-26	RU8283803436517214496879594083501	внутренняя	1885633.0483	529.2049	отправлена	\N
821	RU1683803436549082108439124677076	840	2023-10-25	KZ2029768581944852650948310	международная	3882002.0096	51.7126	отменена	IRVTUS3NXXX
822	RU4783803436576956010684046744289	356	2023-11-23	IN4116559163875033602607655	международная	6369126.9749	121.9051	отправлена	SBININBBXXX
823	RU7483803436516612664745741202549	156	2023-12-18	RU4783803436556925313909023616425	внутренняя	9836959.2706	208.7166	отменена	\N
824	RU5883803436537252361294139722938	978	2023-11-17	BY9774925374892003243346754	международная	7699479.7374	860.6947	отменена	RZBAATWW
825	RU3183803436522808312515599877028	398	2023-03-20	VN8711864762751900468266829	международная	7769761.7687	727.9813	доставлена	CASPKZKAXXX
826	RU3383803436551883036237842733910	978	2023-11-20	BY5422945402111350377752370	международная	9280785.6656	429.0857	отправлена	DEUTDEFFXXX
827	RU1183803436587920364130887563809	156	2023-04-16	BY8335284602560628474815922	международная	9865512.6599	879.1330	отправлена	BKCHCNBJ
828	RU8583803436586707949034749896750	398	2023-03-12	RU3183803436545750333950215053352	внутренняя	8986407.8973	499.0895	отменена	\N
829	RU4283803436530972916151822377436	156	2023-07-26	VN6757806719029682538116433	международная	3397221.1677	218.3391	отменена	BKCHCNBJ
830	RU9983803436581801115411623274695	643	2023-11-29	RU1983803436558651220197686454204	внутренняя	658400.5371	320.7017	отменена	\N
831	RU5083803436537344339331652897359	156	2023-08-14	RU7183803436551143317683635788042	внутренняя	6552111.7676	970.3120	отменена	\N
832	RU8383803436583878629872361871714	356	2023-09-27	RU7945271943160199558842789	внутренняя	5649836.3536	366.5176	отправлена	\N
833	RU5883803436576828712243252221562	978	2023-08-01	KZ3568040087497384809518474	международная	1679533.3728	965.3006	отправлена	DEUTDEFFXXX
834	RU3883803436564256045508064629374	643	2023-07-30	BY9938530048178504882520923	внутренняя	6865872.8553	155.9858	отправлена	\N
835	RU6983803436517488129268543865126	643	2023-10-27	VN1518366604466167064363885	внутренняя	5997764.0512	226.4657	доставлена	\N
836	RU9783803436586848496167067081204	978	2023-09-30	BY6860353313569934199956049	международная	891041.0865	294.1517	отправлена	RZBAATWW
837	RU1983803436558651220197686454204	156	2023-09-15	RU5583803436556151120487866130687	внутренняя	6559120.6153	881.6973	доставлена	\N
838	RU8983803436588264357315670765686	978	2023-04-10	RU3883803436554504516286459147223	внутренняя	4353038.5795	674.3512	доставлена	\N
839	RU8483803436576032684947735830335	398	2023-07-09	RU3983803436583730529285495292571	внутренняя	7805021.2777	991.0910	отменена	\N
840	RU1983803436549890414007715363567	840	2023-06-15	DE7923276508071080894097062	международная	1235145.7701	150.2801	отменена	IRVTUS3NXXX
841	RU1583803436592948110594062864167	398	2023-12-15	RU7183803436513501317784267991188	внутренняя	6213725.5174	500.5955	отменена	\N
842	RU2583803436511360000518303822185	156	2023-09-18	PT4594831511571512665879394	международная	8649162.2855	363.4389	отправлена	BKCHCNBJ
843	RU8383803436557193853878723819444	156	2023-09-24	RU1183803436513944372774322746458	внутренняя	5847935.3152	608.6127	доставлена	\N
844	RU1183803436587920364130887563809	643	2023-09-26	VN8177910917025067856352886	внутренняя	2207950.7490	896.3222	отменена	\N
845	RU1983803436549890414007715363567	156	2023-02-01	KZ9827976007788586432797423	международная	180589.2176	109.0286	отправлена	BKCHCNBJ
846	RU3283803436586063041663029658571	978	2023-05-04	ES6165577738941544437495136	международная	4849184.1806	928.5425	отправлена	DEUTDEFFXXX
847	RU5683803436581377733469772235779	156	2023-05-01	RU1983803436537997284898110055528	внутренняя	7520189.3403	70.2198	отменена	\N
848	RU2583803436510413813910694958748	978	2023-09-23	VN8573618528746810310684875	международная	7182131.5005	742.7914	отправлена	SOGEFRPP
849	RU1383803436585969091171133733533	156	2023-04-20	DE6916503998872454378365891	международная	7416955.1194	357.7976	доставлена	BKCHCNBJ
850	RU5083803436537344339331652897359	356	2023-11-05	RU2883803436510195395163379960366	внутренняя	3578658.0049	785.9447	отправлена	\N
851	RU7183803436535160662680026565691	643	2023-10-04	DE1436080097704739981600342	внутренняя	931264.5209	536.1323	отменена	\N
852	RU6983803436580831999013679742086	356	2023-02-18	AD7598201141067836028108344	международная	123809.2961	565.4613	доставлена	SBININBBXXX
853	RU6583803436588261503476787515721	643	2023-01-24	RU4883803436561825246742556433732	внутренняя	5496337.8589	434.4376	отправлена	\N
854	RU6383803436517724803474176712817	356	2023-01-02	BY7291099601701514592755331	международная	663426.0674	653.4871	отправлена	SBININBBXXX
855	RU3483803436537283842522563725379	978	2023-01-28	BY4689145232313541676227228	международная	1351137.7237	78.9000	отправлена	DEUTDEFFXXX
856	RU9683803436571883645805733128714	643	2023-01-18	RU7183803436551143317683635788042	внутренняя	5297917.5284	601.3140	отменена	\N
857	RU7783803436529059332090835348557	156	2023-05-23	PT3595639903903707108954287	международная	930059.1679	20.7074	отправлена	BKCHCNBJ
858	RU9883803436580908913943520973504	156	2023-07-26	ES2592985679779735393085361	международная	6137572.1883	622.8919	отправлена	BKCHCNBJ
859	RU3383803436527231938190662146888	156	2023-05-27	PT8324060388529188184008040	международная	5436492.0271	802.9683	доставлена	BKCHCNBJ
860	RU8783803436544746989208687599320	356	2023-05-05	RU1483803436555535016685486735994	внутренняя	2072480.0303	447.2092	доставлена	\N
861	RU5983803436585678890114061651314	643	2023-02-13	ES9654661523519341922937218	внутренняя	2630710.4341	697.1058	отправлена	\N
862	RU9583803436589245078784775619456	978	2023-12-08	VN4597223242154356914501972	международная	3387463.4368	516.7248	доставлена	DEUTDEFFXXX
863	RU9783803436586848496167067081204	398	2023-07-08	ES4842760288798945909422507	международная	8586712.4818	607.2493	отменена	CASPKZKAXXX
864	RU9083803436527710172880684864084	356	2023-06-28	RU4583803436546993711061481413708	внутренняя	5937460.1574	769.8620	доставлена	\N
865	RU5183803436588801456118987264753	840	2023-09-06	RU2483803436550335144467075253432	внутренняя	9559715.2370	714.6487	доставлена	\N
866	RU1183803436569972795023903837949	398	2023-12-12	BY1690949839184540005572365	международная	1115907.5636	337.2855	отправлена	CASPKZKAXXX
867	RU8483803436583598027317615125571	398	2023-02-05	PT4522249758854818793346152	международная	7390503.8731	186.3159	отправлена	CASPKZKAXXX
868	RU3683803436526413764026311806751	398	2023-10-22	RU2183803436538160023828199079683	внутренняя	2038145.9948	395.4476	отменена	\N
869	RU4983803436534576819154749347962	840	2023-07-17	VN9269977719914396211299215	международная	2078911.7856	118.9227	доставлена	IRVTUS3NXXX
870	RU8483803436523751116997614384937	840	2023-10-28	RU3783803436562139250445157080524	внутренняя	7838010.7795	326.3706	отменена	\N
871	RU5183803436599553165549416662045	356	2023-09-28	RU3583803436597484588589933917343	внутренняя	1491517.7527	932.2196	доставлена	\N
872	RU9883803436580908913943520973504	978	2023-11-25	BY4021627059421004472345990	международная	3983810.9996	375.8093	доставлена	RZBAATWW
873	RU2383803436569895097903578030814	156	2023-10-13	KZ4418516108738099960436099	международная	1858094.1841	415.4917	доставлена	BKCHCNBJ
874	RU4283803436544879224116585983050	978	2023-12-03	AD6773270216336221677772219	международная	4274281.7621	214.3578	отменена	RZBAATWW
875	RU5483803436551418630110242560620	156	2023-04-26	ES5071819132380770096441789	международная	3480407.8216	259.0088	отправлена	BKCHCNBJ
876	RU1583803436522600904788279282430	978	2023-11-01	RU2583803436569716293278278112122	внутренняя	2609197.2071	146.3750	отменена	\N
877	RU2283803436555228451424548337941	156	2023-08-21	DE4443622361808362196851383	международная	5917037.0815	757.2967	отменена	BKCHCNBJ
878	RU5983803436565674700991182664479	398	2023-12-01	RU2483803436550335144467075253432	внутренняя	7134006.6233	490.4242	отменена	\N
879	RU5283803436570838144716210841495	643	2023-07-22	RU5183803436573013692902081587761	внутренняя	1923928.6025	176.9939	отменена	\N
880	RU6783803436582018660242960957244	398	2023-09-22	RU5483803436551418630110242560620	внутренняя	2704911.4345	75.6770	отправлена	\N
881	RU5183803436585063037953141711870	840	2023-11-07	ES5851559566517335532383535	международная	7369918.9894	95.6445	доставлена	IRVTUS3NXXX
882	RU8583803436598717986670697262250	156	2023-05-15	ES2311861732973312814044679	международная	1051033.5831	660.9628	отменена	BKCHCNBJ
883	RU2583803436586349630493889324094	978	2023-10-03	RU5183803436531460410872953149827	внутренняя	6061561.4410	577.1669	отправлена	\N
884	RU4883803436561825246742556433732	398	2023-07-01	RU2583803436510413813910694958748	внутренняя	9209314.2759	121.2360	доставлена	\N
885	RU2983803436510489846489627969282	840	2023-12-19	VN2352554679115266086882642	международная	5287933.0594	562.4176	отправлена	IRVTUS3NXXX
886	RU8483803436528403655778834568144	643	2023-02-28	AD3982699085284023204190738	внутренняя	8799184.7904	101.8886	отменена	\N
887	RU3383803436551883036237842733910	643	2023-10-19	RU3183803436538368625987340316428	внутренняя	2719486.5721	94.2892	отправлена	\N
888	RU6883803436524866655852609791727	156	2023-04-15	RU2283803436555228451424548337941	внутренняя	1054270.7799	469.6178	отправлена	\N
889	RU2083803436593214630941740939011	398	2023-05-12	RU5883803436576828712243252221562	внутренняя	1247321.7286	755.1607	доставлена	\N
890	RU8583803436567351126582917385267	156	2023-09-23	RU9783803436566819882292917709885	внутренняя	9496283.4110	684.3085	отправлена	\N
891	RU2183803436538160023828199079683	356	2023-03-29	RU4483803436574648344464338946055	внутренняя	9191632.8153	467.4507	отправлена	\N
892	RU2983803436585384738431881857607	643	2023-03-02	RU7283803436565335970635584506660	внутренняя	9123660.6356	57.0028	отменена	\N
893	RU4483803436574648344464338946055	398	2023-05-25	ES5886583979867072992722803	международная	7018210.0527	994.0621	доставлена	CASPKZKAXXX
894	RU6983803436517488129268543865126	978	2023-04-30	AL1642149803988371528753135	международная	1448702.7124	962.6617	отменена	RZBAATWW
895	RU8183803436576334203563049364101	643	2022-12-30	AL3921913409143143475955945	внутренняя	1166532.1365	708.6099	отправлена	\N
896	RU5183803436523181844916432548416	840	2023-07-12	RU6883803436524866655852609791727	внутренняя	5468962.8680	576.9915	отправлена	\N
897	RU7383803436515152831562897371432	978	2023-09-05	RU1223523204368356571529683	внутренняя	7316535.6367	113.2495	отправлена	\N
898	RU6983803436580831999013679742086	356	2023-08-23	RU4183803436593654490331448399606	внутренняя	7337918.5018	537.2530	отменена	\N
899	RU7183803436578006903833632767386	356	2022-12-31	RU2983803436545911307181108696312	внутренняя	9254339.9559	318.0990	отправлена	\N
900	RU6283803436577836700807681117407	398	2023-10-28	RU2583803436569716293278278112122	внутренняя	144313.5543	63.7790	отменена	\N
901	RU3783803436562091905141244310726	643	2023-12-11	AL9696022858939016764494823	внутренняя	1034341.6830	547.4339	отменена	\N
902	RU6083803436583599210196850890015	643	2023-06-20	BY6126625659058701247334535	внутренняя	3072241.0075	820.9642	доставлена	\N
903	RU9683803436579408636311341559980	156	2023-02-21	BY5657054656238457112105115	международная	4441773.3941	687.1735	доставлена	BKCHCNBJ
904	RU1383803436565139777755041333233	978	2023-05-11	PT4252971111848100322713108	международная	815180.1061	580.7829	отменена	DEUTDEFFXXX
905	RU2183803436555308456329784386702	978	2023-04-30	RU3583803436597484588589933917343	внутренняя	1506878.7195	315.2217	отправлена	\N
906	RU5083803436563140090168469536649	643	2023-03-14	PT7217793075056485872026563	внутренняя	3673978.8215	311.8247	доставлена	\N
907	RU9583803436537234117226554935344	840	2023-08-23	AD2899729186617476088308780	международная	7363855.5073	263.4868	отменена	IRVTUS3NXXX
908	RU2783803436512588965300606208370	840	2023-03-20	RU2983803436572636545308279163382	внутренняя	9892494.8994	574.3278	доставлена	\N
909	RU8183803436566794763466227027850	978	2023-10-15	RU3083803436556733352794187735054	внутренняя	5225228.4713	168.4936	отменена	\N
910	RU7383803436585863943754594310819	156	2023-12-18	RU6383803436519000124215462920616	внутренняя	326833.7538	567.3641	доставлена	\N
911	RU4283803436512174946847064448344	978	2023-01-14	RU3583803436597484588589933917343	внутренняя	8125156.7291	944.6984	отменена	\N
912	RU9083803436527710172880684864084	978	2023-05-22	IN3018041758975779264434349	международная	8727402.2847	834.8137	отменена	DEUTDEFFXXX
913	RU5683803436573106663960342062340	840	2023-04-08	VN8759412499432264655289701	международная	8064276.8772	674.5762	отправлена	IRVTUS3NXXX
914	RU7483803436595027677837710467368	978	2023-04-02	RU9683803436524115739172828059349	внутренняя	7664616.2422	959.1539	отменена	\N
915	RU9683803436520170153501466272589	840	2023-10-11	RU1383803436585969091171133733533	внутренняя	520997.8072	710.6220	доставлена	\N
916	RU4583803436576777630615652907536	156	2023-05-16	RU6466381739041875786965656	внутренняя	8770915.8846	987.0045	отправлена	\N
917	RU3483803436534657689181631833463	978	2023-03-13	ES3893791296022148410307687	международная	6807943.1207	865.8404	отправлена	RZBAATWW
918	RU1283803436545193525808988988532	978	2023-10-10	AL7589493656251827912034784	международная	6064411.1440	690.7593	отменена	DEUTDEFFXXX
919	RU4983803436522833268295991391237	398	2023-04-08	RU7683803436589524723383129532286	внутренняя	2023240.9801	402.1367	отправлена	\N
920	RU2483803436550335144467075253432	643	2023-12-15	RU9983803436588442958405952112241	внутренняя	6865575.5151	79.5212	доставлена	\N
921	RU2683803436566742853200336170327	356	2023-09-19	BY7088267288094402721040805	международная	5539758.0281	905.5971	отправлена	SBININBBXXX
922	RU9483803436585469145832242711561	643	2022-12-30	RU7283803436565335970635584506660	внутренняя	2184940.5932	817.8852	отправлена	\N
923	RU5783803436568341660520010753753	356	2023-09-17	RU7483803436595528340078834029783	внутренняя	1012467.9971	187.9880	доставлена	\N
924	RU9883803436510697875492928159959	643	2023-12-24	PT9654544094756323155366633	внутренняя	364409.7048	767.5661	отправлена	\N
925	RU7683803436565241249132549566386	840	2023-12-04	RU7183803436546875767014611813689	внутренняя	2104948.2021	723.1144	доставлена	\N
926	RU4483803436593534887929979895004	398	2023-06-24	RU6383803436519000124215462920616	внутренняя	1167422.5447	617.3317	отменена	\N
927	RU5383803436537654175631942789109	978	2023-06-13	RU2083803436571871160330810400191	внутренняя	6252555.1532	48.3222	доставлена	\N
928	RU9683803436520170153501466272589	398	2023-01-15	RU2083803436571871160330810400191	внутренняя	7144838.6118	413.9953	отправлена	\N
929	RU1883803436562141776165180370424	356	2023-01-07	DE9379371331682114785337168	международная	5863459.8403	444.6235	доставлена	SBININBBXXX
930	RU6383803436519000124215462920616	398	2023-04-25	IN7057051801255950295239872	международная	7150865.8699	52.6854	отменена	CASPKZKAXXX
931	RU5483803436547543071206231343471	398	2023-05-26	AD3435673316053249589938620	международная	2372639.0221	187.0606	отправлена	CASPKZKAXXX
932	RU5483803436547543071206231343471	398	2023-11-10	RU6683803436575472065287991925682	внутренняя	5435210.6726	866.5782	отправлена	\N
933	RU5183803436599553165549416662045	398	2023-12-18	KZ8791554025468360653905617	международная	2633341.8021	591.4136	отправлена	CASPKZKAXXX
934	RU3183803436545750333950215053352	156	2023-07-04	RU1883803436547883958852583813660	внутренняя	6630863.2252	762.7295	отменена	\N
935	RU5783803436523742307313248220811	840	2023-07-01	RU4383803436559640804885433764330	внутренняя	4048095.6295	715.0621	отправлена	\N
936	RU3983803436583730529285495292571	356	2023-12-20	RU8510145448615042769544271	внутренняя	4980043.4075	527.2632	отменена	\N
937	RU6983803436596433824452063468541	978	2023-11-11	VN9061414921089810509752300	международная	7083875.4225	494.2006	доставлена	DEUTDEFFXXX
938	RU6883803436521704893234788177503	978	2023-12-14	RU4583803436567844239839748091371	внутренняя	4285384.8116	752.0411	отправлена	\N
939	RU8483803436517523304653033637180	840	2023-06-02	VN4768635971319007889105524	международная	2931978.9586	653.1441	отменена	CHASUS33
940	RU3083803436518573891716312234719	356	2023-03-26	RU8158071367661977245230203	внутренняя	9237311.1652	981.5230	отменена	\N
941	RU9783803436566819882292917709885	398	2023-09-03	KZ4859636023935097891341125	международная	8425852.4816	80.5949	доставлена	CASPKZKAXXX
942	RU4083803436534430125114460530795	978	2023-03-20	AD5257008225741358356932607	международная	9835986.1078	431.9904	доставлена	SOGEFRPP
943	RU9883803436510697875492928159959	356	2023-04-29	RU3783803436562091905141244310726	внутренняя	3656373.5139	528.9290	доставлена	\N
944	RU2883803436581906276084692901201	978	2023-06-19	RU2583803436586349630493889324094	внутренняя	4272581.9665	525.7148	отправлена	\N
945	RU8183803436576334203563049364101	840	2023-02-16	IN2270460836945043514467751	международная	5745637.8263	432.3653	отправлена	IRVTUS3NXXX
946	RU5983803436585678890114061651314	398	2023-02-06	RU6183803436536163842184020816729	внутренняя	7361134.6857	816.7395	доставлена	\N
947	RU1583803436578714315409224923820	156	2023-12-11	RU5883803436576828712243252221562	внутренняя	9081230.1359	922.4331	отправлена	\N
948	RU6483803436575827628326698282321	156	2023-11-29	PT2183296013145273260013365	международная	7257388.1378	774.9845	отменена	BKCHCNBJ
949	RU6783803436583735354795738130605	978	2023-01-03	RU2283803436588289284937975921944	внутренняя	4489659.2752	666.1022	доставлена	\N
950	RU1983803436592911874717339237016	840	2023-02-20	BY6444336368736450995088182	международная	2280412.7582	447.8230	отменена	CHASUS33
951	RU2583803436511360000518303822185	840	2023-02-14	RU5783803436553735504938098098542	внутренняя	3614218.9126	140.6000	отменена	\N
952	RU8583803436548069379320039967893	643	2023-04-05	RU8028883507812813640223870	внутренняя	2680896.8023	59.2037	доставлена	\N
953	RU4083803436537218400436107027314	840	2023-07-03	AD7288875763740419921201341	международная	7933191.8467	259.4797	отменена	CHASUS33
954	RU7283803436565335970635584506660	978	2023-12-09	RU9683803436597203099828784600586	внутренняя	863783.7511	47.6562	доставлена	\N
955	RU5683803436522754650880470438385	356	2023-04-29	RU7183803436551143317683635788042	внутренняя	668616.7284	646.5050	отправлена	\N
956	RU3683803436521305656177527242839	978	2023-05-05	RU4083803436526038486689011711230	внутренняя	6141762.6325	977.6672	отменена	\N
957	RU1583803436597114679330016317094	356	2023-05-12	IN6898775693567225333772110	международная	9592312.5067	317.9098	доставлена	SBININBBXXX
958	RU9583803436537234117226554935344	356	2023-06-15	RU9883803436510697875492928159959	внутренняя	4817362.9530	742.2956	отправлена	\N
959	RU6783803436534011789886956964173	356	2023-09-02	RU5083803436521160540176223483455	внутренняя	7686338.0697	204.1687	доставлена	\N
960	RU4583803436535138140020222748384	840	2023-05-18	AD8332487789964269597354148	международная	3303392.5028	585.5840	отправлена	IRVTUS3NXXX
961	RU5583803436525031727011657164177	356	2023-12-12	DE3970212644775163979532849	международная	1330913.8044	693.6395	доставлена	SBININBBXXX
962	RU7783803436557425582753958788900	398	2023-04-12	IN3969694216433549147397195	международная	7875485.7634	37.0632	отправлена	CASPKZKAXXX
963	RU5883803436537252361294139722938	643	2023-12-03	RU2883803436538134433783624054557	внутренняя	4305368.8787	164.3821	отправлена	\N
964	RU6583803436556215016292535847892	643	2023-05-04	RU1583803436578714315409224923820	внутренняя	8109671.2386	833.3173	доставлена	\N
965	RU4383803436583134155448910498762	156	2023-03-29	VN6964291801251712540953724	международная	7647586.3688	553.6745	отменена	BKCHCNBJ
966	RU7783803436529059332090835348557	156	2023-10-31	ES1762691705059802487121719	международная	613170.4843	79.7022	доставлена	BKCHCNBJ
967	RU1583803436592948110594062864167	356	2023-04-16	AD3396020651023907410564646	международная	7552241.0146	926.0657	доставлена	SBININBBXXX
968	RU2883803436564862346362051659673	643	2023-09-10	RU5683803436522754650880470438385	внутренняя	3628966.3598	757.2301	доставлена	\N
969	RU4083803436537218400436107027314	356	2023-12-08	RU1183803436512373318427988836252	внутренняя	8685680.8816	585.0182	отправлена	\N
970	RU6983803436521001508692071958064	398	2023-01-31	AL7567888118513968655440661	международная	938106.6345	329.3400	доставлена	CASPKZKAXXX
971	RU4183803436575456526806163894045	356	2022-12-30	RU1283803436521770311179326367954	внутренняя	2277716.6130	154.2302	отправлена	\N
972	RU4983803436548786021946522460624	398	2023-07-12	AL7757933293772301964922118	международная	1771909.2006	0.0000	отправлена	CASPKZKAXXX
973	RU2383803436518501918755699207235	643	2023-11-25	PT7495936176782230032813943	внутренняя	3130522.2908	779.0458	отправлена	\N
974	RU8983803436513229118545499417330	978	2023-08-05	DE4569969275008828776337432	международная	6891713.3288	42.3943	отправлена	RZBAATWW
975	RU5583803436533254773648721597711	840	2023-12-18	RU4183803436593654490331448399606	внутренняя	1717047.4158	366.9928	отправлена	\N
976	RU7683803436578953117174553181317	356	2023-08-18	KZ5555399603257213193071437	международная	7537668.9250	932.5695	отменена	SBININBBXXX
977	RU5083803436537344339331652897359	398	2023-05-12	PT8232372772138813034414700	международная	2313248.0919	806.7904	доставлена	CASPKZKAXXX
978	RU8583803436580493050529274956761	156	2023-11-30	AL1649210633360521007970428	международная	2088871.4008	545.8550	доставлена	BKCHCNBJ
979	RU6583803436592149423686806465410	356	2023-03-14	RU2883803436510195395163379960366	внутренняя	8778320.1311	759.5321	отправлена	\N
980	RU2983803436572678251629055132350	840	2023-08-02	ES7760919473636768326976003	международная	2730800.8588	559.1487	доставлена	IRVTUS3NXXX
981	RU1683803436536773128968824249362	643	2023-08-24	RU5383803436532276110708298062956	внутренняя	2447173.2526	577.7073	отправлена	\N
982	RU4883803436577275200947611443039	398	2023-07-05	RU5783803436568341660520010753753	внутренняя	9365282.3517	230.6176	отправлена	\N
983	RU7683803436578953117174553181317	398	2023-06-22	RU8563257972166462069525994	внутренняя	8032964.4411	934.0691	доставлена	\N
984	RU3683803436589669964829443545971	398	2023-01-27	RU7783803436578403910419087666263	внутренняя	7327757.6131	550.9987	отправлена	\N
985	RU8783803436519169154241731281817	978	2023-04-19	RU4583803436567844239839748091371	внутренняя	1439174.7103	912.6066	отменена	\N
986	RU4083803436526038486689011711230	156	2023-02-20	DE3425191989247734806457150	международная	9863914.4146	384.6163	доставлена	BKCHCNBJ
987	RU4183803436575456526806163894045	156	2023-08-13	AL6539117549334520033651859	международная	1002851.9500	98.9156	отменена	BKCHCNBJ
988	RU8483803436523751116997614384937	398	2023-06-04	RU6183803436547326038705936576601	внутренняя	5451102.3717	678.7825	отправлена	\N
989	RU8983803436519227550175732694863	356	2023-09-14	RU9583803436547610609904791788853	внутренняя	2910613.1948	132.0514	доставлена	\N
990	RU2583803436573489146610412814439	398	2023-08-13	RU3683803436589669964829443545971	внутренняя	7006921.8908	342.3842	отменена	\N
991	RU6983803436518663051613263930888	643	2023-11-25	RU1383803436565139777755041333233	внутренняя	3746439.0185	142.5975	доставлена	\N
992	RU5383803436537654175631942789109	978	2023-04-16	RU8183803436584325139466333599286	внутренняя	7617711.4525	461.0438	отменена	\N
993	RU5983803436513359014201161572816	356	2023-11-06	DE2044458823331948486468275	международная	7727356.0191	905.1272	отменена	SBININBBXXX
994	RU8683803436531608639655465618756	840	2023-11-16	RU1383803436523658112524214881297	внутренняя	6428010.2173	398.3643	отменена	\N
995	RU9683803436511276549947859990709	398	2023-04-07	RU5883803436571013870275428717873	внутренняя	2376960.2080	826.6543	доставлена	\N
996	RU1383803436523658112524214881297	978	2023-10-08	RU4783803436556925313909023616425	внутренняя	9191175.5075	798.9874	доставлена	\N
997	RU6783803436527708547728704282997	840	2023-06-21	RU6183803436551232797419519235346	внутренняя	9852123.3636	362.2650	отправлена	\N
998	RU9683803436524115739172828059349	978	2023-10-22	RU2983803436510489846489627969282	внутренняя	3058277.0427	519.0887	отменена	\N
999	RU4183803436544525596730636267692	398	2023-03-29	PT9589221198258093459372673	международная	556645.9173	91.2427	отменена	CASPKZKAXXX
1000	RU3983803436554516084539411139147	978	2023-04-20	PT7569632643780842761405596	международная	3414731.0651	434.9991	отменена	DEUTDEFFXXX
1001	RU3783803436562091905141244310726	398	2023-12-08	RU9583803436589245078784775619456	внутренняя	9906495.8870	901.2775	отменена	\N
1002	RU5183803436588244188761426669013	156	2023-12-20	RU7783803436585076163513647706071	внутренняя	1353155.5146	842.9111	доставлена	\N
1003	RU8883803436592173067148862634991	643	2023-08-21	ES5964963592371535764144234	внутренняя	8258300.9779	434.9762	доставлена	\N
1004	RU5483803436538988818998904026382	978	2023-07-23	KZ5530036035465518221892434	международная	6731577.9289	908.9039	отправлена	RZBAATWW
1005	RU6583803436573484995572407857396	840	2023-05-16	DE7366043763912222452338653	международная	980141.8917	883.1866	отменена	CHASUS33
1006	RU8183803436584325139466333599286	398	2023-03-10	BY4947014681303147663057168	международная	6293971.9249	600.2589	отправлена	CASPKZKAXXX
1007	RU1683803436549082108439124677076	356	2023-11-18	RU8183803436555934243334630961587	внутренняя	5025508.7286	641.2443	отменена	\N
1008	RU1583803436522600904788279282430	978	2023-01-14	AL8011835546827738082226314	международная	1953531.5025	410.1401	отправлена	DEUTDEFFXXX
1009	RU3083803436548755847047281062638	643	2023-02-10	KZ8331663728810143990717733	внутренняя	2181144.7555	490.4789	отменена	\N
1010	RU6383803436512605200896614597744	398	2023-05-04	AD7226397935948749638872964	международная	5557749.1836	693.6355	отправлена	CASPKZKAXXX
1011	RU5583803436516539388298963058164	356	2023-07-07	RU6683803436534213789698830771682	внутренняя	9946587.6855	982.6569	доставлена	\N
1012	RU1983803436568263609873115174417	398	2023-12-18	RU6683803436547011171926119923803	внутренняя	3294103.6388	170.6251	отменена	\N
1013	RU8483803436586135450040789229889	978	2022-12-29	PT3328763554682376878825720	международная	4546728.7280	799.9834	отменена	SOGEFRPP
1014	RU4983803436522833268295991391237	840	2023-06-28	ES6266996237394428397632969	международная	9050519.0997	22.1635	отменена	IRVTUS3NXXX
1015	RU3983803436583730529285495292571	978	2023-02-23	BY4456766829306743812136563	международная	2747315.4735	717.9432	отправлена	SOGEFRPP
1016	RU3083803436556733352794187735054	643	2023-05-10	ES3077432868519862759198163	внутренняя	9508735.9626	295.1541	доставлена	\N
1017	RU4683803436518754352401343547893	356	2023-04-24	VN4899858242422360608186455	международная	1450125.3704	890.4557	отправлена	SBININBBXXX
1018	RU4183803436544525596730636267692	840	2023-07-03	AL6584993096437995104179296	международная	1229434.2447	474.7446	отправлена	IRVTUS3NXXX
1019	RU9983803436515137760640096699879	643	2023-12-22	DE8078925847365718837850536	внутренняя	9619526.2753	527.6091	отправлена	\N
1020	RU5983803436518386216122030936247	978	2023-10-20	RU7285734275088590777273801	внутренняя	5337871.8839	344.3800	доставлена	\N
1021	RU6583803436526807323529165700056	978	2023-10-08	ES7938348665012603257601513	международная	513941.9757	267.9378	отменена	SOGEFRPP
1022	RU2683803436575198696607383546599	398	2023-02-27	RU5183803436550941857646482749776	внутренняя	5093881.2542	895.1457	доставлена	\N
1023	RU4483803436537144245226352938256	398	2023-08-01	RU5983803436565674700991182664479	внутренняя	4780852.4396	501.1721	отменена	\N
1024	RU3383803436551883036237842733910	840	2023-08-24	RU6283803436577836700807681117407	внутренняя	4169406.5096	149.9038	отправлена	\N
1025	RU7483803436591068390387769478580	156	2023-08-18	RU7683803436578953117174553181317	внутренняя	5663750.7999	587.2344	отправлена	\N
1026	RU8983803436519227550175732694863	840	2023-08-21	RU9983803436521153026985692784451	внутренняя	4866266.5502	240.8109	отменена	\N
1027	RU6083803436557649065533492172245	840	2023-11-29	AL4093516135762108187179624	международная	1574752.7418	388.4578	отправлена	IRVTUS3NXXX
1028	RU9983803436588442958405952112241	643	2023-01-20	RU3883803436564256045508064629374	внутренняя	6881217.9131	142.3402	отменена	\N
1029	RU2683803436566742853200336170327	840	2023-11-21	RU8983803436550652073660555482382	внутренняя	3952602.6583	338.2292	отправлена	\N
1030	RU9883803436559947701649293062119	156	2023-03-04	ES6660441221712256499665311	международная	5297408.4382	806.2319	отправлена	BKCHCNBJ
1031	RU9383803436587347167184231490115	398	2023-06-21	DE1818879683622411646059020	международная	8840041.0507	798.0121	отправлена	CASPKZKAXXX
1032	RU5483803436538988818998904026382	398	2023-05-27	RU1983803436549890414007715363567	внутренняя	2612507.6046	696.8333	отменена	\N
1033	RU2583803436573489146610412814439	978	2023-02-26	RU6573039439242434008060999	внутренняя	8433675.0376	115.6156	отправлена	\N
1034	RU9683803436531094862059243712475	840	2022-12-27	RU6583803436573484995572407857396	внутренняя	9140119.7292	355.9398	доставлена	\N
1035	RU7483803436575212193030608824580	840	2023-08-28	RU7183803436584925378313266803439	внутренняя	200725.4201	333.0036	отменена	\N
1036	RU9983803436521153026985692784451	156	2023-06-14	RU8883803436542351475891948314875	внутренняя	8533079.5087	831.2797	отправлена	\N
1037	RU6283803436577836700807681117407	840	2023-11-26	RU8283803436593409912626065485368	внутренняя	1114848.2072	808.9297	доставлена	\N
1038	RU7083803436595909521339223196614	156	2023-02-10	AD1228461152349658440220293	международная	4499104.7425	137.1816	отменена	BKCHCNBJ
1039	RU5883803436571013870275428717873	978	2023-10-30	BY3254853956066166675719365	международная	296714.3451	622.0242	отправлена	DEUTDEFFXXX
1040	RU2983803436530272226005609138408	156	2023-09-13	RU5583803436533254773648721597711	внутренняя	3502694.0411	354.5858	доставлена	\N
1041	RU5783803436598085342824416355658	643	2023-09-27	ES7724558334551632690980646	внутренняя	9572954.8294	487.8896	доставлена	\N
1042	RU6383803436530975100435134167112	356	2023-12-09	RU8483803436586135450040789229889	внутренняя	5459648.5587	982.9709	отправлена	\N
1043	RU3883803436519845868206132784952	840	2023-11-05	RU4383803436597428452957764955765	внутренняя	6818197.5925	638.4960	доставлена	\N
1044	RU2583803436511360000518303822185	643	2023-01-11	KZ4067379213467863265764321	внутренняя	5131430.9328	953.5232	отменена	\N
1045	RU9483803436570307762028951954874	398	2023-03-22	RU4583803436571583967013936520660	внутренняя	1900231.6058	97.2321	отправлена	\N
1046	RU1983803436574962372646294489745	643	2023-10-06	RU3883803436571430516571621799878	внутренняя	6728578.7736	477.7713	отправлена	\N
1047	RU6783803436510078136565817264354	643	2023-07-04	ES4774495845075458895528561	внутренняя	1886422.2142	907.7269	отменена	\N
1048	RU2583803436586349630493889324094	156	2023-08-20	RU6383803436530975100435134167112	внутренняя	1120597.3554	572.1166	отправлена	\N
1049	RU3583803436597484588589933917343	356	2023-05-18	KZ9161920823439601955282905	международная	9068346.0660	698.9052	отменена	SBININBBXXX
1050	RU5283803436570838144716210841495	356	2023-03-03	RU4883803436583846522749125412438	внутренняя	8485968.4777	236.8352	отменена	\N
1051	RU8983803436530366335955653516096	840	2023-10-28	IN1862723997130841272088078	международная	5427244.6864	752.7526	отменена	IRVTUS3NXXX
1052	RU9683803436571883645805733128714	356	2023-12-01	RU2583803436510413813910694958748	внутренняя	8758746.4907	311.0137	доставлена	\N
1053	RU4483803436574648344464338946055	643	2023-06-29	AL8075221865745121015096805	внутренняя	1702445.2645	854.8878	отправлена	\N
1054	RU5183803436531460410872953149827	398	2023-11-25	RU3683803436529963181547651499120	внутренняя	4516884.8436	318.1073	отменена	\N
1055	RU6383803436530975100435134167112	978	2023-05-30	PT7361734711198222129967205	международная	7747116.7438	610.2104	доставлена	DEUTDEFFXXX
1056	RU8683803436511417676206561932357	643	2023-11-27	RU6483803436557881046066137062384	внутренняя	3673953.5706	913.1834	отправлена	\N
1057	RU2083803436517185898516741185299	840	2023-03-05	BY8228872701173497500796374	международная	8268962.1908	344.1407	отменена	CHASUS33
1058	RU9983803436563015974445739907644	156	2023-07-17	RU2983803436588011593439328399453	внутренняя	3256603.4252	101.1919	отправлена	\N
1059	RU6983803436517488129268543865126	156	2023-02-22	BY5951241085609316941503384	международная	398080.7897	720.8640	отправлена	BKCHCNBJ
1060	RU2283803436588289284937975921944	356	2023-03-04	AD1264362885160945479330029	международная	2621394.8652	71.8450	отменена	SBININBBXXX
1061	RU8183803436546948351691601253240	978	2023-04-05	RU5883803436537252361294139722938	внутренняя	2321635.2115	325.8096	отменена	\N
1062	RU8183803436576908594301902139271	840	2023-08-20	RU5583803436544105301147510534206	внутренняя	8241595.9656	163.5124	отправлена	\N
1063	RU3683803436529963181547651499120	398	2023-02-13	ES6366430588344766203218710	международная	3130171.0688	332.2003	доставлена	CASPKZKAXXX
1064	RU9383803436515318038329930627155	978	2023-11-30	PT6541286315663054728262692	международная	6910875.1587	400.6714	доставлена	DEUTDEFFXXX
1065	RU1883803436547883958852583813660	156	2023-12-22	RU4183803436593654490331448399606	внутренняя	1918407.1717	193.2500	доставлена	\N
1066	RU7483803436512314763652680872976	156	2023-05-31	AL1180016441936159509166484	международная	1486253.7483	57.6201	доставлена	BKCHCNBJ
1067	RU6083803436582119843499506879640	978	2023-05-24	ES7399415247178210766527634	международная	5395503.9346	608.7663	отменена	DEUTDEFFXXX
1068	RU3183803436545750333950215053352	156	2023-09-07	RU2983803436597155052344917689453	внутренняя	1684149.9804	774.0262	отправлена	\N
1069	RU3883803436559428008275215914286	398	2023-05-27	RU1883803436547883958852583813660	внутренняя	4748636.3828	300.5034	доставлена	\N
1070	RU7383803436569356631218275502161	643	2023-06-16	RU5383803436537654175631942789109	внутренняя	3634738.6360	887.9072	отменена	\N
1071	RU1983803436592911874717339237016	356	2023-10-02	BY8469011993143285110808929	международная	2967635.9825	909.5567	доставлена	SBININBBXXX
1072	RU9783803436531316283778462589484	978	2023-07-31	RU5683803436575772290627280121203	внутренняя	4737872.1873	267.4967	отправлена	\N
1073	RU5483803436559214869633349674125	840	2023-01-28	AL1498625385205024267449158	международная	9030415.1020	950.6537	отменена	IRVTUS3NXXX
1074	RU7483803436544936047225386728318	643	2023-02-07	RU7283803436551671539996901196859	внутренняя	159412.1949	824.1648	доставлена	\N
1075	RU8283803436536082355231514909614	356	2023-03-29	IN6166359918580883234178760	международная	6623876.6668	25.7456	отправлена	SBININBBXXX
1076	RU9783803436586848496167067081204	978	2023-03-22	RU7783803436578403910419087666263	внутренняя	3738536.3582	419.2542	отменена	\N
1077	RU7783803436557425582753958788900	356	2023-09-02	RU5983803436563752601230784661821	внутренняя	6964696.3631	607.7670	отправлена	\N
1078	RU7283803436528848493351990702937	156	2023-11-24	RU7783803436578403910419087666263	внутренняя	735475.4438	664.3891	отменена	\N
1079	RU5383803436537654175631942789109	978	2023-05-22	RU4083803436565489336932623834655	внутренняя	5583912.1791	846.8912	отправлена	\N
1080	RU6583803436546434088553514688778	643	2023-12-20	RU7483803436516612664745741202549	внутренняя	9773621.4736	291.8259	доставлена	\N
1081	RU2783803436580745382811010865973	978	2023-03-09	RU5083803436563140090168469536649	внутренняя	681885.2929	558.8617	доставлена	\N
1082	RU7483803436591068390387769478580	840	2023-04-24	RU2283803436521727957364583057084	внутренняя	9970204.8273	535.8896	доставлена	\N
1083	RU4183803436555804329090528802664	356	2023-04-07	RU8983803436545494349013660032430	внутренняя	4462389.7736	452.0037	отменена	\N
1084	RU3883803436519845868206132784952	978	2023-07-22	RU4170111751884372562384725	внутренняя	8976303.7870	873.0534	доставлена	\N
1085	RU5083803436537344339331652897359	398	2023-08-23	VN8461419139531471099812117	международная	8233224.9187	131.7919	доставлена	CASPKZKAXXX
1086	RU9383803436515318038329930627155	398	2023-03-10	RU6583803436547384322379422553840	внутренняя	4837056.4121	915.6732	отменена	\N
1087	RU6183803436551232797419519235346	156	2023-11-15	ES5088015031172453534166008	международная	7712868.0557	367.7744	доставлена	BKCHCNBJ
1088	RU7483803436529598231033100377224	840	2023-02-14	DE4235351507211858295393462	международная	8266283.4048	286.2833	отменена	CHASUS33
1089	RU4183803436598422593606583773593	156	2023-07-25	AL7827641366087878512505052	международная	1190362.7882	975.2561	отправлена	BKCHCNBJ
1090	RU6183803436547326038705936576601	356	2023-10-29	RU8983287843580599742255585	внутренняя	7085641.0579	440.6046	отменена	\N
1091	RU2683803436532775565489898182986	978	2023-09-17	RU5583803436541779385547740767657	внутренняя	7811022.3492	469.1108	отправлена	\N
1092	RU9483803436585469145832242711561	643	2023-02-25	RU2583803436586349630493889324094	внутренняя	5543351.5780	340.5028	отменена	\N
1093	RU9883803436580908913943520973504	356	2023-11-15	VN2354587244406336669024510	международная	9420546.1299	390.4538	отменена	SBININBBXXX
1094	RU6483803436595566817980742907742	398	2023-04-20	KZ8787921565055063239243011	международная	9441957.5041	969.1756	отменена	CASPKZKAXXX
1095	RU2483803436580851808318436691458	840	2023-07-06	RU2683803436532775565489898182986	внутренняя	740471.9286	407.4055	отправлена	\N
1096	RU4783803436556925313909023616425	398	2023-07-19	BY3485203305355366591092391	международная	1036845.9722	525.3584	отменена	CASPKZKAXXX
1097	RU8383803436554622159366581134752	840	2023-07-19	RU9483803436521022327823815694666	внутренняя	3562030.0440	124.8332	доставлена	\N
1098	RU1683803436510344781123537250392	356	2023-08-12	RU6683803436534213789698830771682	внутренняя	5452802.4546	649.3912	отправлена	\N
1099	RU5883803436576828712243252221562	156	2023-03-08	RU7783803436529059332090835348557	внутренняя	1330256.7087	986.0226	отменена	\N
1100	RU4183803436555804329090528802664	978	2023-01-09	AL8251826894917214562158320	международная	4153175.6982	854.7211	отправлена	RZBAATWW
1101	RU5083803436583492295875343805447	643	2023-10-25	AD7196280429017955989664517	внутренняя	6244151.1317	692.5669	отправлена	\N
1102	RU5583803436556151120487866130687	356	2023-12-27	KZ6123819842201778825422653	международная	3190952.6791	370.8520	доставлена	SBININBBXXX
1103	RU3883803436564256045508064629374	643	2023-03-24	RU5883803436571013870275428717873	внутренняя	4244605.3295	206.3006	доставлена	\N
1104	RU9683803436524115739172828059349	978	2023-04-02	RU7483803436595528340078834029783	внутренняя	7116853.1973	358.7776	отменена	\N
1105	RU3983803436580604058878329162478	978	2023-04-26	RU5883803436549838724600410631189	внутренняя	8904444.3736	255.0023	доставлена	\N
1106	RU7483803436575212193030608824580	156	2023-10-05	IN8868586231935791304964001	международная	7631889.1002	799.4634	отправлена	BKCHCNBJ
1107	RU8483803436593374085227717891522	643	2023-10-07	RU8783803436519169154241731281817	внутренняя	367910.9735	356.4764	отправлена	\N
1108	RU5983803436513359014201161572816	840	2023-03-20	RU5683803436539120556194350818141	внутренняя	6509555.3343	188.2363	отправлена	\N
1109	RU9783803436586848496167067081204	840	2023-01-01	RU8183803436564595439284009293487	внутренняя	6573065.0125	652.3193	отправлена	\N
1110	RU5983803436558435772787343054218	840	2023-01-18	RU8583803436567351126582917385267	внутренняя	4590956.7404	350.4573	отправлена	\N
1111	RU7283803436551671539996901196859	398	2023-03-13	KZ7967037947746627470595683	международная	8361322.2400	428.4772	отменена	CASPKZKAXXX
1112	RU1283803436545193525808988988532	398	2023-03-03	RU2783803436529440294678710752920	внутренняя	8283986.8696	748.7402	отменена	\N
1113	RU9383803436575688788160155647011	356	2023-12-03	RU2983803436572636545308279163382	внутренняя	3379629.2721	994.0538	отменена	\N
1114	RU8183803436576334203563049364101	840	2023-04-22	RU2983803436545911307181108696312	внутренняя	9013952.5850	234.3743	отправлена	\N
1115	RU3783803436562091905141244310726	840	2023-11-29	RU7583803436593274051968042799324	внутренняя	9976101.0341	435.6627	отменена	\N
1116	RU2083803436571871160330810400191	356	2023-03-11	PT9289575251028793822019370	международная	9722106.4253	777.2388	отправлена	SBININBBXXX
1117	RU6583803436599318340096840026283	156	2023-07-16	RU3183803436564747839620735247465	внутренняя	5055215.6218	618.2690	отправлена	\N
1118	RU9883803436559947701649293062119	978	2023-05-03	RU7783803436585076163513647706071	внутренняя	7882817.3564	196.6699	отменена	\N
1119	RU5683803436575772290627280121203	356	2023-04-17	RU2483803436550335144467075253432	внутренняя	8440649.4511	43.5140	отправлена	\N
1120	RU8183803436564595439284009293487	156	2023-09-14	IN1356183742729211503174297	международная	3383143.5723	644.7583	отправлена	BKCHCNBJ
1121	RU1383803436523658112524214881297	156	2023-10-16	RU8683803436531608639655465618756	внутренняя	701881.0356	988.9350	отправлена	\N
1122	RU2683803436575198696607383546599	840	2023-06-07	RU2883803436564862346362051659673	внутренняя	7640958.5821	922.1812	доставлена	\N
1123	RU7483803436529598231033100377224	356	2022-12-30	RU3083803436556733352794187735054	внутренняя	759374.4747	948.5882	доставлена	\N
1124	RU4383803436597428452957764955765	156	2023-09-09	PT8378833902529993881562262	международная	8850362.4236	13.2975	отправлена	BKCHCNBJ
1125	RU3183803436538368625987340316428	978	2023-05-13	KZ3781642302437164157172415	международная	1881487.0851	728.4828	отправлена	RZBAATWW
1126	RU5783803436568341660520010753753	643	2023-09-02	RU1583803436578714315409224923820	внутренняя	91285.8126	35.5561	доставлена	\N
1127	RU6583803436599318340096840026283	978	2023-01-23	RU6383803436517724803474176712817	внутренняя	7324329.0114	82.3765	отменена	\N
1128	RU4383803436538414207445829899653	356	2023-10-14	AD1123823856115144801808884	международная	2881950.5124	584.3112	отправлена	SBININBBXXX
1129	RU8383803436583878629872361871714	398	2023-10-09	VN3255226103163756032992772	международная	462815.7405	29.7218	доставлена	CASPKZKAXXX
1130	RU2083803436518033160343253894367	978	2023-11-09	RU1583803436533479152204865778047	внутренняя	3384391.8548	479.7961	доставлена	\N
1131	RU3883803436564256045508064629374	398	2023-01-21	RU9383803436568402663247236595753	внутренняя	4699391.6448	499.0935	отправлена	\N
1132	RU1183803436541561390025398925839	840	2023-11-06	RU8083803436588746463552823930061	внутренняя	4133688.6858	431.6502	отменена	\N
1133	RU4283803436532641085536208083176	356	2023-10-10	IN3414126549826113825674023	международная	7240534.6828	391.1070	отменена	SBININBBXXX
1134	RU8083803436588746463552823930061	643	2023-05-14	RU8183803436546948351691601253240	внутренняя	6407973.0743	942.2194	доставлена	\N
1135	RU1483803436555535016685486735994	398	2023-09-07	PT5811967096091611451286661	международная	1752110.9389	336.5047	доставлена	CASPKZKAXXX
1136	RU9683803436541591047480784615833	356	2023-09-29	RU4283803436544879224116585983050	внутренняя	6675810.5734	656.4780	отправлена	\N
1137	RU8183803436584325139466333599286	643	2023-03-07	ES7675436043634168218704642	внутренняя	3952862.9609	351.5409	отправлена	\N
1138	RU2083803436593214630941740939011	840	2023-03-13	RU5883803436537252361294139722938	внутренняя	6319707.1747	929.3025	отправлена	\N
1139	RU8483803436512925144599170278485	978	2023-08-10	RU2983803436545911307181108696312	внутренняя	9311973.6962	864.5011	отменена	\N
1140	RU8083803436548053884024737088236	978	2023-11-18	RU7283803436551671539996901196859	внутренняя	3256809.5842	573.1379	доставлена	\N
1141	RU7283803436582085910615477000049	398	2023-08-18	RU3383803436551883036237842733910	внутренняя	8473157.2485	315.0098	отменена	\N
1142	RU3183803436564747839620735247465	978	2023-01-07	RU6583803436592149423686806465410	внутренняя	1297646.8208	511.0501	отправлена	\N
1143	RU1383803436546084241558471107471	156	2023-06-08	RU8383803436583878629872361871714	внутренняя	5129846.1833	10.2829	отменена	\N
1144	RU4983803436522833268295991391237	398	2023-06-04	RU4429790463443068272823402	внутренняя	2518756.3847	126.1829	отправлена	\N
1145	RU6183803436551232797419519235346	356	2023-08-14	BY7324949252798737035804019	международная	7797680.8592	855.5056	отменена	SBININBBXXX
1146	RU9483803436521022327823815694666	643	2023-08-09	RU4683803436518754352401343547893	внутренняя	2982296.6176	19.7880	отправлена	\N
1147	RU1683803436549082108439124677076	978	2023-11-27	PT1112172836566652782312626	международная	3010650.4541	67.5254	отправлена	DEUTDEFFXXX
1148	RU4883803436540069564759439339493	156	2023-01-22	RU7383803436567535429961689788567	внутренняя	9543469.1172	263.8577	отправлена	\N
1149	RU3983803436562540544761068231244	643	2023-07-28	PT9225934395924700967809747	внутренняя	7792885.2832	349.4269	доставлена	\N
1150	RU5183803436588244188761426669013	398	2023-08-23	AL5167002558259300545870458	международная	5950898.6796	247.7414	отправлена	CASPKZKAXXX
1151	RU2283803436594102552659582448178	156	2023-09-16	IN4671852253794169424626840	международная	8216354.8848	841.0619	доставлена	BKCHCNBJ
1152	RU6583803436573484995572407857396	978	2023-02-06	DE5947259912861195996649645	международная	3636017.5769	186.7823	отправлена	DEUTDEFFXXX
1153	RU3783803436562139250445157080524	978	2023-06-11	RU1983803436510712914540451632365	внутренняя	7064073.7114	577.3942	отправлена	\N
1154	RU4583803436567844239839748091371	156	2023-12-01	RU1983803436568263609873115174417	внутренняя	6863687.9075	565.4594	отменена	\N
1155	RU5983803436513359014201161572816	978	2023-10-25	ES3454190404710371170225964	международная	9074362.0252	554.7643	отменена	RZBAATWW
1156	RU9383803436575688788160155647011	840	2023-03-17	KZ2775564486592127346724889	международная	149472.9051	772.6330	отправлена	IRVTUS3NXXX
1157	RU7783803436529059332090835348557	840	2023-11-22	VN9889150361635736094172596	международная	4859099.3899	800.4694	отправлена	CHASUS33
1158	RU3683803436589669964829443545971	840	2023-11-17	ES9638286002944484252981821	международная	2027515.1195	492.8753	доставлена	IRVTUS3NXXX
1159	RU8183803436576908594301902139271	156	2023-11-09	RU3783803436585191546282680625888	внутренняя	642650.2676	146.5991	доставлена	\N
1160	RU6683803436575472065287991925682	840	2023-12-21	BY4184131473763082871631691	международная	2784906.4465	11.7023	отправлена	IRVTUS3NXXX
1161	RU5283803436529894140873721164089	840	2023-06-05	KZ7978135767327756199555336	международная	5365830.4215	651.8723	отменена	CHASUS33
1162	RU1083803436563162471160560931522	156	2023-03-16	KZ4022889342330869406235787	международная	1354516.2361	779.5622	доставлена	BKCHCNBJ
1163	RU3983803436554516084539411139147	840	2023-10-24	RU7783803436585076163513647706071	внутренняя	2135353.2028	574.5583	отправлена	\N
1164	RU4883803436561825246742556433732	978	2023-08-17	AD3566348904424519656546265	международная	5773135.8381	518.8310	отменена	DEUTDEFFXXX
1165	RU1883803436537462946976236392804	356	2023-09-24	RU8983803436550652073660555482382	внутренняя	4659798.9153	128.6471	отправлена	\N
1166	RU1983803436558651220197686454204	356	2023-07-03	KZ6061954786066456276066447	международная	1370277.8481	84.4861	отменена	SBININBBXXX
1167	RU5183803436523181844916432548416	978	2023-02-13	RU7397334973907900963650182	внутренняя	33381.0265	891.5848	доставлена	\N
1168	RU5683803436575772290627280121203	156	2023-09-25	AL9963531572938649869824977	международная	5781646.8678	231.1022	отправлена	BKCHCNBJ
1169	RU5783803436556321671762187197309	398	2023-07-31	AD7138565109601053132650196	международная	4945572.7222	712.2164	доставлена	CASPKZKAXXX
1170	RU2183803436551906716086082339754	840	2023-09-29	VN6079776935921944980814417	международная	7330320.5563	582.8040	отправлена	CHASUS33
1171	RU9583803436537234117226554935344	156	2023-02-12	VN9474053413132154099985572	международная	1917766.7805	467.8353	доставлена	BKCHCNBJ
1172	RU2783803436515955219320238454317	398	2023-03-15	RU7483803436591068390387769478580	внутренняя	6162562.1650	248.6252	отменена	\N
1173	RU8983803436518961229187913059129	643	2023-12-14	ES4411492418640631843691737	внутренняя	6368260.0600	163.4680	доставлена	\N
1174	RU2083803436518033160343253894367	156	2023-10-05	RU3683803436583826961336736431806	внутренняя	8282064.9725	572.8073	отправлена	\N
1175	RU5283803436570838144716210841495	156	2023-08-30	VN5360521885137322226729100	международная	701230.2676	393.7512	отправлена	BKCHCNBJ
1176	RU1983803436518034161993382946183	356	2023-01-22	KZ4482696409998826074793250	международная	3103231.3537	741.4292	отправлена	SBININBBXXX
1177	RU6483803436575827628326698282321	840	2023-02-25	RU6983803436596433824452063468541	внутренняя	9590199.2211	469.0774	доставлена	\N
1178	RU5483803436551418630110242560620	156	2023-01-26	RU1983803436592911874717339237016	внутренняя	7890458.7202	146.0864	отправлена	\N
1179	RU5783803436553735504938098098542	643	2023-03-15	PT5297435898662407458392627	внутренняя	8529802.7458	648.7868	доставлена	\N
1180	RU6983803436518663051613263930888	398	2023-10-15	RU3883803436559428008275215914286	внутренняя	1291291.9255	608.6298	доставлена	\N
1181	RU6083803436569163727288631654599	840	2023-03-25	RU2583803436525056668985275863842	внутренняя	1725481.7055	230.7827	отменена	\N
1182	RU6783803436582018660242960957244	398	2023-12-04	RU5683803436581377733469772235779	внутренняя	2827257.3342	0.0000	доставлена	\N
1183	RU2483803436563361420871450061347	398	2023-09-18	RU4183803436512683300418013703414	внутренняя	1607862.3870	259.9031	отменена	\N
1184	RU1283803436521770311179326367954	643	2023-04-11	RU8083803436548053884024737088236	внутренняя	2809001.7999	895.1798	отправлена	\N
1185	RU9083803436548965374028188380728	840	2023-04-02	RU6983803436518663051613263930888	внутренняя	8322850.3046	640.3478	отправлена	\N
1186	RU4683803436518754352401343547893	356	2023-10-12	RU8883803436542351475891948314875	внутренняя	5081278.5977	735.9289	доставлена	\N
1187	RU9983803436581801115411623274695	643	2023-05-05	RU5710776482094916469118123	внутренняя	5935786.0228	975.7109	отменена	\N
1188	RU8683803436520349379894661014091	978	2023-04-09	RU4583803436588661449801193641363	внутренняя	2786475.0664	824.9630	доставлена	\N
1189	RU1183803436512373318427988836252	156	2023-06-08	BY7397171097059504895003579	международная	3124117.9526	47.0274	доставлена	BKCHCNBJ
1190	RU4183803436555804329090528802664	643	2023-10-10	AL4013458113382795337081449	внутренняя	6666294.2344	937.0940	отправлена	\N
1191	RU4283803436532641085536208083176	978	2023-09-11	IN9248368921106434347638719	международная	9540393.8463	609.9881	отправлена	SOGEFRPP
1192	RU2983803436596711612246779730808	398	2023-10-02	IN3757849627090439565082108	международная	4749156.1152	873.1304	отменена	CASPKZKAXXX
1193	RU6583803436588261503476787515721	840	2023-02-02	RU2483803436537933507280624045523	внутренняя	1018393.1185	11.7258	отменена	\N
1194	RU3883803436531800763308499008852	978	2023-05-04	RU2883803436512412400998624231254	внутренняя	2611935.7648	986.3752	доставлена	\N
1195	RU3983803436562540544761068231244	156	2023-07-26	RU4083803436561171626967381260937	внутренняя	1554930.8570	544.1055	отменена	\N
1196	RU6283803436577836700807681117407	978	2023-09-01	RU8183803436513368239655842198331	внутренняя	2626403.1083	214.9939	отправлена	\N
1197	RU6183803436555838927651384339574	840	2023-06-30	KZ7693846338924372908030516	международная	1455729.3532	68.6292	отменена	CHASUS33
1198	RU3983803436569376600246742084811	356	2023-08-13	RU8783803436522200736153030297680	внутренняя	7176568.8258	220.6230	доставлена	\N
1199	RU7583803436597888322431139189153	978	2023-07-13	DE9587709267782944084913166	международная	5889705.9269	378.2938	отменена	SOGEFRPP
1200	RU6283803436561107985248905256058	398	2023-12-14	RU4183803436555804329090528802664	внутренняя	3034615.3259	813.4978	отменена	\N
1201	RU8583803436586707949034749896750	643	2023-01-29	VN1027713441519135286797729	внутренняя	8059274.0679	525.6713	отправлена	\N
1202	RU5383803436537654175631942789109	398	2023-08-30	DE4194786434978834733110054	международная	5377223.4869	994.5170	отменена	CASPKZKAXXX
1203	RU2983803436545911307181108696312	840	2023-01-01	RU3683803436529963181547651499120	внутренняя	3758561.1720	689.6046	отправлена	\N
1204	RU3683803436589669964829443545971	398	2023-05-27	RU8183803436566794763466227027850	внутренняя	6678261.5101	484.6991	отправлена	\N
1205	RU7583803436593274051968042799324	356	2023-06-23	AL9367569861254693990530320	международная	3992129.5654	694.6231	отменена	SBININBBXXX
1206	RU9083803436513364676730542126445	356	2023-07-13	PT6449278628188313999364347	международная	5854431.2536	165.2275	доставлена	SBININBBXXX
1207	RU4083803436565489336932623834655	840	2023-10-23	RU2283803436555228451424548337941	внутренняя	5407081.1383	781.7398	отменена	\N
1208	RU7783803436578403910419087666263	643	2023-09-09	RU5883803436571013870275428717873	внутренняя	8626820.7828	389.9859	доставлена	\N
1209	RU2983803436585384738431881857607	398	2023-09-29	RU9283803436581282514241262822584	внутренняя	6701679.9071	745.7173	отправлена	\N
1210	RU7383803436585863943754594310819	156	2023-06-20	RU1183803436569972795023903837949	внутренняя	5161858.5945	597.6630	отменена	\N
1211	RU6383803436541953279771793851240	978	2023-05-22	ES7692107464342214476007823	международная	4652244.2485	125.8619	доставлена	DEUTDEFFXXX
1212	RU8083803436548053884024737088236	356	2023-06-20	AD6468610037345879400706483	международная	942979.2836	72.7660	отменена	SBININBBXXX
1213	RU2383803436569895097903578030814	978	2023-07-27	VN3346186078225524938423848	международная	8015110.4199	503.9889	доставлена	DEUTDEFFXXX
1214	RU2183803436551906716086082339754	398	2023-03-23	RU3683803436583826961336736431806	внутренняя	3172768.3537	168.0890	отменена	\N
1215	RU4583803436546993711061481413708	643	2023-12-09	RU8583803436567351126582917385267	внутренняя	1477807.5260	302.9973	доставлена	\N
1216	RU1383803436585969091171133733533	156	2023-10-15	RU3183803436564747839620735247465	внутренняя	4479113.7395	678.8337	отменена	\N
1217	RU9883803436596118671708861810646	356	2023-04-16	RU7458824018874445906726880	внутренняя	1304592.4167	111.9519	отправлена	\N
1218	RU6783803436510078136565817264354	156	2023-06-15	PT4743565548583668961400594	международная	5520730.1622	850.1675	отправлена	BKCHCNBJ
1219	RU2083803436571871160330810400191	156	2023-11-03	RU3383803436530100232705488681423	внутренняя	7344270.2170	43.7350	отправлена	\N
1220	RU3983803436583094600516227232333	840	2023-11-28	RU5583803436533254773648721597711	внутренняя	4734555.3081	352.0339	доставлена	\N
1221	RU6283803436541447099313442593938	156	2023-09-05	RU8683803436531608639655465618756	внутренняя	6501977.0565	932.6799	отменена	\N
1222	RU4683803436584135461455281070651	156	2023-12-15	AL2380352319494335556213052	международная	5699336.8247	982.8676	отправлена	BKCHCNBJ
1223	RU2083803436593214630941740939011	398	2023-05-21	RU3383803436527231938190662146888	внутренняя	1567216.3304	189.5968	доставлена	\N
1224	RU8983803436518961229187913059129	156	2023-12-17	ES3676365427021379105401223	международная	9175996.3433	293.3192	отменена	BKCHCNBJ
1225	RU5183803436588244188761426669013	356	2023-08-26	AD6624487001728904192729520	международная	2540112.8173	510.1292	доставлена	SBININBBXXX
1226	RU3283803436579852018195047883736	840	2023-04-04	RU2283803436588289284937975921944	внутренняя	8008654.7260	638.6141	отменена	\N
1227	RU8483803436586135450040789229889	840	2023-10-12	VN7938450067960517711084618	международная	5444700.1388	775.0792	отменена	IRVTUS3NXXX
1228	RU7183803436546875767014611813689	398	2023-03-14	VN9690069071217509051198996	международная	1052930.4919	208.2829	доставлена	CASPKZKAXXX
1229	RU2683803436556115738690945420927	156	2023-02-04	ES3759866143662487181030466	международная	8627990.1914	437.8843	отменена	BKCHCNBJ
1230	RU9683803436520170153501466272589	840	2023-07-04	IN1375752528612172866940104	международная	3353020.7175	922.3314	доставлена	IRVTUS3NXXX
1231	RU9683803436541591047480784615833	978	2023-01-05	RU2683803436566742853200336170327	внутренняя	7902536.7898	593.4262	отправлена	\N
1232	RU3983803436554516084539411139147	156	2023-04-24	RU1983803436558651220197686454204	внутренняя	275044.2753	655.7881	отменена	\N
1233	RU1883803436547883958852583813660	356	2023-06-24	RU7583803436593274051968042799324	внутренняя	1503536.3513	963.1711	доставлена	\N
1234	RU7583803436593621382878998665048	643	2023-02-01	RU7283803436551671539996901196859	внутренняя	2847412.3840	0.0000	отправлена	\N
1235	RU6383803436541953279771793851240	398	2023-07-22	ES8210412017674753238617292	международная	3471314.1456	44.5555	отправлена	CASPKZKAXXX
1236	RU7083803436565850801859363291526	978	2023-12-12	AD9790224857895339788991739	международная	3923350.0313	762.9709	доставлена	DEUTDEFFXXX
1237	RU8183803436532187852215520403243	398	2023-04-27	RU6744135692328069793951144	внутренняя	5329455.7861	576.5625	доставлена	\N
1238	RU2083803436536025786076127901648	643	2023-03-01	RU8583803436580493050529274956761	внутренняя	8311959.2010	384.6324	отменена	\N
1239	RU7283803436565335970635584506660	356	2023-11-09	RU3883803436571430516571621799878	внутренняя	3364766.5949	798.0118	отменена	\N
1240	RU3183803436522808312515599877028	398	2023-10-27	RU1683803436549082108439124677076	внутренняя	2200017.4771	372.9840	отменена	\N
1241	RU6583803436565551879254347008316	398	2023-07-01	AL2532052829986039226343837	международная	7091500.6214	450.8312	отправлена	CASPKZKAXXX
1242	RU7583803436593274051968042799324	398	2023-02-05	RU8383803436554622159366581134752	внутренняя	8702819.5498	823.1063	отменена	\N
1243	RU5483803436547543071206231343471	643	2023-02-20	RU1883803436547883958852583813660	внутренняя	6283984.3254	992.3902	доставлена	\N
1244	RU3383803436533625475503259998648	156	2023-03-12	RU7383803436569356631218275502161	внутренняя	2637713.6726	954.4539	доставлена	\N
1245	RU2783803436512588965300606208370	398	2023-06-19	RU4483803436593534887929979895004	внутренняя	4979763.7320	130.6735	доставлена	\N
1246	RU3883803436531800763308499008852	643	2023-06-08	RU8083803436567877444686336475183	внутренняя	2881711.2609	967.5012	доставлена	\N
1247	RU6183803436556503720110500069421	156	2023-11-15	RU8583803436590890149305918634043	внутренняя	1997970.4822	798.2862	доставлена	\N
1248	RU9483803436588743613330942629999	978	2023-02-06	VN8135582897962644526072210	международная	9790480.2878	243.5214	отправлена	SOGEFRPP
1249	RU2283803436527235231809863175226	840	2023-02-10	RU1183803436587920364130887563809	внутренняя	2931029.7313	96.0003	отменена	\N
1250	RU7683803436565241249132549566386	156	2023-09-19	AD7338415253538720149733317	международная	1053732.9603	887.7245	доставлена	BKCHCNBJ
1251	RU9883803436597607312145326011401	398	2023-04-18	PT9189328217517261852991390	международная	5146500.3544	335.4816	отправлена	CASPKZKAXXX
1252	RU3383803436527231938190662146888	643	2023-02-09	PT7865820629048744624428694	внутренняя	569764.2767	45.4354	отменена	\N
1253	RU8583803436598717986670697262250	643	2023-03-12	RU4783803436556925313909023616425	внутренняя	9334434.5234	503.7849	отменена	\N
1254	RU9483803436516702191580023603147	356	2023-05-09	RU3383803436548623436381587682007	внутренняя	6774747.6976	839.4778	отменена	\N
1255	RU1983803436558651220197686454204	840	2023-09-18	KZ6122349459824424119024255	международная	9960665.3724	361.0446	отменена	CHASUS33
1256	RU2683803436532775565489898182986	398	2023-09-22	RU2183803436586747579379810386651	внутренняя	9022225.7266	484.2102	отправлена	\N
1257	RU1983803436592911874717339237016	840	2023-05-05	BY3213037731435396743377655	международная	1344837.9805	640.2816	отменена	CHASUS33
1258	RU8283803436517214496879594083501	356	2023-04-29	VN2422560596604046653418455	международная	6097803.9014	752.6360	доставлена	SBININBBXXX
1259	RU6083803436569163727288631654599	978	2023-07-21	RU4083803436519648806531502670697	внутренняя	9300857.3951	632.2895	отправлена	\N
4148	RU6683803436546559918630563560759	643	2022-12-27	AD5054331377671649380726318	внутренняя	1954427.4946	354.7642	отменена	\N
1260	RU1683803436510344781123537250392	643	2023-05-25	RU4283803436515276086545867508581	внутренняя	7057446.2912	606.5891	доставлена	\N
1261	RU3783803436562091905141244310726	356	2023-03-29	RU6583803436556215016292535847892	внутренняя	7720355.4064	285.9583	отменена	\N
1262	RU8383803436543267469021061769102	356	2023-09-17	RU3283803436586063041663029658571	внутренняя	3048762.0890	703.2835	доставлена	\N
1263	RU9283803436581282514241262822584	398	2023-09-05	RU6383803436517724803474176712817	внутренняя	9693441.7558	997.1654	доставлена	\N
1264	RU8983803436513229118545499417330	643	2023-01-05	BY9525208345288143285933400	внутренняя	4010404.4903	490.3782	отправлена	\N
1265	RU2983803436596711612246779730808	398	2023-08-21	RU5583803436544105301147510534206	внутренняя	8689115.9526	264.3370	доставлена	\N
1266	RU8183803436555934243334630961587	156	2023-10-16	RU9129389354406572086247476	внутренняя	9152883.0529	142.3741	доставлена	\N
1267	RU8183803436546948351691601253240	398	2023-03-31	KZ9172935898837885611615425	международная	3058982.7444	603.2235	отменена	CASPKZKAXXX
1268	RU9183803436594783043422280553530	643	2023-01-10	AL6760173524279404991677469	внутренняя	441996.5321	971.8744	доставлена	\N
1269	RU7483803436560908970835757520521	643	2023-04-13	RU6383803436541953279771793851240	внутренняя	1409443.1831	332.6269	доставлена	\N
1270	RU4183803436555804329090528802664	643	2023-02-06	BY8396292856125306598706053	внутренняя	349307.8654	869.3230	отправлена	\N
1271	RU2083803436573246597416370413406	156	2023-11-29	RU5483803436547543071206231343471	внутренняя	7816569.7330	306.8615	отправлена	\N
1272	RU9283803436529032721317031749293	643	2023-01-08	RU2683803436512319317744369021772	внутренняя	3858803.4494	515.3612	отменена	\N
1273	RU9483803436570307762028951954874	840	2023-05-13	RU9083803436527710172880684864084	внутренняя	4508419.9436	194.1289	отменена	\N
1274	RU2283803436527235231809863175226	840	2023-12-11	RU9683803436571883645805733128714	внутренняя	7337252.4597	895.9199	отменена	\N
1275	RU8683803436558409197465918354522	643	2023-09-14	RU7183803436578006903833632767386	внутренняя	9957311.5343	964.0388	отправлена	\N
1276	RU4083803436525661046500520760430	398	2023-11-06	DE5253029032940994196595146	международная	5975347.1611	776.1435	отправлена	CASPKZKAXXX
1277	RU1183803436536239647096212180861	643	2023-12-17	IN2129417806794932281419293	внутренняя	6650843.7786	187.1360	отменена	\N
1278	RU5183803436596697120047636808100	356	2023-12-17	RU6483803436513432249664452306210	внутренняя	8124049.2116	940.2988	отменена	\N
1279	RU9683803436559214297350823715344	156	2023-08-17	VN7810934693554431750235445	международная	8961432.4726	492.3887	доставлена	BKCHCNBJ
1280	RU7383803436534050516387288663509	978	2023-04-07	RU9283803436529032721317031749293	внутренняя	5119878.0990	597.1637	доставлена	\N
1281	RU2183803436555308456329784386702	156	2023-03-02	PT3292382807700548361446613	международная	5937714.6039	852.9102	доставлена	BKCHCNBJ
1282	RU9383803436515318038329930627155	156	2023-07-04	RU1283803436597755454846611928328	внутренняя	4045167.7803	319.2812	отправлена	\N
1283	RU8583803436548069379320039967893	643	2023-08-26	AL7566374401255435517955985	внутренняя	1118877.2807	390.3564	доставлена	\N
1284	RU5983803436563752601230784661821	978	2023-02-24	KZ1112380575143096305028119	международная	7403011.8168	723.7319	доставлена	RZBAATWW
1285	RU2283803436555228451424548337941	978	2023-03-14	RU3583803436543438797337964557116	внутренняя	6389387.8040	540.6188	доставлена	\N
1286	RU4583803436576777630615652907536	840	2023-03-26	KZ6462593917379869184406737	международная	7988268.8489	658.8510	отменена	IRVTUS3NXXX
1287	RU7783803436557425582753958788900	356	2023-02-14	RU5683803436581377733469772235779	внутренняя	3857355.7168	789.1851	отправлена	\N
1288	RU7783803436556242953974983768067	356	2023-04-03	BY7944828292480880112120295	международная	718411.7564	121.2884	отправлена	SBININBBXXX
1289	RU5883803436551017474710608700284	156	2023-05-02	AL5515262378642312810695384	международная	8210507.1316	0.0000	отменена	BKCHCNBJ
1290	RU2283803436551819000625747494652	643	2023-04-04	ES8320863394796755108469258	внутренняя	4200695.3026	745.5127	отменена	\N
1291	RU7283803436582085910615477000049	978	2023-02-06	AD5153355593634423273226981	международная	326269.5643	115.7417	доставлена	RZBAATWW
1292	RU1183803436536239647096212180861	356	2023-06-15	DE9396649947238130081225826	международная	5447151.4735	967.9202	отправлена	SBININBBXXX
1293	RU6483803436575827628326698282321	356	2023-12-26	AD8681857174188575063740742	международная	1483759.1758	382.1968	отправлена	SBININBBXXX
1294	RU2183803436586747579379810386651	398	2023-06-08	RU5183803436531460410872953149827	внутренняя	3891571.9679	55.6523	отправлена	\N
1295	RU8983803436543970357311304848339	978	2023-05-30	RU2983803436572678251629055132350	внутренняя	2389131.2445	66.5540	доставлена	\N
1296	RU4583803436576777630615652907536	356	2023-10-21	RU1583803436592948110594062864167	внутренняя	826675.3074	813.7167	доставлена	\N
1297	RU2483803436559904294875702128517	156	2023-09-13	ES6990283306239828639826331	международная	6408951.7325	369.1537	отменена	BKCHCNBJ
1298	RU2183803436555308456329784386702	398	2023-11-12	RU2683803436575198696607383546599	внутренняя	8847034.5229	220.8541	доставлена	\N
1299	RU8883803436542351475891948314875	840	2023-10-22	IN9913613366357921335226763	международная	9173733.2689	898.7149	отправлена	CHASUS33
1300	RU8183803436546948351691601253240	643	2023-08-26	DE8716795283631859967717906	внутренняя	7304421.5300	68.6900	отменена	\N
1301	RU4483803436531766422461159975910	356	2023-06-18	AD6429101591313300053826864	международная	2091915.7437	301.2661	отправлена	SBININBBXXX
1302	RU8983803436543970357311304848339	978	2023-01-17	RU9683803436541591047480784615833	внутренняя	6917757.3454	889.8132	отправлена	\N
1303	RU1183803436513944372774322746458	978	2023-08-19	RU3383803436540416635821116917223	внутренняя	2498268.2080	648.2713	доставлена	\N
1304	RU7683803436589524723383129532286	398	2023-11-23	RU4083803436519648806531502670697	внутренняя	8501222.7701	849.0476	доставлена	\N
1305	RU9483803436588743613330942629999	643	2023-03-10	IN6850706909889375590994854	внутренняя	3495485.3042	817.8928	доставлена	\N
1306	RU1283803436521770311179326367954	398	2023-10-12	PT8322199345813814451105840	международная	3597015.5893	443.9673	отправлена	CASPKZKAXXX
1307	RU7383803436567535429961689788567	156	2023-05-09	VN7462265579385658192147241	международная	3867218.7643	14.7803	отменена	BKCHCNBJ
1308	RU1683803436583298094705869717304	156	2023-01-25	ES4371906494470409219119305	международная	9819609.4261	361.6624	отменена	BKCHCNBJ
1309	RU2883803436581906276084692901201	840	2023-10-16	RU4383803436594641659799774635872	внутренняя	5093624.3403	438.0381	доставлена	\N
1310	RU3283803436579852018195047883736	156	2023-03-16	RU1383803436523658112524214881297	внутренняя	8270654.6741	451.1436	доставлена	\N
1311	RU8783803436562772820294479967682	356	2023-11-11	RU5183803436573013692902081587761	внутренняя	3146664.1757	47.5536	отправлена	\N
1312	RU8283803436593409912626065485368	156	2023-06-20	KZ4872202348142909433282367	международная	4315630.9142	393.7624	отправлена	BKCHCNBJ
1313	RU9583803436562562119396535016715	356	2023-01-24	AL6568385425346876699033070	международная	2233823.5954	762.4040	отменена	SBININBBXXX
1314	RU5883803436549838724600410631189	398	2023-12-18	RU8683803436558409197465918354522	внутренняя	1609099.4092	685.8550	отменена	\N
1315	RU7783803436520045957277741704368	840	2023-05-08	RU7683803436565241249132549566386	внутренняя	4204662.6409	321.6365	отменена	\N
1316	RU4483803436574648344464338946055	398	2023-04-30	RU3583803436543438797337964557116	внутренняя	7097963.5571	470.2043	доставлена	\N
1317	RU5183803436550941857646482749776	398	2023-07-13	IN7998633086593707109969603	международная	883858.9574	328.7588	отменена	CASPKZKAXXX
1318	RU2283803436521727957364583057084	840	2023-11-10	RU7383803436567535429961689788567	внутренняя	5980996.8685	396.8462	отправлена	\N
1319	RU9383803436546841675173507423577	398	2023-06-18	ES8134199343502191068929981	международная	6986789.2938	673.0091	отправлена	CASPKZKAXXX
1320	RU6983803436542868245387240901621	398	2023-07-26	RU8583803436593152008036708778596	внутренняя	1442325.8514	465.7464	отменена	\N
1321	RU1583803436575905915250327615306	978	2023-01-20	RU7583803436593274051968042799324	внутренняя	6783668.9944	94.7735	отменена	\N
1322	RU1583803436533479152204865778047	398	2023-01-07	AL8635966651139844985576108	международная	1590384.5765	822.0975	отправлена	CASPKZKAXXX
1323	RU1283803436513390712190126736747	978	2023-06-08	BY8025890143312317269693238	международная	2512644.8022	876.5067	отправлена	DEUTDEFFXXX
1324	RU1283803436597755454846611928328	978	2023-11-09	RU2983803436588011593439328399453	внутренняя	7680383.6348	689.6122	отменена	\N
1325	RU1383803436565139777755041333233	840	2023-11-13	IN8392405194972190986660814	международная	4417798.5330	950.9388	отправлена	IRVTUS3NXXX
1326	RU5283803436570838144716210841495	398	2023-12-10	RU9183803436523189940915642395180	внутренняя	7107986.1465	978.5889	доставлена	\N
1327	RU2183803436555308456329784386702	840	2023-04-22	ES4444418684167444782048164	международная	3163219.8347	333.2766	отправлена	IRVTUS3NXXX
1328	RU7083803436565850801859363291526	978	2023-11-11	RU8583803436590890149305918634043	внутренняя	3329231.6552	661.1065	доставлена	\N
1329	RU4183803436575456526806163894045	356	2023-02-14	RU3183803436522808312515599877028	внутренняя	2291562.9178	223.6167	доставлена	\N
1330	RU5083803436556786327042016836549	356	2023-03-03	IN5048030665554157375519300	международная	4125100.2992	372.9517	отменена	SBININBBXXX
1331	RU4483803436537144245226352938256	840	2023-03-24	AD3476147545977366944731191	международная	6907118.0127	736.2672	отменена	CHASUS33
1332	RU9583803436515959194321808018014	978	2023-08-03	RU5283803436570838144716210841495	внутренняя	3552695.5399	491.3691	отменена	\N
1333	RU3983803436580604058878329162478	356	2023-12-04	RU6983803436518663051613263930888	внутренняя	5764505.4829	299.4094	отправлена	\N
1334	RU8583803436580493050529274956761	643	2023-01-04	VN7369736553615220492187008	внутренняя	6732130.3061	824.6777	отправлена	\N
1335	RU2583803436586349630493889324094	643	2023-06-24	PT7725798761611536007056458	внутренняя	2752059.9911	717.8155	отправлена	\N
1336	RU5583803436516539388298963058164	356	2023-11-01	RU6983803436557684576294868357987	внутренняя	9769147.6998	212.3169	отправлена	\N
1337	RU3783803436559423561964096195262	356	2023-02-10	RU3183803436583121152517184662518	внутренняя	5639951.6711	642.2045	отправлена	\N
1338	RU2883803436538134433783624054557	398	2023-12-22	ES3456996129676859978485475	международная	2860370.1170	848.4624	отправлена	CASPKZKAXXX
1339	RU6883803436521704893234788177503	840	2023-02-05	ES7540064206359571939151703	международная	2502235.5308	233.6505	отменена	CHASUS33
1340	RU8183803436555934243334630961587	356	2023-09-25	BY4759878695746429474135375	международная	3471553.3863	118.2219	отменена	SBININBBXXX
1341	RU4083803436534430125114460530795	840	2023-03-20	RU3960785987122816270738306	внутренняя	1523948.8256	377.5040	отменена	\N
1342	RU2483803436580851808318436691458	978	2023-11-06	RU5183803436596697120047636808100	внутренняя	9863809.8154	893.0771	доставлена	\N
1343	RU5883803436549838724600410631189	356	2023-01-13	RU2083803436573246597416370413406	внутренняя	1246895.0291	556.1846	отправлена	\N
1344	RU2083803436593214630941740939011	156	2023-07-20	RU1583803436592948110594062864167	внутренняя	7552642.6025	955.6353	доставлена	\N
1345	RU3683803436583826961336736431806	156	2023-02-24	IN5040905858656127214284441	международная	7240087.0805	465.1306	отменена	BKCHCNBJ
1346	RU1683803436543683792461716245841	356	2023-06-10	VN2136793247464197208200833	международная	2290858.2306	447.0462	отправлена	SBININBBXXX
1347	RU1683803436543683792461716245841	840	2023-09-03	KZ7345876064245349757696687	международная	4435802.7706	301.3604	отправлена	CHASUS33
1348	RU4083803436530357399673623809331	156	2023-01-24	AD9949432957692921464907380	международная	3739927.4554	980.8085	отправлена	BKCHCNBJ
1349	RU2283803436588289284937975921944	356	2023-03-16	RU8283803436536082355231514909614	внутренняя	7652205.8919	753.1476	доставлена	\N
1350	RU6583803436556215016292535847892	356	2023-07-07	RU1383803436523658112524214881297	внутренняя	3306618.6309	646.9414	отменена	\N
1351	RU8983803436513229118545499417330	978	2023-12-24	ES2759974039217194062470693	международная	9494570.8597	905.8499	отправлена	SOGEFRPP
1352	RU1683803436536773128968824249362	840	2023-03-08	AL4827791859909640179365799	международная	2103725.4207	79.9160	доставлена	IRVTUS3NXXX
1353	RU7783803436556242953974983768067	978	2023-06-12	RU8583803436529401978461350257287	внутренняя	4567293.9055	899.7262	отправлена	\N
1354	RU2883803436538134433783624054557	643	2023-06-25	PT7240402718044416697351907	внутренняя	9327496.0999	932.7437	отправлена	\N
1355	RU4083803436565489336932623834655	840	2023-03-14	ES1483256452529074910504252	международная	3491613.3516	533.2717	отправлена	CHASUS33
1356	RU5183803436599553165549416662045	840	2023-11-08	ES6720035554208703557954230	международная	7847949.6367	705.9955	отправлена	CHASUS33
1357	RU8983803436530366335955653516096	840	2023-09-11	IN7699924123728289343846581	международная	3344437.5210	102.5275	отправлена	IRVTUS3NXXX
1358	RU1083803436563162471160560931522	398	2023-10-27	RU1183803436513944372774322746458	внутренняя	9407939.0553	682.1666	отменена	\N
1359	RU6083803436569163727288631654599	978	2023-07-31	VN5633650033293742451623842	международная	7074931.2871	572.8407	отправлена	DEUTDEFFXXX
1360	RU9383803436515318038329930627155	643	2023-09-10	RU2083803436571871160330810400191	внутренняя	9575774.1156	853.9899	доставлена	\N
1361	RU6983803436517488129268543865126	356	2023-08-12	RU9483803436516702191580023603147	внутренняя	2281510.8867	135.8726	отменена	\N
1362	RU3783803436559423561964096195262	643	2023-03-22	AL6019409483339611381912425	внутренняя	3749519.8180	801.9376	доставлена	\N
1363	RU9983803436515137760640096699879	643	2023-03-23	AL9844652506395382451021770	внутренняя	4567172.1972	350.8967	отменена	\N
1364	RU1283803436545193525808988988532	156	2023-01-22	RU7783803436585076163513647706071	внутренняя	770772.6635	983.3898	отменена	\N
1365	RU8183803436513368239655842198331	398	2023-12-19	AD7371561204416249243008371	международная	6381861.0920	172.6066	отправлена	CASPKZKAXXX
1366	RU7783803436578403910419087666263	978	2023-10-03	BY9744654374528572728429030	международная	5330649.3916	31.6323	доставлена	SOGEFRPP
1367	RU8183803436555934243334630961587	978	2023-10-06	AL8866130191787478161732264	международная	4791555.6168	710.7687	доставлена	SOGEFRPP
1368	RU5583803436533254773648721597711	978	2023-04-22	VN2559384136598858777046497	международная	5487776.7173	391.3571	отменена	DEUTDEFFXXX
1369	RU9483803436588743613330942629999	840	2023-04-22	ES8837924828989597198315672	международная	2140108.0195	12.4480	отменена	CHASUS33
1370	RU4983803436534576819154749347962	840	2023-06-14	RU3983803436583094600516227232333	внутренняя	4098994.0754	544.0719	доставлена	\N
1371	RU4883803436540069564759439339493	840	2023-06-30	BY4957499978272627514836474	международная	7582143.5892	220.9516	отправлена	IRVTUS3NXXX
1372	RU4283803436530972916151822377436	156	2023-02-18	AL6327684687849929072488257	международная	6583520.9584	509.4142	доставлена	BKCHCNBJ
1373	RU1383803436537041354890218533954	840	2023-09-15	ES8642523691835987493542721	международная	1109341.0182	451.2204	отправлена	IRVTUS3NXXX
1374	RU9683803436531094862059243712475	156	2023-07-19	DE1785317237327675618324693	международная	9979122.7874	931.9749	доставлена	BKCHCNBJ
1375	RU8683803436571821829992754282142	643	2023-04-06	AL4533442984354824452026987	внутренняя	4936706.3983	769.0086	отменена	\N
1376	RU1683803436536773128968824249362	840	2023-07-05	AL3439053704907731287119843	международная	8529077.3432	36.9145	отменена	CHASUS33
1377	RU4483803436537144245226352938256	356	2023-03-20	DE1517265052881658994489055	международная	5784678.5132	839.6590	отправлена	SBININBBXXX
1378	RU3683803436529963181547651499120	356	2023-03-09	KZ7918011002307142054692177	международная	9006805.6821	551.9217	отправлена	SBININBBXXX
1379	RU8383803436557193853878723819444	978	2023-10-19	DE9936825712854755357838978	международная	2722675.6132	986.7327	отменена	DEUTDEFFXXX
1380	RU8483803436593374085227717891522	398	2023-06-13	VN4330672626585300094798810	международная	4404551.8767	395.3608	отменена	CASPKZKAXXX
1381	RU5583803436581992686445972740236	643	2023-12-25	IN7239095133968999616914836	внутренняя	6387082.6258	482.3729	отменена	\N
1382	RU7483803436595027677837710467368	398	2023-05-14	RU6583803436599318340096840026283	внутренняя	5410982.5998	768.8316	отправлена	\N
1383	RU7183803436584925378313266803439	978	2023-05-08	RU6283803436541447099313442593938	внутренняя	8702532.0233	131.8072	отменена	\N
1384	RU4383803436557380827011382643653	840	2023-03-12	DE4332603146084316701429214	международная	3551344.1566	10.1296	отправлена	CHASUS33
1385	RU4083803436525661046500520760430	398	2023-07-12	RU7283803436583841985241060182740	внутренняя	6973313.4141	288.9530	отправлена	\N
1386	RU5783803436523742307313248220811	398	2023-08-22	RU7783803436578403910419087666263	внутренняя	234973.4067	213.6752	отменена	\N
1387	RU7583803436593621382878998665048	156	2023-03-02	AL1810530721342111839127396	международная	2773303.6788	725.8716	доставлена	BKCHCNBJ
1388	RU2683803436566742853200336170327	356	2023-11-22	RU9483803436588743613330942629999	внутренняя	3223811.2607	852.5414	доставлена	\N
1389	RU8683803436557989786811096289958	643	2023-03-05	RU1583803436533479152204865778047	внутренняя	9838774.3475	411.5175	отправлена	\N
1390	RU5483803436551418630110242560620	978	2023-10-18	ES7611315261627817879816638	международная	3839459.8539	808.0772	доставлена	RZBAATWW
1391	RU1683803436596193217028081534610	643	2023-05-29	DE6968596233988721495105296	внутренняя	4169173.6655	616.1051	отправлена	\N
1392	RU4283803436571605132393354830061	840	2023-10-23	RU9583803436589245078784775619456	внутренняя	6867954.0427	0.0000	доставлена	\N
1393	RU1583803436592948110594062864167	156	2023-06-11	RU3183803436538368625987340316428	внутренняя	4740391.2864	420.5791	доставлена	\N
1394	RU4083803436525661046500520760430	643	2023-11-09	RU8683803436520349379894661014091	внутренняя	8297763.5353	528.6775	отправлена	\N
1395	RU4483803436537144245226352938256	643	2023-01-05	VN5160739648611500621654236	внутренняя	2465022.7042	363.8917	отменена	\N
1396	RU5483803436547543071206231343471	156	2023-06-19	RU6783803436510078136565817264354	внутренняя	7085754.1166	878.8572	отправлена	\N
1397	RU6483803436513432249664452306210	156	2023-11-07	RU2083803436536025786076127901648	внутренняя	8023980.2356	19.1488	доставлена	\N
1398	RU2583803436586349630493889324094	978	2023-05-17	RU7783803436520045957277741704368	внутренняя	6053466.0567	919.0558	отправлена	\N
1399	RU1883803436537462946976236392804	398	2023-04-06	RU5983803436565674700991182664479	внутренняя	9127377.0839	750.3486	отменена	\N
1400	RU6583803436573484995572407857396	978	2023-10-08	AL9047939723947510627965728	международная	3505104.0219	87.4865	отправлена	RZBAATWW
1401	RU1683803436543683792461716245841	356	2023-03-07	AD7822327498383088415817399	международная	752643.4292	744.9676	отменена	SBININBBXXX
1402	RU5183803436550941857646482749776	356	2023-01-02	RU3583803436531844714480494060517	внутренняя	5493084.5660	799.0843	доставлена	\N
1403	RU7383803436515152831562897371432	978	2023-09-11	RU6983803436551969328605594993446	внутренняя	3294251.2666	665.3157	отправлена	\N
1404	RU5983803436558435772787343054218	840	2022-12-29	RU2583803436573489146610412814439	внутренняя	7851588.9823	790.0881	доставлена	\N
1405	RU8683803436520349379894661014091	156	2023-12-20	RU7583803436545511345420608427589	внутренняя	6333014.8696	762.7255	отправлена	\N
1406	RU7383803436585863943754594310819	643	2023-04-25	RU1183803436569972795023903837949	внутренняя	9487958.7418	188.9208	отменена	\N
1407	RU7483803436595027677837710467368	840	2023-10-03	AD8627099215747716574019435	международная	2474239.4075	888.8064	доставлена	IRVTUS3NXXX
1408	RU9183803436512467785925904841435	156	2023-07-13	RU2183803436538160023828199079683	внутренняя	4144944.6949	541.7321	отправлена	\N
1409	RU4783803436576956010684046744289	840	2023-01-26	RU8483803436597380246113206833117	внутренняя	7757628.5309	771.4493	отменена	\N
1410	RU5483803436559214869633349674125	156	2023-05-17	RU5383803436532276110708298062956	внутренняя	2692777.2366	578.8483	доставлена	\N
1411	RU8483803436546395435496825405512	156	2023-08-02	RU1683803436510344781123537250392	внутренняя	5990267.9684	602.9667	доставлена	\N
1412	RU5083803436521160540176223483455	356	2023-12-16	VN7159860811978948107302027	международная	277012.9060	504.3342	отправлена	SBININBBXXX
1413	RU7583803436545511345420608427589	156	2023-12-20	ES7243077101962513206526239	международная	8203312.6952	492.5956	доставлена	BKCHCNBJ
1414	RU2683803436566742853200336170327	978	2023-05-09	RU1283803436591782126481419856685	внутренняя	9544613.4301	68.9624	доставлена	\N
1415	RU5683803436522754650880470438385	356	2023-03-09	IN3540761276159064077327811	международная	6150905.3061	103.1734	доставлена	SBININBBXXX
1416	RU6383803436519000124215462920616	356	2023-02-06	RU6483803436527000884469712767990	внутренняя	7311829.0549	570.7368	отменена	\N
1417	RU5783803436567884889437805923129	643	2023-11-15	RU5583803436533254773648721597711	внутренняя	5533652.9965	0.0000	доставлена	\N
1418	RU8583803436593152008036708778596	978	2023-09-14	RU5183803436550941857646482749776	внутренняя	1249395.2508	311.8408	отменена	\N
1419	RU9083803436542335742968981386823	978	2023-02-04	RU5283803436570838144716210841495	внутренняя	799420.0866	186.2663	доставлена	\N
1420	RU5883803436549838724600410631189	156	2023-01-05	AL1293009512804186160997337	международная	1597006.3698	739.0143	отменена	BKCHCNBJ
1421	RU2183803436535230801413319305895	978	2023-06-05	RU5473473049510539835689220	внутренняя	971886.4451	355.5799	отправлена	\N
1422	RU6583803436588261503476787515721	978	2023-10-22	BY1358984827167916357533621	международная	4678027.3894	636.4556	отменена	DEUTDEFFXXX
1423	RU8283803436558421168306139201398	840	2023-04-16	DE6671209226193723903474767	международная	6078849.0832	528.2499	отменена	CHASUS33
1424	RU4083803436525661046500520760430	978	2023-01-19	RU2283803436594102552659582448178	внутренняя	9985210.1716	752.7102	доставлена	\N
1425	RU7683803436589524723383129532286	978	2023-05-09	BY6758576878069105114427369	международная	2224564.3430	687.0997	отправлена	DEUTDEFFXXX
1426	RU2083803436536025786076127901648	156	2023-10-10	RU6783803436583735354795738130605	внутренняя	7864277.5245	71.3900	отменена	\N
1427	RU4583803436576777630615652907536	978	2023-06-14	RU7056199343629253471116317	внутренняя	5016199.4880	520.7676	доставлена	\N
1428	RU9483803436585469145832242711561	978	2023-12-21	RU8483803436517523304653033637180	внутренняя	3322736.5713	676.2073	отправлена	\N
1429	RU2383803436569895097903578030814	356	2023-07-18	RU4283803436515276086545867508581	внутренняя	9030176.3197	276.5016	отменена	\N
1430	RU6283803436577836700807681117407	643	2023-11-13	AL6569495526021287056910661	внутренняя	3915481.1011	552.0284	доставлена	\N
1431	RU9483803436585469145832242711561	840	2023-09-08	AL8761444046303003829023499	международная	7400384.5453	39.0130	доставлена	IRVTUS3NXXX
1432	RU2083803436518033160343253894367	398	2023-11-26	IN7133759234239484624279337	международная	2627788.2697	824.2172	отправлена	CASPKZKAXXX
1433	RU1983803436537997284898110055528	156	2023-06-13	RU2598120772047704986217949	внутренняя	7505792.0969	377.0862	отправлена	\N
1434	RU5583803436541779385547740767657	356	2023-05-15	KZ9080826955026013530680529	международная	5000901.6204	691.1717	доставлена	SBININBBXXX
1435	RU1983803436518034161993382946183	356	2023-05-08	RU4283803436583191860084907222827	внутренняя	3512544.3710	457.3103	доставлена	\N
1436	RU4183803436555804329090528802664	398	2023-05-20	RU1383803436546084241558471107471	внутренняя	5547039.2513	918.2884	доставлена	\N
1437	RU7483803436591068390387769478580	398	2023-09-03	RU1583803436597114679330016317094	внутренняя	7176723.2653	884.1860	отменена	\N
1438	RU4383803436583134155448910498762	398	2023-03-24	RU2083803436517185898516741185299	внутренняя	8061203.8735	276.6229	отправлена	\N
1439	RU8783803436544746989208687599320	156	2023-08-05	PT1783484177439026792413747	международная	3853798.3574	636.2849	отменена	BKCHCNBJ
1440	RU3383803436533625475503259998648	398	2023-04-10	RU2283803436594102552659582448178	внутренняя	9806071.9896	397.4147	доставлена	\N
1441	RU2083803436573246597416370413406	840	2023-06-02	PT1689110436356978485572357	международная	5021125.8462	580.4768	доставлена	CHASUS33
1442	RU6583803436592149423686806465410	356	2023-06-26	RU7527013132769406770639605	внутренняя	9179748.5344	156.1453	доставлена	\N
1443	RU8983803436530366335955653516096	398	2023-05-30	RU4583803436588661449801193641363	внутренняя	8096829.8423	148.1648	отправлена	\N
1444	RU8383803436557193853878723819444	356	2023-08-14	RU8583803436580493050529274956761	внутренняя	5866603.1676	474.1627	отправлена	\N
1445	RU4083803436526038486689011711230	356	2023-08-20	RU7027126877842017015314548	внутренняя	307597.7227	99.0190	отправлена	\N
1446	RU9683803436559214297350823715344	356	2023-10-31	BY9610908089749375034732537	международная	3820703.0644	705.3325	отправлена	SBININBBXXX
1447	RU4383803436535637847836978327691	398	2023-03-23	PT5218513125758454741772347	международная	3351108.0448	714.0720	доставлена	CASPKZKAXXX
1448	RU4983803436534576819154749347962	356	2023-10-25	AL1878169922869453007900221	международная	6868858.3103	744.3404	отправлена	SBININBBXXX
1449	RU9083803436527710172880684864084	156	2023-03-21	AD6323777252224827922870764	международная	6399882.4379	275.5755	доставлена	BKCHCNBJ
1450	RU8783803436544746989208687599320	156	2023-07-17	PT4578967435142497936096674	международная	8277410.4086	258.2416	отправлена	BKCHCNBJ
1451	RU5183803436588244188761426669013	356	2023-10-10	IN7949449174862047477610913	международная	2596469.1732	223.4199	доставлена	SBININBBXXX
1452	RU2283803436551819000625747494652	643	2023-07-20	VN5698461705215924208759581	внутренняя	6553630.5044	629.2945	отменена	\N
1453	RU2883803436564862346362051659673	356	2023-04-14	RU6783803436582018660242960957244	внутренняя	1926250.6983	764.1337	отправлена	\N
1454	RU2683803436512319317744369021772	356	2023-10-30	IN4097119286622010151612159	международная	1265931.2741	471.8363	отправлена	SBININBBXXX
1455	RU7083803436595909521339223196614	356	2023-04-15	AL8443812679129843708477779	международная	4312288.3637	596.7821	доставлена	SBININBBXXX
1456	RU5583803436556151120487866130687	398	2023-02-12	DE1264650679310231481348382	международная	6203366.4768	405.1835	отправлена	CASPKZKAXXX
1457	RU9683803436559214297350823715344	398	2023-10-19	AL3686195211738624862531081	международная	8263662.3373	884.5648	доставлена	CASPKZKAXXX
1458	RU3383803436533625475503259998648	156	2023-04-16	AL3956954973983532261841368	международная	6493083.2151	156.9669	доставлена	BKCHCNBJ
1459	RU8483803436514025076841381077297	356	2023-01-07	RU6683803436575472065287991925682	внутренняя	3218310.0482	741.3474	отменена	\N
1460	RU2983803436588011593439328399453	643	2023-05-31	RU2483803436559904294875702128517	внутренняя	629880.7305	713.8948	отменена	\N
1461	RU7183803436513501317784267991188	978	2023-08-12	ES9582555163642840606271819	международная	3174380.7320	718.3570	отправлена	SOGEFRPP
1462	RU1383803436596151895061926683764	356	2023-10-20	KZ3092865543563929286479122	международная	7249645.2149	730.8204	отправлена	SBININBBXXX
1463	RU2583803436586349630493889324094	978	2023-09-20	BY3128775003482906129962340	международная	1041581.4537	14.6475	доставлена	RZBAATWW
1464	RU6383803436517724803474176712817	156	2023-04-27	RU7818033482905984668266163	внутренняя	8145973.6823	532.7351	отменена	\N
1465	RU1983803436510686315036595318873	978	2023-05-24	RU1283803436591782126481419856685	внутренняя	6487425.7380	566.9928	отправлена	\N
1466	RU7183803436551143317683635788042	356	2023-08-26	RU8183803436576908594301902139271	внутренняя	8016513.1226	627.1449	доставлена	\N
1467	RU3983803436583094600516227232333	156	2022-12-30	IN4534943758763308801710988	международная	7984414.9705	31.4279	отменена	BKCHCNBJ
1468	RU7483803436595027677837710467368	398	2023-03-31	RU9383803436587347167184231490115	внутренняя	9651628.6098	955.9252	доставлена	\N
1469	RU3683803436529963181547651499120	978	2023-05-29	IN1064681332972787426733205	международная	7980851.3422	14.5444	отправлена	DEUTDEFFXXX
1470	RU5783803436573951128453151787227	356	2023-02-01	AD1749589686657831685642320	международная	8867297.8560	559.9679	отправлена	SBININBBXXX
1471	RU4783803436556925313909023616425	643	2023-06-01	PT4895020854036409008335641	внутренняя	4495938.3818	843.1926	доставлена	\N
1472	RU2683803436566742853200336170327	643	2023-02-11	RU4283803436544879224116585983050	внутренняя	3765065.9007	679.0801	доставлена	\N
1473	RU1583803436578714315409224923820	978	2023-08-17	AL2242002356543862286806214	международная	1964345.8406	228.8802	отправлена	DEUTDEFFXXX
1474	RU7083803436569474567525801645267	978	2023-10-16	KZ9592733531156042455563192	международная	3637290.8059	776.3233	отменена	SOGEFRPP
1475	RU3783803436562091905141244310726	156	2023-10-09	IN4916077734995133665075578	международная	1918323.8692	850.9115	отправлена	BKCHCNBJ
1476	RU2183803436551906716086082339754	156	2023-01-29	RU2083803436593214630941740939011	внутренняя	7118217.4239	718.5630	отправлена	\N
1477	RU1383803436537041354890218533954	643	2023-01-06	AL2349641948862537020914410	внутренняя	3205800.1478	775.8229	доставлена	\N
1478	RU1883803436562141776165180370424	356	2023-03-06	RU3983803436580604058878329162478	внутренняя	2841171.4627	872.0797	доставлена	\N
1479	RU9583803436574471411467135718624	398	2023-12-15	PT6014192459253038510000650	международная	9388009.1668	899.4447	отправлена	CASPKZKAXXX
1480	RU9783803436531316283778462589484	156	2023-07-25	RU3183803436564747839620735247465	внутренняя	4838163.6212	260.7666	доставлена	\N
1481	RU2783803436515955219320238454317	840	2023-03-24	RU5583803436525031727011657164177	внутренняя	7943888.5908	419.5335	отменена	\N
1482	RU3683803436533022850683714599602	156	2023-11-18	PT7367538989885563629904267	международная	1234338.8416	867.2613	отменена	BKCHCNBJ
1483	RU6483803436595566817980742907742	356	2023-04-22	RU8483803436552375991404578719285	внутренняя	9219012.4631	132.0006	отменена	\N
1484	RU2083803436536025786076127901648	840	2023-07-16	RU5083803436563140090168469536649	внутренняя	7357330.6931	266.7659	отменена	\N
1485	RU8683803436520349379894661014091	156	2023-02-23	RU1883803436547883958852583813660	внутренняя	1130766.0239	617.0941	отменена	\N
1486	RU3983803436562540544761068231244	156	2023-10-22	RU6983803436551969328605594993446	внутренняя	2200448.7571	21.1687	отменена	\N
1487	RU8483803436597380246113206833117	398	2023-01-28	ES2269052622511544823758775	международная	6130884.2369	301.6662	отправлена	CASPKZKAXXX
1488	RU7483803436516612664745741202549	156	2023-06-14	ES2961923866387439443057928	международная	4562227.1840	492.7276	доставлена	BKCHCNBJ
1489	RU1583803436533479152204865778047	840	2023-02-06	RU5583803436516539388298963058164	внутренняя	3073074.9449	157.8735	отменена	\N
1490	RU6883803436521704893234788177503	840	2023-09-12	KZ8148606279204347385105563	международная	7761113.1507	995.6642	отменена	IRVTUS3NXXX
1491	RU6783803436527708547728704282997	978	2023-12-24	PT6999983554189548128938054	международная	1383722.7707	718.0678	отправлена	DEUTDEFFXXX
1492	RU8183803436546948351691601253240	156	2023-06-30	RU2483803436559904294875702128517	внутренняя	4019258.0274	115.0200	отменена	\N
1493	RU4583803436567844239839748091371	398	2023-02-12	IN8854680577313725072683836	международная	6409010.3843	46.2942	доставлена	CASPKZKAXXX
1494	RU9283803436529032721317031749293	356	2023-01-09	RU3483803436537283842522563725379	внутренняя	9082948.8216	593.1236	отправлена	\N
1495	RU5383803436537654175631942789109	643	2023-07-08	RU9383803436546841675173507423577	внутренняя	4462131.3297	118.5395	отправлена	\N
1496	RU4683803436521950147450839996450	643	2023-01-05	RU6583803436526807323529165700056	внутренняя	2833668.0184	676.6050	отправлена	\N
1497	RU6383803436530975100435134167112	840	2023-05-28	RU1983803436518034161993382946183	внутренняя	8713964.5424	991.3871	доставлена	\N
1498	RU4783803436556925313909023616425	398	2023-08-25	ES5467419175814067902262446	международная	4863854.8218	869.2635	доставлена	CASPKZKAXXX
1499	RU3283803436586063041663029658571	356	2023-04-07	ES5080305698928871363392624	международная	9670785.1805	366.7055	отправлена	SBININBBXXX
1500	RU8283803436517214496879594083501	398	2023-11-29	IN1695246987152915348714844	международная	3101587.4286	846.1925	отправлена	CASPKZKAXXX
1501	RU3183803436583121152517184662518	356	2023-11-15	RU1983803436574962372646294489745	внутренняя	5777539.5261	97.8171	отменена	\N
1502	RU4283803436538514172142523078432	156	2023-12-18	KZ3535795848841172552155401	международная	3243177.1594	648.0737	отменена	BKCHCNBJ
1503	RU1583803436513968949783488654583	356	2023-04-13	VN3554000507573361392844063	международная	890567.1943	751.5579	отправлена	SBININBBXXX
1504	RU4283803436538514172142523078432	643	2023-03-23	VN3725172357252757330345879	внутренняя	6205868.9813	147.1379	отправлена	\N
1505	RU3083803436556733352794187735054	978	2023-03-05	RU8583803436580493050529274956761	внутренняя	5150163.9183	110.6732	отменена	\N
1506	RU9983803436545906901757432591750	978	2023-08-03	RU4183803436593654490331448399606	внутренняя	708416.9698	64.3580	отправлена	\N
1507	RU3683803436529963181547651499120	156	2023-10-20	RU5283803436529894140873721164089	внутренняя	4363290.6667	332.4045	доставлена	\N
1508	RU3183803436583121152517184662518	356	2023-03-05	IN3512561659972389695006311	международная	8179675.1466	749.3368	отменена	SBININBBXXX
1509	RU9983803436545906901757432591750	840	2023-10-26	RU4583803436546993711061481413708	внутренняя	341022.4729	893.5892	отменена	\N
1510	RU6083803436582119843499506879640	398	2023-06-08	DE8567558757469998330188592	международная	3251504.4698	132.4192	отправлена	CASPKZKAXXX
1511	RU1183803436536239647096212180861	978	2023-01-11	IN3822643414738487277307394	международная	222723.7416	782.6684	отменена	DEUTDEFFXXX
1512	RU1583803436533479152204865778047	356	2023-08-21	RU4983803436534576819154749347962	внутренняя	5171153.3672	705.8080	отменена	\N
1513	RU1383803436537041354890218533954	356	2023-11-13	RU9583803436557636243711161422858	внутренняя	8607537.7786	808.9782	отправлена	\N
1514	RU8183803436555934243334630961587	840	2023-02-05	RU1977740621772179351089488	внутренняя	2169195.1837	85.1816	отправлена	\N
1515	RU9583803436515959194321808018014	643	2023-01-30	PT6350910162248948970932351	внутренняя	6341442.3668	378.9257	отменена	\N
1516	RU8183803436559528710172368223769	356	2023-01-04	IN6243756812823459846066397	международная	5682143.6585	371.5992	отменена	SBININBBXXX
1517	RU5483803436538988818998904026382	356	2023-05-25	RU6294435051659257518338236	внутренняя	2460722.6216	459.8069	доставлена	\N
1518	RU8383803436543267469021061769102	156	2023-02-01	RU3183803436538368625987340316428	внутренняя	2389423.3509	427.3308	отменена	\N
1519	RU2983803436530272226005609138408	643	2023-05-17	KZ9279230658973665217101470	внутренняя	5912885.3626	343.9189	доставлена	\N
1520	RU4283803436583191860084907222827	398	2023-03-05	RU5483803436551418630110242560620	внутренняя	6329409.8912	245.5525	доставлена	\N
1521	RU1283803436521770311179326367954	643	2023-08-31	RU9483803436570307762028951954874	внутренняя	2678628.9126	882.3169	доставлена	\N
1522	RU4883803436577275200947611443039	398	2023-12-16	RU2983803436588011593439328399453	внутренняя	1745190.7627	53.4063	отменена	\N
1523	RU4883803436561825246742556433732	156	2023-01-21	PT9842587316393620711937862	международная	4418435.9525	854.4615	отменена	BKCHCNBJ
1524	RU4183803436593654490331448399606	356	2023-06-30	RU9683803436597203099828784600586	внутренняя	9836656.4178	406.5724	отменена	\N
1525	RU6983803436521001508692071958064	398	2023-11-18	RU4483803436534969190676238532628	внутренняя	5204025.4310	600.8963	отменена	\N
1526	RU5583803436533254773648721597711	978	2023-04-07	RU6283803436577836700807681117407	внутренняя	604784.6483	430.6914	отменена	\N
1527	RU2983803436572678251629055132350	978	2023-09-23	RU5278414986939902266280058	внутренняя	9334294.8243	783.0820	доставлена	\N
1528	RU6383803436530975100435134167112	398	2023-06-03	RU6523091998038148989934905	внутренняя	1105517.5406	300.9540	доставлена	\N
1529	RU8683803436557989786811096289958	156	2023-03-09	RU6983803436521001508692071958064	внутренняя	6236442.7440	177.8597	доставлена	\N
1530	RU9683803436511276549947859990709	978	2023-10-25	RU4883803436510661666911089208306	внутренняя	1789742.5182	488.9978	доставлена	\N
1531	RU4983803436522833268295991391237	978	2023-10-17	RU5483803436559214869633349674125	внутренняя	1479908.9806	463.6514	доставлена	\N
1532	RU4183803436598422593606583773593	840	2023-08-22	RU5783803436598085342824416355658	внутренняя	5008745.9038	705.7214	доставлена	\N
1533	RU5183803436588801456118987264753	398	2023-06-18	RU8483803436597380246113206833117	внутренняя	3421962.1065	805.7423	отправлена	\N
1534	RU6383803436512605200896614597744	643	2023-11-09	IN9045718236202497960042563	внутренняя	3361961.4234	868.8711	доставлена	\N
1535	RU3683803436533022850683714599602	156	2023-05-29	PT4891355119716718537389198	международная	472241.7234	508.4815	доставлена	BKCHCNBJ
1536	RU4283803436583191860084907222827	978	2023-02-19	AL9466600182836937937437176	международная	4106472.0767	41.7936	отменена	DEUTDEFFXXX
1537	RU8283803436593409912626065485368	156	2023-12-17	RU8583803436567351126582917385267	внутренняя	611564.5998	631.2160	отправлена	\N
1538	RU9383803436563463129216774786629	978	2023-08-18	RU5583803436556151120487866130687	внутренняя	2985506.6262	133.1496	отменена	\N
1539	RU6083803436569163727288631654599	643	2023-02-21	RU2283803436594102552659582448178	внутренняя	599505.6082	363.0913	доставлена	\N
1540	RU9683803436526786707929300961979	356	2023-05-11	VN4521256415664959425511674	международная	4967246.2611	912.8998	отменена	SBININBBXXX
1541	RU5083803436563140090168469536649	398	2023-07-05	PT9942623398487559154325530	международная	7980582.9503	952.9945	отменена	CASPKZKAXXX
1542	RU2183803436555308456329784386702	356	2023-01-15	RU5983803436518386216122030936247	внутренняя	3625519.9465	191.9314	доставлена	\N
1543	RU6483803436557881046066137062384	978	2022-12-27	AL6560774234352755553284165	международная	27625.9008	259.2871	доставлена	SOGEFRPP
1544	RU3183803436538368625987340316428	356	2023-01-30	RU7183803436551143317683635788042	внутренняя	7508231.0928	937.3740	доставлена	\N
1545	RU8283803436536082355231514909614	156	2023-03-16	AL3780537714287657556159068	международная	256348.0467	831.6122	отправлена	BKCHCNBJ
1546	RU8183803436559528710172368223769	978	2023-10-21	RU6483803436513432249664452306210	внутренняя	4912167.5572	438.0307	отменена	\N
1547	RU8083803436588746463552823930061	156	2023-02-27	DE6942919286242631314785875	международная	9020148.1436	792.6053	отправлена	BKCHCNBJ
1548	RU3383803436551883036237842733910	156	2023-06-24	RU3111702559297996898467709	внутренняя	2848566.9798	223.1094	доставлена	\N
1549	RU3683803436529963181547651499120	978	2023-05-24	RU7283803436551671539996901196859	внутренняя	1678778.1403	994.3519	отправлена	\N
1550	RU4983803436522833268295991391237	156	2023-05-20	RU6383803436530975100435134167112	внутренняя	4612817.9374	696.5022	отправлена	\N
1551	RU8983803436519227550175732694863	978	2023-10-27	RU5283803436570838144716210841495	внутренняя	2643624.6667	665.4017	отменена	\N
1552	RU8483803436586135450040789229889	643	2023-12-11	RU7683803436565241249132549566386	внутренняя	4289271.5987	461.3268	доставлена	\N
1553	RU4083803436530357399673623809331	643	2023-11-08	RU1683803436510344781123537250392	внутренняя	2283219.1713	398.7421	отменена	\N
1554	RU1983803436518034161993382946183	840	2023-01-07	VN3640507537588656091742803	международная	5012005.2872	746.4802	доставлена	IRVTUS3NXXX
1555	RU1983803436558651220197686454204	356	2023-01-01	KZ3530698625383493953685441	международная	8935654.1063	427.3235	отменена	SBININBBXXX
1556	RU4183803436593654490331448399606	156	2023-01-06	RU9283803436564588409350021574669	внутренняя	1849013.1380	17.9423	доставлена	\N
1557	RU9883803436596118671708861810646	398	2023-02-19	VN8619472966226875220546618	международная	148218.8564	195.8974	отправлена	CASPKZKAXXX
1558	RU2783803436512588965300606208370	643	2023-06-09	IN8084135976057730767199104	внутренняя	8286657.8255	821.6948	доставлена	\N
1559	RU4383803436535637847836978327691	356	2023-04-05	VN7894515164547886095984927	международная	8641355.1654	94.2107	отменена	SBININBBXXX
1560	RU4783803436576956010684046744289	840	2023-10-16	RU4083803436525661046500520760430	внутренняя	506732.2462	20.2945	доставлена	\N
1561	RU6183803436547326038705936576601	978	2023-10-13	AD4126381011012298448344637	международная	9774847.4202	85.4454	доставлена	SOGEFRPP
1562	RU5383803436537654175631942789109	840	2023-07-05	IN3398842681255817964421576	международная	1376242.8972	112.7115	отменена	IRVTUS3NXXX
1563	RU8183803436576334203563049364101	643	2023-08-10	RU2683803436512319317744369021772	внутренняя	5551999.6035	736.7900	доставлена	\N
1564	RU9483803436522220035875117822565	978	2023-03-06	AD4878549526240171528680208	международная	5092639.7883	168.1665	доставлена	SOGEFRPP
1565	RU6583803436592149423686806465410	356	2023-02-09	RU5983803436565674700991182664479	внутренняя	8326752.6158	671.9228	отменена	\N
1566	RU2283803436527235231809863175226	398	2023-03-23	ES6130670525397801080105522	международная	8888244.3870	522.1661	отменена	CASPKZKAXXX
1567	RU8483803436546395435496825405512	978	2023-03-12	AD9588392077205145268386685	международная	4196779.3602	127.3092	отменена	SOGEFRPP
1568	RU4983803436534576819154749347962	840	2023-04-30	IN5986830839241861228514096	международная	3218587.6988	241.5958	доставлена	CHASUS33
1569	RU2783803436529440294678710752920	156	2023-03-20	RU5183803436550941857646482749776	внутренняя	8963177.3400	169.4102	отменена	\N
1570	RU8783803436522200736153030297680	840	2023-05-08	RU2783803436580745382811010865973	внутренняя	1176789.5931	140.8519	отправлена	\N
1571	RU9683803436511276549947859990709	978	2023-12-04	BY5127351947420066886629350	международная	2988441.2067	838.4217	отправлена	RZBAATWW
1572	RU2183803436586747579379810386651	156	2023-06-09	RU5680337878840353905335596	внутренняя	9997394.7518	366.1308	доставлена	\N
1573	RU5083803436537344339331652897359	398	2023-02-01	PT5859304845244658157344242	международная	7863397.4219	966.4849	доставлена	CASPKZKAXXX
1574	RU7483803436529598231033100377224	643	2023-04-18	RU4583803436571583967013936520660	внутренняя	6021292.8285	458.2795	доставлена	\N
1575	RU6483803436595566817980742907742	398	2023-10-11	RU2983803436572636545308279163382	внутренняя	4264885.3052	685.1425	доставлена	\N
1576	RU6183803436547326038705936576601	156	2023-05-04	RU6883803436524866655852609791727	внутренняя	7374817.7407	866.7474	отправлена	\N
1577	RU5583803436525031727011657164177	978	2023-04-13	RU2283803436594102552659582448178	внутренняя	3791574.0013	956.4071	доставлена	\N
1578	RU2383803436518501918755699207235	978	2023-10-22	AD8991393627771133483764501	международная	2946107.0302	555.1280	отменена	DEUTDEFFXXX
1579	RU1883803436547883958852583813660	978	2023-11-11	VN3217772724804332488340828	международная	6203672.0915	680.5948	доставлена	RZBAATWW
1580	RU4483803436537144245226352938256	356	2023-05-16	RU2983803436530272226005609138408	внутренняя	5497381.7493	324.0071	доставлена	\N
1581	RU8183803436532187852215520403243	643	2023-04-09	KZ4281021838887097196071435	внутренняя	6198819.5494	689.7716	отменена	\N
1582	RU8483803436576032684947735830335	356	2023-11-15	RU7283803436565335970635584506660	внутренняя	2958267.3863	123.1626	отправлена	\N
1583	RU3683803436526413764026311806751	643	2023-10-15	DE2188006537624315635809389	внутренняя	4082792.6296	357.8285	отменена	\N
1584	RU8583803436598717986670697262250	978	2023-09-25	PT7181870417260429987725342	международная	2875120.0645	292.3643	отменена	DEUTDEFFXXX
1585	RU8483803436593374085227717891522	978	2023-08-08	RU2483803436537933507280624045523	внутренняя	3644355.5828	633.3951	доставлена	\N
1586	RU1383803436546084241558471107471	840	2023-09-09	RU1983803436510712914540451632365	внутренняя	1313615.5947	460.9650	отправлена	\N
1587	RU7483803436591068390387769478580	978	2023-04-14	RU9517178852782083225519823	внутренняя	5403366.6471	226.4409	доставлена	\N
1588	RU2083803436573246597416370413406	840	2023-09-11	RU4068104921124100624273278	внутренняя	1846073.9439	635.1961	отправлена	\N
1589	RU4183803436593654490331448399606	643	2023-09-29	KZ9047566067072885511401543	внутренняя	7468609.6304	94.4960	доставлена	\N
1590	RU7483803436512314763652680872976	156	2023-08-16	AD3693689453419035250602679	международная	5832372.9153	493.5122	отменена	BKCHCNBJ
1591	RU8983803436550652073660555482382	978	2023-08-06	RU8983803436519227550175732694863	внутренняя	8128158.7201	452.0722	отменена	\N
1592	RU1383803436565139777755041333233	356	2023-01-01	PT4761999283869099329796204	международная	123028.7661	10.9210	доставлена	SBININBBXXX
1593	RU7183803436546875767014611813689	840	2023-07-30	RU8883803436542351475891948314875	внутренняя	8528939.9385	665.5503	отправлена	\N
1594	RU4883803436510661666911089208306	156	2023-03-05	RU9383803436546841675173507423577	внутренняя	4066896.6426	367.4903	отправлена	\N
1595	RU1183803436536239647096212180861	156	2023-05-30	RU7083803436565850801859363291526	внутренняя	2172177.7024	731.8992	отправлена	\N
1596	RU8583803436529401978461350257287	398	2023-06-07	AD7396677808765360706098624	международная	9125278.1044	160.7449	отправлена	CASPKZKAXXX
1597	RU1683803436596193217028081534610	398	2023-09-24	KZ2919825862186332519887865	международная	603669.6991	370.3986	отправлена	CASPKZKAXXX
1598	RU7183803436584925378313266803439	643	2023-02-12	RU9583803436557636243711161422858	внутренняя	7192908.8423	933.4914	доставлена	\N
1599	RU6983803436542868245387240901621	840	2023-02-17	RU6583803436546434088553514688778	внутренняя	323896.5467	462.4216	отправлена	\N
1600	RU9083803436548965374028188380728	356	2023-09-03	BY4973158901855705061511322	международная	5216608.9738	54.7916	отменена	SBININBBXXX
1601	RU3983803436569376600246742084811	643	2023-10-09	RU3869436395293511316990005	внутренняя	5580480.3124	831.5932	отменена	\N
1602	RU4483803436534969190676238532628	356	2023-11-13	AD4321628931974677043246019	международная	8463693.8249	91.1439	отменена	SBININBBXXX
1603	RU5483803436538988818998904026382	356	2023-03-02	RU6183803436547326038705936576601	внутренняя	2445470.8758	455.7046	отменена	\N
1604	RU4383803436597428452957764955765	840	2023-01-26	RU1983803436510712914540451632365	внутренняя	1298621.5910	452.0400	отменена	\N
1605	RU2283803436555228451424548337941	356	2023-01-03	RU9983803436545906901757432591750	внутренняя	2862025.7511	794.9112	отменена	\N
1606	RU5583803436516539388298963058164	356	2023-10-18	AD1752243012649361366601260	международная	2714161.5727	698.3483	доставлена	SBININBBXXX
1607	RU3583803436597484588589933917343	156	2023-04-16	AD1814285912567327458086082	международная	229021.7353	157.9562	отправлена	BKCHCNBJ
1608	RU6683803436546559918630563560759	643	2023-07-30	RU3483803436537283842522563725379	внутренняя	4364843.2255	629.7657	отменена	\N
1609	RU3383803436527231938190662146888	978	2023-08-22	RU5683803436575772290627280121203	внутренняя	1719625.4427	119.2268	отправлена	\N
1610	RU8983803436588264357315670765686	398	2023-08-03	RU4283803436532641085536208083176	внутренняя	4982445.1934	856.7755	доставлена	\N
1611	RU5183803436573013692902081587761	978	2023-10-28	ES2035931754745023256592448	международная	4682967.8268	716.8431	отменена	RZBAATWW
1612	RU3083803436572725983728902081378	398	2023-08-21	RU5783803436568341660520010753753	внутренняя	742369.2831	366.6295	отправлена	\N
1613	RU2983803436572678251629055132350	840	2023-02-14	AL6056149984978413769440882	международная	2997431.2760	710.0110	отменена	IRVTUS3NXXX
1614	RU2783803436580745382811010865973	643	2023-05-28	RU2983803436530272226005609138408	внутренняя	2394469.2958	415.4548	доставлена	\N
1615	RU6383803436519000124215462920616	156	2023-06-06	AL7220329619950047744108987	международная	5593461.8706	971.5660	отправлена	BKCHCNBJ
1616	RU2483803436537933507280624045523	356	2023-05-10	RU2225184485268676842941989	внутренняя	1240185.1801	88.9781	доставлена	\N
1617	RU3983803436554516084539411139147	156	2023-08-07	KZ9558090459451726514455978	международная	6809571.8857	837.8375	отправлена	BKCHCNBJ
1618	RU8083803436567877444686336475183	840	2023-08-08	KZ7498636079995666033431877	международная	976855.4826	874.0282	отменена	IRVTUS3NXXX
1619	RU8483803436583598027317615125571	156	2023-05-21	PT8067905454150707690138697	международная	6179241.4647	917.9585	отправлена	BKCHCNBJ
1620	RU2583803436573489146610412814439	643	2023-03-09	RU4396176603219114673493830	внутренняя	2241423.5149	163.9399	доставлена	\N
1621	RU2683803436566742853200336170327	643	2023-04-27	RU1583803436513968949783488654583	внутренняя	4804445.2446	866.4927	отменена	\N
1622	RU7283803436583841985241060182740	156	2023-07-14	AL4796558404135895709713542	международная	7071889.6752	721.5320	отменена	BKCHCNBJ
1623	RU2183803436551906716086082339754	398	2023-07-21	ES1753240904289068019149430	международная	9869565.5496	800.5428	отправлена	CASPKZKAXXX
1624	RU4883803436563163057705977553405	156	2023-01-12	RU1983803436537997284898110055528	внутренняя	8345487.7502	668.3448	доставлена	\N
1625	RU5983803436558435772787343054218	840	2023-09-30	RU3383803436548623436381587682007	внутренняя	4114547.7681	835.4859	отменена	\N
1626	RU8983803436513229118545499417330	978	2023-12-27	BY1350753709048281024470451	международная	6693668.6018	693.7098	доставлена	RZBAATWW
1627	RU2583803436569716293278278112122	978	2023-06-15	BY5214964485441232839929080	международная	1602821.4248	99.4224	отправлена	SOGEFRPP
1628	RU3983803436554516084539411139147	398	2023-11-26	RU1683803436543683792461716245841	внутренняя	7345004.1331	851.3488	отправлена	\N
1629	RU6283803436561107985248905256058	978	2023-10-10	RU1883803436537462946976236392804	внутренняя	3457106.4064	666.2456	доставлена	\N
1630	RU2883803436564862346362051659673	156	2023-05-27	IN7951282706932444535279540	международная	7040521.8916	252.5073	отменена	BKCHCNBJ
1631	RU1983803436574962372646294489745	156	2023-03-22	RU5783803436523742307313248220811	внутренняя	8957496.6367	82.7557	отправлена	\N
1632	RU7483803436544936047225386728318	356	2023-02-03	BY3637076757455416164462811	международная	4594839.4575	997.8761	доставлена	SBININBBXXX
1633	RU4183803436555804329090528802664	398	2023-06-09	RU3683803436542925451475324573982	внутренняя	7399285.0258	671.5348	отменена	\N
1634	RU9883803436510697875492928159959	156	2023-03-06	RU3183803436564747839620735247465	внутренняя	5778248.6404	669.0314	доставлена	\N
1635	RU6883803436521704893234788177503	840	2023-07-18	ES4642514558272193807271597	международная	1359472.7777	91.5748	отправлена	CHASUS33
1636	RU8483803436593374085227717891522	156	2023-02-10	AD2631313836992050293480351	международная	9541120.8885	439.0949	отменена	BKCHCNBJ
1637	RU3183803436583121152517184662518	356	2023-04-19	VN1871324384598714976841063	международная	3990008.4827	135.1979	отправлена	SBININBBXXX
1638	RU8483803436593374085227717891522	356	2023-10-02	RU1983803436558651220197686454204	внутренняя	3307645.1425	295.1851	доставлена	\N
1639	RU6583803436588261503476787515721	356	2023-05-14	BY3138649307231910852931895	международная	7607808.7644	187.1783	отправлена	SBININBBXXX
1640	RU6683803436534213789698830771682	398	2023-05-16	RU8983803436588264357315670765686	внутренняя	6008691.5882	198.3471	отправлена	\N
1641	RU4083803436525661046500520760430	643	2023-07-17	RU3183803436583121152517184662518	внутренняя	8337300.7869	434.1609	доставлена	\N
1642	RU3383803436527231938190662146888	978	2023-10-07	RU2083803436571871160330810400191	внутренняя	125473.0989	514.6550	отменена	\N
1643	RU1583803436513968949783488654583	356	2023-04-21	PT3889698981884281826796755	международная	1326944.5628	837.2478	отменена	SBININBBXXX
1644	RU8683803436531608639655465618756	643	2023-09-27	BY9486842261472268982720045	внутренняя	2058087.1297	319.9098	отправлена	\N
1645	RU7383803436515152831562897371432	840	2023-10-11	KZ8272519172859952927967129	международная	5685411.9547	651.9840	доставлена	CHASUS33
1646	RU7783803436529059332090835348557	978	2023-11-01	IN5865827797646011543292845	международная	9033872.4097	867.2711	доставлена	SOGEFRPP
1647	RU4283803436530972916151822377436	840	2023-08-24	AD1040044758314846144759739	международная	3506083.0599	348.7633	отменена	IRVTUS3NXXX
1648	RU2983803436585384738431881857607	978	2023-06-23	AD4137012281681775892503495	международная	2713902.6598	255.2210	отменена	DEUTDEFFXXX
1649	RU2083803436593214630941740939011	156	2023-06-03	PT6117330639879069668608903	международная	9320794.3531	784.6730	доставлена	BKCHCNBJ
1650	RU4183803436593654490331448399606	156	2023-04-15	ES8086856766117533307536046	международная	2930896.7009	918.0416	доставлена	BKCHCNBJ
1651	RU8483803436552375991404578719285	978	2023-08-24	RU9165417953956716321047810	внутренняя	7130183.9885	51.4505	отменена	\N
1652	RU2283803436551819000625747494652	156	2023-03-23	RU8183803436546948351691601253240	внутренняя	5802847.4750	639.5769	отменена	\N
1653	RU7683803436578953117174553181317	840	2023-08-31	RU2883803436512412400998624231254	внутренняя	9059568.4591	801.8744	отменена	\N
1654	RU2183803436586747579379810386651	156	2023-10-01	RU8183803436566794763466227027850	внутренняя	2881970.1835	56.2399	отменена	\N
1655	RU6283803436577836700807681117407	840	2023-04-09	ES8498668548737143156282451	международная	5749528.4920	859.9130	отправлена	CHASUS33
1656	RU6983803436582618731634671628237	978	2023-06-13	RU6983803436596433824452063468541	внутренняя	8609997.1030	263.7927	отправлена	\N
1657	RU6583803436573484995572407857396	398	2023-05-27	RU7483803436595027677837710467368	внутренняя	4766758.6134	154.0126	доставлена	\N
1658	RU9783803436586848496167067081204	978	2023-08-05	RU7183803436546875767014611813689	внутренняя	6192451.9263	905.4032	отправлена	\N
1659	RU5083803436556786327042016836549	643	2023-10-31	RU3783803436562091905141244310726	внутренняя	9273717.3286	325.9245	отправлена	\N
1660	RU8583803436529401978461350257287	643	2023-09-03	AD4435050915823652623359084	внутренняя	8208278.4139	850.7255	отправлена	\N
1661	RU4383803436597428452957764955765	978	2023-01-09	DE3611106795218697460424908	международная	274106.2036	238.4922	отправлена	RZBAATWW
1662	RU7583803436545511345420608427589	156	2023-07-09	VN2789529936647579401737238	международная	563880.4885	432.0332	отменена	BKCHCNBJ
1663	RU4983803436548786021946522460624	356	2022-12-30	KZ6716957454453728456195377	международная	5264385.2694	99.5796	отправлена	SBININBBXXX
1664	RU2283803436521727957364583057084	840	2023-10-08	RU8483803436552375991404578719285	внутренняя	609284.0688	937.5058	отменена	\N
1665	RU3183803436522808312515599877028	643	2023-10-19	RU6583803436526807323529165700056	внутренняя	281291.0988	870.5598	доставлена	\N
1666	RU6483803436557881046066137062384	643	2023-06-21	VN5546298857826249292624329	внутренняя	6173146.7170	793.0292	доставлена	\N
1667	RU7183803436535160662680026565691	840	2023-01-24	RU9083803436542335742968981386823	внутренняя	2244852.8822	797.1833	доставлена	\N
1668	RU5583803436533254773648721597711	978	2023-02-22	AD9474818221208827741624697	международная	3381467.6480	271.1437	доставлена	DEUTDEFFXXX
1669	RU7783803436529059332090835348557	978	2023-05-10	KZ8797830852504815745706868	международная	321091.9998	708.9818	отменена	RZBAATWW
1670	RU9483803436588743613330942629999	840	2023-06-16	ES8663854243239100056667885	международная	405830.1510	529.8439	отменена	IRVTUS3NXXX
1671	RU2283803436555228451424548337941	398	2023-11-07	VN5618671573315894388889514	международная	5199460.5681	823.7695	отправлена	CASPKZKAXXX
1672	RU3783803436562091905141244310726	643	2023-12-24	RU8083803436588746463552823930061	внутренняя	8673189.3068	904.4083	отменена	\N
1673	RU9183803436594783043422280553530	156	2023-10-17	AL3776697668601095102482750	международная	7973897.3449	730.8343	доставлена	BKCHCNBJ
1674	RU8683803436511417676206561932357	398	2023-03-06	PT7751409884484391434025299	международная	6573852.2594	30.1549	доставлена	CASPKZKAXXX
1675	RU2283803436577856579987093576845	156	2023-01-18	KZ9454146625014814202784149	международная	2693854.3184	105.9801	отправлена	BKCHCNBJ
1676	RU2983803436530272226005609138408	156	2023-04-25	BY1562391818326312667452080	международная	1547988.6213	562.1677	отменена	BKCHCNBJ
1677	RU3883803436571430516571621799878	156	2023-02-02	RU4483803436593534887929979895004	внутренняя	8422575.7835	815.1878	доставлена	\N
1678	RU7383803436534050516387288663509	840	2023-04-02	DE6288142333717880126554396	международная	6357182.6897	228.7369	отправлена	IRVTUS3NXXX
1679	RU9683803436511276549947859990709	398	2023-09-28	RU3883803436515226766320509995235	внутренняя	1825003.8507	380.2461	доставлена	\N
1680	RU9583803436574471411467135718624	840	2023-11-25	RU3383803436533625475503259998648	внутренняя	2120798.2574	397.0612	отправлена	\N
1681	RU2883803436564862346362051659673	156	2023-05-15	AL3764964721589439253238074	международная	1291975.5840	194.4450	доставлена	BKCHCNBJ
1682	RU9483803436516702191580023603147	356	2023-03-06	BY6411523955257188136669371	международная	6772183.9184	493.0193	отправлена	SBININBBXXX
1683	RU8483803436576032684947735830335	643	2023-04-04	RU1383803436585969091171133733533	внутренняя	7934253.7336	489.7567	отправлена	\N
1684	RU2283803436577856579987093576845	156	2023-11-07	BY7178503077875878942391926	международная	1642043.2254	579.1806	доставлена	BKCHCNBJ
1685	RU9083803436548965374028188380728	643	2023-02-27	RU6272597299384936237444174	внутренняя	4039752.7480	746.2634	доставлена	\N
1686	RU7683803436578953117174553181317	398	2023-12-04	RU7284522674799992406241130	внутренняя	6527639.2376	702.1685	отправлена	\N
1687	RU8183803436532187852215520403243	978	2023-03-19	RU4583803436544769415444430855700	внутренняя	4076913.8881	427.9227	отменена	\N
1688	RU6483803436557881046066137062384	398	2023-05-25	RU3483803436534657689181631833463	внутренняя	5754125.1623	72.2289	доставлена	\N
1689	RU9683803436526786707929300961979	643	2023-11-07	RU5483803436538988818998904026382	внутренняя	5465463.2029	895.5442	доставлена	\N
1690	RU1883803436547883958852583813660	840	2023-04-27	ES7443825405945526166344158	международная	9861431.6819	0.0000	отменена	CHASUS33
1691	RU9383803436515318038329930627155	356	2023-07-30	ES8147395959108701808516755	международная	389234.6877	332.7658	отменена	SBININBBXXX
1692	RU1583803436575905915250327615306	156	2023-04-20	IN1971820503916499661556996	международная	6741209.7659	421.8784	доставлена	BKCHCNBJ
1693	RU7283803436583841985241060182740	356	2023-10-01	RU5983803436533405804846460378377	внутренняя	6228097.3235	173.6572	отправлена	\N
1694	RU9783803436566819882292917709885	398	2023-05-25	BY3882618641767358288128380	международная	7777532.5442	220.6640	доставлена	CASPKZKAXXX
1695	RU4483803436531766422461159975910	156	2023-11-14	RU4083803436565489336932623834655	внутренняя	1352125.4886	502.0815	отменена	\N
1696	RU9583803436589245078784775619456	643	2023-02-21	RU9783803436531316283778462589484	внутренняя	7008139.0876	521.0666	отправлена	\N
1697	RU7583803436593274051968042799324	840	2023-06-10	AL3169398384864933664990939	международная	4576151.2321	173.3755	отменена	IRVTUS3NXXX
1698	RU8583803436590890149305918634043	398	2023-02-24	RU4883803436561825246742556433732	внутренняя	6807598.5649	382.7848	отменена	\N
1699	RU2583803436510413813910694958748	643	2023-11-24	RU7483803436575212193030608824580	внутренняя	9180758.4869	260.2893	доставлена	\N
1700	RU3383803436527231938190662146888	643	2023-04-23	RU7183803436596080848426828093950	внутренняя	622521.3743	562.8805	доставлена	\N
1701	RU7183803436546875767014611813689	156	2023-10-23	IN8363399463399114040251644	международная	6313748.7800	917.0772	доставлена	BKCHCNBJ
1702	RU2983803436539974076802515756241	840	2023-10-30	RU3083803436556733352794187735054	внутренняя	3871253.5913	893.9699	отправлена	\N
1703	RU2483803436550335144467075253432	398	2023-10-10	PT6297799166333483084637266	международная	9009063.2258	501.5117	отменена	CASPKZKAXXX
1704	RU1983803436510686315036595318873	356	2023-05-04	RU6383803436530975100435134167112	внутренняя	8550933.6182	787.7259	отправлена	\N
1705	RU3983803436580604058878329162478	643	2023-08-12	RU5483803436547543071206231343471	внутренняя	3219409.5052	559.7526	отправлена	\N
1706	RU6183803436571932790348770462135	356	2023-07-08	RU3783803436559423561964096195262	внутренняя	6436716.3234	566.8370	отправлена	\N
1707	RU8583803436548069379320039967893	398	2023-05-13	IN4654077107592481823930714	международная	4047681.3778	370.6149	доставлена	CASPKZKAXXX
1708	RU3983803436569376600246742084811	643	2023-05-28	RU3783803436585191546282680625888	внутренняя	8651405.4237	233.0840	отменена	\N
1709	RU5983803436563752601230784661821	643	2023-04-07	RU4683803436518754352401343547893	внутренняя	9504454.9529	628.8701	отправлена	\N
1710	RU4483803436534969190676238532628	356	2023-11-16	RU2283803436527235231809863175226	внутренняя	3645858.4961	389.8740	отправлена	\N
1711	RU5883803436512174556620785995683	840	2023-02-08	ES7794290259370062560300134	международная	4441884.5380	609.2742	отправлена	IRVTUS3NXXX
1712	RU3583803436543438797337964557116	398	2023-03-13	RU3383803436527231938190662146888	внутренняя	8106977.6913	789.8389	отменена	\N
1713	RU6583803436599318340096840026283	156	2023-08-15	PT1429984027646655743794419	международная	5640148.4398	205.3201	отменена	BKCHCNBJ
1714	RU9383803436515318038329930627155	356	2023-05-12	RU9683803436524115739172828059349	внутренняя	7545970.3556	977.2687	отменена	\N
1715	RU4883803436583846522749125412438	156	2023-02-28	RU6483803436513432249664452306210	внутренняя	3571319.0961	479.7507	доставлена	\N
1716	RU5783803436553735504938098098542	156	2023-04-29	BY6341243635448908614837801	международная	6711282.0703	831.5761	отправлена	BKCHCNBJ
1717	RU9383803436587347167184231490115	978	2023-01-19	VN4515396633367461022160855	международная	2703969.6309	623.6009	доставлена	DEUTDEFFXXX
1718	RU5983803436558435772787343054218	398	2023-07-09	RU5883803436544935035293164341064	внутренняя	38710.7351	693.9887	отменена	\N
1719	RU2783803436598441945275189813351	978	2023-09-25	VN6653687907304590507312833	международная	288273.1206	996.5853	доставлена	DEUTDEFFXXX
1720	RU8683803436511417676206561932357	356	2023-05-14	RU8583803436548069379320039967893	внутренняя	625814.5944	106.7005	отправлена	\N
1721	RU2983803436588011593439328399453	156	2023-07-26	RU8183803436555934243334630961587	внутренняя	6823412.0914	503.1122	доставлена	\N
1722	RU6983803436582618731634671628237	156	2023-11-29	BY3874268504337922147302178	международная	8943976.4351	479.2398	отменена	BKCHCNBJ
1723	RU4083803436565489336932623834655	356	2023-11-24	RU8383803436554622159366581134752	внутренняя	4471908.1649	844.9677	доставлена	\N
1724	RU7483803436544936047225386728318	840	2023-04-27	ES4171342924478352481698903	международная	5870975.5426	996.2703	отменена	IRVTUS3NXXX
1725	RU2583803436573489146610412814439	978	2023-09-19	AD3564917532724105891086197	международная	671295.8159	830.2192	доставлена	DEUTDEFFXXX
1726	RU3683803436521305656177527242839	156	2023-10-17	RU9483803436585469145832242711561	внутренняя	8161078.0205	535.9885	отправлена	\N
1727	RU2083803436571871160330810400191	398	2023-07-09	BY6732636181168330218778881	международная	4420561.7416	590.4496	отправлена	CASPKZKAXXX
1728	RU5183803436573013692902081587761	156	2023-09-15	RU4383803436583134155448910498762	внутренняя	4281043.7540	573.3354	отправлена	\N
1729	RU6583803436573484995572407857396	643	2023-12-12	RU3083803436556733352794187735054	внутренняя	5927622.4596	186.8841	отменена	\N
1730	RU8383803436543267469021061769102	156	2023-02-21	RU6383803436517724803474176712817	внутренняя	4982885.8117	407.4412	доставлена	\N
1731	RU6983803436596433824452063468541	643	2023-04-26	RU8475664741354371119399966	внутренняя	8259858.6718	823.8403	доставлена	\N
1732	RU3683803436589669964829443545971	356	2023-09-12	RU5583803436581992686445972740236	внутренняя	7389644.7836	626.9800	отправлена	\N
1733	RU2683803436566742853200336170327	156	2023-11-12	PT3458634173203528818652503	международная	6254566.8580	746.3212	отправлена	BKCHCNBJ
1734	RU2083803436517185898516741185299	978	2022-12-27	BY4252767974829018706225525	международная	3405917.1239	559.2273	отправлена	DEUTDEFFXXX
1735	RU9483803436588743613330942629999	398	2023-09-20	AL7630686472755821000078701	международная	7518635.7225	149.2812	отменена	CASPKZKAXXX
1736	RU3983803436554516084539411139147	356	2023-09-02	DE5577370112718557397095415	международная	2008323.3608	50.0330	доставлена	SBININBBXXX
1737	RU6483803436595566817980742907742	156	2023-06-23	BY4986850735285765280713466	международная	5354588.3709	564.5808	отправлена	BKCHCNBJ
1738	RU1583803436597114679330016317094	156	2023-09-05	PT6851640171753382625970344	международная	4881704.1424	98.8149	отменена	BKCHCNBJ
1739	RU3983803436562540544761068231244	398	2023-12-18	AL5832366415265023852753142	международная	4974440.8130	838.1226	доставлена	CASPKZKAXXX
1740	RU4383803436597428452957764955765	356	2023-09-10	RU7783803436529059332090835348557	внутренняя	2031280.6289	249.3719	отправлена	\N
1741	RU4383803436559640804885433764330	398	2023-03-05	RU9683803436531094862059243712475	внутренняя	2799804.4297	72.9842	доставлена	\N
1742	RU8583803436586707949034749896750	156	2023-05-08	PT2144007765161182556234936	международная	2831535.3834	811.1017	доставлена	BKCHCNBJ
1743	RU5583803436525031727011657164177	840	2023-08-03	RU6083803436557649065533492172245	внутренняя	7631080.0956	901.1397	доставлена	\N
1744	RU5883803436544935035293164341064	156	2023-09-27	RU8583803436567351126582917385267	внутренняя	4282363.4405	433.7487	отменена	\N
1745	RU3883803436519845868206132784952	978	2023-04-10	RU6583803436588261503476787515721	внутренняя	6997969.0027	809.0374	отменена	\N
1746	RU8583803436548069379320039967893	398	2023-02-23	RU7810440928067085739321329	внутренняя	5636185.2339	860.0159	отменена	\N
1747	RU8483803436552375991404578719285	398	2023-01-24	RU6783803436582018660242960957244	внутренняя	9443486.3043	673.2899	отправлена	\N
1748	RU8683803436571821829992754282142	156	2023-03-17	RU2883803436581906276084692901201	внутренняя	3167122.4250	244.1123	доставлена	\N
1749	RU1083803436532178175395898264605	398	2023-10-10	DE1564919768840709777644498	международная	3479782.1456	22.7839	отправлена	CASPKZKAXXX
1750	RU8483803436593374085227717891522	398	2022-12-28	PT8797043501973495468023718	международная	130951.1006	505.4488	отменена	CASPKZKAXXX
1751	RU8983803436588264357315670765686	840	2023-04-14	RU7483803436595528340078834029783	внутренняя	8583994.5652	615.7462	доставлена	\N
1752	RU5583803436556151120487866130687	643	2023-04-14	DE1218852319927063367869319	внутренняя	7454348.0291	969.8632	отправлена	\N
1753	RU3383803436551883036237842733910	643	2023-02-11	RU7483803436544936047225386728318	внутренняя	566034.3909	156.0561	доставлена	\N
1754	RU8483803436586135450040789229889	840	2023-10-07	RU8183803436559528710172368223769	внутренняя	412993.3537	408.2370	отправлена	\N
1755	RU1183803436547102061688733775669	398	2023-02-25	RU3053948915526220498363799	внутренняя	4444621.5864	108.8892	отменена	\N
1756	RU7583803436545511345420608427589	840	2023-01-14	RU7183803436596080848426828093950	внутренняя	6655775.7614	11.2817	отменена	\N
1757	RU2283803436577856579987093576845	643	2023-03-11	RU2183803436551906716086082339754	внутренняя	9889814.0316	430.8974	отправлена	\N
1758	RU8483803436583598027317615125571	156	2023-03-22	AL5137864662789116492586564	международная	9230841.8957	461.4776	доставлена	BKCHCNBJ
1759	RU2083803436536025786076127901648	643	2023-04-06	ES8344052461144891333331926	внутренняя	8291519.3636	30.5205	отменена	\N
1760	RU6583803436547384322379422553840	978	2023-03-22	AL4686059217763223026637998	международная	8133814.1317	379.5754	доставлена	RZBAATWW
1761	RU8383803436583878629872361871714	840	2023-07-13	RU5383803436537654175631942789109	внутренняя	2657741.2805	14.0386	отменена	\N
1762	RU5983803436533405804846460378377	156	2022-12-29	VN4410212278614589987028696	международная	549808.6248	982.0223	доставлена	BKCHCNBJ
1763	RU4583803436571583967013936520660	643	2023-02-21	RU9983803436581801115411623274695	внутренняя	5163114.7126	895.7821	отменена	\N
1764	RU7483803436529598231033100377224	156	2023-04-20	ES7316170978679604941024330	международная	3114768.8885	92.3801	отменена	BKCHCNBJ
1765	RU4583803436544769415444430855700	398	2023-09-20	AD2014006696723133735997511	международная	3478147.8750	629.2161	доставлена	CASPKZKAXXX
1766	RU5783803436567884889437805923129	978	2023-03-02	KZ6687657929408106578763377	международная	9131167.6143	87.0198	доставлена	SOGEFRPP
1767	RU4383803436583134155448910498762	398	2023-12-19	RU9483803436570307762028951954874	внутренняя	2233095.1692	514.7661	отправлена	\N
1768	RU5483803436547543071206231343471	840	2023-04-14	KZ9433701206140489815611026	международная	817709.4108	481.0489	доставлена	CHASUS33
1769	RU6783803436510078136565817264354	156	2023-12-04	BY7557122512186068437710052	международная	2700431.6702	38.5874	доставлена	BKCHCNBJ
1770	RU5583803436541779385547740767657	978	2023-04-19	RU7483803436560908970835757520521	внутренняя	720411.9132	341.8719	отменена	\N
1771	RU8983803436518961229187913059129	398	2023-07-23	RU6983803436548066705729944547736	внутренняя	2427399.8309	504.5880	доставлена	\N
1772	RU7783803436585076163513647706071	356	2023-02-03	RU7783803436529059332090835348557	внутренняя	9663332.6852	520.8432	отменена	\N
1773	RU3383803436551883036237842733910	398	2023-10-11	RU9783803436531316283778462589484	внутренняя	5784682.1003	362.2443	отменена	\N
1774	RU6983803436596433824452063468541	356	2023-10-06	PT3019056281951137441182204	международная	9138434.0990	673.2711	доставлена	SBININBBXXX
1775	RU9483803436521022327823815694666	356	2023-11-10	RU3983803436583730529285495292571	внутренняя	782237.5677	998.2591	отменена	\N
1776	RU6083803436582119843499506879640	356	2023-09-06	AD8974865733069467112080109	международная	7310368.8979	467.8566	отменена	SBININBBXXX
1777	RU6583803436592149423686806465410	978	2023-04-08	RU6283803436561107985248905256058	внутренняя	6577962.3294	487.5150	доставлена	\N
1778	RU2183803436535230801413319305895	356	2023-10-09	DE8229794993368223712938845	международная	8856232.8666	888.4602	отправлена	SBININBBXXX
1779	RU6983803436550083462130199504453	356	2023-04-07	RU4483803436534969190676238532628	внутренняя	6433751.1763	383.7094	отменена	\N
1780	RU9183803436594783043422280553530	356	2023-10-15	AD1933385686661256488937708	международная	6825001.4494	620.0808	отправлена	SBININBBXXX
1781	RU8583803436529401978461350257287	356	2023-11-28	AL2926035706611456024192351	международная	7583332.4067	428.3397	отменена	SBININBBXXX
1782	RU5683803436522754650880470438385	978	2023-04-17	RU3583803436580986023375789999847	внутренняя	6975151.1210	392.7750	доставлена	\N
1783	RU1383803436585969091171133733533	978	2023-03-01	PT3491435273680431775403930	международная	8077237.4702	670.8600	отменена	SOGEFRPP
1784	RU5183803436585063037953141711870	840	2023-04-19	AL3335468501668798186025185	международная	5157119.5351	285.3848	отменена	IRVTUS3NXXX
1785	RU5683803436573106663960342062340	356	2023-12-17	AD3985168861908015734555025	международная	9693068.9195	782.9343	доставлена	SBININBBXXX
1786	RU4683803436518754352401343547893	398	2023-10-31	DE8976126387214512293424798	международная	5022575.5864	588.5961	отправлена	CASPKZKAXXX
1787	RU4883803436583846522749125412438	398	2023-11-27	RU6483803436531317735484528392559	внутренняя	1834086.6534	222.0604	отправлена	\N
1788	RU1683803436583298094705869717304	398	2023-04-23	ES8193176363309935666897431	международная	2567692.0388	28.8914	доставлена	CASPKZKAXXX
1789	RU9683803436524115739172828059349	978	2023-08-05	RU4583803436571583967013936520660	внутренняя	8588163.3596	69.9866	доставлена	\N
1790	RU6783803436583735354795738130605	398	2023-08-12	PT4220367046407076172906454	международная	378057.0708	444.5350	отправлена	CASPKZKAXXX
1791	RU8083803436588746463552823930061	356	2023-03-09	AD8283026294770507446073010	международная	9532864.3602	770.2062	отправлена	SBININBBXXX
1792	RU8983803436518961229187913059129	356	2023-03-21	RU2983803436588011593439328399453	внутренняя	3076810.0560	82.3179	отправлена	\N
1793	RU1583803436513968949783488654583	643	2023-04-29	RU6583803436556215016292535847892	внутренняя	6367503.0632	630.6005	доставлена	\N
1794	RU5183803436573013692902081587761	156	2023-09-18	ES3085258188177657913531747	международная	8587117.0874	688.9400	доставлена	BKCHCNBJ
1795	RU6483803436557881046066137062384	398	2023-03-17	RU2461458145013749553485784	внутренняя	6466774.3539	553.6151	отменена	\N
1796	RU6183803436556503720110500069421	156	2023-02-14	ES1915729174022268745779901	международная	9008634.5365	402.5446	отправлена	BKCHCNBJ
1797	RU8483803436514025076841381077297	398	2023-11-24	RU1883803436562141776165180370424	внутренняя	1264411.7682	534.7363	доставлена	\N
1798	RU3183803436522808312515599877028	840	2023-07-19	RU6583803436546434088553514688778	внутренняя	750251.9902	400.6232	отправлена	\N
1799	RU2183803436535230801413319305895	840	2023-07-13	RU7383803436569356631218275502161	внутренняя	9562490.8506	924.4586	отменена	\N
1800	RU1583803436533479152204865778047	978	2023-01-14	RU8083803436588746463552823930061	внутренняя	6005790.9584	507.9846	отменена	\N
1801	RU5583803436541779385547740767657	356	2023-02-11	RU7083803436595909521339223196614	внутренняя	960463.2897	605.9539	доставлена	\N
1802	RU1983803436574962372646294489745	978	2023-03-19	RU6483803436557881046066137062384	внутренняя	4569651.6770	122.4104	доставлена	\N
1803	RU7783803436520045957277741704368	156	2023-02-27	DE5893137137176149296310735	международная	722775.6555	418.8103	отправлена	BKCHCNBJ
1804	RU6683803436575472065287991925682	398	2023-01-07	AL4198879829561898382227365	международная	2937934.3601	222.4551	отменена	CASPKZKAXXX
1805	RU8183803436576908594301902139271	978	2023-05-27	RU4083803436526038486689011711230	внутренняя	5697053.4134	249.7994	отправлена	\N
1806	RU9483803436522220035875117822565	398	2023-10-03	AD7781272227294928116708317	международная	9165881.1948	375.2435	отменена	CASPKZKAXXX
1807	RU9083803436527710172880684864084	840	2023-11-19	RU8783803436522200736153030297680	внутренняя	9650720.5254	92.3347	отправлена	\N
1808	RU4083803436525661046500520760430	978	2023-07-02	VN8357317083524983065756934	международная	7206263.8373	330.7605	отправлена	DEUTDEFFXXX
1809	RU6983803436521001508692071958064	398	2023-02-24	RU9683803436559214297350823715344	внутренняя	9528459.7201	641.4736	отправлена	\N
1810	RU1383803436565139777755041333233	643	2023-02-19	RU9183803436523189940915642395180	внутренняя	1644442.4939	463.8428	отправлена	\N
1811	RU5183803436596697120047636808100	356	2023-04-07	RU3983803436569376600246742084811	внутренняя	8504567.3190	926.8843	отправлена	\N
1812	RU8283803436536082355231514909614	156	2023-06-29	RU6583803436592149423686806465410	внутренняя	5167349.1052	988.4474	доставлена	\N
1813	RU1583803436578714315409224923820	356	2023-06-26	RU8483803436562780872181379760829	внутренняя	694649.0892	529.1508	доставлена	\N
1814	RU1483803436556765140449291811625	398	2023-10-03	RU8183803436566794763466227027850	внутренняя	5594142.4053	171.9957	отправлена	\N
1815	RU6883803436521704893234788177503	840	2023-01-21	RU4183803436598422593606583773593	внутренняя	6201853.1939	886.8731	отменена	\N
1816	RU6483803436599929208547720213297	356	2023-03-08	RU4283803436515276086545867508581	внутренняя	4243248.6833	16.5738	доставлена	\N
1817	RU2283803436551819000625747494652	978	2023-07-19	RU4383803436538414207445829899653	внутренняя	9684426.7755	263.5698	доставлена	\N
1818	RU5583803436555177704368963744222	398	2023-05-15	RU2683803436566742853200336170327	внутренняя	1380088.4808	199.5257	доставлена	\N
1819	RU4083803436534430125114460530795	156	2022-12-31	AL5839409194355519929444390	международная	3442305.9911	799.9042	доставлена	BKCHCNBJ
1820	RU2283803436527235231809863175226	356	2023-12-20	RU2983803436530272226005609138408	внутренняя	2947042.1439	406.5527	отменена	\N
1821	RU4683803436584135461455281070651	156	2023-10-12	ES3644506649805893695633305	международная	8378030.1431	621.6387	доставлена	BKCHCNBJ
1822	RU3083803436518573891716312234719	398	2023-02-26	RU4783803436556925313909023616425	внутренняя	5035068.0693	369.1426	отправлена	\N
1823	RU5983803436565674700991182664479	356	2023-06-18	RU8983803436550652073660555482382	внутренняя	6898182.9638	745.0443	отменена	\N
1824	RU7183803436546875767014611813689	356	2023-11-27	AL9894535323746724786800771	международная	7903419.1737	461.5856	доставлена	SBININBBXXX
1825	RU4583803436576777630615652907536	398	2023-11-07	RU6483803436595566817980742907742	внутренняя	4763139.6820	82.7028	отправлена	\N
1826	RU4583803436576777630615652907536	156	2023-02-02	RU8983803436551003507571679577910	внутренняя	2850519.8443	261.4067	отменена	\N
1827	RU4283803436544879224116585983050	356	2023-03-01	BY4867193542906349129319489	международная	2017081.3446	961.8542	доставлена	SBININBBXXX
1828	RU9883803436596118671708861810646	356	2023-03-26	DE4363197481608981461805325	международная	8960452.1302	642.9799	отправлена	SBININBBXXX
1829	RU6183803436536163842184020816729	643	2023-04-24	RU3483803436534657689181631833463	внутренняя	4125516.3432	64.9530	отправлена	\N
1830	RU8783803436522200736153030297680	840	2023-01-29	VN5840925626949303503825158	международная	9736715.0742	670.1066	доставлена	IRVTUS3NXXX
1831	RU7583803436545511345420608427589	398	2023-04-08	RU9383803436568402663247236595753	внутренняя	9667949.7887	942.0360	отправлена	\N
1832	RU8983803436519227550175732694863	398	2023-03-27	BY5146724451407104952657593	международная	6307881.3128	107.3767	отправлена	CASPKZKAXXX
1833	RU5783803436567884889437805923129	356	2023-01-13	ES1461006961608470219382920	международная	6628055.5171	563.9464	отменена	SBININBBXXX
1834	RU2483803436550335144467075253432	156	2023-01-23	RU2183803436555308456329784386702	внутренняя	4290904.4721	394.2901	доставлена	\N
1835	RU3883803436531800763308499008852	156	2023-10-11	RU8283803436517214496879594083501	внутренняя	5451752.2228	173.3398	отправлена	\N
1836	RU5583803436541779385547740767657	356	2023-08-11	AL9341981227415587115367550	международная	3711465.9104	43.6578	отменена	SBININBBXXX
1837	RU3983803436580604058878329162478	643	2023-06-02	KZ8688745194820356815395236	внутренняя	6963482.2155	155.8308	отправлена	\N
1838	RU5783803436523742307313248220811	398	2023-11-29	RU9383803436546841675173507423577	внутренняя	6388964.9349	529.6518	доставлена	\N
1839	RU1983803436592911874717339237016	643	2023-04-09	KZ2641013203323967149138217	внутренняя	1499935.3337	177.8471	отправлена	\N
1840	RU7083803436569474567525801645267	356	2023-10-10	RU8483803436523751116997614384937	внутренняя	1693473.7910	496.1130	отправлена	\N
1841	RU6283803436577836700807681117407	840	2023-03-18	RU8783803436522200736153030297680	внутренняя	698725.2535	119.4529	доставлена	\N
1842	RU7783803436585076163513647706071	398	2023-04-29	KZ5378967926360859932212052	международная	9563937.7610	459.0231	отправлена	CASPKZKAXXX
1843	RU5883803436512174556620785995683	840	2023-02-02	BY7027923052001564538054384	международная	3712879.2755	628.3840	отменена	CHASUS33
1844	RU4583803436546993711061481413708	978	2023-06-18	RU5883803436576828712243252221562	внутренняя	5764545.0238	113.2648	доставлена	\N
1845	RU5883803436537252361294139722938	840	2023-11-28	RU7883803436577262824038798840088	внутренняя	2347080.0356	216.8173	доставлена	\N
1846	RU6983803436551969328605594993446	840	2023-04-13	IN3277920937959916109586637	международная	6839120.7632	237.4546	отправлена	CHASUS33
1847	RU8283803436517214496879594083501	398	2023-11-18	ES9181496984828310896598338	международная	1860577.4866	846.2507	отправлена	CASPKZKAXXX
1848	RU2983803436510489846489627969282	840	2023-01-15	VN7863406509685078868606593	международная	3427045.7961	270.2719	отменена	CHASUS33
1849	RU7483803436516612664745741202549	978	2023-08-09	ES5564692409573260266627779	международная	8142206.2267	391.7179	отменена	DEUTDEFFXXX
1850	RU8183803436584325139466333599286	156	2023-06-04	AD8799807781716522880864679	международная	5267180.0584	820.3484	доставлена	BKCHCNBJ
1851	RU5783803436573951128453151787227	356	2023-11-22	RU3583803436543438797337964557116	внутренняя	2025919.3224	194.6102	доставлена	\N
1852	RU2483803436537933507280624045523	398	2023-02-22	RU6431796434155400560256378	внутренняя	1694668.7661	787.0170	отправлена	\N
1853	RU8983803436550652073660555482382	398	2023-11-04	RU9283803436581282514241262822584	внутренняя	421279.4630	212.7832	отменена	\N
1854	RU5083803436583492295875343805447	398	2023-11-16	RU4283803436538514172142523078432	внутренняя	1971476.6481	319.6606	отправлена	\N
1855	RU2083803436517185898516741185299	978	2023-09-05	RU6183803436551232797419519235346	внутренняя	8052584.3388	965.2832	отправлена	\N
1856	RU1483803436552189189819570176682	978	2023-12-12	RU1983803436568263609873115174417	внутренняя	2611606.9551	80.7352	отправлена	\N
1857	RU5583803436541779385547740767657	643	2023-04-29	PT6983798837743944602099972	внутренняя	7538304.8488	143.7269	отправлена	\N
1858	RU3383803436527231938190662146888	156	2023-07-01	DE8748648509417307524538799	международная	6849640.7801	143.7927	отправлена	BKCHCNBJ
1859	RU5983803436533405804846460378377	643	2023-12-14	DE2246902891861106832084662	внутренняя	6853947.3581	617.7328	доставлена	\N
1860	RU3583803436580986023375789999847	398	2023-11-26	RU6383803436530975100435134167112	внутренняя	854262.2269	653.2161	доставлена	\N
1861	RU3483803436537283842522563725379	643	2023-08-31	RU1983803436549890414007715363567	внутренняя	5781481.8008	731.1807	отменена	\N
1862	RU7183803436513501317784267991188	978	2023-01-18	VN1278497384400160931538620	международная	251411.6623	865.1892	отменена	SOGEFRPP
1863	RU8983803436550652073660555482382	398	2023-08-16	DE1564528022607923577248624	международная	5184706.1581	598.1744	доставлена	CASPKZKAXXX
1864	RU4583803436535138140020222748384	356	2023-10-12	RU2983803436572678251629055132350	внутренняя	127962.2744	231.7601	доставлена	\N
1865	RU8183803436576334203563049364101	356	2023-11-09	RU1383803436565139777755041333233	внутренняя	9256738.0939	870.0251	доставлена	\N
1866	RU3883803436554504516286459147223	643	2023-01-01	AL6419517901484982842002827	внутренняя	3938044.4538	186.7635	доставлена	\N
1867	RU5583803436556151120487866130687	156	2023-04-05	IN2461628126159311678033284	международная	7540826.9651	217.4298	доставлена	BKCHCNBJ
1868	RU5983803436565674700991182664479	643	2023-02-19	IN2050527192520916550951069	внутренняя	5363922.9099	713.6904	отправлена	\N
1869	RU1183803436569972795023903837949	978	2023-06-05	RU7783803436557425582753958788900	внутренняя	2341870.2531	384.7530	отправлена	\N
1870	RU8783803436562772820294479967682	643	2023-07-18	RU3383803436527231938190662146888	внутренняя	6325823.1997	627.3410	доставлена	\N
1871	RU2683803436566742853200336170327	840	2023-04-12	RU5983803436558435772787343054218	внутренняя	3439730.8626	909.2387	отправлена	\N
1872	RU5283803436529894140873721164089	840	2023-12-03	RU2083803436593214630941740939011	внутренняя	8858740.2154	674.0998	отправлена	\N
1873	RU1983803436518034161993382946183	643	2023-09-18	RU8483803436552375991404578719285	внутренняя	6881481.0096	847.8713	доставлена	\N
1874	RU2683803436575198696607383546599	156	2023-09-01	RU8183803436532187852215520403243	внутренняя	6538460.7972	867.0105	доставлена	\N
1875	RU9083803436548965374028188380728	156	2023-03-21	AD2233032084460927684880519	международная	8568256.8793	593.4267	отправлена	BKCHCNBJ
1876	RU6983803436580831999013679742086	978	2023-03-03	RU2983803436596711612246779730808	внутренняя	112144.7982	358.4292	доставлена	\N
1877	RU3583803436531844714480494060517	398	2023-12-02	KZ5767081558439161903845584	международная	3546176.9849	327.8995	отправлена	CASPKZKAXXX
1878	RU9483803436588743613330942629999	643	2023-10-20	AD2248171858850448860832652	внутренняя	9812757.1232	810.9630	доставлена	\N
1879	RU8483803436552375991404578719285	156	2023-12-16	BY7338595584005708000074826	международная	9984421.3390	944.5350	отменена	BKCHCNBJ
1880	RU6183803436536163842184020816729	356	2023-03-19	AD6639666886409657298986847	международная	2328316.0679	265.7588	отменена	SBININBBXXX
1881	RU5883803436544935035293164341064	840	2023-03-13	BY4547810737043976790723109	международная	1176677.0795	43.4058	отправлена	CHASUS33
1882	RU7683803436589524723383129532286	643	2023-06-27	RU5483803436559214869633349674125	внутренняя	8083279.8318	783.2604	отправлена	\N
1883	RU7283803436528848493351990702937	156	2023-06-30	PT6819926173692805736261255	международная	3168169.9131	559.9843	доставлена	BKCHCNBJ
1884	RU3783803436562139250445157080524	156	2023-06-29	RU3183803436583121152517184662518	внутренняя	5248955.1472	184.3334	отменена	\N
1885	RU1183803436513944372774322746458	356	2023-01-09	RU3583803436580986023375789999847	внутренняя	4105913.6305	300.9110	доставлена	\N
1886	RU5483803436551418630110242560620	643	2023-10-13	RU8783803436562772820294479967682	внутренняя	8953778.6162	714.6614	отправлена	\N
1887	RU5483803436559214869633349674125	356	2023-01-04	RU5883803436544935035293164341064	внутренняя	6649990.9700	711.9586	отменена	\N
1888	RU6983803436517488129268543865126	840	2023-08-17	RU3883803436531800763308499008852	внутренняя	6473332.9839	328.1058	отправлена	\N
1889	RU4283803436532641085536208083176	156	2023-12-14	PT1224633775396079726437475	международная	8570422.4244	440.5107	отправлена	BKCHCNBJ
1890	RU8983803436551003507571679577910	356	2023-07-05	IN2348069199503101207419266	международная	6030944.9900	868.8628	отменена	SBININBBXXX
1891	RU8683803436557989786811096289958	356	2023-08-22	RU6683803436546559918630563560759	внутренняя	9562866.6420	73.0108	отправлена	\N
1892	RU5783803436523742307313248220811	156	2023-06-21	RU8383803436557193853878723819444	внутренняя	9704231.6152	658.4345	доставлена	\N
1893	RU8383803436543267469021061769102	398	2023-02-27	RU9683803436571883645805733128714	внутренняя	5172830.1231	590.2873	доставлена	\N
1894	RU6383803436530975100435134167112	978	2023-01-17	PT2936837881318738887470476	международная	862918.2567	655.6038	доставлена	DEUTDEFFXXX
1895	RU6083803436557649065533492172245	840	2023-08-12	RU8483803436528403655778834568144	внутренняя	666367.4687	994.9326	отправлена	\N
1896	RU7283803436528848493351990702937	356	2023-02-17	VN5242768244586918347206873	международная	8852768.9307	964.2003	отменена	SBININBBXXX
1897	RU2283803436555228451424548337941	978	2023-09-21	RU1983803436558651220197686454204	внутренняя	1095010.5821	42.7815	отменена	\N
1898	RU8683803436557989786811096289958	156	2023-06-19	PT9043863566619336262355695	международная	1224943.4627	43.8126	отправлена	BKCHCNBJ
1899	RU5483803436559214869633349674125	978	2023-10-25	BY3385716427129711996509531	международная	6249669.6818	926.3291	отправлена	RZBAATWW
1900	RU8583803436580493050529274956761	643	2023-05-27	RU1283803436521770311179326367954	внутренняя	2658559.2978	280.2117	доставлена	\N
1901	RU4783803436576956010684046744289	156	2023-04-02	BY8488559234122322939466451	международная	8834028.3661	205.4884	доставлена	BKCHCNBJ
1902	RU2283803436577856579987093576845	356	2023-11-25	KZ6448838118404690989634541	международная	9935869.8614	352.5052	отменена	SBININBBXXX
1903	RU5183803436531460410872953149827	978	2023-02-19	RU1283803436597755454846611928328	внутренняя	9106886.2275	964.9960	доставлена	\N
1904	RU4383803436559640804885433764330	398	2023-05-26	PT1349516259659933753685941	международная	9777046.0665	308.0302	отменена	CASPKZKAXXX
1905	RU6583803436592149423686806465410	978	2023-04-27	RU8383803436583878629872361871714	внутренняя	5382922.4389	744.5622	доставлена	\N
1906	RU9683803436531094862059243712475	356	2023-04-16	RU5583803436544105301147510534206	внутренняя	7114807.2956	633.3826	отправлена	\N
1907	RU8383803436557193853878723819444	978	2023-11-17	IN1759085739483118472894885	международная	6873.6445	616.2214	отправлена	RZBAATWW
1908	RU6783803436583735354795738130605	156	2023-03-28	RU7783803436536804517087406327796	внутренняя	4558442.2557	434.2711	доставлена	\N
1909	RU2683803436566742853200336170327	840	2023-06-22	RU2483803436580851808318436691458	внутренняя	8229132.7594	213.5082	отменена	\N
1910	RU1883803436562141776165180370424	356	2023-01-27	RU3383803436533625475503259998648	внутренняя	154751.7466	900.2025	доставлена	\N
1911	RU2483803436550335144467075253432	978	2023-02-11	BY1846598982439876264079370	международная	3883160.2779	507.4259	отправлена	SOGEFRPP
1912	RU5183803436588244188761426669013	840	2023-05-12	IN1090133392146779570912551	международная	2163744.9336	752.0329	отменена	CHASUS33
1913	RU4883803436540069564759439339493	156	2023-09-30	RU7283803436551671539996901196859	внутренняя	6070185.4402	538.4424	отменена	\N
1914	RU2283803436527235231809863175226	840	2023-07-04	RU9983803436563015974445739907644	внутренняя	3748397.1282	318.6098	отправлена	\N
1915	RU7283803436565335970635584506660	978	2023-06-03	RU4724286241167089203732913	внутренняя	6226429.0002	650.7937	отправлена	\N
1916	RU7783803436529059332090835348557	978	2023-11-02	IN8852694763114275683093685	международная	2723428.2980	181.3288	доставлена	RZBAATWW
1917	RU4083803436523112590591409946049	840	2023-05-24	ES6383453525782924115755851	международная	3467397.0753	481.1103	отправлена	CHASUS33
1918	RU7483803436512314763652680872976	356	2023-08-31	RU3683803436529963181547651499120	внутренняя	2812674.8464	43.9420	отправлена	\N
1919	RU8783803436562772820294479967682	398	2023-12-08	RU3783803436562139250445157080524	внутренняя	25462.4098	350.4557	отменена	\N
1920	RU6883803436521704893234788177503	398	2023-12-18	RU9683803436511276549947859990709	внутренняя	3558754.2036	29.2758	отменена	\N
1921	RU2783803436580745382811010865973	643	2023-11-05	RU1383803436596151895061926683764	внутренняя	5537190.9842	158.9571	отправлена	\N
1922	RU6183803436551232797419519235346	356	2023-03-16	RU8483803436576032684947735830335	внутренняя	4002753.8109	222.6868	отменена	\N
1923	RU4583803436544769415444430855700	978	2023-12-23	RU7583803436545511345420608427589	внутренняя	6620906.8536	535.5309	доставлена	\N
1924	RU8483803436546395435496825405512	978	2023-06-19	RU7283803436582085910615477000049	внутренняя	8699011.9773	339.3543	отправлена	\N
1925	RU8183803436546948351691601253240	978	2023-06-12	AL1327548136717189251784293	международная	419830.8198	216.7973	отправлена	SOGEFRPP
1926	RU2983803436545911307181108696312	356	2023-06-08	RU1383803436546084241558471107471	внутренняя	8142606.9281	363.1355	отправлена	\N
1927	RU8783803436544746989208687599320	978	2023-03-12	BY8997290663311229704039220	международная	3169645.1930	498.6098	отправлена	DEUTDEFFXXX
1928	RU8683803436531608639655465618756	978	2023-01-23	IN5590745428182754727166105	международная	9230673.3841	279.2735	отправлена	RZBAATWW
1929	RU7483803436591068390387769478580	978	2023-06-18	DE4762371937795303644267944	международная	9036488.1516	182.5208	доставлена	RZBAATWW
1930	RU6983803436582618731634671628237	978	2023-08-12	BY5720375946700686113510502	международная	7111651.3209	837.3359	отправлена	SOGEFRPP
1931	RU5683803436573106663960342062340	643	2023-05-06	RU2483803436537933507280624045523	внутренняя	999263.5934	428.7090	отправлена	\N
1932	RU5483803436549562102902686014927	840	2023-11-11	KZ4087996724053959087257341	международная	9002988.1946	382.4623	доставлена	CHASUS33
1933	RU8883803436592173067148862634991	398	2023-07-16	RU1856153187090722321278069	внутренняя	6005339.2341	433.1857	отменена	\N
1934	RU2883803436564862346362051659673	840	2023-07-03	AD8732613808219677954024388	международная	8451419.0928	572.2568	отправлена	CHASUS33
1935	RU3883803436559428008275215914286	643	2023-08-11	RU5783803436598085342824416355658	внутренняя	183807.1377	713.6343	доставлена	\N
1936	RU8383803436583878629872361871714	978	2023-12-14	AL5478393391570926885811833	международная	6196170.6727	92.5803	отправлена	SOGEFRPP
1937	RU7383803436569356631218275502161	398	2023-10-21	VN1883691971853482154377953	международная	5119482.0829	609.7259	доставлена	CASPKZKAXXX
1938	RU4683803436521950147450839996450	398	2023-02-14	VN3769248374821800089806762	международная	9165051.5394	664.2226	доставлена	CASPKZKAXXX
1939	RU2583803436511360000518303822185	643	2023-08-04	KZ2777607579598991211183185	внутренняя	239891.9725	972.7149	отправлена	\N
1940	RU9283803436529032721317031749293	978	2023-01-10	RU5683803436522754650880470438385	внутренняя	9653662.7848	639.6236	отменена	\N
1941	RU3683803436533022850683714599602	398	2023-02-10	VN8634900674456208900562933	международная	3939568.4751	411.0732	отправлена	CASPKZKAXXX
1942	RU9583803436557636243711161422858	156	2023-08-31	KZ8486069329686048679183553	международная	7235330.3976	267.4753	отменена	BKCHCNBJ
1943	RU4483803436531766422461159975910	356	2023-06-17	RU1583803436533479152204865778047	внутренняя	300405.8462	920.0563	отправлена	\N
1944	RU1183803436569972795023903837949	398	2023-03-09	RU9283803436564588409350021574669	внутренняя	5943705.2972	664.3764	отменена	\N
1945	RU9283803436564588409350021574669	156	2023-10-02	KZ5443521241052081823836386	международная	3070544.3444	519.6897	отправлена	BKCHCNBJ
1946	RU6483803436513432249664452306210	156	2023-07-19	RU6389253241235662618856037	внутренняя	4885559.0823	465.4483	доставлена	\N
1947	RU5883803436549838724600410631189	840	2023-12-23	RU5583803436581992686445972740236	внутренняя	9988786.0470	160.0580	доставлена	\N
1948	RU3383803436527231938190662146888	356	2023-06-01	RU4283803436512174946847064448344	внутренняя	4826182.8055	12.1593	доставлена	\N
1949	RU9983803436563015974445739907644	840	2023-01-28	KZ1962993334404307329274589	международная	8613124.1521	845.6434	доставлена	CHASUS33
1950	RU1183803436536239647096212180861	356	2023-11-27	RU9983803436581801115411623274695	внутренняя	172055.3007	647.9915	доставлена	\N
1951	RU5883803436537252361294139722938	643	2023-12-23	RU4283803436512174946847064448344	внутренняя	558581.4074	979.9405	отменена	\N
1952	RU6783803436583735354795738130605	398	2023-07-31	AL6084262395164245148421956	международная	2584570.1897	105.7404	отправлена	CASPKZKAXXX
1953	RU7783803436529059332090835348557	156	2023-09-15	RU9983803436563015974445739907644	внутренняя	6461005.7223	582.5662	отменена	\N
1954	RU1283803436591782126481419856685	356	2023-02-07	RU6283803436561107985248905256058	внутренняя	7750010.4127	163.7676	доставлена	\N
1955	RU2683803436575198696607383546599	356	2023-03-06	DE1322154789390075584950890	международная	1722948.8516	409.2923	отправлена	SBININBBXXX
1956	RU5583803436516539388298963058164	398	2022-12-28	RU4583803436576777630615652907536	внутренняя	1954226.5832	734.7158	доставлена	\N
1957	RU6183803436555838927651384339574	643	2023-08-09	RU8183803436559528710172368223769	внутренняя	9878314.3865	239.8427	отменена	\N
1958	RU5883803436571013870275428717873	398	2023-08-07	RU1383803436598073263367823117200	внутренняя	35355.5790	907.6110	доставлена	\N
1959	RU3483803436534657689181631833463	356	2023-07-18	KZ6490737728906273871834307	международная	5036611.2643	137.4906	отменена	SBININBBXXX
1960	RU9083803436527710172880684864084	643	2023-10-03	RU2583803436525056668985275863842	внутренняя	5885532.2184	657.5359	отправлена	\N
1961	RU4683803436518754352401343547893	643	2023-07-14	RU5783803436567884889437805923129	внутренняя	786428.4660	204.4154	доставлена	\N
1962	RU8183803436555934243334630961587	643	2022-12-30	RU6355565706297207888776575	внутренняя	8419681.0323	643.9090	отправлена	\N
1963	RU8883803436542351475891948314875	156	2023-05-20	RU6783803436582018660242960957244	внутренняя	1599365.3753	957.9991	отправлена	\N
1964	RU4183803436544525596730636267692	978	2023-08-02	ES5819794571911221081464727	международная	3260497.7774	309.8475	отправлена	SOGEFRPP
1965	RU6583803436546434088553514688778	156	2023-07-26	RU8983803436513229118545499417330	внутренняя	7059849.2339	210.2504	отправлена	\N
1966	RU1183803436587920364130887563809	156	2023-11-24	IN8459469978869746779115033	международная	5834419.8158	509.8824	доставлена	BKCHCNBJ
1967	RU7083803436595909521339223196614	978	2023-11-13	RU4783803436576956010684046744289	внутренняя	4835004.9858	614.6497	отменена	\N
1968	RU4883803436561825246742556433732	643	2023-06-19	RU3174999913989885767834900	внутренняя	7699660.5421	771.5400	отправлена	\N
1969	RU6083803436569163727288631654599	356	2023-01-12	BY5157562476251476496483852	международная	5433971.9281	521.5141	отправлена	SBININBBXXX
1970	RU1583803436575905915250327615306	840	2023-09-13	RU5483803436538988818998904026382	внутренняя	1867628.7085	587.3698	доставлена	\N
1971	RU7483803436591068390387769478580	156	2023-11-23	AL9515961472665903955248324	международная	5287828.5539	486.9300	доставлена	BKCHCNBJ
1972	RU6983803436582618731634671628237	156	2023-05-07	RU3883803436559428008275215914286	внутренняя	9551697.6897	761.7866	доставлена	\N
1973	RU3883803436571430516571621799878	356	2023-02-01	RU8483803436562780872181379760829	внутренняя	4933776.2814	524.3291	отправлена	\N
1974	RU6983803436521001508692071958064	156	2023-04-10	PT1098955709962202836172722	международная	1266666.8330	106.6259	доставлена	BKCHCNBJ
1975	RU8983803436519227550175732694863	643	2023-05-15	DE7618438661381516223817328	внутренняя	830445.9910	708.2975	отменена	\N
1976	RU2983803436530272226005609138408	643	2023-07-13	AD7518118649509104136794792	внутренняя	5110797.4243	621.9244	отправлена	\N
1977	RU2283803436555228451424548337941	356	2023-03-05	RU9663340541379414307709814	внутренняя	2899327.8594	734.0387	отменена	\N
1978	RU1483803436552189189819570176682	978	2023-05-11	RU7483803436516612664745741202549	внутренняя	9521436.4368	513.2721	отменена	\N
1979	RU3283803436586063041663029658571	398	2023-06-23	RU4483803436593534887929979895004	внутренняя	1206376.0667	88.6088	отправлена	\N
1980	RU8583803436593152008036708778596	356	2023-04-01	RU5583803436541779385547740767657	внутренняя	1855289.1338	923.2777	доставлена	\N
1981	RU6983803436518663051613263930888	356	2023-12-06	BY6121065012202499114195432	международная	1376541.1920	649.9910	отправлена	SBININBBXXX
1982	RU6283803436561107985248905256058	156	2023-07-03	ES7693276267538151173489775	международная	9831298.0575	563.3914	отправлена	BKCHCNBJ
1983	RU4483803436593534887929979895004	398	2023-08-13	KZ5781547517090975079183599	международная	8058388.0524	37.4441	доставлена	CASPKZKAXXX
1984	RU8483803436597380246113206833117	156	2023-12-12	RU7783803436557425582753958788900	внутренняя	9865719.9269	811.8417	доставлена	\N
1985	RU5083803436537344339331652897359	156	2023-06-01	RU6683803436534213789698830771682	внутренняя	7370190.6762	964.6900	доставлена	\N
1986	RU3983803436569376600246742084811	398	2023-02-13	RU3083803436556733352794187735054	внутренняя	7699189.7866	644.8493	отправлена	\N
1987	RU4483803436593534887929979895004	356	2023-02-05	RU2083803436571871160330810400191	внутренняя	1763805.7422	986.7609	отправлена	\N
1988	RU6483803436527000884469712767990	398	2023-07-04	RU5083803436537344339331652897359	внутренняя	8523232.4441	715.7971	отменена	\N
1989	RU2783803436515955219320238454317	643	2023-01-02	AD9359755519320513407906361	внутренняя	9231024.2765	442.2434	доставлена	\N
1990	RU4183803436593654490331448399606	643	2023-02-26	ES5734417114777718489798597	внутренняя	3565260.2041	251.6977	доставлена	\N
1991	RU1183803436513944372774322746458	840	2023-05-21	PT3677126796755474635922575	международная	9448680.1333	360.1491	доставлена	IRVTUS3NXXX
1992	RU1183803436512373318427988836252	356	2023-09-10	KZ5319673684767269891672846	международная	4416156.2801	854.3646	отменена	SBININBBXXX
1993	RU1983803436537997284898110055528	840	2023-12-15	RU7183803436513501317784267991188	внутренняя	6285421.2576	954.9931	отменена	\N
1994	RU5883803436571013870275428717873	643	2023-06-23	RU8983803436518961229187913059129	внутренняя	6980562.1420	225.8534	отправлена	\N
1995	RU8183803436564595439284009293487	156	2023-01-03	VN5948010952041358957750578	международная	2085583.9025	230.5161	отменена	BKCHCNBJ
1996	RU8783803436544746989208687599320	978	2023-01-31	RU7483803436560908970835757520521	внутренняя	8267346.7408	970.2650	доставлена	\N
1997	RU4883803436540069564759439339493	840	2023-12-13	ES1619136395514169221491005	международная	3609373.4037	628.1227	отменена	CHASUS33
1998	RU4983803436534576819154749347962	840	2023-08-05	AD2881972702564630246038106	международная	2731375.4610	694.5879	доставлена	IRVTUS3NXXX
1999	RU4283803436544879224116585983050	978	2023-07-24	RU8583803436567351126582917385267	внутренняя	3226254.7445	200.9026	отправлена	\N
2000	RU2683803436575198696607383546599	156	2023-08-14	RU8553572515277170876103200	внутренняя	3582050.0702	290.5969	доставлена	\N
2001	RU9683803436524115739172828059349	156	2022-12-28	IN8174472814391280268391023	международная	7912371.6822	64.9524	отправлена	BKCHCNBJ
2002	RU7783803436578403910419087666263	643	2023-04-20	AL2793854482850893477348949	внутренняя	6231398.4409	383.3402	доставлена	\N
2003	RU6983803436557684576294868357987	156	2023-12-21	BY5147574351281992442035822	международная	8104227.9471	887.5334	отправлена	BKCHCNBJ
2004	RU3683803436529963181547651499120	978	2023-01-13	RU6583803436573484995572407857396	внутренняя	7597602.2111	247.8923	доставлена	\N
2005	RU9483803436521022327823815694666	398	2023-11-07	AL1178501443518268527336163	международная	9502433.5786	132.8193	отменена	CASPKZKAXXX
2006	RU1583803436592948110594062864167	398	2023-09-26	VN7836858965813520386344444	международная	1798330.4460	262.2848	отправлена	CASPKZKAXXX
2007	RU5683803436581377733469772235779	978	2023-08-20	AD9342999482362836584198678	международная	742599.9662	673.6077	доставлена	SOGEFRPP
2008	RU5983803436558435772787343054218	156	2023-03-01	RU3883803436554504516286459147223	внутренняя	2362883.1623	452.7620	отправлена	\N
2009	RU6483803436599929208547720213297	156	2023-08-17	BY1281355483960224019665166	международная	6075972.9940	32.1452	доставлена	BKCHCNBJ
2010	RU8483803436514025076841381077297	840	2023-02-16	AL1868915903265297715559798	международная	2014357.9169	740.3032	отменена	IRVTUS3NXXX
2011	RU9883803436559947701649293062119	978	2023-05-21	RU4183803436575456526806163894045	внутренняя	5467046.0175	808.3078	отменена	\N
2012	RU9183803436594783043422280553530	643	2023-05-27	IN4743561399847327346259702	внутренняя	5080932.6786	132.5927	отменена	\N
2013	RU1683803436583298094705869717304	643	2023-11-14	RU6183803436571932790348770462135	внутренняя	9147404.7655	198.7780	отправлена	\N
2014	RU7683803436589524723383129532286	156	2023-05-23	RU2583803436586349630493889324094	внутренняя	6463912.3120	933.0881	отправлена	\N
2015	RU1583803436575905915250327615306	356	2023-11-06	ES7685310075506500474252620	международная	2395182.5911	218.1493	доставлена	SBININBBXXX
2016	RU6183803436551232797419519235346	398	2023-09-11	PT8127486964376175053260323	международная	1658958.9318	802.7182	отправлена	CASPKZKAXXX
2017	RU9183803436523189940915642395180	840	2023-03-16	ES5145495227959189415066216	международная	2339968.4455	615.2121	отправлена	IRVTUS3NXXX
2018	RU5383803436532276110708298062956	398	2023-01-19	AL3889625776726861935402835	международная	8288495.8282	73.9591	отменена	CASPKZKAXXX
2019	RU4383803436535637847836978327691	156	2023-05-13	VN4972957222462530090434268	международная	8935836.8998	343.2952	доставлена	BKCHCNBJ
2020	RU2783803436598441945275189813351	156	2022-12-31	DE5070324614455462719257191	международная	3144419.2586	767.4258	отменена	BKCHCNBJ
2021	RU4183803436512683300418013703414	978	2023-12-18	DE8633591584219263697421412	международная	4208424.3294	234.7831	отменена	DEUTDEFFXXX
2022	RU6983803436550083462130199504453	356	2023-07-07	RU2383803436518501918755699207235	внутренняя	5949673.2789	70.8984	доставлена	\N
2023	RU6083803436582119843499506879640	356	2023-11-03	IN6643159169741040571490516	международная	3706897.8734	447.5388	отправлена	SBININBBXXX
2024	RU5083803436563140090168469536649	356	2023-12-17	BY4596179871097217916389198	международная	1767160.2185	701.2444	отправлена	SBININBBXXX
2025	RU9483803436516702191580023603147	643	2023-11-17	AD8795783643657464846320193	внутренняя	7289000.4745	290.4767	доставлена	\N
2026	RU9883803436580908913943520973504	356	2023-07-06	ES3635328095060839639573975	международная	5875232.4387	666.3224	отменена	SBININBBXXX
2027	RU9383803436563463129216774786629	156	2023-12-23	RU1683803436583298094705869717304	внутренняя	5102438.0776	67.2235	доставлена	\N
2028	RU2283803436577856579987093576845	356	2023-05-04	RU3583803436531844714480494060517	внутренняя	6117061.5415	838.0421	доставлена	\N
2029	RU7383803436569356631218275502161	156	2023-10-11	RU3883803436519845868206132784952	внутренняя	6471106.7780	316.7930	отменена	\N
2030	RU2583803436511360000518303822185	398	2023-08-15	RU5383803436532276110708298062956	внутренняя	3409656.8775	334.3881	отменена	\N
2031	RU4583803436571583967013936520660	356	2023-08-12	RU6583803436573484995572407857396	внутренняя	9978590.0924	146.5994	отправлена	\N
2032	RU7483803436560908970835757520521	156	2023-11-16	BY2013307825341208807700972	международная	3029244.6287	572.1062	доставлена	BKCHCNBJ
2033	RU6583803436526807323529165700056	356	2023-04-03	VN5957415418130529300675153	международная	2950253.3591	469.1541	отменена	SBININBBXXX
2034	RU2283803436577856579987093576845	643	2023-04-25	RU8083803436567877444686336475183	внутренняя	3103708.4880	279.1675	доставлена	\N
2035	RU2983803436545911307181108696312	840	2023-07-02	AL8076233498801262763088210	международная	9177808.0431	485.0296	отменена	IRVTUS3NXXX
2036	RU9983803436515137760640096699879	156	2023-01-21	BY6554037255047238555195724	международная	7762472.2820	924.6008	отменена	BKCHCNBJ
2037	RU3983803436569376600246742084811	356	2023-08-16	ES5612564254930539990900388	международная	2482270.3221	156.4495	доставлена	SBININBBXXX
2038	RU5783803436568341660520010753753	156	2023-09-04	DE1297886477109350768083804	международная	6565099.0171	108.1507	доставлена	BKCHCNBJ
2039	RU7483803436512314763652680872976	978	2023-01-22	RU3383803436548623436381587682007	внутренняя	6469330.9337	753.5950	доставлена	\N
2040	RU2983803436585384738431881857607	398	2022-12-27	RU7183803436546875767014611813689	внутренняя	7413108.7920	86.8775	отправлена	\N
2041	RU7083803436595909521339223196614	356	2023-03-01	BY1582063256531285739920017	международная	5361588.5880	179.6501	отправлена	SBININBBXXX
2042	RU2083803436518033160343253894367	978	2023-01-17	VN9586568236899704751121924	международная	9837641.2654	207.9343	отправлена	RZBAATWW
2043	RU8483803436593374085227717891522	643	2023-11-23	PT1093957281812736981451464	внутренняя	6596061.7558	604.2284	доставлена	\N
2044	RU2883803436581906276084692901201	398	2023-11-08	VN7665379098002825842910077	международная	6637469.7641	305.0422	отправлена	CASPKZKAXXX
2045	RU6383803436599902939219818792376	398	2023-08-15	RU2683803436512319317744369021772	внутренняя	6596817.1393	502.0496	отменена	\N
2046	RU9683803436597203099828784600586	356	2023-01-20	VN1956072065811125959726673	международная	5271235.2720	804.2576	отправлена	SBININBBXXX
2047	RU4383803436594641659799774635872	356	2023-09-27	DE4699474271590589461049916	международная	8063722.0173	343.1421	доставлена	SBININBBXXX
2048	RU3283803436579852018195047883736	356	2023-08-21	VN8614199934507409466501657	международная	5840966.2127	401.1814	отменена	SBININBBXXX
2049	RU4683803436584135461455281070651	978	2022-12-28	VN2985151204037105656899595	международная	6029174.8400	259.9816	доставлена	DEUTDEFFXXX
2050	RU7283803436565335970635584506660	356	2023-06-01	RU2983803436530272226005609138408	внутренняя	3062175.3316	969.1669	отменена	\N
2051	RU6183803436551232797419519235346	978	2023-09-06	RU9729729847034736132124556	внутренняя	2030518.9077	397.2091	отменена	\N
2052	RU8483803436528403655778834568144	978	2023-03-06	RU8983803436530366335955653516096	внутренняя	9231384.0263	182.7104	отменена	\N
2053	RU4283803436583191860084907222827	398	2023-10-16	RU8183803436564595439284009293487	внутренняя	5581763.7906	602.6208	отменена	\N
2054	RU2083803436518033160343253894367	356	2023-12-24	RU9083803436513364676730542126445	внутренняя	71701.7370	0.0000	отправлена	\N
2055	RU3383803436540416635821116917223	398	2023-04-27	IN5866680893267583938276651	международная	4633710.7668	815.0704	отправлена	CASPKZKAXXX
2056	RU9983803436581801115411623274695	356	2023-09-01	KZ6253916946328981152516945	международная	3863706.7762	573.1642	доставлена	SBININBBXXX
2057	RU1983803436568263609873115174417	643	2023-11-16	IN7998235301039308541972066	внутренняя	8963134.1535	779.7910	доставлена	\N
2058	RU5883803436537252361294139722938	643	2023-03-01	RU3183803436522808312515599877028	внутренняя	7630705.1670	320.5442	отправлена	\N
2059	RU5583803436541779385547740767657	356	2023-06-03	RU7583803436597888322431139189153	внутренняя	7648134.0886	932.1913	доставлена	\N
2060	RU4283803436532641085536208083176	156	2023-06-30	VN9737366161516531153553374	международная	6397142.8825	423.0331	отменена	BKCHCNBJ
2061	RU5483803436538988818998904026382	643	2023-03-14	VN9059502678245569222614285	внутренняя	9215659.3367	367.9062	отправлена	\N
2062	RU1983803436510712914540451632365	156	2023-12-13	RU5783803436573951128453151787227	внутренняя	2479131.3602	761.9572	доставлена	\N
2063	RU5483803436547543071206231343471	643	2023-01-27	AD9027489559701264030130791	внутренняя	5664807.6241	59.9634	отправлена	\N
2064	RU4183803436575456526806163894045	840	2023-12-23	RU3083803436556733352794187735054	внутренняя	7678809.2142	939.6943	отменена	\N
2065	RU1283803436513390712190126736747	356	2023-03-27	RU4483803436574648344464338946055	внутренняя	1673014.8749	62.7980	доставлена	\N
2066	RU4583803436546993711061481413708	978	2023-10-17	RU3583803436556382446278007957702	внутренняя	8884376.0783	788.0097	доставлена	\N
2067	RU5783803436573951128453151787227	643	2023-01-30	RU2783803436598441945275189813351	внутренняя	7813628.4671	569.4009	отправлена	\N
2068	RU4283803436530972916151822377436	840	2023-10-24	RU7783803436557425582753958788900	внутренняя	1357815.4705	854.7324	отменена	\N
2069	RU5583803436544105301147510534206	978	2023-07-05	RU2983803436572636545308279163382	внутренняя	9390991.3728	235.0679	отменена	\N
2070	RU7283803436528848493351990702937	398	2023-11-10	RU7383803436569356631218275502161	внутренняя	6885607.6113	527.7460	доставлена	\N
2071	RU5983803436558435772787343054218	840	2023-10-29	RU7783803436585076163513647706071	внутренняя	9506997.1484	365.2430	доставлена	\N
2072	RU9783803436586848496167067081204	643	2023-09-19	DE9067653215275647924992419	внутренняя	131137.4503	553.0674	отменена	\N
2073	RU5183803436550941857646482749776	978	2023-04-08	RU1983803436549890414007715363567	внутренняя	4630676.4352	700.9454	отправлена	\N
2074	RU4283803436538514172142523078432	643	2023-08-27	RU5983803436565674700991182664479	внутренняя	8164583.9864	760.9129	отменена	\N
2075	RU8883803436592173067148862634991	978	2023-03-12	RU8583803436586707949034749896750	внутренняя	8728519.1386	138.2820	отменена	\N
2076	RU7783803436585076163513647706071	398	2023-03-13	RU2983803436597155052344917689453	внутренняя	4841170.0379	163.7639	отменена	\N
2077	RU6783803436510078136565817264354	398	2023-06-03	ES6071190916970927912406452	международная	2788068.2472	343.7921	отправлена	CASPKZKAXXX
2078	RU8483803436562780872181379760829	156	2023-12-17	RU2683803436512319317744369021772	внутренняя	1719490.6979	29.2893	отправлена	\N
2079	RU9983803436545906901757432591750	398	2023-04-24	IN3567173456133815125437197	международная	649206.3691	618.5250	отменена	CASPKZKAXXX
2080	RU4483803436534969190676238532628	356	2023-09-20	DE1454326935981370854452960	международная	6537633.3447	91.4494	отменена	SBININBBXXX
2081	RU5783803436598085342824416355658	356	2023-04-01	AL9282903767423436700043836	международная	2583687.1100	830.7222	отправлена	SBININBBXXX
2082	RU7183803436535160662680026565691	356	2023-11-10	KZ2232786084760187442550434	международная	1559789.2523	86.2277	доставлена	SBININBBXXX
2083	RU6583803436556215016292535847892	398	2023-11-26	RU8483803436593374085227717891522	внутренняя	8592270.9784	859.2037	отправлена	\N
2084	RU1283803436597755454846611928328	840	2023-10-06	PT9721283075887441753873794	международная	8332475.4768	740.4338	отправлена	IRVTUS3NXXX
2085	RU3183803436522808312515599877028	840	2023-05-24	DE9191555138281580688994812	международная	971245.8578	572.5969	отправлена	CHASUS33
2086	RU2283803436555228451424548337941	840	2023-01-12	RU5583803436541779385547740767657	внутренняя	5108873.1815	499.5510	отменена	\N
2087	RU5583803436544105301147510534206	398	2023-04-16	ES7519518043919095637727728	международная	6400882.3420	348.5104	отменена	CASPKZKAXXX
2088	RU5983803436596779338391553657957	840	2023-05-24	RU6783803436534011789886956964173	внутренняя	9590655.0167	380.4845	доставлена	\N
2089	RU2583803436511360000518303822185	156	2023-03-16	IN7470445864192583455255590	международная	4674491.3926	760.1642	доставлена	BKCHCNBJ
2090	RU6083803436583599210196850890015	398	2023-05-23	IN1117300051512429610134301	международная	5370715.9648	252.9573	доставлена	CASPKZKAXXX
2091	RU2183803436555308456329784386702	356	2023-05-16	AL3232580208241804249607725	международная	1851313.0187	357.1199	отменена	SBININBBXXX
2092	RU4183803436512683300418013703414	978	2023-01-09	BY3026217268368660082864896	международная	6207234.8352	279.3930	отменена	DEUTDEFFXXX
2093	RU1683803436583298094705869717304	156	2023-01-18	RU5983803436533405804846460378377	внутренняя	780675.8553	164.7479	доставлена	\N
2094	RU5183803436585063037953141711870	978	2023-01-18	RU8983803436550652073660555482382	внутренняя	9296816.1108	862.1903	отменена	\N
2095	RU9683803436511276549947859990709	840	2023-12-26	RU4583803436571583967013936520660	внутренняя	2456055.4617	425.6497	отменена	\N
2096	RU8983803436551003507571679577910	840	2023-06-20	VN5786782038531928448541950	международная	2634542.5331	226.8360	доставлена	IRVTUS3NXXX
2097	RU1283803436513390712190126736747	156	2023-01-25	RU2583803436510413813910694958748	внутренняя	5519196.6689	340.8430	отправлена	\N
2098	RU4283803436515276086545867508581	398	2023-01-26	BY6133403795579477017190327	международная	3060531.3019	103.1299	доставлена	CASPKZKAXXX
2099	RU8083803436588746463552823930061	643	2023-01-04	VN4831487211188811560022441	внутренняя	5372850.9932	450.4408	доставлена	\N
2100	RU5583803436544105301147510534206	978	2023-07-03	RU1383803436523658112524214881297	внутренняя	6069473.7947	165.9475	отправлена	\N
2101	RU9183803436594783043422280553530	643	2023-11-10	RU1083803436563162471160560931522	внутренняя	1066216.8216	57.5178	доставлена	\N
2102	RU1383803436598073263367823117200	356	2023-09-22	DE5283942484867145483216626	международная	5364932.7160	152.2860	отменена	SBININBBXXX
2103	RU5483803436559214869633349674125	356	2023-08-20	RU2283803436588289284937975921944	внутренняя	7004248.8306	954.8403	отменена	\N
2104	RU9483803436588743613330942629999	840	2023-11-14	RU3783803436585191546282680625888	внутренняя	1768517.4853	156.7160	доставлена	\N
2105	RU4583803436546993711061481413708	156	2023-08-18	RU3883803436515226766320509995235	внутренняя	1768102.2854	165.0884	отменена	\N
2106	RU3183803436538368625987340316428	356	2023-10-17	BY6917268191173743488891040	международная	7096591.8481	408.9565	отправлена	SBININBBXXX
2107	RU7783803436529059332090835348557	978	2023-10-17	DE5636110559497623469863368	международная	5935668.2165	614.7290	отменена	RZBAATWW
2108	RU3783803436559423561964096195262	356	2023-07-27	AL1996930701336583182418625	международная	8697908.6370	862.6708	отменена	SBININBBXXX
2109	RU3583803436531844714480494060517	978	2023-09-30	IN1740769356974274464278132	международная	5745394.8059	651.4058	доставлена	RZBAATWW
2110	RU5083803436583492295875343805447	840	2023-05-14	RU1183803436536239647096212180861	внутренняя	1574718.6517	792.0262	отправлена	\N
2111	RU7783803436578403910419087666263	356	2023-10-27	RU3883803436571430516571621799878	внутренняя	3688807.8515	221.9287	отменена	\N
2112	RU2383803436569895097903578030814	840	2023-04-25	BY1427825248046195494208554	международная	5160343.0204	698.7822	отправлена	CHASUS33
2113	RU1383803436546084241558471107471	156	2023-06-02	RU9083803436542335742968981386823	внутренняя	9479206.1166	147.0197	отправлена	\N
2114	RU9283803436581282514241262822584	840	2023-02-11	RU8583803436553386257766521949981	внутренняя	4025724.7294	482.3323	отправлена	\N
2115	RU5183803436573013692902081587761	156	2023-05-17	RU4983803436548786021946522460624	внутренняя	1861330.6986	212.4245	доставлена	\N
2116	RU7383803436515152831562897371432	156	2023-03-15	RU1583803436533479152204865778047	внутренняя	6225443.4057	859.8022	отправлена	\N
2117	RU5283803436570838144716210841495	978	2023-12-08	PT1375143149053865497649040	международная	7467410.2478	598.9072	отменена	DEUTDEFFXXX
2118	RU2183803436535230801413319305895	643	2023-07-13	RU4883803436510661666911089208306	внутренняя	8662704.9487	882.1779	отменена	\N
2119	RU3683803436529963181547651499120	356	2023-01-05	PT9260027839289608136152069	международная	3489766.5971	363.6859	доставлена	SBININBBXXX
2120	RU2683803436556115738690945420927	978	2023-04-10	PT5722520612591406853984220	международная	697718.2326	899.5953	отменена	DEUTDEFFXXX
2121	RU8183803436576908594301902139271	398	2023-10-06	AD4412163176230676352748917	международная	3400254.4581	298.3209	отменена	CASPKZKAXXX
2122	RU7283803436565335970635584506660	156	2023-01-26	RU7791719342877154319150693	внутренняя	1794015.3112	303.2258	отправлена	\N
2123	RU9983803436563015974445739907644	398	2023-11-30	RU8483803436576032684947735830335	внутренняя	3693791.5142	87.2353	доставлена	\N
2124	RU2683803436532775565489898182986	356	2023-11-28	RU7083803436565850801859363291526	внутренняя	4231718.7391	122.5309	доставлена	\N
2125	RU6983803436551969328605594993446	840	2023-04-14	IN9692262447066809774836783	международная	7507690.6145	725.5726	отправлена	CHASUS33
2126	RU5483803436551418630110242560620	978	2023-09-06	RU7283803436582085910615477000049	внутренняя	8847299.4634	837.9087	отправлена	\N
2127	RU2683803436512319317744369021772	398	2023-03-26	RU4383803436538414207445829899653	внутренняя	3343938.0304	500.8993	отменена	\N
2128	RU7483803436591068390387769478580	356	2023-05-22	RU1183803436587920364130887563809	внутренняя	6854472.6718	36.8713	отправлена	\N
2129	RU3683803436526413764026311806751	356	2023-02-02	VN6789331432293850483956896	международная	1397232.9902	352.5730	доставлена	SBININBBXXX
2130	RU6383803436599902939219818792376	156	2023-08-21	RU7683803436565241249132549566386	внутренняя	889089.6606	466.8961	отправлена	\N
2131	RU9983803436515137760640096699879	156	2023-02-10	RU5083803436521160540176223483455	внутренняя	3718587.0818	783.7340	отменена	\N
2132	RU1583803436522600904788279282430	978	2023-09-26	RU5183803436596697120047636808100	внутренняя	4612598.3955	502.9544	доставлена	\N
2133	RU3483803436534657689181631833463	840	2023-10-10	RU1183803436569972795023903837949	внутренняя	1060741.5530	344.4383	отменена	\N
2134	RU8683803436531608639655465618756	356	2023-10-28	RU1883803436562141776165180370424	внутренняя	1034477.6693	728.2479	отменена	\N
2135	RU4583803436576777630615652907536	643	2023-02-04	BY2017550162250282400985872	внутренняя	3765915.0243	252.5004	отменена	\N
2136	RU6483803436599929208547720213297	643	2023-05-12	IN3257594239758546637612088	внутренняя	6802161.5459	134.9048	отправлена	\N
2137	RU9283803436560888794155508079505	840	2023-08-26	PT7551666094106974903196750	международная	3571623.6578	423.1665	отменена	CHASUS33
2138	RU5183803436588244188761426669013	840	2023-11-11	KZ8967946096863067979487017	международная	3505008.5105	16.5996	доставлена	IRVTUS3NXXX
2139	RU6783803436583735354795738130605	643	2023-08-11	AL3292331471190294324156009	внутренняя	6376900.8681	917.5595	отменена	\N
2140	RU6283803436577836700807681117407	156	2023-06-26	ES6759787489930914341949419	международная	969114.2269	258.9803	доставлена	BKCHCNBJ
2141	RU6783803436582018660242960957244	978	2023-03-02	BY7549074012879445845806981	международная	2169021.1508	225.1460	доставлена	RZBAATWW
2142	RU6283803436541447099313442593938	978	2023-06-30	AL9892835241096939422851199	международная	6660572.2996	807.6245	доставлена	DEUTDEFFXXX
2143	RU2183803436535230801413319305895	398	2023-09-14	RU2883803436564862346362051659673	внутренняя	3225275.3774	382.2505	отправлена	\N
2144	RU5183803436573013692902081587761	356	2023-02-09	PT5930046513567706580928242	международная	3130933.1468	75.1455	отменена	SBININBBXXX
2145	RU9783803436566819882292917709885	643	2023-07-17	DE1443800601834675107245482	внутренняя	5245390.0022	933.2740	отменена	\N
2146	RU1983803436510712914540451632365	156	2023-05-21	AD7250223582042186693514724	международная	5025467.5387	114.7377	отменена	BKCHCNBJ
2147	RU8983803436543970357311304848339	643	2023-10-08	ES9539336617640461293762043	внутренняя	6424656.3715	239.9565	отменена	\N
2148	RU7783803436556242953974983768067	356	2023-09-12	AD1130698776836821098398767	международная	6347178.2316	466.0439	отменена	SBININBBXXX
2149	RU7483803436575212193030608824580	643	2023-01-20	RU6983803436518663051613263930888	внутренняя	768007.9109	269.9108	доставлена	\N
2150	RU2083803436517185898516741185299	840	2023-03-07	RU8783803436522200736153030297680	внутренняя	2830662.3404	550.3065	доставлена	\N
2151	RU5483803436538988818998904026382	356	2023-02-18	KZ4979922762140540088757709	международная	4575066.8836	21.1103	доставлена	SBININBBXXX
2152	RU7783803436557425582753958788900	840	2023-04-01	RU5783803436568341660520010753753	внутренняя	9211014.3390	425.6855	доставлена	\N
2153	RU2283803436521727957364583057084	156	2023-09-05	ES7597795699968969177461342	международная	5695490.0460	35.3144	отменена	BKCHCNBJ
2154	RU5783803436523742307313248220811	156	2023-03-02	AD9025092023789875502260416	международная	3023201.6420	312.5305	отправлена	BKCHCNBJ
2155	RU5283803436529894140873721164089	978	2022-12-29	RU7183803436513501317784267991188	внутренняя	624052.2911	350.7931	отменена	\N
2156	RU4383803436559640804885433764330	978	2023-02-22	RU8783803436522200736153030297680	внутренняя	4866557.8860	613.4291	отправлена	\N
2157	RU9483803436570307762028951954874	643	2023-12-09	RU2961964526845334770194277	внутренняя	6280866.7085	303.4161	отменена	\N
2158	RU3883803436515226766320509995235	840	2023-04-11	RU2883803436564862346362051659673	внутренняя	382012.2465	189.5516	отменена	\N
2159	RU3183803436559935083955185145410	398	2023-03-19	BY5699002174211733286858329	международная	9696243.6684	335.4050	отменена	CASPKZKAXXX
2160	RU6583803436599318340096840026283	356	2023-02-15	PT8980896877544896895647138	международная	1547196.9303	0.0000	отменена	SBININBBXXX
2161	RU9983803436581801115411623274695	978	2023-05-21	RU2783803436529440294678710752920	внутренняя	9330843.2153	778.5147	отменена	\N
2162	RU3483803436534657689181631833463	156	2023-07-18	VN3514744502642289085536434	международная	8586437.6623	134.3160	отменена	BKCHCNBJ
2163	RU7483803436512314763652680872976	840	2023-01-25	ES5238282167051876618535965	международная	3140803.6364	941.1707	отменена	IRVTUS3NXXX
2164	RU8183803436584325139466333599286	156	2023-12-15	RU5983803436513359014201161572816	внутренняя	8822679.1567	909.4019	отправлена	\N
2165	RU9583803436557636243711161422858	840	2023-05-26	RU2483803436550335144467075253432	внутренняя	3624253.7526	178.6278	отменена	\N
2166	RU3383803436530100232705488681423	398	2023-12-14	RU9983803436521153026985692784451	внутренняя	475412.5726	330.9895	доставлена	\N
2167	RU1383803436598073263367823117200	356	2023-02-14	RU2583803436573489146610412814439	внутренняя	5876214.6682	556.9053	доставлена	\N
2168	RU7383803436534050516387288663509	840	2023-03-21	IN3818192606313337816563083	международная	2965759.2393	626.4325	отменена	CHASUS33
2169	RU5483803436551418630110242560620	398	2023-05-04	IN2987082961342510565211217	международная	7439770.2786	645.4240	отменена	CASPKZKAXXX
2170	RU3583803436580986023375789999847	356	2023-06-26	RU6483803436513432249664452306210	внутренняя	4687407.0432	189.0307	отменена	\N
2171	RU7583803436593621382878998665048	356	2023-12-13	RU7583803436597888322431139189153	внутренняя	6429026.0533	29.1279	доставлена	\N
2172	RU6583803436588261503476787515721	356	2023-07-19	PT8394463854871179586786013	международная	3508398.1997	22.3665	отправлена	SBININBBXXX
2173	RU1483803436552189189819570176682	156	2023-08-24	RU6583803436552414284054924599360	внутренняя	240571.2765	787.6744	доставлена	\N
2174	RU4283803436532641085536208083176	398	2023-12-15	RU1583803436597114679330016317094	внутренняя	399319.3728	17.9065	доставлена	\N
2175	RU8583803436567351126582917385267	156	2023-12-17	RU2783803436580745382811010865973	внутренняя	421367.6717	270.2201	доставлена	\N
2176	RU9483803436522220035875117822565	156	2023-03-21	ES5958824574923658864470713	международная	5860224.9403	239.3064	доставлена	BKCHCNBJ
2177	RU4683803436584135461455281070651	156	2023-05-03	IN4132778365461692195020561	международная	1333397.0763	834.4909	доставлена	BKCHCNBJ
2178	RU9383803436587347167184231490115	156	2023-03-15	IN5730395071767389287310829	международная	630376.1711	355.4576	отправлена	BKCHCNBJ
2179	RU5983803436533405804846460378377	156	2023-07-08	BY6656956783497153637787413	международная	2449448.1985	420.5073	доставлена	BKCHCNBJ
2180	RU2983803436597155052344917689453	156	2023-02-20	RU6483803436575827628326698282321	внутренняя	1356708.5316	846.6544	отменена	\N
2181	RU2483803436559904294875702128517	398	2023-10-09	BY9737797909466722420519889	международная	2644047.7749	313.1575	доставлена	CASPKZKAXXX
2182	RU5583803436516539388298963058164	840	2023-02-22	RU1683803436530784164352439032526	внутренняя	1594225.9667	91.0327	отправлена	\N
2183	RU2383803436518501918755699207235	978	2023-06-17	ES8322663326230891415049645	международная	137265.5026	821.6493	отменена	SOGEFRPP
2184	RU1183803436547102061688733775669	156	2023-09-30	RU5683803436575772290627280121203	внутренняя	5479064.0431	425.5909	отменена	\N
2185	RU9783803436566819882292917709885	840	2023-07-18	RU1383803436596151895061926683764	внутренняя	2732552.2880	782.6435	отменена	\N
2186	RU5583803436533254773648721597711	840	2023-07-12	RU9683803436541591047480784615833	внутренняя	7876781.1252	274.5106	доставлена	\N
2187	RU7083803436575256167282941443393	356	2023-08-22	RU3783803436562139250445157080524	внутренняя	7089793.9484	0.0000	отменена	\N
2188	RU5183803436588801456118987264753	643	2023-09-25	AD4176428989314392190622756	внутренняя	3446669.6753	905.0351	доставлена	\N
2189	RU7383803436569356631218275502161	156	2023-05-04	RU9254529549504042781580778	внутренняя	646857.4362	725.8689	доставлена	\N
2190	RU1983803436592911874717339237016	643	2023-03-26	RU7183803436551143317683635788042	внутренняя	2511469.0091	634.7695	отменена	\N
2191	RU3183803436564747839620735247465	156	2023-11-27	RU1383803436598073263367823117200	внутренняя	9195023.2050	192.4744	доставлена	\N
2192	RU9683803436520170153501466272589	643	2023-05-02	AL3182095274568640263602753	внутренняя	2893127.7678	683.5844	отправлена	\N
2193	RU8783803436562772820294479967682	156	2023-11-23	IN1761307539384171257507275	международная	4749669.3011	405.3703	отменена	BKCHCNBJ
2194	RU4183803436593654490331448399606	978	2023-05-27	RU1483803436556765140449291811625	внутренняя	5194167.2648	547.1846	доставлена	\N
2195	RU1183803436541561390025398925839	840	2023-04-04	RU4683803436518754352401343547893	внутренняя	4453223.9707	150.6218	доставлена	\N
2196	RU4083803436526038486689011711230	398	2023-02-17	RU4583803436588661449801193641363	внутренняя	5047533.0961	11.6902	отправлена	\N
2197	RU7483803436591068390387769478580	840	2023-02-21	RU3983803436580604058878329162478	внутренняя	1963006.0823	459.3010	отменена	\N
2198	RU2183803436586747579379810386651	978	2023-02-10	BY7540758323478067286238976	международная	6258895.0867	928.4343	доставлена	DEUTDEFFXXX
2199	RU2083803436518033160343253894367	978	2023-08-15	RU7483803436529598231033100377224	внутренняя	9289496.2371	801.7776	доставлена	\N
2200	RU2583803436586349630493889324094	840	2023-02-12	RU5483803436559214869633349674125	внутренняя	621131.7110	267.1689	доставлена	\N
2201	RU9783803436586848496167067081204	356	2023-06-08	RU7783803436536804517087406327796	внутренняя	2365633.2075	424.4559	отправлена	\N
2202	RU6683803436563942598707878107815	978	2023-09-13	RU2083803436518033160343253894367	внутренняя	8995788.0778	249.6117	отменена	\N
2203	RU3483803436534657689181631833463	356	2023-01-17	DE5299068051613001186862894	международная	5057871.1821	220.7847	доставлена	SBININBBXXX
2204	RU5883803436544935035293164341064	156	2023-03-30	RU7483803436529598231033100377224	внутренняя	1317031.9251	31.2984	доставлена	\N
2205	RU1383803436546084241558471107471	840	2022-12-31	ES9247375412272527207490355	международная	787251.3534	95.0218	доставлена	IRVTUS3NXXX
2206	RU2183803436586747579379810386651	978	2023-07-17	RU8283803436593409912626065485368	внутренняя	2933003.4629	294.3063	отправлена	\N
2207	RU4383803436594641659799774635872	840	2023-07-04	RU6983803436521001508692071958064	внутренняя	3396359.8091	96.0128	отправлена	\N
2208	RU8983803436551003507571679577910	156	2023-10-28	VN2649536477157874953704100	международная	1157178.9319	421.8049	отменена	BKCHCNBJ
2209	RU4683803436518754352401343547893	398	2023-09-13	RU6683803436546559918630563560759	внутренняя	716270.6302	201.6065	отменена	\N
2210	RU6683803436547011171926119923803	978	2023-03-17	BY4386553117255227900432657	международная	5707448.0294	698.6749	доставлена	RZBAATWW
2211	RU9083803436548965374028188380728	356	2023-10-27	RU7783803436520045957277741704368	внутренняя	5761653.5182	233.2742	отправлена	\N
2212	RU9883803436596118671708861810646	978	2023-01-17	RU6065874509131234943761209	внутренняя	8654155.9861	822.2230	отправлена	\N
2213	RU4283803436571605132393354830061	156	2023-02-24	RU1964109737369224215916240	внутренняя	9950408.0518	341.7415	доставлена	\N
2214	RU1583803436513968949783488654583	156	2023-08-13	RU4583803436567844239839748091371	внутренняя	7560956.4723	246.9981	отправлена	\N
2215	RU6983803436542868245387240901621	643	2023-07-18	RU5483803436551418630110242560620	внутренняя	6659287.9817	196.4285	отменена	\N
2216	RU4183803436575456526806163894045	356	2023-02-04	AL6732424246849567233823213	международная	356001.1649	986.0331	отправлена	SBININBBXXX
2217	RU2283803436588289284937975921944	840	2023-04-06	RU5983803436533405804846460378377	внутренняя	6509320.7107	370.6060	отменена	\N
2218	RU2283803436594102552659582448178	840	2023-06-15	RU4083803436530357399673623809331	внутренняя	3779537.4837	954.5350	доставлена	\N
2219	RU1383803436596151895061926683764	840	2023-02-14	RU2783803436515955219320238454317	внутренняя	3173475.1998	875.0145	отправлена	\N
2220	RU8483803436597380246113206833117	643	2023-04-09	KZ8175363853505784769810687	внутренняя	9159180.0079	794.7821	отменена	\N
2221	RU3983803436583094600516227232333	643	2023-11-03	PT1543878927398577222372662	внутренняя	7037120.8832	886.3613	отправлена	\N
2222	RU9383803436575688788160155647011	156	2023-04-07	DE5222711029155463003411014	международная	6463890.6749	561.3397	отменена	BKCHCNBJ
2223	RU9083803436513364676730542126445	840	2023-09-19	VN1485542626760340259886707	международная	7340137.5410	194.0929	доставлена	CHASUS33
2224	RU6583803436556215016292535847892	978	2023-07-29	RU3683803436521305656177527242839	внутренняя	7257714.7639	915.0772	отменена	\N
2225	RU8583803436598717986670697262250	356	2023-02-16	RU9795439491797553969641043	внутренняя	4385729.5147	610.5035	отправлена	\N
2226	RU4883803436561825246742556433732	398	2023-08-29	RU6383803436519000124215462920616	внутренняя	5140765.8632	703.6315	отменена	\N
2227	RU2083803436518033160343253894367	398	2023-12-20	RU2683803436566742853200336170327	внутренняя	3907972.0950	61.3123	отправлена	\N
2228	RU4283803436544879224116585983050	356	2023-07-31	RU2183803436535230801413319305895	внутренняя	3217592.3901	522.7396	доставлена	\N
2229	RU3883803436531800763308499008852	356	2023-05-14	AL8775374313062170029777596	международная	668255.3336	411.8637	доставлена	SBININBBXXX
2230	RU4483803436531766422461159975910	356	2023-08-24	AD2580278583414815303287437	международная	2102758.2119	431.7355	отправлена	SBININBBXXX
2231	RU3383803436540416635821116917223	978	2023-05-18	RU6183803436573612137819734816326	внутренняя	9330439.9349	266.2891	доставлена	\N
2232	RU2183803436555308456329784386702	978	2023-11-22	RU8289841064427052103981934	внутренняя	8892892.5687	573.8993	доставлена	\N
2233	RU3383803436533625475503259998648	840	2023-10-06	ES8680695433401095013363777	международная	8551974.8573	772.4914	доставлена	IRVTUS3NXXX
2234	RU6483803436513432249664452306210	156	2023-08-02	RU6283803436541447099313442593938	внутренняя	9326783.3325	31.5209	доставлена	\N
2235	RU6383803436530975100435134167112	643	2023-09-15	RU1383803436565139777755041333233	внутренняя	2341877.3611	432.0495	доставлена	\N
2236	RU7283803436583841985241060182740	840	2023-05-29	RU9883803436559947701649293062119	внутренняя	9185866.9659	793.6407	доставлена	\N
2237	RU5983803436596779338391553657957	840	2023-05-27	RU4383803436597428452957764955765	внутренняя	462505.6910	756.5908	отменена	\N
2238	RU9883803436580908913943520973504	978	2023-11-29	PT2029987636808825639358333	международная	4869684.1792	420.3207	доставлена	SOGEFRPP
2239	RU6083803436583599210196850890015	398	2023-11-13	RU3183803436545750333950215053352	внутренняя	1434741.4302	920.8225	отменена	\N
2240	RU1983803436574962372646294489745	398	2023-11-28	AD8222752123285029725940766	международная	7034960.4162	155.2442	отменена	CASPKZKAXXX
2241	RU9583803436574471411467135718624	643	2023-03-26	RU1794892595761026071641398	внутренняя	4459750.8892	516.7243	отправлена	\N
2242	RU4883803436561825246742556433732	643	2023-01-29	RU1683803436543683792461716245841	внутренняя	9971727.0911	824.1111	отправлена	\N
2243	RU2583803436511360000518303822185	156	2023-07-29	RU5983803436585678890114061651314	внутренняя	583644.4628	661.0837	отправлена	\N
2244	RU3983803436583094600516227232333	156	2023-10-23	IN8312495125451813120963074	международная	6576920.8479	217.6493	доставлена	BKCHCNBJ
2245	RU8783803436519169154241731281817	978	2023-12-17	RU8483803436523751116997614384937	внутренняя	1902281.9734	929.6868	отменена	\N
2246	RU9383803436587347167184231490115	840	2023-01-16	RU4183803436593654490331448399606	внутренняя	4075536.4629	685.7544	доставлена	\N
2247	RU4483803436574648344464338946055	156	2023-11-23	IN5973391204879355155046244	международная	5181586.8953	32.4112	доставлена	BKCHCNBJ
2248	RU9583803436574471411467135718624	840	2023-09-16	DE8348112943148812158088398	международная	9765100.3595	211.9746	отменена	IRVTUS3NXXX
2249	RU7583803436593274051968042799324	356	2023-02-11	AD8225825689291484580433623	международная	1596930.2453	286.2402	отправлена	SBININBBXXX
2250	RU3683803436526413764026311806751	156	2023-08-22	IN9998038608169326227845184	международная	4711039.1980	145.8842	доставлена	BKCHCNBJ
2251	RU4883803436583846522749125412438	978	2023-06-23	RU5783803436523742307313248220811	внутренняя	6628547.6501	809.0903	отправлена	\N
2252	RU1383803436565139777755041333233	398	2023-09-20	RU3883803436515226766320509995235	внутренняя	8551552.2450	306.9699	отправлена	\N
2253	RU6583803436547384322379422553840	840	2023-11-15	ES8894083494973577788270475	международная	220174.1173	305.6603	доставлена	CHASUS33
2254	RU7483803436512314763652680872976	398	2023-08-18	RU8383803436557193853878723819444	внутренняя	4947027.9178	552.3549	отменена	\N
2255	RU5983803436533405804846460378377	840	2023-06-10	IN4395579645436383946344717	международная	409081.9043	382.9149	отправлена	CHASUS33
2256	RU4983803436534576819154749347962	840	2023-01-13	RU5983803436561671607015303339932	внутренняя	9420849.3028	540.6926	доставлена	\N
2257	RU4683803436521950147450839996450	978	2023-04-06	RU2083803436518033160343253894367	внутренняя	3223492.4541	724.6592	доставлена	\N
2258	RU6283803436541447099313442593938	643	2023-04-14	AL7753160702405162291048551	внутренняя	955221.9120	144.9709	отправлена	\N
2259	RU9683803436531094862059243712475	398	2023-07-08	RU4883803436583846522749125412438	внутренняя	8200017.4962	856.0290	отправлена	\N
2260	RU5683803436581377733469772235779	643	2023-10-05	RU1083803436588429797000364388942	внутренняя	1262150.1421	952.8019	отменена	\N
2261	RU9783803436586848496167067081204	398	2022-12-27	PT8310450954604987156892796	международная	2468576.1383	68.6768	отменена	CASPKZKAXXX
2262	RU1183803436536239647096212180861	398	2023-10-08	VN7463807946792884051870629	международная	6211463.1587	459.4939	отменена	CASPKZKAXXX
2263	RU6483803436557881046066137062384	840	2023-05-21	IN2720719216056409513653660	международная	5916766.8427	851.5183	отменена	IRVTUS3NXXX
2264	RU2883803436564862346362051659673	398	2023-03-05	RU7683803436565241249132549566386	внутренняя	7579351.5718	263.1117	доставлена	\N
2265	RU8283803436558421168306139201398	643	2023-06-01	RU9683803436579408636311341559980	внутренняя	5492459.2165	921.7702	доставлена	\N
2266	RU8283803436558421168306139201398	840	2023-06-16	RU8583803436529401978461350257287	внутренняя	2564109.8066	81.6829	отменена	\N
2267	RU9483803436516702191580023603147	978	2023-06-01	RU9171774152873967295672138	внутренняя	5950295.3559	223.4320	отправлена	\N
2268	RU6483803436531317735484528392559	156	2023-01-23	DE3234672505889218929732315	международная	4870122.5314	612.7637	отменена	BKCHCNBJ
2269	RU4183803436593654490331448399606	840	2023-10-12	RU7283803436528848493351990702937	внутренняя	4120162.4990	213.4551	отменена	\N
2270	RU8483803436586135450040789229889	398	2023-03-03	RU3126318698347040090513094	внутренняя	6415540.1633	751.4596	доставлена	\N
2271	RU2183803436555308456329784386702	643	2023-11-18	ES2037442607122467056542133	внутренняя	2617771.5215	735.5578	отменена	\N
2272	RU5583803436544105301147510534206	398	2023-01-26	RU3883803436571430516571621799878	внутренняя	6706182.0780	433.2220	отменена	\N
2273	RU6483803436595566817980742907742	356	2023-08-25	KZ9285767635045392686966069	международная	5737771.2312	155.7975	отменена	SBININBBXXX
2274	RU9683803436524115739172828059349	643	2023-04-04	RU2852826178447299676694840	внутренняя	431080.2986	205.2545	доставлена	\N
2275	RU6383803436599902939219818792376	840	2023-01-13	RU5783803436523742307313248220811	внутренняя	4415450.0144	187.5019	отправлена	\N
2276	RU3783803436559423561964096195262	840	2023-04-02	DE9317056487843657598378992	международная	756372.2991	655.6482	отменена	CHASUS33
2277	RU3683803436583826961336736431806	840	2023-02-12	RU6783803436510078136565817264354	внутренняя	4644309.2004	210.0863	отправлена	\N
2278	RU9083803436548965374028188380728	156	2023-06-28	RU7383803436534050516387288663509	внутренняя	9200876.2605	963.2052	доставлена	\N
2279	RU9383803436546841675173507423577	356	2023-04-25	RU2483803436559904294875702128517	внутренняя	7217944.4398	284.9998	отправлена	\N
2280	RU1283803436513390712190126736747	356	2023-01-15	RU8483803436586135450040789229889	внутренняя	129178.0124	923.3465	отменена	\N
2281	RU5883803436544935035293164341064	643	2023-03-19	DE5067185163682635444965599	внутренняя	6002284.3432	377.2354	отменена	\N
2282	RU1283803436545193525808988988532	643	2023-04-09	RU1983803436518034161993382946183	внутренняя	3544628.1989	233.4711	отменена	\N
2283	RU7483803436575212193030608824580	978	2023-08-25	RU8183803436566794763466227027850	внутренняя	5060358.6200	724.7237	доставлена	\N
2284	RU4983803436534576819154749347962	643	2023-09-24	RU5883803436571013870275428717873	внутренняя	438025.0517	413.6173	доставлена	\N
2285	RU9683803436597203099828784600586	156	2023-01-16	BY4311124701349827680615023	международная	5033498.3687	287.7552	отправлена	BKCHCNBJ
2286	RU3783803436562091905141244310726	978	2023-01-14	AL3728615059601040143013001	международная	2764080.6356	706.9443	отменена	DEUTDEFFXXX
2287	RU4983803436534576819154749347962	978	2023-08-09	DE7488832684053456466567196	международная	1437416.0112	858.6015	доставлена	RZBAATWW
2288	RU6983803436557684576294868357987	156	2023-08-08	BY8633606028489278529802044	международная	3307440.3658	482.4497	отправлена	BKCHCNBJ
2289	RU8583803436580493050529274956761	978	2023-08-16	RU5183803436523181844916432548416	внутренняя	6677234.9765	785.0792	отправлена	\N
2290	RU3583803436531844714480494060517	356	2023-07-04	VN6067833796542425413581694	международная	592097.5072	436.2220	отменена	SBININBBXXX
2291	RU3983803436562540544761068231244	978	2023-04-10	AL5886617806700576553296154	международная	3516939.4419	668.0234	доставлена	DEUTDEFFXXX
2292	RU2483803436559904294875702128517	156	2023-06-30	RU5983803436513359014201161572816	внутренняя	936565.1955	547.1472	доставлена	\N
2293	RU7483803436560908970835757520521	156	2023-09-18	AL5097376622981738280752591	международная	4268516.0545	144.9737	отправлена	BKCHCNBJ
2294	RU1283803436513390712190126736747	156	2023-02-27	RU5583803436544105301147510534206	внутренняя	8138804.4062	985.9320	доставлена	\N
2295	RU6983803436596433824452063468541	356	2023-04-13	RU3383803436530100232705488681423	внутренняя	9878490.5580	969.7725	доставлена	\N
2296	RU2283803436527235231809863175226	978	2023-07-11	RU1346736069497738520803848	внутренняя	3101274.1648	870.4868	отправлена	\N
2297	RU9083803436527710172880684864084	356	2023-11-23	RU7883803436577262824038798840088	внутренняя	814825.8801	152.3297	доставлена	\N
2298	RU4683803436521950147450839996450	643	2023-10-30	RU6683803436563942598707878107815	внутренняя	4779113.9358	516.4285	доставлена	\N
2299	RU3083803436572725983728902081378	356	2023-10-26	BY8432204122656456449225352	международная	4726356.8247	79.4924	отправлена	SBININBBXXX
2300	RU7483803436575212193030608824580	398	2023-07-31	VN8287916896332424963940469	международная	3646387.5009	772.0075	отправлена	CASPKZKAXXX
2301	RU1983803436574962372646294489745	643	2023-03-24	RU8783803436519169154241731281817	внутренняя	7771063.4257	454.3868	отменена	\N
2302	RU7483803436560908970835757520521	356	2023-04-20	AL7945187169886352960218405	международная	9392026.1933	149.1258	отправлена	SBININBBXXX
2303	RU4383803436586323329892508459044	398	2023-06-12	RU5883803436571013870275428717873	внутренняя	3104098.9614	664.2018	отправлена	\N
2304	RU6483803436575827628326698282321	978	2023-07-29	AL1393577473755919476959769	международная	5532252.4269	604.2714	отменена	DEUTDEFFXXX
2305	RU6483803436595566817980742907742	356	2023-03-19	RU8983803436519227550175732694863	внутренняя	7714752.1990	559.8323	доставлена	\N
2306	RU6883803436521704893234788177503	840	2023-05-15	ES2851156607950589759145434	международная	1874904.1603	985.6502	отправлена	CHASUS33
2307	RU2783803436529440294678710752920	978	2023-05-26	IN7532743127607267512877860	международная	4545596.1840	112.5543	доставлена	DEUTDEFFXXX
2308	RU7683803436565241249132549566386	840	2023-12-25	AD4576624075394577500660924	международная	9609340.9930	584.0124	отправлена	CHASUS33
2309	RU2083803436593214630941740939011	398	2023-04-15	RU9983803436545906901757432591750	внутренняя	5324360.1713	937.4760	отменена	\N
2310	RU4583803436546993711061481413708	156	2023-02-16	RU9483803436522220035875117822565	внутренняя	9716013.7317	96.6746	отправлена	\N
2311	RU3483803436537283842522563725379	978	2023-01-06	RU3961780401605578725026048	внутренняя	2597235.5319	802.0318	отправлена	\N
2312	RU4583803436576777630615652907536	156	2023-12-25	ES9311114823459598898555296	международная	5190488.5129	568.0276	отменена	BKCHCNBJ
2313	RU1983803436592911874717339237016	356	2023-08-16	ES8849794587427492406084069	международная	8466229.7500	359.0866	отменена	SBININBBXXX
2314	RU6983803436517488129268543865126	643	2023-11-28	RU3883803436531800763308499008852	внутренняя	8033968.5720	411.4188	отменена	\N
2315	RU3683803436521305656177527242839	356	2023-06-21	RU1683803436510344781123537250392	внутренняя	2792628.0771	767.8986	отправлена	\N
2316	RU5783803436523742307313248220811	643	2023-01-27	RU4283803436583191860084907222827	внутренняя	9305057.4551	94.5062	отправлена	\N
2317	RU4883803436583846522749125412438	840	2023-07-01	BY2584702325876726153358279	международная	4282192.1022	171.8689	доставлена	CHASUS33
2318	RU2783803436515955219320238454317	840	2023-06-21	AD7045560186629696363091720	международная	5902749.9647	779.8602	отправлена	IRVTUS3NXXX
2319	RU2383803436518501918755699207235	840	2023-09-19	RU7677953277970378784348884	внутренняя	3416519.0537	178.2912	отправлена	\N
2320	RU9883803436510697875492928159959	643	2023-01-22	AL4716590564389670400880578	внутренняя	1856468.9898	486.5670	доставлена	\N
2321	RU6883803436521704893234788177503	978	2023-07-29	AD9930066674045530574181771	международная	6173807.8066	955.4908	отменена	SOGEFRPP
2322	RU7183803436596080848426828093950	643	2023-10-07	KZ3458184733669448509142570	внутренняя	3627623.0112	272.9337	отправлена	\N
2323	RU8083803436588746463552823930061	643	2023-09-16	RU4283803436571605132393354830061	внутренняя	5477213.6099	760.8754	отменена	\N
2324	RU3883803436571430516571621799878	643	2023-06-16	RU2183803436551906716086082339754	внутренняя	9421319.1062	284.1377	отменена	\N
2325	RU1683803436549082108439124677076	156	2023-03-12	VN9266214368988722920691807	международная	8816276.2282	563.9232	отправлена	BKCHCNBJ
2326	RU7583803436593621382878998665048	643	2023-07-11	RU5783803436556321671762187197309	внутренняя	4494812.1095	51.7262	отменена	\N
2327	RU4183803436555804329090528802664	643	2023-03-07	BY1183325014969126708869547	внутренняя	1830583.4039	591.8269	отправлена	\N
2328	RU2283803436551819000625747494652	398	2023-12-19	RU3542448757841534611211946	внутренняя	771722.9421	53.8658	отправлена	\N
2329	RU3183803436559935083955185145410	643	2023-06-21	RU1183803436587920364130887563809	внутренняя	1508164.2594	452.8155	отправлена	\N
2330	RU8183803436584325139466333599286	978	2023-11-09	RU8183803436576908594301902139271	внутренняя	2516227.6071	436.6580	отправлена	\N
2331	RU5183803436588244188761426669013	643	2023-01-12	RU5083803436521160540176223483455	внутренняя	8397630.7852	35.9877	отправлена	\N
2332	RU5783803436598085342824416355658	398	2023-03-06	PT8297647709084394107674800	международная	1257407.8805	508.1752	отправлена	CASPKZKAXXX
2333	RU1983803436510712914540451632365	356	2023-05-27	RU3683803436521305656177527242839	внутренняя	897291.3841	198.2431	отменена	\N
2334	RU5083803436521160540176223483455	356	2023-01-12	RU8983803436519227550175732694863	внутренняя	3375422.8220	42.3275	отменена	\N
2335	RU9783803436566819882292917709885	398	2023-04-26	AD6652771273033323161388495	международная	8697711.0917	855.7717	отправлена	CASPKZKAXXX
2336	RU9683803436511276549947859990709	356	2023-12-21	RU4683803436518754352401343547893	внутренняя	4062143.5452	88.8118	отправлена	\N
2337	RU4383803436586323329892508459044	356	2023-07-26	RU5783803436598085342824416355658	внутренняя	3401882.8231	507.8503	отменена	\N
2338	RU3883803436559428008275215914286	840	2023-09-02	PT3066458334806319178659675	международная	1337104.9710	998.4700	отправлена	IRVTUS3NXXX
2339	RU8583803436586707949034749896750	840	2023-07-28	RU1552390032300892007563779	внутренняя	4597567.7752	792.0665	отправлена	\N
2340	RU3383803436548623436381587682007	398	2023-08-22	RU1790821976900277497789330	внутренняя	4949114.8633	865.4239	отправлена	\N
2341	RU8183803436566794763466227027850	356	2023-08-24	RU6183803436555838927651384339574	внутренняя	5958898.8844	633.5559	отменена	\N
2342	RU7183803436551143317683635788042	156	2023-04-12	ES6073983194616973537249884	международная	7665005.9458	392.2111	доставлена	BKCHCNBJ
2343	RU1583803436597114679330016317094	356	2023-12-20	RU6183803436573612137819734816326	внутренняя	4959362.1231	129.5302	отменена	\N
2344	RU4183803436593654490331448399606	398	2023-05-09	RU3683803436526413764026311806751	внутренняя	3991585.0064	795.0030	доставлена	\N
2345	RU5983803436533405804846460378377	643	2023-12-18	RU2283803436594102552659582448178	внутренняя	9113664.9594	974.3745	доставлена	\N
2346	RU5883803436549838724600410631189	356	2023-05-09	RU8483803436552375991404578719285	внутренняя	929082.8192	546.3372	отправлена	\N
2347	RU7483803436591068390387769478580	840	2023-09-02	RU3683803436589669964829443545971	внутренняя	1093825.8076	608.7324	отменена	\N
2348	RU6983803436580831999013679742086	356	2023-03-14	ES8867229585175223035414228	международная	765188.6831	343.8014	отменена	SBININBBXXX
2349	RU5883803436512174556620785995683	840	2023-11-27	RU1183803436569972795023903837949	внутренняя	6307015.5710	64.1556	отменена	\N
2350	RU6983803436582618731634671628237	156	2023-02-03	RU8883803436592173067148862634991	внутренняя	5724506.1516	617.3971	отправлена	\N
2351	RU6283803436577836700807681117407	156	2023-03-17	DE1133824449916918321690253	международная	5468971.8892	104.7789	доставлена	BKCHCNBJ
2352	RU4583803436546993711061481413708	156	2023-03-24	RU3999135532242263265988282	внутренняя	2738034.8962	761.1447	доставлена	\N
2353	RU8483803436586135450040789229889	398	2023-06-02	RU5683803436539120556194350818141	внутренняя	3938718.5212	462.2851	отменена	\N
2354	RU2583803436511360000518303822185	156	2023-08-04	RU9683803436524115739172828059349	внутренняя	6879387.7041	425.8688	доставлена	\N
2355	RU2883803436564862346362051659673	643	2023-03-04	AL6951225017711073530713578	внутренняя	8803223.6611	905.6453	доставлена	\N
2356	RU7583803436597888322431139189153	643	2023-09-17	DE2742864862567621177728189	внутренняя	2014093.3972	34.9763	доставлена	\N
2357	RU8583803436553386257766521949981	398	2023-01-08	RU5883803436576828712243252221562	внутренняя	700453.3398	90.8686	отправлена	\N
2358	RU7183803436551143317683635788042	978	2023-12-05	DE1495411994578926149093716	международная	3765844.8476	913.1739	доставлена	SOGEFRPP
2359	RU9383803436575688788160155647011	398	2023-07-31	DE8281109891914178616816579	международная	773171.1350	988.5842	доставлена	CASPKZKAXXX
2360	RU8783803436544746989208687599320	356	2023-02-07	KZ5362068344458518885270098	международная	6082025.6833	60.3963	доставлена	SBININBBXXX
2361	RU6383803436519000124215462920616	398	2023-01-28	RU9583803436574471411467135718624	внутренняя	3488814.3491	319.8707	отправлена	\N
2362	RU3783803436562091905141244310726	398	2023-12-17	AD3716945656046960814703751	международная	1602803.9300	291.2424	отменена	CASPKZKAXXX
2363	RU5683803436573106663960342062340	643	2023-09-14	RU9883803436597607312145326011401	внутренняя	6682293.6423	370.0696	отправлена	\N
2364	RU9283803436560888794155508079505	840	2023-11-18	RU8583803436567351126582917385267	внутренняя	7367341.9857	119.0907	отменена	\N
2365	RU9683803436526786707929300961979	398	2023-03-26	BY5782811072515663035575274	международная	1952407.2788	339.5965	доставлена	CASPKZKAXXX
2366	RU8983803436588264357315670765686	643	2023-11-13	RU6483803436599929208547720213297	внутренняя	2887449.7882	444.5093	доставлена	\N
2367	RU2483803436537933507280624045523	398	2023-10-10	RU2283803436551819000625747494652	внутренняя	3968184.5039	513.1375	отменена	\N
2368	RU5383803436532276110708298062956	643	2023-10-18	RU2183803436551906716086082339754	внутренняя	3645616.1181	211.4198	доставлена	\N
2369	RU9883803436580908913943520973504	356	2023-05-21	RU8083803436588746463552823930061	внутренняя	9440255.8244	327.0846	отменена	\N
2370	RU8383803436583878629872361871714	643	2023-10-18	IN5129763078294920146639078	внутренняя	4890528.0534	255.4462	отправлена	\N
2371	RU7383803436534050516387288663509	156	2023-02-13	RU1583803436513968949783488654583	внутренняя	609052.3810	694.9013	отменена	\N
2372	RU7783803436585076163513647706071	156	2023-11-13	RU5664839337772113830373616	внутренняя	7309878.8545	434.6765	доставлена	\N
2373	RU1183803436512373318427988836252	643	2023-03-15	IN2414108057037691275483468	внутренняя	7131441.8759	345.7646	доставлена	\N
2374	RU6883803436521704893234788177503	840	2023-09-29	RU4383803436594641659799774635872	внутренняя	8452266.6887	453.6488	доставлена	\N
2375	RU6183803436536163842184020816729	398	2023-07-27	RU1683803436583298094705869717304	внутренняя	6267162.6317	117.0320	отменена	\N
2376	RU4983803436548786021946522460624	643	2023-10-16	RU9583803436537234117226554935344	внутренняя	2143478.4503	274.3934	доставлена	\N
2377	RU6983803436518663051613263930888	398	2023-01-15	ES2971743273214323385920185	международная	7545329.1669	825.7866	отправлена	CASPKZKAXXX
2378	RU8383803436543267469021061769102	840	2023-06-09	RU5483803436549562102902686014927	внутренняя	5559787.3284	907.0365	доставлена	\N
2379	RU6483803436527000884469712767990	156	2023-01-21	RU3883803436564256045508064629374	внутренняя	5031088.0304	145.1722	доставлена	\N
2380	RU3083803436556733352794187735054	978	2023-06-15	IN9854693487922176937412063	международная	8422166.9042	751.0891	отправлена	DEUTDEFFXXX
2381	RU5983803436518386216122030936247	643	2023-08-24	RU8183803436576334203563049364101	внутренняя	9431675.0442	403.5099	доставлена	\N
2382	RU9083803436513364676730542126445	356	2023-12-06	RU5583803436556151120487866130687	внутренняя	2374437.1007	321.7272	доставлена	\N
2383	RU4583803436576777630615652907536	643	2023-12-11	RU1583803436522600904788279282430	внутренняя	7322584.4208	728.0151	доставлена	\N
2384	RU6583803436573484995572407857396	643	2023-10-19	VN7639374891659900538302782	внутренняя	5489074.0773	601.9550	отменена	\N
2385	RU6083803436557649065533492172245	356	2023-10-24	ES8020238754387773816401358	международная	106797.7126	32.4927	доставлена	SBININBBXXX
2386	RU4283803436512174946847064448344	398	2023-10-09	RU4883803436563163057705977553405	внутренняя	4962805.6412	692.9396	доставлена	\N
2387	RU2783803436515955219320238454317	356	2023-07-20	RU3883803436559428008275215914286	внутренняя	1099787.4666	26.0575	отменена	\N
2388	RU6483803436575827628326698282321	356	2023-12-02	AD3324264861138526455323285	международная	529371.3477	579.1674	отправлена	SBININBBXXX
2389	RU2283803436521727957364583057084	398	2023-03-16	RU3783803436562091905141244310726	внутренняя	6874186.1476	265.5621	отменена	\N
2390	RU1583803436578714315409224923820	840	2023-09-20	RU8413386265565629197008471	внутренняя	6371692.7835	221.1679	отправлена	\N
2391	RU4583803436546993711061481413708	356	2023-05-08	BY3956351855834681132864964	международная	1963883.2661	695.4096	доставлена	SBININBBXXX
2392	RU8183803436559528710172368223769	398	2023-10-01	PT8231215976005937093207161	международная	8572557.7989	199.9775	доставлена	CASPKZKAXXX
2393	RU1283803436545193525808988988532	356	2023-04-20	IN1723907948085309772201854	международная	6609160.7089	797.4796	доставлена	SBININBBXXX
2394	RU2783803436529440294678710752920	978	2023-04-29	RU3383803436551883036237842733910	внутренняя	2343878.0327	347.0463	отменена	\N
2395	RU2583803436586349630493889324094	643	2023-12-07	RU9683803436571883645805733128714	внутренняя	392074.6920	956.7927	доставлена	\N
2396	RU2083803436573246597416370413406	978	2023-10-04	IN8613694239832036742457227	международная	7001934.6649	277.2929	отменена	DEUTDEFFXXX
2397	RU1383803436546084241558471107471	356	2023-12-17	DE2458158973862312388674904	международная	7286631.0044	503.5268	доставлена	SBININBBXXX
2398	RU6783803436583735354795738130605	398	2023-02-08	RU5983803436533405804846460378377	внутренняя	4348865.8791	929.4890	отправлена	\N
2399	RU1683803436536773128968824249362	156	2023-01-08	RU1183803436541561390025398925839	внутренняя	666571.7852	323.6131	отправлена	\N
2400	RU3083803436556733352794187735054	156	2023-09-04	KZ4163055027874344429144847	международная	1293961.2865	911.8857	отправлена	BKCHCNBJ
2401	RU9283803436529032721317031749293	356	2023-01-14	RU3583803436597484588589933917343	внутренняя	1654863.2560	314.5016	отменена	\N
2402	RU3983803436554516084539411139147	398	2023-04-14	RU8883803436592173067148862634991	внутренняя	7189343.6067	707.6369	отменена	\N
2403	RU5683803436522754650880470438385	356	2023-08-02	AD6887002703813358349625182	международная	6512581.0711	371.9920	отправлена	SBININBBXXX
2404	RU8383803436583878629872361871714	398	2023-03-25	RU7583803436593621382878998665048	внутренняя	2841161.3417	745.0503	доставлена	\N
2405	RU3583803436556382446278007957702	156	2023-10-01	ES2165284623956601918815730	международная	3726407.5572	758.8597	отменена	BKCHCNBJ
2406	RU3383803436548623436381587682007	978	2023-10-23	RU1915920354253250896631937	внутренняя	1064226.8892	425.5377	отправлена	\N
2407	RU4283803436515276086545867508581	156	2023-02-06	KZ3418825052337213601233151	международная	8544661.4985	958.2881	отправлена	BKCHCNBJ
2408	RU4883803436577275200947611443039	356	2023-02-27	RU2783803436580745382811010865973	внутренняя	4559969.7675	982.7811	отправлена	\N
2409	RU5983803436518386216122030936247	643	2023-07-16	AL8059655437163929030303410	внутренняя	9083319.7117	555.3874	отменена	\N
2410	RU9583803436574471411467135718624	398	2023-06-26	BY6572330271537643415551224	международная	7058039.7580	134.2561	доставлена	CASPKZKAXXX
2411	RU6783803436583735354795738130605	156	2023-05-04	RU6783803436534011789886956964173	внутренняя	4143094.7744	619.0046	отправлена	\N
2412	RU8583803436567351126582917385267	840	2023-11-21	RU4583803436571583967013936520660	внутренняя	1444556.6428	484.2237	доставлена	\N
2413	RU2683803436575198696607383546599	156	2023-01-29	RU8583803436553386257766521949981	внутренняя	5789811.9984	417.0043	доставлена	\N
2414	RU8083803436588746463552823930061	643	2023-06-18	RU5483803436549562102902686014927	внутренняя	9464679.0556	909.0335	отменена	\N
2415	RU9483803436516702191580023603147	356	2023-04-08	RU3383803436540416635821116917223	внутренняя	3270203.4539	866.5051	доставлена	\N
2416	RU2083803436593214630941740939011	398	2023-03-29	AL3348117531553008349072556	международная	2451634.0546	750.4549	доставлена	CASPKZKAXXX
2417	RU1583803436592948110594062864167	156	2023-12-15	RU3083803436572725983728902081378	внутренняя	1786750.8224	640.6464	отправлена	\N
2418	RU9683803436531094862059243712475	643	2023-11-01	RU5583803436544105301147510534206	внутренняя	8200662.8892	725.3250	доставлена	\N
2419	RU8483803436514025076841381077297	978	2023-03-08	RU9383803436575688788160155647011	внутренняя	5989901.9995	156.0154	отменена	\N
2420	RU5183803436523181844916432548416	840	2023-08-30	BY4441238876520944918496996	международная	7371973.6098	10.6847	отправлена	CHASUS33
2421	RU4083803436530357399673623809331	643	2023-06-01	RU4583803436544769415444430855700	внутренняя	2155054.5589	478.5779	отправлена	\N
2422	RU5683803436539120556194350818141	356	2023-01-31	PT8886286164137979141637195	международная	4541886.6438	597.2424	доставлена	SBININBBXXX
2423	RU2183803436586747579379810386651	978	2023-12-14	IN6868767763090641673279255	международная	2194763.5634	929.9046	отменена	DEUTDEFFXXX
2424	RU9883803436580908913943520973504	978	2023-02-04	BY4723778355844405101862133	международная	3013714.8659	528.6387	отменена	DEUTDEFFXXX
2425	RU8483803436528403655778834568144	643	2023-09-08	RU6283803436561107985248905256058	внутренняя	3621563.2071	89.5986	отправлена	\N
2426	RU3583803436531844714480494060517	398	2023-04-14	VN1588118717105649335854782	международная	7497016.9303	905.0262	доставлена	CASPKZKAXXX
2427	RU9583803436562562119396535016715	398	2023-09-27	RU6783803436583735354795738130605	внутренняя	6962083.1157	77.2155	отменена	\N
2428	RU1883803436547883958852583813660	840	2023-04-20	RU5183803436585063037953141711870	внутренняя	5724719.1301	0.0000	доставлена	\N
2429	RU6583803436592149423686806465410	156	2023-04-15	RU5783803436568341660520010753753	внутренняя	7003382.4211	691.6676	отправлена	\N
2430	RU6783803436534011789886956964173	643	2023-06-13	IN7380894844468657068546989	внутренняя	9786843.0984	437.6528	отменена	\N
2431	RU7483803436595528340078834029783	643	2023-03-18	RU5783803436573951128453151787227	внутренняя	5949537.9683	158.5514	доставлена	\N
2432	RU9883803436596118671708861810646	156	2023-08-22	DE4172078507215858494701628	международная	1573114.4751	137.5648	отправлена	BKCHCNBJ
2433	RU3883803436515226766320509995235	356	2023-10-13	RU8796113841191768993644595	внутренняя	5513429.5481	731.3855	отменена	\N
2434	RU2683803436575198696607383546599	398	2023-12-12	RU5583803436544105301147510534206	внутренняя	2761425.4303	353.6882	отправлена	\N
2435	RU2683803436556115738690945420927	643	2023-05-27	VN8281500633876435657293284	внутренняя	674318.9515	387.1582	отправлена	\N
2436	RU2583803436511360000518303822185	356	2023-11-12	VN4156683823056730131951216	международная	7392045.2160	160.5273	отменена	SBININBBXXX
2437	RU9583803436547610609904791788853	978	2023-12-10	RU2083803436536025786076127901648	внутренняя	8285692.3772	89.9967	отменена	\N
2438	RU7883803436577262824038798840088	156	2023-04-10	RU8583803436580493050529274956761	внутренняя	2545420.8309	787.5651	доставлена	\N
2439	RU4083803436561171626967381260937	398	2023-02-13	RU6983803436550083462130199504453	внутренняя	9416200.9127	263.2800	отправлена	\N
2440	RU4283803436571605132393354830061	156	2023-11-07	AL1998438042132722062898175	международная	1528275.5448	43.5860	отменена	BKCHCNBJ
2441	RU8783803436544746989208687599320	978	2023-10-05	DE9968575635756958076860659	международная	7365317.5802	60.5506	отправлена	DEUTDEFFXXX
2442	RU4883803436510661666911089208306	356	2023-03-07	RU8983803436551003507571679577910	внутренняя	4034521.2941	83.8378	отменена	\N
2443	RU4583803436535138140020222748384	978	2023-02-23	VN5179192803447664146746326	международная	9436707.5967	839.3311	отменена	RZBAATWW
2444	RU9083803436542335742968981386823	643	2023-09-01	AD3849696894720311372224341	внутренняя	1762353.2846	360.3967	отменена	\N
2445	RU2683803436512319317744369021772	156	2023-01-22	BY1215974387212360213899070	международная	47694.7899	588.7167	отменена	BKCHCNBJ
2446	RU5183803436596697120047636808100	978	2023-06-13	RU8783803436519169154241731281817	внутренняя	788904.7413	331.0858	отправлена	\N
2447	RU7583803436597888322431139189153	643	2023-03-23	DE7852972659072680579938946	внутренняя	1204667.6930	536.7995	отменена	\N
2448	RU3883803436554504516286459147223	356	2023-07-16	AL4439254108743991298145352	международная	8759380.9773	0.0000	отменена	SBININBBXXX
2449	RU2283803436521727957364583057084	643	2023-07-31	ES3090534365238654359057814	внутренняя	2963322.1240	458.2979	отправлена	\N
2450	RU4983803436548786021946522460624	840	2023-10-25	DE4933310011576095996212587	международная	5271601.8695	87.7533	доставлена	CHASUS33
2451	RU7783803436536804517087406327796	643	2023-08-10	KZ5175225577272683381843809	внутренняя	1574869.8900	191.6267	отправлена	\N
2452	RU2683803436575198696607383546599	643	2023-09-13	RU8383803436543267469021061769102	внутренняя	9292167.6730	187.6869	отправлена	\N
2453	RU2783803436512588965300606208370	156	2023-09-14	KZ5832156074959801686933679	международная	1612642.0093	311.7043	доставлена	BKCHCNBJ
2454	RU1283803436521770311179326367954	398	2023-11-07	DE2638901814672245877576830	международная	5502558.0707	333.9058	доставлена	CASPKZKAXXX
2455	RU4783803436556925313909023616425	840	2023-09-12	RU8183803436513368239655842198331	внутренняя	8131020.0669	24.7771	доставлена	\N
2456	RU3583803436580986023375789999847	643	2023-08-04	RU8686794137724852494091780	внутренняя	5970631.0169	877.2203	отменена	\N
2457	RU2083803436593214630941740939011	398	2023-04-12	RU5983803436596779338391553657957	внутренняя	1599472.3701	195.3592	отменена	\N
2458	RU3783803436562091905141244310726	840	2022-12-31	DE8238524807251233264109592	международная	1876924.3990	771.4042	отменена	CHASUS33
2459	RU2283803436577856579987093576845	398	2023-07-19	RU6083803436583599210196850890015	внутренняя	214751.2882	285.3320	отправлена	\N
2460	RU9883803436580908913943520973504	840	2023-11-02	BY9532296331629064557423794	международная	8055711.5450	815.0711	отправлена	IRVTUS3NXXX
2461	RU4783803436556925313909023616425	643	2023-11-20	BY1821725824964375503391171	внутренняя	3610491.1529	877.7107	отменена	\N
2462	RU5083803436583492295875343805447	156	2023-10-10	RU6783803436510078136565817264354	внутренняя	4040519.2862	458.8793	отменена	\N
2463	RU8483803436546395435496825405512	840	2023-05-08	RU4183803436544525596730636267692	внутренняя	9449456.5208	457.2192	отправлена	\N
2464	RU9583803436537234117226554935344	398	2023-05-01	RU2783803436515955219320238454317	внутренняя	3648379.0428	959.5107	отменена	\N
2465	RU4883803436577275200947611443039	356	2023-03-22	RU3983803436562540544761068231244	внутренняя	8987817.0269	82.3961	доставлена	\N
2466	RU9783803436531316283778462589484	643	2023-07-03	RU9383803436563463129216774786629	внутренняя	3115459.7711	649.1351	отменена	\N
2467	RU2383803436518501918755699207235	978	2023-11-18	AD3654456923497424564476840	международная	3678439.2395	662.4886	отменена	RZBAATWW
2468	RU1583803436522600904788279282430	643	2023-05-11	RU9883803436596118671708861810646	внутренняя	4920344.2047	22.1622	отправлена	\N
2469	RU5583803436516539388298963058164	643	2023-04-01	RU1283803436591782126481419856685	внутренняя	6932873.5105	202.6959	доставлена	\N
2470	RU9583803436562562119396535016715	156	2023-11-23	RU2083803436517185898516741185299	внутренняя	4537212.4007	348.0772	доставлена	\N
2471	RU7483803436512314763652680872976	840	2023-04-03	ES1945196425744179632442589	международная	7004121.3666	31.7521	доставлена	IRVTUS3NXXX
2472	RU1483803436556765140449291811625	156	2023-05-25	VN6613343794017970002576489	международная	8285865.2878	308.7295	доставлена	BKCHCNBJ
2473	RU9683803436526786707929300961979	840	2023-10-30	RU8283803436558421168306139201398	внутренняя	7306190.2577	703.6004	отменена	\N
2474	RU6583803436552414284054924599360	398	2023-03-08	KZ7189135679445541586335320	международная	344897.6092	434.0725	доставлена	CASPKZKAXXX
2475	RU8983803436550652073660555482382	840	2023-08-11	IN2147729911446531601783343	международная	1078074.4354	113.5879	доставлена	IRVTUS3NXXX
2476	RU2583803436510413813910694958748	978	2023-06-20	RU3583803436543438797337964557116	внутренняя	1335477.0948	838.1767	доставлена	\N
2477	RU5783803436568341660520010753753	398	2023-08-03	RU9025747082774472900674839	внутренняя	1073003.0683	437.8410	доставлена	\N
2478	RU4683803436518754352401343547893	978	2023-04-06	PT7995158156237654681672116	международная	6037253.6380	51.8239	отправлена	SOGEFRPP
2479	RU4383803436583134155448910498762	840	2023-01-18	AL3334066764257042412115910	международная	6677562.1182	461.6430	отправлена	IRVTUS3NXXX
2480	RU2483803436559904294875702128517	978	2023-09-09	RU3383803436551883036237842733910	внутренняя	6106114.6900	859.9354	отправлена	\N
2481	RU1383803436598073263367823117200	978	2023-02-15	RU3083803436556733352794187735054	внутренняя	709901.3637	131.4545	отправлена	\N
2482	RU3983803436580604058878329162478	840	2023-05-31	RU8683803436520349379894661014091	внутренняя	2461665.0110	680.3647	доставлена	\N
2483	RU8483803436517523304653033637180	356	2023-11-05	RU6883803436524866655852609791727	внутренняя	8420869.7402	904.3502	отправлена	\N
2484	RU8983803436588264357315670765686	156	2023-08-27	RU7783803436536804517087406327796	внутренняя	4319023.0589	878.8032	отправлена	\N
2485	RU6183803436573612137819734816326	156	2023-02-16	PT1162729956259004929063759	международная	2796407.0625	799.8506	отменена	BKCHCNBJ
2486	RU1183803436569972795023903837949	840	2023-01-28	RU8983803436530366335955653516096	внутренняя	9037937.5823	346.4181	доставлена	\N
2487	RU8683803436558409197465918354522	398	2023-04-26	RU5083803436556786327042016836549	внутренняя	4737387.8278	117.9654	отправлена	\N
2488	RU1283803436597755454846611928328	643	2023-04-23	BY9286485686383985464472356	внутренняя	9072041.6232	322.9384	отменена	\N
2489	RU9583803436547610609904791788853	978	2022-12-29	RU4283803436544879224116585983050	внутренняя	1597011.2888	389.8596	отменена	\N
2490	RU6083803436582119843499506879640	156	2022-12-29	RU4383803436557380827011382643653	внутренняя	7081091.5592	250.9780	отменена	\N
2491	RU1283803436591782126481419856685	840	2023-03-29	RU4058709797986796548436689	внутренняя	106290.8948	838.9693	отправлена	\N
2492	RU6483803436599929208547720213297	356	2023-07-01	BY7034429172496615141756462	международная	64509.5384	502.4893	отменена	SBININBBXXX
2493	RU6983803436542868245387240901621	840	2023-09-19	DE7218573402485669634323355	международная	7672454.4200	311.8834	отправлена	CHASUS33
2494	RU3783803436585191546282680625888	356	2023-01-18	RU4183803436593654490331448399606	внутренняя	6205485.5560	411.8756	доставлена	\N
2495	RU3583803436531844714480494060517	356	2023-06-05	IN6869417554641605441290748	международная	8166516.4076	230.8630	отправлена	SBININBBXXX
2496	RU2583803436586349630493889324094	398	2023-01-24	DE5063733622066297190961053	международная	6790074.5027	720.1379	отменена	CASPKZKAXXX
2497	RU6183803436555838927651384339574	398	2023-04-07	RU1483803436552189189819570176682	внутренняя	75263.0911	698.7073	отправлена	\N
2498	RU9683803436571883645805733128714	840	2023-11-02	RU9883803436596118671708861810646	внутренняя	9345707.4414	611.8918	отправлена	\N
2499	RU5983803436596779338391553657957	156	2023-02-07	RU9683803436531094862059243712475	внутренняя	4567111.0383	794.6653	отменена	\N
2500	RU2983803436530272226005609138408	356	2023-08-03	RU3883803436554504516286459147223	внутренняя	8377326.3652	234.7104	доставлена	\N
2501	RU8983803436588264357315670765686	398	2023-05-13	IN4712634258435460476209228	международная	3310317.4060	687.2810	отменена	CASPKZKAXXX
2502	RU5283803436529894140873721164089	840	2023-08-15	AL2018173271822431117768580	международная	1048396.7684	569.4162	отменена	IRVTUS3NXXX
2503	RU3583803436531844714480494060517	398	2023-05-15	RU9683803436511276549947859990709	внутренняя	613804.8413	806.0115	отменена	\N
2504	RU6083803436582119843499506879640	978	2023-03-19	BY3292349212522794644273219	международная	1085382.4134	294.0417	отменена	SOGEFRPP
2505	RU6583803436588261503476787515721	356	2023-12-02	IN9913990876559145215231570	международная	1671690.0604	501.2403	отправлена	SBININBBXXX
2506	RU9383803436568402663247236595753	156	2023-12-08	RU5783803436568341660520010753753	внутренняя	9611497.1016	121.4205	отменена	\N
2507	RU7183803436584925378313266803439	156	2023-11-06	RU5583803436516539388298963058164	внутренняя	2987990.4887	295.9462	отправлена	\N
2508	RU9683803436559214297350823715344	643	2023-12-06	RU4383803436559640804885433764330	внутренняя	70821.2114	570.8747	отменена	\N
2509	RU5983803436596779338391553657957	978	2023-01-14	RU1383803436546084241558471107471	внутренняя	6845801.7843	584.2762	отменена	\N
2510	RU7283803436528848493351990702937	156	2023-04-17	VN4865446092148426252921627	международная	5731973.9421	697.1581	отправлена	BKCHCNBJ
2511	RU8583803436580493050529274956761	356	2023-06-23	ES1693111413847134645121878	международная	9681655.5449	244.3056	отправлена	SBININBBXXX
2512	RU9983803436545906901757432591750	978	2023-11-22	RU8783803436519169154241731281817	внутренняя	8961665.6965	828.5829	доставлена	\N
2513	RU7383803436534050516387288663509	840	2023-09-19	RU8183803436532187852215520403243	внутренняя	5593797.2853	728.7536	доставлена	\N
2514	RU8283803436536082355231514909614	643	2023-06-18	DE7894613904426073236082996	внутренняя	7657149.7738	747.0812	доставлена	\N
2516	RU7483803436591068390387769478580	840	2023-01-15	AL5438115554376963382578419	международная	1273134.8617	824.2761	отправлена	CHASUS33
2517	RU3683803436521305656177527242839	840	2023-06-06	KZ6199255923403430490725131	международная	2146530.1555	942.9617	отменена	CHASUS33
2518	RU3383803436527231938190662146888	978	2023-05-17	ES3863609393002809627106209	международная	1912725.5005	843.7964	доставлена	DEUTDEFFXXX
2519	RU8183803436576908594301902139271	156	2023-04-01	PT8916957981243478356861438	международная	1815546.2914	912.0728	отправлена	BKCHCNBJ
2520	RU7183803436578006903833632767386	978	2023-09-17	AD5844588591226373409012943	международная	8396287.2212	226.7176	отменена	SOGEFRPP
2521	RU3883803436571430516571621799878	978	2023-10-16	VN8582417771308225686171693	международная	9550421.2675	351.2420	доставлена	DEUTDEFFXXX
2522	RU1983803436558651220197686454204	398	2023-09-06	DE1289619837905049949793094	международная	2505910.4384	174.6930	отправлена	CASPKZKAXXX
2523	RU3283803436586063041663029658571	156	2023-03-19	RU2183803436538160023828199079683	внутренняя	3210987.7022	101.1263	отменена	\N
2524	RU9983803436563015974445739907644	356	2023-02-10	RU9583803436574471411467135718624	внутренняя	8977478.0293	335.3135	отменена	\N
2525	RU8583803436567351126582917385267	840	2023-12-04	RU8783803436562772820294479967682	внутренняя	5809460.3363	980.3075	отправлена	\N
2526	RU8583803436567351126582917385267	978	2023-11-03	RU8483803436546395435496825405512	внутренняя	5686383.4937	544.6001	отправлена	\N
2527	RU2783803436529440294678710752920	156	2023-11-19	AL6967964701248756811387957	международная	5796079.7145	965.0448	доставлена	BKCHCNBJ
2528	RU8183803436532187852215520403243	978	2023-09-11	RU3583803436597484588589933917343	внутренняя	3787587.4370	850.0860	отправлена	\N
2529	RU8183803436532187852215520403243	356	2023-03-31	RU4283803436532641085536208083176	внутренняя	4510600.7448	911.7406	отправлена	\N
2530	RU3683803436589669964829443545971	356	2023-12-20	RU7883803436577262824038798840088	внутренняя	3266267.3123	516.9478	отправлена	\N
2531	RU5883803436537252361294139722938	978	2023-07-30	RU6583803436547384322379422553840	внутренняя	7121943.0698	792.7542	отменена	\N
2532	RU8683803436531608639655465618756	156	2023-10-13	RU6083803436569163727288631654599	внутренняя	7820459.9039	119.3609	отменена	\N
2533	RU4883803436577275200947611443039	156	2023-08-01	RU5783803436553735504938098098542	внутренняя	2605546.1759	272.9348	доставлена	\N
2534	RU4883803436563163057705977553405	156	2023-12-22	RU1583803436578714315409224923820	внутренняя	4940936.2823	69.2362	отменена	\N
2535	RU9983803436545906901757432591750	978	2023-01-24	KZ5535374546018394815463045	международная	6853102.9018	459.7558	отправлена	RZBAATWW
2536	RU6383803436530975100435134167112	840	2023-11-28	IN6612767822924991151670774	международная	1605101.3963	716.9579	отменена	CHASUS33
2537	RU2983803436530272226005609138408	840	2023-01-25	RU4583803436576777630615652907536	внутренняя	3781552.0910	541.8720	отменена	\N
2538	RU3983803436580604058878329162478	398	2023-03-30	IN5370813249259937861041632	международная	8072931.6369	96.4858	отправлена	CASPKZKAXXX
2539	RU6583803436526807323529165700056	643	2023-10-16	ES1895504578228751362271560	внутренняя	5808584.8598	901.9767	доставлена	\N
2540	RU9683803436571883645805733128714	398	2023-10-02	RU6183803436556503720110500069421	внутренняя	365257.2248	266.9360	доставлена	\N
2541	RU1683803436549082108439124677076	643	2023-11-23	AL1877777073757540874100047	внутренняя	1889418.4267	112.5940	отменена	\N
2542	RU4483803436531766422461159975910	978	2023-09-24	RU2883803436564862346362051659673	внутренняя	3751070.9112	531.0297	отменена	\N
2543	RU1583803436533479152204865778047	356	2023-08-27	VN6843952247236222330882226	международная	552914.9845	330.9514	отправлена	SBININBBXXX
2544	RU4183803436512683300418013703414	156	2023-09-09	RU9383803436515318038329930627155	внутренняя	952576.6907	293.4163	доставлена	\N
2545	RU1883803436537462946976236392804	356	2023-03-12	PT4474305996569301865489408	международная	8837399.2032	995.3243	отменена	SBININBBXXX
2546	RU6483803436513432249664452306210	398	2023-07-21	RU1267824513204586282354178	внутренняя	1791839.5686	836.5347	отправлена	\N
2547	RU6383803436519000124215462920616	978	2023-04-12	PT7695273163991146842225747	международная	7832398.2706	24.1774	доставлена	RZBAATWW
2548	RU5183803436596697120047636808100	156	2023-10-07	PT2235359587980863817394832	международная	1175962.7222	776.4220	отправлена	BKCHCNBJ
2549	RU8483803436552375991404578719285	398	2023-12-24	DE4625909972203640723558716	международная	6780700.6951	78.4703	отправлена	CASPKZKAXXX
2550	RU8983803436513229118545499417330	643	2023-09-28	BY9545529729808780830460506	внутренняя	5372542.7219	0.0000	отменена	\N
2551	RU5783803436573951128453151787227	840	2023-06-09	RU5583803436555177704368963744222	внутренняя	9806660.5900	619.6608	отменена	\N
2552	RU9283803436529032721317031749293	356	2023-07-15	RU3883803436515226766320509995235	внутренняя	9759967.4121	582.0637	отменена	\N
2553	RU5683803436573106663960342062340	840	2023-05-22	RU6983803436580831999013679742086	внутренняя	1017509.1255	155.6604	доставлена	\N
2554	RU1383803436598073263367823117200	978	2023-01-15	IN2482643324849341524732165	международная	5054527.5667	491.4369	отменена	RZBAATWW
2555	RU6683803436575472065287991925682	840	2023-03-26	BY2518516303055914176655184	международная	4652728.1127	311.7552	доставлена	CHASUS33
2556	RU4683803436518754352401343547893	643	2023-05-15	RU2983803436588011593439328399453	внутренняя	1562259.4849	688.9648	отменена	\N
2557	RU2983803436597155052344917689453	356	2023-04-09	DE8693144548742249447880459	международная	4027106.2810	730.9358	доставлена	SBININBBXXX
2558	RU1083803436563162471160560931522	978	2023-12-27	AL2153707912757929219022519	международная	1248881.3129	461.8269	отменена	RZBAATWW
2559	RU3983803436583730529285495292571	643	2023-01-27	IN6350293942189038748246518	внутренняя	1030119.1828	287.4424	отменена	\N
2560	RU1683803436549082108439124677076	978	2023-04-26	IN6317359689027017581530684	международная	288296.3390	587.3555	отменена	DEUTDEFFXXX
2561	RU9383803436563463129216774786629	643	2023-03-24	RU7183803436578006903833632767386	внутренняя	8168352.1522	46.0965	доставлена	\N
2562	RU9283803436564588409350021574669	978	2023-01-09	RU2083803436571871160330810400191	внутренняя	9392407.2608	326.8745	отменена	\N
2563	RU9583803436562562119396535016715	156	2023-08-16	RU1083803436588429797000364388942	внутренняя	3366350.5760	987.8540	отменена	\N
2564	RU7283803436583841985241060182740	840	2023-11-01	AL6635244103241649770777695	международная	6335431.1700	312.8434	отменена	CHASUS33
2565	RU6983803436551969328605594993446	356	2023-07-15	AD2599932391244636504969962	международная	3165076.4159	769.7822	отменена	SBININBBXXX
2566	RU6183803436536163842184020816729	398	2023-01-26	RU5483803436551418630110242560620	внутренняя	1774175.2321	499.6816	отправлена	\N
2567	RU6483803436531317735484528392559	398	2023-10-02	IN9278075356223456298306050	международная	5991629.4320	208.8282	доставлена	CASPKZKAXXX
2568	RU7083803436569474567525801645267	643	2023-05-27	RU1383803436598073263367823117200	внутренняя	758943.7938	699.5577	доставлена	\N
2569	RU1683803436530784164352439032526	643	2023-09-10	AD2315912622410733709253450	внутренняя	4930226.2269	434.6388	доставлена	\N
2570	RU8783803436544746989208687599320	156	2023-08-30	AL4084764357295659849975372	международная	8933752.5833	934.7296	отправлена	BKCHCNBJ
2571	RU9583803436557636243711161422858	978	2023-05-23	RU2560866401101250220124736	внутренняя	4501400.3519	680.0848	доставлена	\N
2572	RU6583803436556215016292535847892	840	2023-09-21	RU6983803436557684576294868357987	внутренняя	9946473.3013	525.4277	отменена	\N
2573	RU7083803436569474567525801645267	840	2023-09-26	PT4157638926836625414596912	международная	6786423.1617	749.6759	доставлена	IRVTUS3NXXX
2574	RU6183803436571932790348770462135	156	2023-03-24	PT9761380376788565357124601	международная	5565245.0402	916.4152	отправлена	BKCHCNBJ
2575	RU6783803436527708547728704282997	643	2023-03-29	RU1083803436516100547774990634896	внутренняя	9650806.9438	407.7774	отправлена	\N
2576	RU1283803436545193525808988988532	156	2023-05-10	BY7187554903594966806438786	международная	8402953.5712	832.8439	отменена	BKCHCNBJ
2577	RU6883803436521704893234788177503	156	2023-06-15	AL8898179906270799675590220	международная	3068219.2596	949.2946	отправлена	BKCHCNBJ
2578	RU9283803436564588409350021574669	356	2023-01-04	BY8492194048533552203225826	международная	7339655.1634	951.0191	отправлена	SBININBBXXX
2579	RU2983803436585384738431881857607	156	2023-09-03	RU7283803436528848493351990702937	внутренняя	7562109.0152	27.1879	доставлена	\N
2580	RU7183803436596080848426828093950	398	2023-04-07	RU5683803436564237501745383797829	внутренняя	6240545.4444	962.9494	отправлена	\N
2581	RU5883803436544935035293164341064	156	2023-05-17	RU7283803436565335970635584506660	внутренняя	9493237.8999	628.2533	отправлена	\N
2582	RU8983803436545494349013660032430	398	2023-06-24	KZ2452181148472538836296652	международная	2389569.4120	165.8080	отправлена	CASPKZKAXXX
2583	RU7283803436582085910615477000049	398	2023-01-21	BY3529383865532952258419062	международная	75917.7999	651.9650	доставлена	CASPKZKAXXX
2584	RU3383803436533625475503259998648	840	2023-03-03	ES2151439001360477568613225	международная	3263100.9222	559.9068	доставлена	CHASUS33
2585	RU2183803436538160023828199079683	643	2023-06-03	RU3983803436562540544761068231244	внутренняя	8793454.3467	439.0906	доставлена	\N
2586	RU7083803436569474567525801645267	156	2023-03-11	RU8383803436543267469021061769102	внутренняя	2870670.7615	116.9224	доставлена	\N
2587	RU6383803436519000124215462920616	156	2023-06-16	PT8882631586003346057639147	международная	3621578.5960	270.6261	отправлена	BKCHCNBJ
2588	RU2983803436572636545308279163382	356	2023-03-04	RU7483803436575212193030608824580	внутренняя	4632308.0567	784.3446	доставлена	\N
2589	RU5483803436538988818998904026382	840	2023-01-25	RU9183803436594783043422280553530	внутренняя	8845861.1241	78.2453	отправлена	\N
2590	RU2483803436550335144467075253432	840	2023-12-07	DE8357314945317541218262482	международная	7773552.6857	525.6146	отменена	IRVTUS3NXXX
2591	RU2083803436518033160343253894367	978	2023-04-12	KZ4891261851813555824811080	международная	2762584.6661	281.3397	отменена	RZBAATWW
2592	RU5083803436556786327042016836549	398	2023-06-01	PT3745532392349725494019232	международная	4739331.3941	149.3315	доставлена	CASPKZKAXXX
2593	RU1283803436597755454846611928328	356	2023-01-20	PT2934154696092590672337502	международная	1149518.9122	895.1990	отправлена	SBININBBXXX
2594	RU6983803436542868245387240901621	356	2023-01-17	PT8164179904612268350070374	международная	9956477.2513	719.9811	отправлена	SBININBBXXX
2595	RU3983803436583730529285495292571	643	2023-05-19	VN3737428496592797012017151	внутренняя	9541291.2053	493.9854	отменена	\N
2596	RU5983803436558435772787343054218	398	2023-05-16	RU9430589778141241252671661	внутренняя	887873.5486	387.7343	доставлена	\N
2597	RU5783803436553735504938098098542	156	2023-05-15	RU1683803436530784164352439032526	внутренняя	418237.6867	165.5949	отправлена	\N
2598	RU7583803436545511345420608427589	156	2023-11-04	KZ4580814593266621816205625	международная	346596.4205	438.5658	отменена	BKCHCNBJ
2599	RU3983803436569376600246742084811	398	2023-04-25	RU7383803436515152831562897371432	внутренняя	6533406.8872	656.0708	доставлена	\N
2600	RU8483803436583598027317615125571	840	2023-02-21	RU2676572539982871753352522	внутренняя	3446354.4755	439.4143	доставлена	\N
2601	RU8883803436592173067148862634991	643	2023-11-07	RU9483803436570307762028951954874	внутренняя	1491476.8586	577.8650	доставлена	\N
2602	RU2583803436525056668985275863842	398	2023-05-19	DE1831488614682288695297062	международная	7680748.9503	274.1757	отменена	CASPKZKAXXX
2603	RU1383803436565139777755041333233	840	2023-03-27	IN6419442378509404470058104	международная	2319526.6954	392.6228	отменена	CHASUS33
2604	RU4583803436567844239839748091371	356	2023-11-21	VN4586696537236803648773731	международная	1513288.3231	869.8225	доставлена	SBININBBXXX
2605	RU4183803436512683300418013703414	398	2023-06-19	RU6214620583860088875058172	внутренняя	6027796.0731	969.9453	отменена	\N
2606	RU4583803436571583967013936520660	643	2023-12-25	IN6492012663621507080047660	внутренняя	3300241.7335	871.5432	отправлена	\N
2607	RU8483803436517523304653033637180	156	2023-04-30	DE7878753649828057002326471	международная	3300286.0505	128.3733	отправлена	BKCHCNBJ
2608	RU2583803436511360000518303822185	398	2023-07-29	KZ4986773312685437336872757	международная	4136741.5239	466.8872	отправлена	CASPKZKAXXX
2609	RU9783803436531316283778462589484	398	2023-09-11	RU4583803436567844239839748091371	внутренняя	5751607.8131	97.0106	отменена	\N
2610	RU5583803436516539388298963058164	978	2023-12-21	RU1283803436521770311179326367954	внутренняя	6540788.3456	853.5661	доставлена	\N
2611	RU6483803436599929208547720213297	978	2023-07-13	KZ6889434525663630364433252	международная	8689650.1455	272.2551	отменена	SOGEFRPP
2612	RU7283803436565335970635584506660	156	2023-04-24	IN5393008372028085467521057	международная	6638866.7693	129.3907	отправлена	BKCHCNBJ
2613	RU2983803436539974076802515756241	398	2023-07-02	VN9898453764699132312912068	международная	1680581.0782	305.1749	отменена	CASPKZKAXXX
2614	RU1983803436518034161993382946183	156	2023-05-10	RU2511970676624502210915037	внутренняя	9275060.9666	766.0443	доставлена	\N
2615	RU2983803436530272226005609138408	398	2023-09-30	RU9210157551109385910755162	внутренняя	2943707.3932	705.5808	отменена	\N
2616	RU8983803436530366335955653516096	356	2023-11-20	RU5683803436575772290627280121203	внутренняя	888151.7915	158.1176	отправлена	\N
2617	RU6183803436551232797419519235346	398	2023-01-10	DE9592269969653855316174332	международная	9923438.1026	153.1903	отменена	CASPKZKAXXX
2618	RU8983803436519227550175732694863	643	2023-04-20	VN2591298092364253171205322	внутренняя	6622112.8693	326.9392	доставлена	\N
2619	RU8983803436530366335955653516096	356	2023-12-24	KZ8859077538716931655490771	международная	1781406.5201	939.0781	доставлена	SBININBBXXX
2620	RU8183803436584325139466333599286	978	2023-10-22	RU8526341269986937028007348	внутренняя	9804670.8950	866.1810	доставлена	\N
2621	RU4583803436544769415444430855700	643	2023-08-28	RU6883803436521704893234788177503	внутренняя	9143359.5324	436.0075	отправлена	\N
2622	RU8183803436559528710172368223769	356	2023-08-26	RU4383803436583134155448910498762	внутренняя	8708682.3009	287.0421	отменена	\N
2623	RU2683803436556115738690945420927	643	2023-02-21	RU6983803436517488129268543865126	внутренняя	3097948.3378	338.6032	доставлена	\N
2624	RU9583803436574471411467135718624	840	2023-08-18	DE8193277062689267078247506	международная	9465841.7885	51.4011	отправлена	IRVTUS3NXXX
2625	RU4283803436544879224116585983050	156	2023-09-21	AD6553193615167000716614619	международная	4663998.0938	930.4094	отменена	BKCHCNBJ
2626	RU1383803436523658112524214881297	356	2023-05-04	RU1283803436545193525808988988532	внутренняя	348672.6950	930.7007	отменена	\N
2627	RU5983803436558435772787343054218	978	2023-07-09	RU2883803436538134433783624054557	внутренняя	2582254.1431	514.8359	отправлена	\N
2628	RU6083803436582119843499506879640	356	2023-01-25	RU7783803436556242953974983768067	внутренняя	6916574.4002	143.2670	отменена	\N
2629	RU4183803436544525596730636267692	643	2023-04-23	KZ8022517619950164901251066	внутренняя	3587363.1572	971.5479	доставлена	\N
2630	RU4583803436535138140020222748384	978	2023-09-25	RU4283803436532641085536208083176	внутренняя	8643637.9776	562.6767	отправлена	\N
2631	RU8683803436520349379894661014091	356	2023-11-03	PT5748911569903741408265693	международная	7610955.4504	0.0000	доставлена	SBININBBXXX
2632	RU8483803436597380246113206833117	356	2023-12-07	RU9683803436524115739172828059349	внутренняя	1836057.4178	423.9872	отправлена	\N
2633	RU3983803436583730529285495292571	356	2023-02-04	RU2388626924625414853765745	внутренняя	3227063.8094	387.4298	доставлена	\N
2634	RU4083803436530357399673623809331	978	2023-04-19	RU1983803436549890414007715363567	внутренняя	8499010.8901	57.8806	отменена	\N
2635	RU8483803436517523304653033637180	643	2023-09-14	AD3533131863347088312899900	внутренняя	3204861.0066	913.2560	доставлена	\N
2636	RU1683803436536773128968824249362	643	2023-11-02	VN2772744074486955264231998	внутренняя	8778655.1732	118.4456	доставлена	\N
2637	RU2283803436588289284937975921944	978	2023-11-06	RU4183803436544525596730636267692	внутренняя	5753149.2824	81.4328	отменена	\N
2638	RU9583803436562562119396535016715	398	2023-10-16	AL8458534745047532470486384	международная	4977303.0801	88.9743	отправлена	CASPKZKAXXX
2639	RU2483803436563361420871450061347	840	2023-12-14	ES8667440649006440071897546	международная	6780181.4395	115.2863	доставлена	CHASUS33
2640	RU2483803436563361420871450061347	978	2023-06-02	KZ1411886403369750485741838	международная	4680780.1961	777.8264	отменена	RZBAATWW
2641	RU4483803436531766422461159975910	398	2023-02-27	PT2710104972635222997268908	международная	815644.5615	796.3252	отменена	CASPKZKAXXX
2642	RU5183803436585063037953141711870	643	2023-02-23	RU6983803436551969328605594993446	внутренняя	5467883.6503	316.8176	отменена	\N
2643	RU4483803436593534887929979895004	643	2023-05-05	VN7976551794105823819041146	внутренняя	8101058.9257	596.1911	доставлена	\N
2644	RU5583803436581992686445972740236	156	2023-08-21	KZ8240900833912243822884718	международная	2152698.8818	990.2363	отправлена	BKCHCNBJ
2645	RU9683803436531094862059243712475	356	2023-09-14	RU7683803436565241249132549566386	внутренняя	6980171.5825	193.8144	доставлена	\N
2646	RU3483803436534657689181631833463	840	2023-07-19	AL3944695923907500723975660	международная	2264673.2719	714.4242	доставлена	CHASUS33
2647	RU9583803436589245078784775619456	643	2023-03-12	IN2082626009866572311261107	внутренняя	2927767.4922	689.0366	доставлена	\N
2648	RU3183803436556325220643083039724	356	2023-05-10	RU5883803436549838724600410631189	внутренняя	1002390.9376	629.5150	отправлена	\N
2649	RU9183803436523189940915642395180	356	2023-11-24	VN9033870755265511648642019	международная	6472981.9486	105.1158	отправлена	SBININBBXXX
2650	RU2183803436555308456329784386702	643	2023-01-09	AD6864569013131003709252184	внутренняя	917062.4836	614.6050	доставлена	\N
2651	RU3083803436572725983728902081378	840	2023-12-15	IN3243351271202480806273690	международная	6720914.3032	299.8695	отменена	CHASUS33
2652	RU5183803436588801456118987264753	156	2023-10-21	RU4083803436561171626967381260937	внутренняя	4801810.4521	867.5252	отменена	\N
2653	RU3683803436533022850683714599602	356	2023-09-28	BY8123366185640890654812010	международная	8986158.7944	856.3874	отменена	SBININBBXXX
2654	RU8083803436588746463552823930061	643	2023-10-18	RU9383803436587347167184231490115	внутренняя	1447657.0608	263.8468	отменена	\N
2655	RU1983803436568263609873115174417	643	2023-11-04	RU9483803436516702191580023603147	внутренняя	3645102.0826	738.8047	отправлена	\N
2656	RU9683803436541591047480784615833	978	2023-06-02	RU8183803436564595439284009293487	внутренняя	3266035.0821	325.5873	доставлена	\N
2657	RU3183803436556325220643083039724	840	2023-07-03	IN1740067237521654719714896	международная	4833593.7870	230.5596	отправлена	CHASUS33
2658	RU5783803436568341660520010753753	398	2023-12-20	RU7783803436585076163513647706071	внутренняя	9901725.2998	257.3702	отменена	\N
2659	RU1983803436549890414007715363567	356	2023-10-08	BY6817327397750078496053140	международная	5799230.2220	858.4039	отменена	SBININBBXXX
2660	RU2083803436517185898516741185299	643	2023-09-15	RU3183803436564747839620735247465	внутренняя	1599861.6642	47.7164	отправлена	\N
2661	RU5183803436588244188761426669013	356	2023-01-12	PT1866560561261138166102124	международная	987132.7502	342.6393	доставлена	SBININBBXXX
2662	RU9883803436559947701649293062119	398	2023-01-03	RU2483803436559904294875702128517	внутренняя	4273411.6468	443.0919	отправлена	\N
2663	RU3683803436589669964829443545971	978	2023-10-10	RU6683803436546559918630563560759	внутренняя	721712.9621	704.9747	отменена	\N
2664	RU9683803436524115739172828059349	840	2023-01-04	ES4943972009704024724328830	международная	5736104.4948	558.1115	отправлена	IRVTUS3NXXX
2665	RU8683803436558409197465918354522	356	2023-07-01	RU5083803436583492295875343805447	внутренняя	6284406.8089	626.7481	отправлена	\N
2666	RU7483803436591068390387769478580	398	2023-10-11	RU3583803436597484588589933917343	внутренняя	3676783.1572	964.4834	отправлена	\N
2667	RU3683803436529963181547651499120	840	2023-10-11	RU6083803436557649065533492172245	внутренняя	7802847.7041	405.6158	отменена	\N
2668	RU3683803436533022850683714599602	840	2023-02-27	RU7283803436582085910615477000049	внутренняя	5168217.1250	21.9421	отменена	\N
2669	RU1383803436585969091171133733533	156	2023-10-10	RU2883803436510195395163379960366	внутренняя	8035356.7615	899.0030	отменена	\N
2670	RU5983803436558435772787343054218	978	2023-04-26	IN8622982974613563976150136	международная	9058167.9051	860.5475	доставлена	SOGEFRPP
2671	RU2083803436593214630941740939011	156	2023-09-24	BY3323952071999101819514190	международная	9907109.1331	612.9414	доставлена	BKCHCNBJ
2672	RU5183803436585063037953141711870	356	2023-03-31	KZ3214041736307095140840061	международная	7709913.0001	0.0000	отменена	SBININBBXXX
2673	RU4883803436540069564759439339493	398	2023-03-23	KZ6051592058204081751905190	международная	5825723.2493	184.4832	отменена	CASPKZKAXXX
2674	RU1983803436510686315036595318873	156	2023-05-02	RU3883803436531800763308499008852	внутренняя	3854655.1329	750.3438	отправлена	\N
2675	RU1683803436530784164352439032526	643	2023-04-08	ES2072035683824233209207242	внутренняя	9471092.4336	417.9747	отменена	\N
2676	RU8483803436597380246113206833117	356	2023-12-02	ES2213822876202684265871131	международная	2080234.0548	97.1953	отправлена	SBININBBXXX
2677	RU9783803436586848496167067081204	398	2022-12-27	RU5583803436556151120487866130687	внутренняя	3951181.6413	585.3543	отменена	\N
2678	RU9983803436581801115411623274695	356	2023-01-09	RU2683803436566742853200336170327	внутренняя	9861799.7954	877.6624	отменена	\N
2679	RU7483803436516612664745741202549	840	2023-08-12	RU1283803436513390712190126736747	внутренняя	4525703.4037	513.5337	отменена	\N
2680	RU8983803436551003507571679577910	398	2023-09-24	VN6951255553562412774462754	международная	1611612.8573	394.7322	отменена	CASPKZKAXXX
2681	RU6883803436521704893234788177503	978	2023-11-07	RU8483803436583598027317615125571	внутренняя	4735443.3775	165.2499	отменена	\N
2682	RU4083803436519648806531502670697	840	2023-11-10	ES1618436856910148804271556	международная	4424517.7148	267.5261	отменена	CHASUS33
2683	RU9283803436529032721317031749293	356	2023-10-28	RU8028184251898325891755645	внутренняя	4422751.5888	319.8222	отправлена	\N
2684	RU3183803436556325220643083039724	643	2023-04-10	RU8583803436580493050529274956761	внутренняя	2549282.2335	52.1179	доставлена	\N
2685	RU3183803436559935083955185145410	156	2023-12-12	VN6157192217233912998856928	международная	9657330.4416	776.8543	доставлена	BKCHCNBJ
2686	RU7783803436536804517087406327796	643	2023-03-06	RU8583803436593152008036708778596	внутренняя	315150.9533	205.0458	доставлена	\N
2687	RU5883803436549838724600410631189	978	2023-07-21	RU7183803436513501317784267991188	внутренняя	8957506.3821	103.0525	отправлена	\N
2688	RU4583803436544769415444430855700	398	2023-02-25	RU8583803436593152008036708778596	внутренняя	3801714.3551	351.1391	отправлена	\N
2689	RU4483803436537144245226352938256	156	2023-10-31	RU6383803436519000124215462920616	внутренняя	3570294.1373	680.9925	доставлена	\N
2690	RU8983803436543970357311304848339	398	2023-01-11	RU2583803436511360000518303822185	внутренняя	1232053.3182	393.4840	отменена	\N
2691	RU7583803436545511345420608427589	356	2023-02-09	KZ8691816145650707394203825	международная	8340721.2899	992.2095	отправлена	SBININBBXXX
2692	RU8583803436580493050529274956761	840	2023-08-26	AL7383324652251254828715259	международная	7687904.4001	130.1052	доставлена	CHASUS33
2693	RU8483803436586135450040789229889	156	2023-09-24	RU4483803436531766422461159975910	внутренняя	7971848.3373	449.1434	отправлена	\N
2694	RU3783803436559423561964096195262	356	2023-05-24	RU2483803436563361420871450061347	внутренняя	294894.6904	800.7551	отменена	\N
2695	RU2983803436510489846489627969282	643	2023-03-12	VN8233254862595333449078191	внутренняя	2222963.2722	272.1783	доставлена	\N
2696	RU2283803436521727957364583057084	840	2023-07-12	RU8383803436554622159366581134752	внутренняя	3301993.6991	76.8152	отменена	\N
2697	RU2883803436564862346362051659673	840	2023-07-20	RU8483803436514025076841381077297	внутренняя	9910339.6577	136.6843	доставлена	\N
2698	RU8483803436576032684947735830335	356	2023-04-20	RU6656250374237583833547878	внутренняя	3723992.3383	714.7829	отправлена	\N
2699	RU6283803436541447099313442593938	978	2023-05-11	ES7780088436757410591858950	международная	8040120.6574	656.2538	отменена	RZBAATWW
2700	RU8383803436583878629872361871714	978	2023-11-11	DE9697883213592396699476916	международная	881725.4828	364.0402	отправлена	DEUTDEFFXXX
2701	RU4083803436530357399673623809331	156	2023-03-28	RU5783803436573951128453151787227	внутренняя	1375025.7262	308.5937	доставлена	\N
2702	RU9583803436547610609904791788853	156	2023-05-25	RU9283803436581282514241262822584	внутренняя	4542946.0744	972.1593	доставлена	\N
2703	RU8983803436543970357311304848339	643	2023-04-01	RU2983803436585384738431881857607	внутренняя	3000838.8110	934.5129	отменена	\N
2704	RU6183803436573612137819734816326	398	2023-04-07	RU9983803436563015974445739907644	внутренняя	1271214.7351	143.6868	отправлена	\N
2705	RU3283803436586063041663029658571	840	2023-10-29	IN3388874603159808438195686	международная	6348277.0632	469.6682	отменена	IRVTUS3NXXX
2706	RU5783803436523742307313248220811	840	2023-08-22	RU4083803436565489336932623834655	внутренняя	3927290.6411	416.2179	отменена	\N
2707	RU6583803436547384322379422553840	840	2023-06-30	IN8555765816366812208027296	международная	5392976.5620	642.4525	отправлена	CHASUS33
2708	RU8383803436543267469021061769102	398	2023-12-26	KZ7326516272938270232024782	международная	2995506.4175	139.2652	отменена	CASPKZKAXXX
2709	RU9483803436570307762028951954874	643	2023-06-12	RU6783803436534011789886956964173	внутренняя	958940.4855	380.0433	доставлена	\N
2710	RU8983803436545494349013660032430	398	2023-03-11	RU9483803436522220035875117822565	внутренняя	2033971.0696	231.4638	отменена	\N
2711	RU1883803436537462946976236392804	643	2023-07-18	RU2283803436594102552659582448178	внутренняя	7752819.0938	536.5336	доставлена	\N
2712	RU1383803436585969091171133733533	840	2023-01-05	RU5783803436567884889437805923129	внутренняя	8402934.2960	604.4878	отправлена	\N
2713	RU4083803436525661046500520760430	356	2023-12-01	RU1283803436597755454846611928328	внутренняя	4742186.2197	853.6672	отправлена	\N
2714	RU7083803436569474567525801645267	840	2023-02-13	RU6983803436557684576294868357987	внутренняя	5128699.9734	117.3041	отправлена	\N
2715	RU3383803436527231938190662146888	398	2023-01-18	AL2849241088117095347603169	международная	1474750.9958	785.9282	отправлена	CASPKZKAXXX
2716	RU2283803436555228451424548337941	840	2023-05-18	RU4283803436583191860084907222827	внутренняя	9109724.7896	963.8745	отменена	\N
2717	RU4283803436515276086545867508581	356	2023-09-20	RU5283803436570838144716210841495	внутренняя	6345056.2140	355.5275	отправлена	\N
2718	RU5183803436585063037953141711870	643	2023-08-07	AD8936793453632839184538206	внутренняя	8993567.6817	88.7928	доставлена	\N
2719	RU2283803436527235231809863175226	978	2023-11-14	AD9523309319446420957128821	международная	3882121.8186	38.8571	отправлена	DEUTDEFFXXX
2720	RU9583803436574471411467135718624	840	2023-01-04	BY3777767124947453674743246	международная	7981578.5835	601.9455	отправлена	CHASUS33
2721	RU8183803436532187852215520403243	356	2023-06-01	IN3868015629858258468523463	международная	4125615.4146	110.6611	отменена	SBININBBXXX
2722	RU1583803436578714315409224923820	840	2023-11-30	RU1683803436536773128968824249362	внутренняя	6570936.2877	571.3444	отправлена	\N
2723	RU4483803436593534887929979895004	978	2023-11-05	PT2056951315130734864407896	международная	4758906.9672	81.4445	доставлена	SOGEFRPP
2724	RU2783803436529440294678710752920	156	2023-03-14	AD9375542341229386960246902	международная	4205355.2480	431.7362	отправлена	BKCHCNBJ
2725	RU2183803436551906716086082339754	356	2023-07-10	AD5980506206698892497814464	международная	8436929.7278	994.4152	отменена	SBININBBXXX
2726	RU8883803436542351475891948314875	978	2023-05-02	RU3583803436543438797337964557116	внутренняя	9771748.3929	100.3890	доставлена	\N
2727	RU6083803436557649065533492172245	643	2023-02-23	RU6983803436518663051613263930888	внутренняя	9453355.3146	258.1804	отменена	\N
2728	RU9683803436541591047480784615833	978	2023-03-12	AD9923685537129532802591450	международная	4963359.2309	339.1865	доставлена	DEUTDEFFXXX
2729	RU7183803436535160662680026565691	643	2023-06-18	ES5673845687231352324611267	внутренняя	71054.2776	450.8629	доставлена	\N
2730	RU9083803436542335742968981386823	840	2023-04-28	IN4891455124550415270784628	международная	1326592.9122	314.3238	отправлена	IRVTUS3NXXX
2731	RU1683803436530784164352439032526	398	2023-09-06	RU2311297906528490476353991	внутренняя	7873901.3167	909.7907	доставлена	\N
2732	RU5783803436523742307313248220811	398	2023-04-23	BY4626035871177905693355834	международная	4358538.4943	281.4031	доставлена	CASPKZKAXXX
2733	RU1683803436583298094705869717304	398	2023-10-24	RU8518456581914349275576118	внутренняя	5823907.8924	196.6365	отправлена	\N
2734	RU6183803436571932790348770462135	156	2023-08-06	VN2238116463254244679977493	международная	2325501.4292	608.9014	отменена	BKCHCNBJ
2735	RU5083803436583492295875343805447	398	2023-01-22	DE1064687611934305808300312	международная	9487724.9614	460.5754	отменена	CASPKZKAXXX
2736	RU5783803436523742307313248220811	356	2023-08-08	BY9885972659181120271153132	международная	8152262.7672	958.4136	доставлена	SBININBBXXX
2737	RU1683803436510344781123537250392	643	2023-07-07	AL1786090386192320265627721	внутренняя	9584194.7056	860.0025	отменена	\N
2738	RU5783803436553735504938098098542	840	2023-11-30	AL3834461581128175342260718	международная	9554242.0822	965.7171	отменена	CHASUS33
2739	RU6783803436534011789886956964173	156	2023-07-24	RU3183803436556325220643083039724	внутренняя	278430.6159	912.8791	доставлена	\N
2740	RU8383803436583878629872361871714	356	2023-02-15	DE7414747313601005172656322	международная	1675003.7871	412.0635	доставлена	SBININBBXXX
2741	RU8583803436590890149305918634043	643	2023-01-15	RU5483803436538988818998904026382	внутренняя	5666174.4810	955.2523	отменена	\N
2742	RU6183803436571932790348770462135	398	2023-10-16	RU9683803436541591047480784615833	внутренняя	6910256.7654	378.2731	доставлена	\N
2743	RU8483803436546395435496825405512	978	2023-08-20	RU9070409638975813554134795	внутренняя	9833225.7473	289.8221	отменена	\N
2744	RU4283803436530972916151822377436	356	2023-08-21	RU7283803436528848493351990702937	внутренняя	2565273.6707	244.8105	отправлена	\N
2745	RU7783803436536804517087406327796	356	2023-07-31	RU6483803436513432249664452306210	внутренняя	9577178.8979	907.2490	отменена	\N
2746	RU1383803436598073263367823117200	840	2023-02-11	RU7683803436565241249132549566386	внутренняя	935231.7917	770.5491	доставлена	\N
2747	RU9483803436521022327823815694666	156	2023-05-20	RU8483803436576032684947735830335	внутренняя	9245296.5812	449.0900	доставлена	\N
2748	RU4583803436576777630615652907536	156	2023-10-20	RU6183803436573612137819734816326	внутренняя	2778724.3709	598.2791	доставлена	\N
2749	RU3283803436579852018195047883736	156	2023-06-14	RU2483803436550335144467075253432	внутренняя	2502006.0118	681.4576	отправлена	\N
2750	RU1983803436510686315036595318873	978	2023-06-30	RU5083803436556786327042016836549	внутренняя	7111497.3835	941.2378	отправлена	\N
2751	RU5183803436585063037953141711870	840	2023-07-13	AL4749075698906338703590352	международная	9900771.1701	506.4189	отправлена	IRVTUS3NXXX
2752	RU6983803436518663051613263930888	840	2023-09-19	ES3454277935508508612363306	международная	6451209.5665	627.5450	отправлена	IRVTUS3NXXX
2753	RU2783803436529440294678710752920	840	2023-09-28	RU5783803436553735504938098098542	внутренняя	5211681.6576	698.6537	отменена	\N
2754	RU2883803436564862346362051659673	398	2023-08-23	AD1852716399524887222185449	международная	8038503.4925	633.2361	отправлена	CASPKZKAXXX
2755	RU9883803436510697875492928159959	398	2023-08-23	RU2483803436580851808318436691458	внутренняя	6531848.1779	447.3504	отменена	\N
2756	RU4683803436518754352401343547893	840	2023-01-17	IN1764813469948205932922766	международная	5089162.9423	935.6901	отменена	CHASUS33
2757	RU4183803436512683300418013703414	398	2023-11-18	AL2824994845143440136941674	международная	370699.1464	985.2180	отправлена	CASPKZKAXXX
2758	RU9083803436548965374028188380728	156	2023-08-05	RU6283803436577836700807681117407	внутренняя	4825741.3804	173.5484	отменена	\N
2759	RU6683803436563942598707878107815	398	2023-04-20	AL5461172902182272243185027	международная	3540365.3997	418.5046	отменена	CASPKZKAXXX
2760	RU8483803436597380246113206833117	356	2023-01-25	RU1383803436523658112524214881297	внутренняя	2473384.7589	292.1343	отменена	\N
2761	RU7483803436544936047225386728318	840	2023-10-04	RU2683803436556115738690945420927	внутренняя	9278668.3767	236.4583	отправлена	\N
2762	RU3383803436527231938190662146888	643	2023-03-19	RU9785992875543996248461317	внутренняя	8285717.2319	551.8999	доставлена	\N
2763	RU4283803436512174946847064448344	398	2023-11-26	BY8945868463206022481702897	международная	2246132.9021	313.4295	отправлена	CASPKZKAXXX
2764	RU6983803436542868245387240901621	356	2023-12-21	DE6149451747318077314236739	международная	7029439.2001	279.7813	доставлена	SBININBBXXX
2765	RU2883803436510195395163379960366	643	2023-06-04	PT6738530809808829223089338	внутренняя	6790855.2430	499.2997	отправлена	\N
2766	RU2183803436551906716086082339754	356	2023-06-28	VN3289101646854515860250109	международная	2570430.5381	939.1877	отменена	SBININBBXXX
2767	RU5883803436576828712243252221562	356	2023-02-25	DE1652006785753869154961884	международная	5783873.6814	152.3490	доставлена	SBININBBXXX
2768	RU9583803436557636243711161422858	356	2023-06-18	RU6083803436569163727288631654599	внутренняя	2562517.7817	513.1742	отправлена	\N
2769	RU3083803436556733352794187735054	643	2023-06-24	RU6083803436569163727288631654599	внутренняя	2187284.5941	81.6136	отправлена	\N
2770	RU7083803436569474567525801645267	978	2023-05-09	PT8730725066365465019235778	международная	4142993.7204	355.2582	отменена	RZBAATWW
2771	RU1183803436536239647096212180861	840	2023-09-09	DE2632909072899726144052639	международная	1359407.6228	515.1236	отправлена	IRVTUS3NXXX
2772	RU8583803436580493050529274956761	643	2023-07-08	ES3249924496046639628163459	внутренняя	285200.7687	903.3411	доставлена	\N
2773	RU9683803436571883645805733128714	156	2023-05-07	RU3183803436522808312515599877028	внутренняя	9116072.6645	405.9606	отменена	\N
2774	RU7583803436593274051968042799324	643	2023-05-25	PT7913670939471550339761864	внутренняя	3087026.4290	535.9919	отправлена	\N
2775	RU6183803436555838927651384339574	156	2023-01-09	RU5583803436533254773648721597711	внутренняя	2566669.3971	477.9428	отправлена	\N
2776	RU7683803436578953117174553181317	643	2023-08-13	IN3385792903969608276537664	внутренняя	4810501.8794	782.2486	отменена	\N
2777	RU5683803436581377733469772235779	356	2023-11-14	RU6383803436519000124215462920616	внутренняя	2407835.8065	823.4683	отменена	\N
2778	RU5183803436523181844916432548416	978	2023-12-18	RU9983803436563015974445739907644	внутренняя	3902776.4751	937.1645	отправлена	\N
2779	RU2283803436521727957364583057084	398	2023-09-19	KZ2029639911596488749161780	международная	9290715.7226	994.6641	доставлена	CASPKZKAXXX
2780	RU7583803436593274051968042799324	398	2023-04-08	RU3683803436583826961336736431806	внутренняя	9823139.4153	732.1656	отправлена	\N
2781	RU4283803436583191860084907222827	978	2023-04-22	RU5983803436561671607015303339932	внутренняя	3724726.5950	475.5606	отменена	\N
2782	RU8983803436513229118545499417330	398	2023-07-08	BY8646390806854987284916062	международная	6516459.0366	270.3872	отправлена	CASPKZKAXXX
2783	RU5183803436599553165549416662045	643	2023-06-26	RU6383803436512605200896614597744	внутренняя	201972.5948	432.6164	отправлена	\N
2784	RU6783803436527708547728704282997	978	2023-08-13	DE7577904847832072546190431	международная	665876.7467	80.9295	отменена	SOGEFRPP
2785	RU4383803436557380827011382643653	356	2023-12-12	KZ7431875627522606378548450	международная	8785850.5100	710.6071	доставлена	SBININBBXXX
2786	RU5883803436512174556620785995683	840	2023-11-19	KZ6435626858758401903406961	международная	7294146.8393	723.4541	доставлена	CHASUS33
2787	RU6583803436599318340096840026283	643	2023-12-13	RU2783803436529440294678710752920	внутренняя	5316165.9525	663.0805	отправлена	\N
2788	RU6583803436556215016292535847892	643	2023-08-09	RU2983803436510489846489627969282	внутренняя	3985362.8417	283.8790	доставлена	\N
2789	RU6583803436546434088553514688778	840	2023-11-15	RU1297243808863231963743305	внутренняя	6610604.9206	111.0701	отменена	\N
2790	RU5683803436575772290627280121203	978	2023-01-27	PT3319906616861624007347087	международная	624281.8056	528.0379	отменена	SOGEFRPP
2791	RU4883803436561825246742556433732	398	2023-10-09	RU8483803436562780872181379760829	внутренняя	2743245.3649	814.1539	отменена	\N
2792	RU1683803436549082108439124677076	643	2023-10-06	VN8181851257188569895818939	внутренняя	5010579.6237	110.4051	отправлена	\N
2793	RU1983803436518034161993382946183	156	2023-05-04	RU2083803436518033160343253894367	внутренняя	285273.8903	645.8832	доставлена	\N
2794	RU7783803436536804517087406327796	840	2023-04-17	AD5921008925450448889487571	международная	2104209.5787	772.1209	отменена	CHASUS33
2795	RU9683803436524115739172828059349	643	2023-05-31	RU9483803436570307762028951954874	внутренняя	9041253.5921	487.0076	доставлена	\N
2796	RU9583803436562562119396535016715	356	2023-12-05	RU7183803436551143317683635788042	внутренняя	32667.9190	606.4830	отменена	\N
2797	RU5183803436523181844916432548416	156	2023-12-26	RU3683803436589669964829443545971	внутренняя	345602.4913	849.6932	доставлена	\N
2798	RU7783803436585076163513647706071	156	2023-05-18	ES6932858853510146583455389	международная	5885466.7966	504.2517	доставлена	BKCHCNBJ
2799	RU3883803436519845868206132784952	356	2023-02-17	RU1083803436588429797000364388942	внутренняя	9529300.2177	249.8720	отправлена	\N
2800	RU5483803436547543071206231343471	156	2023-07-11	VN1829085561131745808432313	международная	1621372.6195	209.7224	отправлена	BKCHCNBJ
2801	RU9583803436557636243711161422858	156	2023-12-15	RU9083803436542335742968981386823	внутренняя	6072795.6864	370.9752	отменена	\N
2802	RU9983803436515137760640096699879	356	2023-01-06	RU4083803436534430125114460530795	внутренняя	4732535.7873	474.6620	отменена	\N
2803	RU3783803436559423561964096195262	156	2023-08-16	RU5583803436556151120487866130687	внутренняя	2133457.8097	117.0502	доставлена	\N
2804	RU7383803436569356631218275502161	643	2023-07-13	RU9583803436537234117226554935344	внутренняя	7258177.5944	456.9367	отправлена	\N
2805	RU6983803436517488129268543865126	398	2023-12-05	RU7083803436565850801859363291526	внутренняя	4493391.9834	835.6046	отменена	\N
2806	RU8083803436588746463552823930061	156	2023-04-18	RU5983803436558435772787343054218	внутренняя	8025589.7668	717.2818	отменена	\N
2807	RU9483803436588743613330942629999	978	2023-05-26	ES1555038921639562229037046	международная	459667.9240	870.9895	доставлена	DEUTDEFFXXX
2808	RU2983803436510489846489627969282	840	2023-09-09	BY6981286434738190646946302	международная	4219589.5344	536.1342	доставлена	CHASUS33
2809	RU7483803436591068390387769478580	356	2023-10-01	RU9583803436562562119396535016715	внутренняя	7296995.8145	300.9721	отменена	\N
2810	RU2283803436527235231809863175226	156	2023-12-03	IN3741022529601299828290558	международная	930534.5070	504.5948	доставлена	BKCHCNBJ
2811	RU6583803436552414284054924599360	398	2023-12-01	KZ8276864052714682772542715	международная	7937334.2715	483.4396	отменена	CASPKZKAXXX
2812	RU2883803436564862346362051659673	840	2023-09-28	RU6883803436524866655852609791727	внутренняя	5556405.2641	59.2339	отправлена	\N
2813	RU9683803436559214297350823715344	643	2023-10-11	IN7968580897286314542327309	внутренняя	9813895.7476	189.6785	отменена	\N
2814	RU1183803436536239647096212180861	356	2023-04-20	PT3585863755846835185488592	международная	6551112.8243	932.9841	доставлена	SBININBBXXX
2815	RU5183803436588244188761426669013	643	2023-07-26	RU8483803436586135450040789229889	внутренняя	5362991.7273	730.1763	отменена	\N
2816	RU4383803436583134155448910498762	978	2023-12-04	BY6920908078787670244736693	международная	8271980.2278	698.4337	доставлена	RZBAATWW
2817	RU9383803436515318038329930627155	840	2023-12-26	RU2283803436594102552659582448178	внутренняя	6385743.6841	783.6341	отправлена	\N
2818	RU6683803436547011171926119923803	840	2023-02-23	RU2783803436598441945275189813351	внутренняя	1692470.6859	846.3925	отменена	\N
2819	RU4383803436586323329892508459044	156	2023-10-28	AL6989492718926963809193115	международная	451168.2449	936.6142	доставлена	BKCHCNBJ
2820	RU3883803436559428008275215914286	978	2023-08-22	RU6483803436595566817980742907742	внутренняя	5090171.0224	892.9598	доставлена	\N
2821	RU6783803436583735354795738130605	398	2023-05-17	RU8983803436545494349013660032430	внутренняя	9836184.2938	996.1381	отменена	\N
2822	RU5783803436567884889437805923129	643	2023-09-21	ES6546387745957389027656856	внутренняя	5991659.7796	833.7458	отправлена	\N
2823	RU7083803436575256167282941443393	398	2023-02-14	RU6583803436556215016292535847892	внутренняя	2855160.3814	753.6357	отправлена	\N
2824	RU2583803436586349630493889324094	398	2023-01-29	RU4383803436538414207445829899653	внутренняя	483792.8448	715.7522	отменена	\N
2825	RU3183803436583121152517184662518	156	2023-05-16	RU9183803436594783043422280553530	внутренняя	9899784.9793	406.5654	отменена	\N
2826	RU9983803436521153026985692784451	978	2023-03-29	AL6131500742823612473122741	международная	5913583.0797	791.8254	отправлена	DEUTDEFFXXX
2827	RU8183803436546948351691601253240	398	2023-06-18	RU1183803436513944372774322746458	внутренняя	7350747.5901	417.3035	доставлена	\N
2828	RU3783803436562091905141244310726	978	2023-03-06	RU3983803436562540544761068231244	внутренняя	8681396.4141	290.1413	доставлена	\N
2829	RU9383803436546841675173507423577	840	2023-09-22	AD3849245569523864037737120	международная	4723308.4808	899.2680	отправлена	CHASUS33
2830	RU4483803436574648344464338946055	643	2023-08-25	RU5483803436551418630110242560620	внутренняя	2742946.9325	766.2549	отправлена	\N
2831	RU9583803436515959194321808018014	356	2023-08-11	PT8210709329872533460255722	международная	9660250.8030	998.9660	доставлена	SBININBBXXX
2832	RU9683803436541591047480784615833	398	2023-09-30	RU4583803436571583967013936520660	внутренняя	6478351.1250	581.3005	доставлена	\N
2833	RU4583803436588661449801193641363	156	2023-04-30	RU4983803436522833268295991391237	внутренняя	3653333.2427	581.8257	отправлена	\N
2834	RU1983803436592911874717339237016	978	2023-05-11	RU9083803436527710172880684864084	внутренняя	3936613.9870	903.7186	отправлена	\N
2835	RU9583803436547610609904791788853	643	2023-09-29	IN3910079656036886657171260	внутренняя	9153899.8476	433.3076	отправлена	\N
2836	RU9783803436586848496167067081204	356	2023-07-19	RU2483803436537933507280624045523	внутренняя	3347809.1849	194.4423	отправлена	\N
2837	RU3183803436559935083955185145410	643	2023-12-01	ES2083444166029589271203670	внутренняя	7343460.0099	944.5834	доставлена	\N
2838	RU2683803436556115738690945420927	840	2023-03-06	IN5632334198532584141293798	международная	3610730.5167	574.6969	отправлена	CHASUS33
2839	RU5083803436563140090168469536649	356	2023-09-15	VN4343549106432683495398995	международная	5145833.4174	953.3275	отправлена	SBININBBXXX
2840	RU4883803436563163057705977553405	156	2023-03-01	ES9514869591065187559887572	международная	7457302.4165	287.7352	отменена	BKCHCNBJ
2841	RU7183803436596080848426828093950	156	2023-06-17	RU6883803436521704893234788177503	внутренняя	8173048.6957	217.1019	отменена	\N
2842	RU4283803436538514172142523078432	356	2023-08-24	DE1187814909215603071543756	международная	9317946.1768	758.1056	отменена	SBININBBXXX
2843	RU8383803436543267469021061769102	840	2023-02-02	RU4683803436521950147450839996450	внутренняя	5618924.3607	328.4453	отправлена	\N
2844	RU3683803436533022850683714599602	978	2023-03-07	RU5483803436547543071206231343471	внутренняя	7603305.5335	78.1064	отменена	\N
2845	RU6183803436555838927651384339574	156	2023-11-25	DE1110419072838498623653171	международная	3405390.6227	378.0857	отменена	BKCHCNBJ
2846	RU1083803436532178175395898264605	840	2023-07-13	ES9366293022349634047683573	международная	2955703.1838	856.1814	доставлена	CHASUS33
2847	RU6983803436582618731634671628237	840	2023-12-12	RU9271477752118450184715940	внутренняя	4680349.1114	21.7136	отправлена	\N
2848	RU4283803436530972916151822377436	156	2023-05-07	VN2332286285131562608940843	международная	5202748.8488	993.1030	отправлена	BKCHCNBJ
2849	RU2583803436586349630493889324094	643	2023-08-15	RU4383803436597428452957764955765	внутренняя	6555800.8782	555.2711	отправлена	\N
2850	RU1983803436592911874717339237016	978	2023-03-28	AD9936635897891266028691375	международная	5418569.1022	134.4636	доставлена	RZBAATWW
2851	RU2883803436510195395163379960366	978	2023-09-03	RU1283803436591782126481419856685	внутренняя	4487673.6528	385.2461	отменена	\N
2852	RU7083803436575256167282941443393	643	2023-08-04	RU4083803436565489336932623834655	внутренняя	9564501.1840	976.9356	доставлена	\N
2853	RU7783803436578403910419087666263	643	2023-12-03	RU8483803436562780872181379760829	внутренняя	8899996.8645	716.1981	доставлена	\N
2854	RU1983803436518034161993382946183	156	2023-06-24	PT2263693554282382272645057	международная	5843656.8941	209.1741	отправлена	BKCHCNBJ
2855	RU3483803436534657689181631833463	398	2023-01-29	DE5470929061714008163095064	международная	9253564.3006	524.5444	отменена	CASPKZKAXXX
2856	RU8683803436571821829992754282142	356	2023-03-27	RU9683803436520170153501466272589	внутренняя	9939788.8449	666.3005	отменена	\N
2857	RU4883803436540069564759439339493	643	2023-05-27	ES7616031393273924092082596	внутренняя	411685.8713	717.2137	отменена	\N
2858	RU1183803436536239647096212180861	978	2023-04-13	RU4883803436561825246742556433732	внутренняя	3458601.1255	805.8458	доставлена	\N
2859	RU9383803436515318038329930627155	978	2023-09-10	AL8596785085665609023042337	международная	6498487.0555	508.1987	доставлена	RZBAATWW
2860	RU6083803436583599210196850890015	978	2023-08-17	RU6483803436575827628326698282321	внутренняя	5179840.5052	522.4425	доставлена	\N
2861	RU7183803436551143317683635788042	156	2023-05-12	DE8167163814022601585309300	международная	8707585.6876	367.3010	отправлена	BKCHCNBJ
2862	RU1383803436546084241558471107471	356	2023-03-20	VN2879434202918626153378882	международная	3897615.5587	893.4546	доставлена	SBININBBXXX
2863	RU7583803436597888322431139189153	978	2023-11-09	RU3983803436569376600246742084811	внутренняя	4462376.1664	539.2724	отменена	\N
2864	RU3883803436515226766320509995235	398	2023-06-19	AD4311028738773244130617103	международная	9426382.0884	54.0817	отменена	CASPKZKAXXX
2865	RU9083803436542335742968981386823	840	2023-05-17	IN5451570964463768450095263	международная	8107934.8463	418.3558	отменена	IRVTUS3NXXX
2866	RU7383803436585863943754594310819	840	2023-10-18	RU3883803436559428008275215914286	внутренняя	2875708.6091	248.4210	доставлена	\N
2867	RU6383803436517724803474176712817	840	2023-10-16	AL8981842536783759894933758	международная	996403.5961	988.3262	доставлена	IRVTUS3NXXX
2868	RU7583803436593621382878998665048	643	2023-08-28	ES7575072349031958906595431	внутренняя	5866958.4503	170.4753	отменена	\N
2869	RU2983803436545911307181108696312	356	2023-04-30	KZ4511962406642237566537179	международная	2201812.5030	348.0195	отменена	SBININBBXXX
2870	RU8583803436590890149305918634043	156	2023-08-30	RU6383803436519000124215462920616	внутренняя	4578367.0037	239.0782	отправлена	\N
2871	RU7183803436596080848426828093950	156	2023-10-22	AD5033125837894188047921409	международная	5831921.0723	793.1249	доставлена	BKCHCNBJ
2872	RU9183803436594783043422280553530	840	2023-02-16	RU4583803436546993711061481413708	внутренняя	2578011.5045	586.0513	отправлена	\N
2873	RU2583803436525056668985275863842	643	2023-12-23	RU5983803436558435772787343054218	внутренняя	7354229.1492	0.0000	отменена	\N
2874	RU9583803436557636243711161422858	398	2023-01-09	VN4441831434257133050764634	международная	5354681.2950	813.4181	отменена	CASPKZKAXXX
2875	RU9383803436515318038329930627155	840	2023-04-30	RU8483803436523751116997614384937	внутренняя	6966078.6666	911.1883	отменена	\N
2876	RU9383803436587347167184231490115	156	2023-05-09	AL1251016355055594839736341	международная	3134469.1045	872.8185	доставлена	BKCHCNBJ
2877	RU3483803436537283842522563725379	643	2023-10-03	RU8483803436517523304653033637180	внутренняя	1424669.2290	483.1004	доставлена	\N
2878	RU6783803436534011789886956964173	398	2023-06-02	RU9683803436511276549947859990709	внутренняя	2008926.7581	196.8880	отправлена	\N
2879	RU6983803436518663051613263930888	156	2023-08-13	AL3019981552040875030048148	международная	6569037.2409	109.9419	отправлена	BKCHCNBJ
2880	RU8183803436566794763466227027850	978	2023-11-11	RU9283803436560888794155508079505	внутренняя	8870783.6190	550.9362	отправлена	\N
2881	RU1683803436536773128968824249362	156	2023-07-01	RU1183803436587920364130887563809	внутренняя	1316819.3802	355.8911	отменена	\N
2882	RU5683803436522754650880470438385	356	2023-11-25	RU4683803436584135461455281070651	внутренняя	3846824.3563	463.2016	доставлена	\N
2883	RU8183803436546948351691601253240	978	2023-06-14	IN1962580245507632948558995	международная	6283933.8175	298.0794	отправлена	DEUTDEFFXXX
2884	RU7483803436560908970835757520521	978	2023-07-17	AL7540327436777175948494581	международная	2320970.8227	233.4570	доставлена	SOGEFRPP
2885	RU7483803436544936047225386728318	398	2023-07-17	RU2483803436563361420871450061347	внутренняя	3609588.3792	824.8558	отменена	\N
2886	RU3183803436559935083955185145410	156	2023-03-03	RU3383803436530100232705488681423	внутренняя	8343693.0476	989.4210	отменена	\N
2887	RU3383803436530100232705488681423	840	2023-03-21	DE8913311438925637635142763	международная	9965177.0030	644.3469	отправлена	CHASUS33
2888	RU6683803436546559918630563560759	978	2023-10-11	BY1386219248449452884172874	международная	7212960.7625	945.6104	отправлена	RZBAATWW
2889	RU5583803436544105301147510534206	978	2023-07-19	AD9592253561144903247631297	международная	5723954.1626	918.4558	отправлена	DEUTDEFFXXX
2890	RU4283803436515276086545867508581	156	2023-05-01	RU3065622749751771131272259	внутренняя	5336846.8338	149.4673	отменена	\N
2891	RU7583803436593274051968042799324	840	2023-11-28	RU4483803436531766422461159975910	внутренняя	5338395.5700	237.4558	отменена	\N
2892	RU2683803436556115738690945420927	156	2023-05-02	AL8952864712291275160150280	международная	8818245.3382	253.2794	доставлена	BKCHCNBJ
2893	RU4483803436537144245226352938256	978	2023-01-23	ES5158339738385687889489499	международная	8863122.1928	686.7015	доставлена	SOGEFRPP
2894	RU3383803436533625475503259998648	643	2023-11-04	RU2183803436538160023828199079683	внутренняя	6336959.1800	916.9654	отправлена	\N
2895	RU6483803436575827628326698282321	643	2023-08-24	DE6710316143495506839432147	внутренняя	3854822.7477	70.7357	отменена	\N
2896	RU4383803436535637847836978327691	643	2023-07-15	RU6583803436526807323529165700056	внутренняя	276854.1685	375.0430	доставлена	\N
2897	RU6583803436599318340096840026283	156	2023-06-05	AL4277333964355148799605235	международная	9107240.6756	718.6694	доставлена	BKCHCNBJ
2898	RU3483803436534657689181631833463	156	2023-10-09	RU1483803436555535016685486735994	внутренняя	1693527.3857	163.9359	отправлена	\N
2899	RU3383803436540416635821116917223	643	2023-12-18	PT2446679099481968673913726	внутренняя	8636831.8766	105.3821	отменена	\N
2900	RU8683803436557989786811096289958	156	2023-07-13	RU5883803436571013870275428717873	внутренняя	9232909.1109	714.5022	доставлена	\N
2901	RU3783803436562139250445157080524	978	2023-05-04	AD5953301929211879843483118	международная	858029.5403	503.6954	отправлена	DEUTDEFFXXX
2902	RU5783803436568341660520010753753	356	2023-01-24	IN4733651386718537465797049	международная	3631724.8316	0.0000	отправлена	SBININBBXXX
2903	RU6683803436575472065287991925682	978	2023-05-02	DE8851955745042483241007262	международная	6461713.6270	424.5174	отменена	RZBAATWW
2904	RU1883803436562141776165180370424	643	2023-03-28	RU8483803436597380246113206833117	внутренняя	1744438.1404	791.2447	отменена	\N
2905	RU2583803436586349630493889324094	978	2023-02-10	RU5583803436556151120487866130687	внутренняя	7574371.2399	499.8988	доставлена	\N
2906	RU5383803436537654175631942789109	978	2023-10-24	RU3483803436537283842522563725379	внутренняя	6929598.6244	731.6532	отменена	\N
2907	RU6483803436557881046066137062384	643	2023-05-15	RU2151966909761669676348297	внутренняя	8050875.1031	666.6822	доставлена	\N
2908	RU2083803436571871160330810400191	978	2023-07-13	DE6495764322386605957937759	международная	8240784.6262	28.8574	отменена	DEUTDEFFXXX
2909	RU6583803436546434088553514688778	356	2023-11-29	RU5183803436596697120047636808100	внутренняя	5172854.6934	263.0156	доставлена	\N
2910	RU8083803436567877444686336475183	840	2023-01-02	DE8534602864888762706649381	международная	4360740.1083	750.7642	отменена	CHASUS33
2911	RU3783803436562139250445157080524	156	2023-04-09	RU5790928557265533571095740	внутренняя	872650.6802	696.1652	отправлена	\N
2912	RU6183803436547326038705936576601	156	2023-09-22	RU9183803436523189940915642395180	внутренняя	8302831.5901	713.0633	отправлена	\N
2913	RU5383803436537654175631942789109	156	2023-08-03	KZ3540188732248044910623807	международная	7446474.5161	348.0281	доставлена	BKCHCNBJ
2914	RU1583803436522600904788279282430	978	2023-05-06	RU8483803436512925144599170278485	внутренняя	4896960.7726	740.4084	отправлена	\N
2915	RU2083803436571871160330810400191	643	2023-02-10	RU9083803436527710172880684864084	внутренняя	2508328.7101	806.2288	доставлена	\N
2916	RU9683803436579408636311341559980	978	2023-06-27	AL7577577411042964168943177	международная	2940275.4094	481.0100	доставлена	SOGEFRPP
2917	RU4483803436534969190676238532628	978	2023-02-16	BY8157927278498962619186189	международная	7206077.8900	787.3408	отменена	DEUTDEFFXXX
2918	RU9383803436575688788160155647011	398	2023-10-01	RU8083803436567877444686336475183	внутренняя	4312694.2156	465.2973	отправлена	\N
2919	RU1883803436537462946976236392804	978	2023-09-18	VN7485534574574224549137087	международная	9263719.6294	900.4504	отправлена	SOGEFRPP
2920	RU1683803436536773128968824249362	978	2023-05-17	VN5948937241756998623029346	международная	5395132.8932	23.5571	доставлена	RZBAATWW
2921	RU5983803436565674700991182664479	156	2023-07-05	RU4883803436540069564759439339493	внутренняя	5464644.3095	506.9354	доставлена	\N
2922	RU6383803436519000124215462920616	643	2023-02-08	RU2583803436511360000518303822185	внутренняя	2420956.2935	378.9898	отменена	\N
2923	RU6983803436582618731634671628237	398	2023-02-12	RU4283803436544879224116585983050	внутренняя	2540349.1464	574.2964	доставлена	\N
2924	RU7783803436585076163513647706071	156	2023-12-10	RU5183803436588244188761426669013	внутренняя	40298.2993	370.0820	доставлена	\N
2925	RU8483803436583598027317615125571	978	2023-10-09	RU9083803436542335742968981386823	внутренняя	1706914.0376	417.8523	доставлена	\N
2926	RU9583803436589245078784775619456	978	2023-04-22	KZ1643560669604972700056749	международная	6150541.1558	457.1574	отправлена	RZBAATWW
2927	RU6383803436519000124215462920616	398	2023-11-09	RU5983803436558435772787343054218	внутренняя	6652721.5380	192.4246	доставлена	\N
2928	RU1683803436530784164352439032526	156	2023-10-01	BY5966594267535029662624256	международная	7972114.8313	668.3143	доставлена	BKCHCNBJ
2929	RU7783803436556242953974983768067	643	2023-04-10	RU2783803436529440294678710752920	внутренняя	4039488.4626	311.6538	доставлена	\N
2930	RU5883803436537252361294139722938	156	2023-06-22	VN5866465895049841011412646	международная	74215.7854	129.6075	доставлена	BKCHCNBJ
2931	RU5283803436529894140873721164089	643	2023-01-18	KZ3532562222466395986191791	внутренняя	7867300.8286	250.5143	отправлена	\N
2932	RU2683803436512319317744369021772	356	2023-10-08	IN4866564491638163634293263	международная	6970924.6824	976.8544	отменена	SBININBBXXX
2933	RU4083803436537218400436107027314	156	2023-07-15	RU1083803436588429797000364388942	внутренняя	6582976.1368	251.2676	доставлена	\N
2934	RU8983803436518961229187913059129	643	2023-08-27	DE8195372784453329345690259	внутренняя	1225656.1518	332.5485	отправлена	\N
2935	RU8683803436520349379894661014091	840	2023-10-14	BY5236934905100739057608073	международная	361430.5290	815.7937	отменена	CHASUS33
2936	RU6383803436517724803474176712817	978	2023-07-05	RU6283803436541447099313442593938	внутренняя	2687122.0116	293.6900	отправлена	\N
2937	RU9883803436597607312145326011401	398	2023-08-30	RU5883803436537252361294139722938	внутренняя	4183081.6747	382.5454	доставлена	\N
2938	RU8183803436566794763466227027850	840	2023-09-12	ES4910800802361360867309158	международная	3349027.2987	849.4716	отправлена	IRVTUS3NXXX
2939	RU1983803436592911874717339237016	840	2023-07-17	ES8664283236118609484497641	международная	3549992.3961	57.2072	доставлена	CHASUS33
2940	RU8683803436557989786811096289958	398	2023-01-08	RU7833563037846421657469436	внутренняя	9510303.6121	238.2289	отменена	\N
2941	RU6483803436513432249664452306210	156	2023-05-30	IN8751837141916274093126655	международная	7105170.7160	603.4380	отправлена	BKCHCNBJ
2942	RU6183803436547326038705936576601	156	2023-12-21	ES6395198043591630688030931	международная	5273266.3035	367.1984	отменена	BKCHCNBJ
2943	RU1883803436547883958852583813660	356	2023-07-20	PT1452221426456061714722444	международная	508520.8381	82.5786	отменена	SBININBBXXX
2944	RU2583803436569716293278278112122	840	2023-02-19	RU2251585018598392607505663	внутренняя	1173955.7560	524.8845	доставлена	\N
2945	RU9983803436581801115411623274695	978	2023-02-22	DE3939679928174104063676576	международная	8129085.3426	975.5051	отменена	RZBAATWW
2946	RU4283803436512174946847064448344	978	2023-03-20	RU6583803436588261503476787515721	внутренняя	2703117.3257	641.3060	отправлена	\N
2947	RU8483803436546395435496825405512	840	2023-04-12	RU8483803436562780872181379760829	внутренняя	5918021.4900	725.9297	отменена	\N
2948	RU4083803436565489336932623834655	398	2023-06-11	PT3837924913564965820596766	международная	3835733.8755	615.0866	доставлена	CASPKZKAXXX
2949	RU1083803436588429797000364388942	978	2023-08-15	RU2083803436536025786076127901648	внутренняя	6300445.9489	859.4478	доставлена	\N
2950	RU1683803436536773128968824249362	840	2023-11-14	RU7483803436595528340078834029783	внутренняя	9373728.7588	0.0000	доставлена	\N
2951	RU8583803436548069379320039967893	398	2023-08-16	IN2819645449751296131143971	международная	1643548.9322	827.5607	доставлена	CASPKZKAXXX
2952	RU2783803436598441945275189813351	398	2023-01-20	DE7914595063320990470662912	международная	2697725.4959	233.7800	отправлена	CASPKZKAXXX
2953	RU8883803436592173067148862634991	840	2023-02-19	BY3223953443084277600648610	международная	9584834.5931	67.4043	отменена	CHASUS33
2954	RU3783803436562091905141244310726	156	2023-01-12	RU3424759853657484732476453	внутренняя	9429674.4373	737.7133	доставлена	\N
2955	RU7783803436585076163513647706071	643	2023-06-12	AD9828156312304548505033841	внутренняя	5808688.6651	368.1931	отправлена	\N
2956	RU4283803436583191860084907222827	840	2023-02-06	RU3183803436556325220643083039724	внутренняя	5306081.8918	426.2139	отправлена	\N
2957	RU4283803436512174946847064448344	156	2023-08-06	RU2983803436585384738431881857607	внутренняя	5616407.9084	645.0201	отправлена	\N
2958	RU6383803436512605200896614597744	840	2023-07-23	RU3883803436554504516286459147223	внутренняя	9281552.1385	526.9397	доставлена	\N
2959	RU2683803436532775565489898182986	840	2023-04-20	RU7783803436585076163513647706071	внутренняя	8903223.1320	735.4688	доставлена	\N
2960	RU6683803436547011171926119923803	978	2023-01-10	RU9983803436515137760640096699879	внутренняя	3289815.4409	250.4735	отменена	\N
2961	RU8183803436559528710172368223769	156	2023-01-05	VN2910396555463590055343017	международная	1764506.2709	546.6076	отправлена	BKCHCNBJ
2962	RU8183803436546948351691601253240	156	2023-02-28	RU8683803436571821829992754282142	внутренняя	5529321.7600	208.3857	отменена	\N
2963	RU8483803436552375991404578719285	356	2023-06-01	RU8583803436598717986670697262250	внутренняя	1009897.9058	201.3124	доставлена	\N
2964	RU2983803436572678251629055132350	356	2023-01-21	RU2183803436535230801413319305895	внутренняя	6779967.2114	631.6732	отменена	\N
2965	RU5783803436553735504938098098542	978	2023-05-30	RU5883803436537252361294139722938	внутренняя	164085.7359	850.8955	отправлена	\N
2966	RU9383803436546841675173507423577	643	2023-05-18	RU7183803436546875767014611813689	внутренняя	5385679.8112	963.8048	отменена	\N
2967	RU1983803436518034161993382946183	156	2023-07-05	DE1127281354660519485175154	международная	295893.4025	417.6751	отправлена	BKCHCNBJ
2968	RU2683803436566742853200336170327	156	2023-07-10	RU1083803436563162471160560931522	внутренняя	6205824.0030	25.2658	отправлена	\N
2969	RU7883803436577262824038798840088	840	2023-08-14	RU7583803436597888322431139189153	внутренняя	5121964.8076	517.5640	отменена	\N
2970	RU1283803436513390712190126736747	840	2023-04-13	RU1325254634031422033657526	внутренняя	7143820.8117	647.5017	доставлена	\N
2971	RU1283803436521770311179326367954	643	2023-07-13	RU1983803436518034161993382946183	внутренняя	523656.6531	150.2452	доставлена	\N
2972	RU8083803436567877444686336475183	156	2023-01-15	RU3883803436531800763308499008852	внутренняя	2263099.0882	595.0173	доставлена	\N
2973	RU1883803436537462946976236392804	156	2023-07-02	RU9883803436559947701649293062119	внутренняя	4777150.8069	101.9322	доставлена	\N
2974	RU8483803436562780872181379760829	356	2023-03-30	IN8077395291126010075044413	международная	1038049.6425	16.6056	отправлена	SBININBBXXX
2975	RU4483803436534969190676238532628	356	2023-09-29	RU2983803436588011593439328399453	внутренняя	9939129.0419	737.9955	отправлена	\N
2976	RU7183803436513501317784267991188	978	2023-12-12	RU8883803436592173067148862634991	внутренняя	6671123.9879	465.2573	отправлена	\N
2977	RU4083803436565489336932623834655	398	2023-04-12	AD4827497675319275671878273	международная	9645545.6286	638.1210	доставлена	CASPKZKAXXX
2978	RU3583803436543438797337964557116	356	2023-08-26	KZ6335218488888196840411998	международная	9952240.7002	358.3165	доставлена	SBININBBXXX
2979	RU4583803436546993711061481413708	978	2023-09-04	RU3383803436533625475503259998648	внутренняя	2585993.1975	113.5131	доставлена	\N
2980	RU8183803436584325139466333599286	643	2023-03-27	VN9533040682680961766647888	внутренняя	828969.0520	333.9394	отправлена	\N
2981	RU2083803436571871160330810400191	156	2023-10-12	RU6983803436550083462130199504453	внутренняя	1910597.4294	190.3552	отправлена	\N
2982	RU3583803436556382446278007957702	156	2023-06-11	RU6283803436541447099313442593938	внутренняя	9698705.5555	46.3887	отменена	\N
2983	RU1083803436532178175395898264605	156	2023-04-01	RU8583803436580493050529274956761	внутренняя	9125466.4273	196.7799	отправлена	\N
2984	RU3183803436556325220643083039724	156	2023-03-05	KZ7596493775357130227939857	международная	635258.1096	271.4062	отправлена	BKCHCNBJ
2985	RU2083803436518033160343253894367	356	2023-05-15	RU2283803436577856579987093576845	внутренняя	5481953.0914	156.6504	отправлена	\N
2986	RU3983803436583094600516227232333	398	2023-09-19	RU1683803436549082108439124677076	внутренняя	8138162.9905	418.5708	отменена	\N
2987	RU1883803436547883958852583813660	978	2023-07-07	RU1283803436597755454846611928328	внутренняя	8017405.3567	621.4574	отменена	\N
2988	RU4383803436597428452957764955765	978	2023-03-28	RU2183803436555308456329784386702	внутренняя	2328327.5188	335.4960	доставлена	\N
2989	RU1383803436546084241558471107471	398	2023-05-12	RU5083803436556786327042016836549	внутренняя	463177.0945	898.4091	отправлена	\N
2990	RU6883803436521704893234788177503	643	2023-04-07	RU8983803436551003507571679577910	внутренняя	8898976.5263	410.3788	доставлена	\N
2991	RU3383803436540416635821116917223	356	2023-03-12	RU8183803436555934243334630961587	внутренняя	6002076.4552	521.3698	доставлена	\N
2992	RU4883803436561825246742556433732	356	2023-06-10	RU9883803436510697875492928159959	внутренняя	1005161.2656	839.0386	отменена	\N
2993	RU9883803436580908913943520973504	398	2023-01-13	PT6430992183068022105309052	международная	4761266.4655	884.6413	доставлена	CASPKZKAXXX
2994	RU1683803436549082108439124677076	978	2023-02-20	RU1083803436516100547774990634896	внутренняя	3063842.4596	111.4061	отправлена	\N
2995	RU4083803436519648806531502670697	978	2023-01-23	RU5483803436551418630110242560620	внутренняя	288160.3190	602.5357	отправлена	\N
2996	RU1683803436530784164352439032526	643	2023-11-18	RU2883803436510195395163379960366	внутренняя	8379851.6777	220.8702	отправлена	\N
2997	RU6683803436547011171926119923803	643	2023-11-30	ES9927519327343575158257043	внутренняя	4685792.2123	267.8392	отправлена	\N
2998	RU4183803436544525596730636267692	643	2023-08-04	VN9358610491456194621899351	внутренняя	8258866.2717	70.0455	отменена	\N
2999	RU1083803436532178175395898264605	398	2023-10-26	RU1583803436533479152204865778047	внутренняя	1707983.9398	508.4774	доставлена	\N
3000	RU4383803436559640804885433764330	978	2023-07-29	AD5829306068640451886316696	международная	1885285.5806	224.3078	отправлена	DEUTDEFFXXX
3001	RU6683803436534213789698830771682	398	2023-02-02	RU1683803436583298094705869717304	внутренняя	5120951.5778	57.1434	отправлена	\N
3002	RU9083803436548965374028188380728	156	2023-09-08	RU7483803436581386287039618321410	внутренняя	669061.6923	313.7385	доставлена	\N
3003	RU5983803436513359014201161572816	398	2023-04-14	RU2083803436517185898516741185299	внутренняя	2153322.9819	511.2752	отменена	\N
3004	RU7183803436513501317784267991188	978	2023-04-27	AD7864285559157390168056089	международная	4059451.5447	678.9771	доставлена	DEUTDEFFXXX
3005	RU6683803436547011171926119923803	156	2023-05-30	AD6076592208139090222492802	международная	3073387.8521	631.1566	отправлена	BKCHCNBJ
3006	RU6983803436517488129268543865126	156	2023-06-05	RU8583803436567351126582917385267	внутренняя	3811871.2667	54.7149	отправлена	\N
3007	RU3883803436571430516571621799878	356	2023-10-24	BY2550649097422396257370355	международная	2432028.6031	385.8308	доставлена	SBININBBXXX
3008	RU3983803436562540544761068231244	356	2023-03-09	RU2483803436580851808318436691458	внутренняя	2338924.0872	934.7597	отправлена	\N
3009	RU7283803436528848493351990702937	978	2023-10-26	IN4076939495281750202574094	международная	9745994.3714	296.4758	доставлена	RZBAATWW
3010	RU9983803436521153026985692784451	840	2023-06-16	VN9074732838978027823499410	международная	4827416.3796	905.4195	отменена	IRVTUS3NXXX
3011	RU4583803436576777630615652907536	840	2023-09-29	IN9814097618193031243449071	международная	3927632.7222	530.4434	отправлена	CHASUS33
3012	RU8483803436552375991404578719285	840	2023-03-06	AD7415698476823700748908250	международная	566316.7860	386.1970	отменена	IRVTUS3NXXX
3013	RU8483803436523751116997614384937	156	2023-05-30	RU3434462649263858726871766	внутренняя	9997941.6070	43.1720	отменена	\N
3014	RU2083803436517185898516741185299	356	2023-06-20	RU8583803436529401978461350257287	внутренняя	6829512.4326	509.7955	отправлена	\N
3015	RU6383803436519000124215462920616	356	2023-06-27	ES1664708555308699613713519	международная	3615591.8961	536.9234	отменена	SBININBBXXX
3016	RU3983803436580604058878329162478	643	2023-04-25	RU4283803436532641085536208083176	внутренняя	4826159.9721	687.6960	доставлена	\N
3017	RU9483803436570307762028951954874	156	2023-01-21	RU6983803436582618731634671628237	внутренняя	9423802.0922	97.7213	отправлена	\N
3018	RU1683803436510344781123537250392	356	2023-09-04	RU4524239896078962916276728	внутренняя	2203022.2348	169.2083	отменена	\N
3019	RU2283803436594102552659582448178	643	2023-09-26	VN8796131221870784321490743	внутренняя	9043910.5045	708.5996	отменена	\N
3020	RU9283803436581282514241262822584	398	2023-06-28	RU2483803436550335144467075253432	внутренняя	8380599.5879	357.4431	отправлена	\N
3021	RU9683803436541591047480784615833	643	2023-10-23	BY7172878459500395725345308	внутренняя	5652501.6519	174.7046	доставлена	\N
3022	RU8383803436543267469021061769102	156	2023-08-09	BY3221510595951166165508885	международная	6121356.8998	397.3184	доставлена	BKCHCNBJ
3023	RU5983803436533405804846460378377	398	2023-05-06	AD7278598849120867183908789	международная	3273548.7558	350.3996	отменена	CASPKZKAXXX
3024	RU5183803436599553165549416662045	643	2023-06-19	RU8783803436562772820294479967682	внутренняя	8025728.7919	41.9337	отменена	\N
3025	RU3083803436548755847047281062638	643	2023-01-22	AD9456900249605596087088642	внутренняя	9379100.8442	611.8160	отправлена	\N
3026	RU1683803436583298094705869717304	840	2023-02-22	ES3599716434585449832046982	международная	824152.2231	259.8193	отменена	IRVTUS3NXXX
3027	RU5983803436565674700991182664479	156	2023-01-07	RU2783803436529440294678710752920	внутренняя	8407192.1122	742.6854	отправлена	\N
3028	RU9283803436529032721317031749293	643	2023-07-15	RU1683803436583298094705869717304	внутренняя	7976627.6541	12.3772	отменена	\N
3029	RU6483803436595566817980742907742	643	2023-12-13	RU8583803436529401978461350257287	внутренняя	4989959.2971	832.9268	отменена	\N
3030	RU2783803436580745382811010865973	156	2023-09-23	RU2683803436566742853200336170327	внутренняя	4307720.3410	464.0229	отправлена	\N
3031	RU8583803436529401978461350257287	156	2023-08-12	BY2719707373810618689714010	международная	4409374.5657	556.4945	отменена	BKCHCNBJ
3032	RU9183803436594783043422280553530	978	2023-11-20	RU5083803436521160540176223483455	внутренняя	3058898.6901	997.4002	отправлена	\N
3033	RU9183803436512467785925904841435	643	2023-07-16	RU7683803436589524723383129532286	внутренняя	7032959.8023	179.2755	отправлена	\N
3034	RU1583803436575905915250327615306	398	2023-04-17	RU3483803436534657689181631833463	внутренняя	2778437.1890	786.3401	отменена	\N
3035	RU6983803436521001508692071958064	156	2023-04-06	KZ1749568779856425194029630	международная	9962059.0112	667.4505	отправлена	BKCHCNBJ
3036	RU1283803436513390712190126736747	643	2023-04-12	RU6983803436518663051613263930888	внутренняя	7437680.2141	421.8100	отменена	\N
3037	RU2483803436559904294875702128517	978	2023-10-01	RU2983803436572636545308279163382	внутренняя	7589132.7725	53.9566	отправлена	\N
3038	RU6583803436592149423686806465410	978	2023-05-22	DE8952196751196831379379611	международная	3990492.2758	652.1997	отменена	DEUTDEFFXXX
3039	RU2883803436564862346362051659673	840	2023-03-18	AD3617800352861957111814952	международная	7970314.3515	373.9254	отправлена	CHASUS33
3040	RU9883803436559947701649293062119	356	2023-11-11	RU2883803436538134433783624054557	внутренняя	5559507.5317	798.5467	отменена	\N
3041	RU6983803436517488129268543865126	156	2023-02-03	PT4615107321303906572688483	международная	1727509.5951	335.6062	отправлена	BKCHCNBJ
3042	RU3183803436556325220643083039724	978	2023-07-29	RU2983803436539974076802515756241	внутренняя	1468918.7443	606.1099	отменена	\N
3043	RU7483803436575212193030608824580	643	2023-02-01	RU4383803436597428452957764955765	внутренняя	2732730.4759	683.1595	отправлена	\N
3044	RU9283803436581282514241262822584	398	2023-08-21	AD8370502272933345020076777	международная	379030.6861	938.6909	доставлена	CASPKZKAXXX
3045	RU1683803436583298094705869717304	356	2023-05-11	DE9778087539331870137582103	международная	3302334.5391	353.3026	отменена	SBININBBXXX
3046	RU6583803436565551879254347008316	398	2023-01-21	RU3883803436531800763308499008852	внутренняя	2690872.6911	702.3881	отправлена	\N
3047	RU9683803436511276549947859990709	356	2023-12-02	RU5983803436518386216122030936247	внутренняя	6880466.7858	476.9065	отправлена	\N
3048	RU3783803436585191546282680625888	356	2023-07-30	RU8983803436588264357315670765686	внутренняя	1448193.8685	591.8949	доставлена	\N
3049	RU1583803436578714315409224923820	156	2023-11-05	AL9929589083080080353586660	международная	2375988.8319	891.1927	отправлена	BKCHCNBJ
3050	RU8683803436558409197465918354522	356	2023-04-11	KZ8251666682713722828109273	международная	3961610.6882	611.7947	доставлена	SBININBBXXX
3051	RU1983803436592911874717339237016	356	2023-05-20	AL9464979189049982100406068	международная	7452697.0014	351.3651	доставлена	SBININBBXXX
3052	RU3683803436526413764026311806751	398	2023-09-11	AD7645193187157983717949161	международная	1339937.8718	316.2732	доставлена	CASPKZKAXXX
3053	RU1083803436563162471160560931522	356	2023-10-08	KZ3955912544879413617259604	международная	594126.1469	74.8599	отправлена	SBININBBXXX
3054	RU6083803436583599210196850890015	356	2023-01-28	RU9483803436570307762028951954874	внутренняя	8524873.3279	870.3629	отправлена	\N
3055	RU7183803436546875767014611813689	156	2023-01-29	RU7655497723768087480905710	внутренняя	3937980.6663	40.4493	доставлена	\N
3056	RU8583803436590890149305918634043	840	2023-01-02	KZ3713632014144948755960066	международная	3358465.0699	223.3243	отправлена	CHASUS33
3057	RU5783803436568341660520010753753	978	2023-10-25	DE5746564151773307066873339	международная	9294978.5541	102.3621	отменена	DEUTDEFFXXX
3058	RU8783803436522200736153030297680	840	2023-10-08	RU5983803436565674700991182664479	внутренняя	8115108.4638	413.4251	отправлена	\N
3059	RU2783803436529440294678710752920	356	2023-01-16	PT3292523685376449091472858	международная	9859158.9818	260.0485	отправлена	SBININBBXXX
3060	RU2583803436586349630493889324094	643	2023-06-11	RU3329863101941816322464399	внутренняя	6574206.1781	819.8086	доставлена	\N
3061	RU9883803436559947701649293062119	643	2023-01-23	RU6737113632974693234502468	внутренняя	6759047.6060	706.2439	доставлена	\N
3062	RU4083803436561171626967381260937	978	2023-08-15	DE8589682352051792836045793	международная	6718158.7422	40.5877	отправлена	SOGEFRPP
3063	RU6783803436534011789886956964173	356	2023-03-13	AD9285137928375659892474062	международная	2410846.3256	47.3007	отправлена	SBININBBXXX
3064	RU8983803436550652073660555482382	156	2023-05-13	RU1483803436552189189819570176682	внутренняя	6779063.6761	290.0293	доставлена	\N
3065	RU1683803436583298094705869717304	156	2023-09-23	RU2883803436538134433783624054557	внутренняя	9112897.8199	429.4156	отменена	\N
3066	RU3383803436540416635821116917223	156	2023-04-02	PT1223082093371584836525919	международная	1892935.3382	779.6983	отменена	BKCHCNBJ
3067	RU7483803436560908970835757520521	978	2023-02-14	ES2640701805085113430396354	международная	2067916.2262	15.8849	доставлена	SOGEFRPP
3068	RU1483803436556765140449291811625	398	2023-09-09	RU1883803436537462946976236392804	внутренняя	9249743.6982	505.6354	отправлена	\N
3069	RU6783803436534011789886956964173	978	2023-10-03	RU3483803436537283842522563725379	внутренняя	5590760.5711	189.5972	отправлена	\N
3070	RU3983803436554516084539411139147	840	2023-07-16	RU4324287085605306778947514	внутренняя	4321950.9622	522.5367	доставлена	\N
3071	RU7483803436544936047225386728318	978	2023-03-19	PT8018303249618829992970602	международная	3864461.1677	52.1860	отправлена	SOGEFRPP
3072	RU6583803436526807323529165700056	398	2023-05-16	RU8583803436553386257766521949981	внутренняя	8376371.7591	553.7315	отменена	\N
3073	RU1983803436592911874717339237016	356	2023-09-09	RU4483803436574648344464338946055	внутренняя	8218263.9612	96.9812	отправлена	\N
3074	RU2583803436569716293278278112122	643	2023-08-23	VN5195199923889251556002234	внутренняя	8005776.3495	454.9098	отменена	\N
3075	RU6583803436526807323529165700056	978	2023-12-16	RU6983803436582618731634671628237	внутренняя	5369480.8451	915.3006	доставлена	\N
3076	RU6583803436552414284054924599360	398	2023-07-29	VN1140043694465350658207196	международная	5397961.2630	573.2548	доставлена	CASPKZKAXXX
3077	RU4083803436523112590591409946049	356	2023-10-27	RU9083803436548965374028188380728	внутренняя	748840.0083	243.4750	отменена	\N
3078	RU5883803436549838724600410631189	643	2023-04-06	DE5892096046061532858444647	внутренняя	7228168.2296	420.7318	доставлена	\N
3079	RU3183803436545750333950215053352	356	2023-07-02	AD1271146959639635744286206	международная	6566815.7822	605.7070	отменена	SBININBBXXX
3080	RU4483803436593534887929979895004	398	2023-03-21	AD9156209234702226492843814	международная	2725998.9601	620.5901	доставлена	CASPKZKAXXX
3081	RU9683803436541591047480784615833	356	2023-04-06	IN9555779296428964954061420	международная	7936249.7225	154.1102	отменена	SBININBBXXX
3082	RU4983803436548786021946522460624	840	2023-03-02	RU6183803436551232797419519235346	внутренняя	4084547.0330	980.7263	доставлена	\N
3083	RU4283803436538514172142523078432	356	2023-03-23	RU1883803436562141776165180370424	внутренняя	2417254.2046	408.9787	доставлена	\N
3084	RU4183803436544525596730636267692	156	2023-06-14	RU6183803436551232797419519235346	внутренняя	7713895.5770	103.4436	отправлена	\N
3085	RU4083803436565489336932623834655	398	2023-01-11	RU3883803436571430516571621799878	внутренняя	816952.3482	99.0114	доставлена	\N
3086	RU8983803436588264357315670765686	398	2023-07-29	BY1435339659045420617677819	международная	7169806.9492	403.9099	отправлена	CASPKZKAXXX
3087	RU2583803436569716293278278112122	398	2023-10-13	AL6647264552044174680142096	международная	5757686.5577	791.0902	доставлена	CASPKZKAXXX
3088	RU5083803436521160540176223483455	398	2023-06-23	AD4429997922142746120738004	международная	9456359.9998	263.9958	доставлена	CASPKZKAXXX
3089	RU8183803436584325139466333599286	398	2023-01-29	DE4817777444253652087208101	международная	2341053.6857	570.3899	доставлена	CASPKZKAXXX
3090	RU1683803436543683792461716245841	840	2023-08-05	RU1284875049240577315556516	внутренняя	4543829.9874	341.5981	доставлена	\N
3091	RU4283803436583191860084907222827	643	2023-07-10	KZ7368697039793658855935372	внутренняя	2420496.5399	11.2033	отправлена	\N
3092	RU3883803436564256045508064629374	643	2023-09-03	PT2139281415390229562610982	внутренняя	9885755.9041	84.3484	отправлена	\N
3093	RU1183803436541561390025398925839	978	2023-07-06	RU5083803436583492295875343805447	внутренняя	5937832.5691	975.2179	доставлена	\N
3094	RU7483803436575212193030608824580	840	2023-09-09	RU8583803436586707949034749896750	внутренняя	1767194.4518	43.0728	отменена	\N
3095	RU1383803436596151895061926683764	398	2023-11-26	VN1598628478015954797393495	международная	3004018.1942	393.6643	отменена	CASPKZKAXXX
3096	RU1983803436537997284898110055528	978	2023-04-06	IN6953472441528767713177458	международная	7532382.6098	493.5907	отправлена	SOGEFRPP
3097	RU6883803436521704893234788177503	643	2023-06-24	RU3883803436515226766320509995235	внутренняя	4117399.3509	406.2839	доставлена	\N
3098	RU8183803436555934243334630961587	156	2023-07-03	RU1983803436558651220197686454204	внутренняя	7228330.7258	603.4508	отменена	\N
3099	RU9683803436559214297350823715344	840	2023-08-25	AL5166474943236242391435665	международная	1581636.6846	312.6398	отменена	CHASUS33
3100	RU4283803436544879224116585983050	840	2023-01-07	PT4069996306594555477908682	международная	1391477.5840	263.7726	отменена	IRVTUS3NXXX
3101	RU3983803436562540544761068231244	643	2023-03-06	BY5016734725467685624751827	внутренняя	989141.7348	420.6603	доставлена	\N
3102	RU8483803436586135450040789229889	156	2023-06-14	ES6075945687647126449848973	международная	5005355.5627	161.0928	отправлена	BKCHCNBJ
3103	RU6983803436557684576294868357987	840	2023-03-20	RU6583803436546434088553514688778	внутренняя	7513167.0905	13.6526	отменена	\N
3104	RU6483803436595566817980742907742	156	2023-10-10	AD4181122834768355745285806	международная	1667484.7498	747.7873	отправлена	BKCHCNBJ
3105	RU1483803436552189189819570176682	643	2023-04-03	PT9468536595151962709370381	внутренняя	7780719.2258	269.8983	отменена	\N
3106	RU8483803436528403655778834568144	643	2023-11-17	RU7383803436534050516387288663509	внутренняя	7401158.5286	753.0312	отправлена	\N
3107	RU2183803436535230801413319305895	356	2023-10-03	RU6583803436565551879254347008316	внутренняя	408222.0821	763.3066	доставлена	\N
3108	RU2683803436532775565489898182986	643	2023-12-13	RU4283803436515276086545867508581	внутренняя	8600858.5841	942.8942	доставлена	\N
3109	RU3383803436533625475503259998648	840	2023-04-08	PT7572349164149492474905130	международная	5138594.4152	516.4423	отправлена	CHASUS33
3110	RU7383803436546512723534280739575	156	2023-07-17	PT1522694955249101317775297	международная	2895356.4793	963.9529	отменена	BKCHCNBJ
3111	RU7483803436595027677837710467368	978	2023-02-21	KZ2561104662688540951286346	международная	6714827.8725	211.2600	отправлена	DEUTDEFFXXX
3112	RU4883803436540069564759439339493	978	2023-04-10	ES8291318442361188757560371	международная	9296274.7779	302.7400	доставлена	RZBAATWW
3113	RU8483803436523751116997614384937	398	2023-05-27	RU4183803436512683300418013703414	внутренняя	1100388.3186	360.4888	доставлена	\N
3114	RU8583803436586707949034749896750	356	2023-01-26	RU9383803436546841675173507423577	внутренняя	4937700.4831	304.4404	отменена	\N
3115	RU5683803436522754650880470438385	156	2023-07-25	AL5584081234506608701495589	международная	2502247.2313	210.2612	доставлена	BKCHCNBJ
3116	RU2183803436535230801413319305895	978	2023-06-09	RU2783803436580745382811010865973	внутренняя	7170577.5337	115.2554	отправлена	\N
3117	RU4183803436593654490331448399606	978	2023-06-29	ES8932841863529372996200254	международная	1608262.2430	520.4162	отменена	DEUTDEFFXXX
3118	RU6183803436555838927651384339574	840	2023-05-15	RU2448810346293508690312615	внутренняя	7214115.3191	778.0595	отменена	\N
3119	RU7183803436551143317683635788042	840	2023-05-09	VN1519954953091842031376998	международная	1232750.3584	718.6544	отменена	CHASUS33
3120	RU4183803436598422593606583773593	840	2023-03-26	VN9810290426170353707896221	международная	4310077.4019	617.1713	отправлена	CHASUS33
3122	RU6983803436521001508692071958064	356	2023-10-10	RU2583803436569716293278278112122	внутренняя	6768932.7801	843.2366	отправлена	\N
3123	RU3683803436529963181547651499120	398	2023-07-03	RU6783803436583735354795738130605	внутренняя	687168.4009	877.1795	отменена	\N
3124	RU8083803436548053884024737088236	978	2023-05-29	BY5074402479012087551625931	международная	9259227.1231	573.7862	отправлена	DEUTDEFFXXX
3125	RU8583803436590890149305918634043	840	2023-07-28	RU8983803436550652073660555482382	внутренняя	3847654.7402	40.8467	отправлена	\N
3126	RU5583803436516539388298963058164	643	2023-11-24	RU6483803436531317735484528392559	внутренняя	6438882.1609	267.3045	отправлена	\N
3127	RU7483803436512314763652680872976	356	2023-01-06	RU9083803436527710172880684864084	внутренняя	6585083.9766	467.6677	отправлена	\N
3128	RU9583803436574471411467135718624	978	2022-12-28	ES6568682994427110889560338	международная	2148541.9435	646.2313	отменена	RZBAATWW
3129	RU5983803436585678890114061651314	840	2023-06-06	RU3983803436562540544761068231244	внутренняя	5995057.8211	660.2367	отменена	\N
3130	RU3583803436580986023375789999847	356	2023-01-13	RU6983803436557684576294868357987	внутренняя	12642.8711	170.9164	отправлена	\N
3131	RU4283803436515276086545867508581	356	2023-02-17	RU9583803436574471411467135718624	внутренняя	136435.0679	562.5248	доставлена	\N
3132	RU7583803436597888322431139189153	978	2023-06-20	AL6736389184237188710429920	международная	1629485.1148	920.4658	отправлена	SOGEFRPP
3133	RU5083803436583492295875343805447	643	2023-05-07	AD5516730471432320673466534	внутренняя	1577627.9567	166.2999	доставлена	\N
3134	RU3083803436572725983728902081378	356	2023-03-28	RU2283803436521727957364583057084	внутренняя	185738.9960	49.5232	отменена	\N
3135	RU7483803436516612664745741202549	356	2023-10-04	RU7383803436546512723534280739575	внутренняя	5129953.6241	909.8224	отправлена	\N
3136	RU4683803436518754352401343547893	156	2023-08-09	IN9348373831414338408910892	международная	9010374.4401	152.3220	отменена	BKCHCNBJ
3137	RU2483803436563361420871450061347	156	2023-11-15	RU2983803436596711612246779730808	внутренняя	2490078.5082	696.6593	отменена	\N
3138	RU5183803436588801456118987264753	356	2023-10-19	BY4225547234303150244887923	международная	9293632.1896	432.9141	отменена	SBININBBXXX
3139	RU4283803436583191860084907222827	156	2023-10-08	RU6983803436580831999013679742086	внутренняя	9153844.3916	441.7896	отправлена	\N
3140	RU7283803436582085910615477000049	643	2023-08-04	PT5589601036274513981083685	внутренняя	9763639.2953	870.8193	доставлена	\N
3141	RU6283803436541447099313442593938	840	2023-08-26	RU6383803436530975100435134167112	внутренняя	4232523.1183	609.6223	отправлена	\N
3142	RU9583803436537234117226554935344	978	2023-07-03	RU5083803436583492295875343805447	внутренняя	3164349.7893	427.2780	отменена	\N
3143	RU4783803436576956010684046744289	840	2023-04-26	RU4583803436546993711061481413708	внутренняя	9622187.0432	342.7024	доставлена	\N
3144	RU7683803436589524723383129532286	840	2023-01-01	RU8583803436586707949034749896750	внутренняя	8723998.3679	59.3709	доставлена	\N
3145	RU4383803436597428452957764955765	356	2023-07-04	RU3383803436530100232705488681423	внутренняя	5881492.8059	853.3805	доставлена	\N
3146	RU2283803436555228451424548337941	643	2023-07-24	RU4683803436521950147450839996450	внутренняя	2987050.6150	391.4829	отправлена	\N
3147	RU1183803436513944372774322746458	356	2023-03-09	RU5283803436529894140873721164089	внутренняя	2559739.0286	131.7146	отменена	\N
3148	RU6583803436546434088553514688778	356	2023-12-20	RU4083803436525661046500520760430	внутренняя	8045418.5354	949.8833	отправлена	\N
3149	RU6283803436541447099313442593938	356	2023-03-24	DE3640480376692489785993343	международная	464413.2556	581.7643	отменена	SBININBBXXX
3150	RU6483803436575827628326698282321	398	2023-01-06	RU5883803436549838724600410631189	внутренняя	8371767.1014	26.5609	отменена	\N
3151	RU6583803436573484995572407857396	356	2023-08-12	IN2972229143741178900235276	международная	2666211.3253	93.2948	доставлена	SBININBBXXX
3152	RU5883803436549838724600410631189	978	2023-06-07	RU4583803436546993711061481413708	внутренняя	5037660.7268	655.4505	доставлена	\N
3153	RU4483803436534969190676238532628	643	2023-09-17	AL3810323119665893746316122	внутренняя	5749212.5309	449.0767	отправлена	\N
3154	RU9883803436580908913943520973504	978	2023-11-24	RU6983803436596433824452063468541	внутренняя	2963357.7120	402.8957	отменена	\N
3155	RU4983803436548786021946522460624	978	2023-12-02	RU2083803436573246597416370413406	внутренняя	132113.6865	524.0699	отправлена	\N
3156	RU9883803436510697875492928159959	156	2023-07-09	DE6717202781261710997048798	международная	973958.3220	603.4327	отправлена	BKCHCNBJ
3157	RU9383803436563463129216774786629	643	2023-12-03	RU6583803436592149423686806465410	внутренняя	969721.3932	585.4094	отправлена	\N
3158	RU7183803436584925378313266803439	643	2023-08-05	RU2183803436535230801413319305895	внутренняя	4287137.0777	716.6977	отправлена	\N
3159	RU5583803436541779385547740767657	398	2023-07-24	AD3673106034176364465154306	международная	4191087.6678	432.5357	отменена	CASPKZKAXXX
3160	RU8583803436580493050529274956761	356	2023-01-29	RU2983803436545911307181108696312	внутренняя	6476239.0943	720.5049	отменена	\N
3161	RU5183803436523181844916432548416	840	2023-06-13	RU4683803436521950147450839996450	внутренняя	7205666.8900	483.6935	доставлена	\N
3162	RU2283803436588289284937975921944	978	2023-07-06	IN6652180042068190705884416	международная	3438695.0372	533.2722	отправлена	RZBAATWW
3163	RU9483803436588743613330942629999	398	2023-02-12	BY4847206547638378176977598	международная	9952247.4062	210.1266	отменена	CASPKZKAXXX
3164	RU7583803436593621382878998665048	398	2023-10-16	IN1699730486867712371746674	международная	8380034.1683	725.7110	отправлена	CASPKZKAXXX
3165	RU8983803436543970357311304848339	356	2023-05-07	RU8883803436542351475891948314875	внутренняя	8767513.2603	978.1086	отправлена	\N
3166	RU6983803436580831999013679742086	840	2023-08-22	AL4362592127253504037318520	международная	2039688.2659	406.3764	доставлена	IRVTUS3NXXX
3167	RU3883803436515226766320509995235	356	2023-06-02	ES8369798527709516300196196	международная	7012749.7459	644.4903	отправлена	SBININBBXXX
3168	RU8183803436576908594301902139271	356	2023-07-27	BY4781825547356307281900344	международная	8225398.9827	663.1809	доставлена	SBININBBXXX
3169	RU7283803436565335970635584506660	398	2023-06-01	BY2296628254708215341075183	международная	5292789.1962	448.6894	отправлена	CASPKZKAXXX
3170	RU4383803436597428452957764955765	643	2023-04-16	RU5883803436551017474710608700284	внутренняя	6268458.3118	591.7332	отменена	\N
3171	RU5183803436550941857646482749776	840	2023-06-05	RU4483803436537144245226352938256	внутренняя	131006.2976	738.5098	отменена	\N
3172	RU1583803436592948110594062864167	398	2023-09-08	RU8856301753572155597859704	внутренняя	8530349.2686	298.1866	доставлена	\N
3173	RU2283803436527235231809863175226	978	2023-02-02	RU6183803436536163842184020816729	внутренняя	6324541.9047	64.0285	отменена	\N
3174	RU9883803436596118671708861810646	978	2023-07-13	RU6983803436542868245387240901621	внутренняя	6482290.5066	380.3185	доставлена	\N
3175	RU4283803436515276086545867508581	840	2023-05-12	RU5983803436558435772787343054218	внутренняя	1278297.0255	335.0595	доставлена	\N
3176	RU1983803436549890414007715363567	643	2023-03-17	RU2483803436580851808318436691458	внутренняя	4422298.2622	475.7888	доставлена	\N
3177	RU2783803436598441945275189813351	840	2023-04-21	AD5681131483351845482343139	международная	1300712.1806	584.6690	отменена	IRVTUS3NXXX
3178	RU1383803436596151895061926683764	643	2023-09-13	RU9983803436521153026985692784451	внутренняя	4391038.0085	409.1061	доставлена	\N
3179	RU8383803436554622159366581134752	978	2023-10-30	RU2183803436538160023828199079683	внутренняя	3757988.7029	317.8327	доставлена	\N
3180	RU1183803436513944372774322746458	156	2023-04-12	RU2883803436564862346362051659673	внутренняя	1506932.6448	73.9491	отправлена	\N
3181	RU4083803436537218400436107027314	643	2023-06-08	RU5583803436516539388298963058164	внутренняя	7735633.2470	577.3579	доставлена	\N
3182	RU3683803436529963181547651499120	356	2023-01-01	RU1983803436510686315036595318873	внутренняя	7803778.1265	136.5843	отправлена	\N
3183	RU1183803436541561390025398925839	398	2023-04-29	RU7483803436595027677837710467368	внутренняя	4900724.6460	873.1010	отменена	\N
3184	RU1983803436592911874717339237016	356	2023-08-05	RU6983803436580831999013679742086	внутренняя	655311.6307	638.2344	доставлена	\N
3185	RU5083803436521160540176223483455	643	2023-05-15	RU7511033367320226498163882	внутренняя	5958161.2734	11.3020	отменена	\N
3186	RU9583803436589245078784775619456	356	2023-01-11	RU5983803436513359014201161572816	внутренняя	7554449.7416	824.5785	отменена	\N
3187	RU5883803436544935035293164341064	643	2023-08-25	DE6259825889685957524088585	внутренняя	4491349.1708	923.5849	отправлена	\N
3188	RU2183803436555308456329784386702	156	2023-07-06	RU7229748149012455514334239	внутренняя	7840271.5171	164.6703	доставлена	\N
3189	RU8283803436593409912626065485368	156	2023-02-25	AL5379021961858089337614346	международная	954830.6463	432.4086	доставлена	BKCHCNBJ
3190	RU5683803436539120556194350818141	156	2023-07-16	RU9183803436594783043422280553530	внутренняя	8823913.2944	339.7366	отменена	\N
3191	RU9183803436594783043422280553530	156	2023-06-03	ES9659948014976709017559171	международная	973373.2518	786.9997	отменена	BKCHCNBJ
3192	RU2483803436559904294875702128517	978	2023-03-08	BY5539800934036282375814280	международная	7382103.3791	598.4513	отправлена	RZBAATWW
3193	RU6583803436565551879254347008316	356	2023-11-20	RU2751902822104863946307651	внутренняя	594916.9779	752.3829	отправлена	\N
3194	RU6983803436557684576294868357987	356	2023-09-21	RU4283803436530972916151822377436	внутренняя	1310499.9095	996.7547	доставлена	\N
3195	RU5783803436598085342824416355658	840	2023-03-11	AL5297908832389807107619993	международная	4998039.5420	492.6816	отменена	IRVTUS3NXXX
3196	RU8583803436553386257766521949981	398	2023-03-09	AD5345082911220106449720056	международная	3955562.9173	481.5167	доставлена	CASPKZKAXXX
3197	RU7283803436551671539996901196859	398	2023-02-28	RU4383803436557380827011382643653	внутренняя	8085138.7237	456.2690	отменена	\N
3198	RU1083803436516100547774990634896	840	2023-11-04	VN5789918743097219547955985	международная	2584100.7414	835.9032	отменена	IRVTUS3NXXX
3199	RU9683803436559214297350823715344	978	2023-12-21	ES5512396346848920859244260	международная	4576801.3613	680.6292	отменена	DEUTDEFFXXX
3200	RU5683803436522754650880470438385	398	2023-11-11	DE8688654659798826301131044	международная	1084864.2705	640.8763	отменена	CASPKZKAXXX
3201	RU5183803436588801456118987264753	156	2023-01-22	BY7060116936359202983442483	международная	9896316.8821	639.9639	доставлена	BKCHCNBJ
3202	RU8883803436542351475891948314875	840	2023-10-28	RU4583803436576777630615652907536	внутренняя	7769173.5201	984.3300	доставлена	\N
3203	RU1283803436591782126481419856685	356	2023-10-06	RU8083803436548053884024737088236	внутренняя	4559448.1137	809.9276	доставлена	\N
3204	RU6683803436534213789698830771682	840	2023-08-23	RU4883803436510661666911089208306	внутренняя	7817400.1137	582.8186	отменена	\N
3205	RU2983803436510489846489627969282	356	2023-04-29	RU5183803436550941857646482749776	внутренняя	894461.7980	573.0047	отменена	\N
3206	RU2583803436525056668985275863842	156	2023-06-19	RU2283803436594102552659582448178	внутренняя	2038360.7066	12.9287	отменена	\N
3207	RU5583803436516539388298963058164	840	2023-07-20	KZ6581593099036729575732213	международная	764039.5267	597.2419	отменена	CHASUS33
3208	RU6783803436582018660242960957244	156	2023-04-26	IN3368445057898976136658812	международная	6325831.4157	270.2651	отправлена	BKCHCNBJ
3209	RU6583803436565551879254347008316	156	2023-08-23	IN4643091368260258937618020	международная	9260564.9936	0.0000	отменена	BKCHCNBJ
3210	RU2283803436527235231809863175226	156	2023-12-24	RU6983803436518663051613263930888	внутренняя	3204996.1272	84.0523	отменена	\N
3211	RU7183803436578006903833632767386	840	2023-06-26	RU5683803436575772290627280121203	внутренняя	9463943.0141	217.8262	доставлена	\N
3212	RU5883803436549838724600410631189	398	2023-11-23	RU4683803436521950147450839996450	внутренняя	1307254.6373	570.7382	отправлена	\N
3213	RU3683803436533022850683714599602	978	2023-01-09	AL6414657218279976738591032	международная	2904957.6074	162.0917	отменена	DEUTDEFFXXX
3214	RU6783803436510078136565817264354	840	2023-09-03	RU1083803436532178175395898264605	внутренняя	2536283.6001	680.0495	отправлена	\N
3215	RU3383803436551883036237842733910	643	2023-05-24	RU7683803436565241249132549566386	внутренняя	7923732.5121	999.7665	доставлена	\N
3216	RU9383803436563463129216774786629	840	2023-02-17	RU7383803436569356631218275502161	внутренняя	1501249.1698	324.3093	отменена	\N
3217	RU6083803436557649065533492172245	643	2023-09-14	RU7683803436578953117174553181317	внутренняя	9110679.8301	874.9355	отправлена	\N
3218	RU5183803436550941857646482749776	978	2023-03-14	RU4383803436535637847836978327691	внутренняя	2220128.6254	657.4125	отменена	\N
3219	RU2183803436555308456329784386702	156	2023-09-11	RU8083803436588746463552823930061	внутренняя	3284237.6575	155.8259	отменена	\N
3220	RU5183803436588801456118987264753	978	2023-11-19	PT4974904917484773893815268	международная	2639876.4889	350.0376	отменена	RZBAATWW
3221	RU4183803436512683300418013703414	840	2023-04-05	RU5183803436523181844916432548416	внутренняя	4119980.8497	207.0009	доставлена	\N
3222	RU5583803436544105301147510534206	356	2023-08-28	RU9583803436574471411467135718624	внутренняя	6141590.6572	981.2735	отменена	\N
3223	RU9383803436568402663247236595753	356	2023-09-20	PT6524372202738645740814394	международная	8430907.6092	182.4923	отправлена	SBININBBXXX
3224	RU4383803436559640804885433764330	156	2023-08-02	IN2145259138220184454470029	международная	4343788.9840	580.7364	отправлена	BKCHCNBJ
3225	RU3783803436562139250445157080524	840	2023-10-16	AL1271879002079862987884515	международная	9728163.7883	702.2043	доставлена	IRVTUS3NXXX
3226	RU7483803436581386287039618321410	643	2023-09-10	RU9383803436546841675173507423577	внутренняя	2649119.1112	999.3643	отменена	\N
3227	RU5583803436556151120487866130687	643	2023-09-05	RU9683803436520170153501466272589	внутренняя	5689638.4481	41.8934	доставлена	\N
3228	RU6183803436573612137819734816326	356	2023-09-14	RU4883803436510661666911089208306	внутренняя	3563749.0171	892.4961	отправлена	\N
3229	RU9283803436581282514241262822584	978	2023-04-18	RU6683803436575472065287991925682	внутренняя	7258780.2880	292.8883	отправлена	\N
3230	RU8683803436520349379894661014091	398	2023-11-28	ES4428740431984556265691653	международная	3398069.9780	568.8590	отправлена	CASPKZKAXXX
3231	RU5783803436568341660520010753753	840	2023-01-29	RU2983803436588011593439328399453	внутренняя	4605930.0985	971.8583	отправлена	\N
3232	RU2983803436539974076802515756241	978	2023-03-25	RU5383803436537654175631942789109	внутренняя	6725488.2209	898.0386	отправлена	\N
3233	RU2283803436551819000625747494652	356	2023-01-04	RU2383803436518501918755699207235	внутренняя	8863675.6282	400.7654	отправлена	\N
3234	RU9083803436548965374028188380728	978	2023-07-16	PT3221372556025558668249113	международная	6262949.9310	330.8039	отменена	RZBAATWW
3235	RU6283803436577836700807681117407	156	2023-05-26	AL1528870679733552977110577	международная	6196874.1106	880.7100	отправлена	BKCHCNBJ
3236	RU1383803436546084241558471107471	356	2023-08-17	RU2583803436586349630493889324094	внутренняя	3204931.7594	835.4846	отправлена	\N
3237	RU8283803436558421168306139201398	978	2023-06-30	RU5183803436588801456118987264753	внутренняя	5501126.3799	0.0000	отменена	\N
3238	RU2983803436596711612246779730808	978	2023-06-08	RU7283803436565335970635584506660	внутренняя	3524300.8660	635.5497	доставлена	\N
3239	RU7583803436545511345420608427589	978	2023-07-08	RU5283803436570838144716210841495	внутренняя	5190980.1475	772.8630	доставлена	\N
3240	RU4483803436574648344464338946055	356	2023-01-15	KZ1536835271984230575384027	международная	4854484.7439	509.6830	доставлена	SBININBBXXX
3241	RU3283803436579852018195047883736	356	2022-12-30	RU4783803436556925313909023616425	внутренняя	384609.2813	215.1316	отменена	\N
3242	RU3283803436586063041663029658571	840	2023-12-16	RU5783803436568341660520010753753	внутренняя	3397087.7756	439.2278	доставлена	\N
3243	RU8183803436576334203563049364101	156	2023-07-05	AD4952422363346593152012515	международная	3593127.8844	800.0747	доставлена	BKCHCNBJ
3244	RU8183803436576908594301902139271	978	2023-10-24	RU6283803436541447099313442593938	внутренняя	1509373.7380	393.8759	доставлена	\N
3245	RU4883803436561825246742556433732	643	2023-02-25	RU3912766413530255587502632	внутренняя	3247194.3423	306.1857	доставлена	\N
3246	RU6483803436575827628326698282321	156	2023-11-22	RU8283803436536082355231514909614	внутренняя	9618808.2502	179.5487	доставлена	\N
3247	RU7083803436569474567525801645267	398	2023-07-17	RU6083803436582119843499506879640	внутренняя	2448675.6737	835.5327	доставлена	\N
3248	RU5183803436585063037953141711870	398	2023-11-13	RU8183803436559528710172368223769	внутренняя	2622471.5949	45.4699	отменена	\N
3249	RU7083803436565850801859363291526	356	2023-05-27	RU9698249418876210482352613	внутренняя	5250083.8044	125.0793	отменена	\N
3250	RU2583803436569716293278278112122	840	2023-05-18	ES4293862738336081296494540	международная	2338026.8820	68.4128	отменена	IRVTUS3NXXX
3251	RU8483803436512925144599170278485	398	2023-08-12	DE9935939052315402901892597	международная	9418424.3715	796.1764	отменена	CASPKZKAXXX
3252	RU1183803436512373318427988836252	156	2023-07-26	RU3972018084858292563839661	внутренняя	7552495.3190	553.9610	отправлена	\N
3253	RU8783803436544746989208687599320	356	2023-06-05	RU6483803436599929208547720213297	внутренняя	6945614.3000	189.9039	доставлена	\N
3254	RU5083803436583492295875343805447	156	2023-06-08	RU9283625976697627621719387	внутренняя	4263855.3521	524.0248	отправлена	\N
3255	RU8283803436593409912626065485368	156	2023-01-20	KZ3368230653071126099876658	международная	7702314.8358	109.6203	отправлена	BKCHCNBJ
3256	RU3583803436531844714480494060517	643	2023-09-07	RU6983803436550083462130199504453	внутренняя	6337886.0271	603.4973	доставлена	\N
3257	RU9783803436531316283778462589484	978	2023-03-26	RU5583803436516539388298963058164	внутренняя	1633459.7398	130.0430	отправлена	\N
3258	RU6583803436588261503476787515721	978	2023-03-08	RU5983803436596779338391553657957	внутренняя	1487681.0257	587.0623	отменена	\N
3259	RU4583803436571583967013936520660	978	2023-12-03	KZ5570365087030340315199305	международная	4934657.4746	877.7556	отменена	DEUTDEFFXXX
3260	RU2683803436512319317744369021772	840	2023-07-07	DE9976624261241567466847016	международная	9851084.0754	761.5164	доставлена	IRVTUS3NXXX
3261	RU8683803436531608639655465618756	643	2023-02-01	RU6483803436575827628326698282321	внутренняя	8086294.4766	965.6073	отменена	\N
3262	RU4583803436576777630615652907536	398	2023-06-10	RU7183803436551143317683635788042	внутренняя	8726771.6440	441.8201	отправлена	\N
3263	RU3683803436521305656177527242839	978	2023-03-06	KZ5326186606223217147104729	международная	6876249.0558	461.7930	отменена	DEUTDEFFXXX
3264	RU7283803436551671539996901196859	643	2023-07-26	RU1183803436569972795023903837949	внутренняя	3255282.5291	760.2506	отправлена	\N
3265	RU1983803436518034161993382946183	398	2023-11-15	IN4972709101128465285937390	международная	7395001.3080	891.9870	отменена	CASPKZKAXXX
3266	RU1183803436513944372774322746458	840	2023-10-15	RU1183803436536239647096212180861	внутренняя	5089680.5493	861.4979	отправлена	\N
3267	RU5983803436518386216122030936247	840	2023-12-04	AL1484708693483592683712842	международная	7276590.3193	332.9422	отправлена	IRVTUS3NXXX
3268	RU6383803436541953279771793851240	356	2023-03-07	RU8178812497743076727600606	внутренняя	9999459.4673	953.7614	доставлена	\N
3269	RU4283803436532641085536208083176	643	2023-06-11	KZ9186828321159160316837669	внутренняя	9347697.9462	631.8466	доставлена	\N
3270	RU9483803436570307762028951954874	156	2023-01-06	IN1560499483797576980449100	международная	8725768.4487	109.2741	отменена	BKCHCNBJ
3271	RU1383803436585969091171133733533	356	2023-05-04	RU7383803436585863943754594310819	внутренняя	3788852.6991	694.7434	доставлена	\N
3272	RU7483803436591068390387769478580	356	2023-06-07	AL3227205535712384378220803	международная	3009082.0606	678.4049	отменена	SBININBBXXX
3273	RU8983803436530366335955653516096	643	2023-06-08	IN3468327974512804051986005	внутренняя	4848419.5491	761.2120	отправлена	\N
3274	RU1983803436510712914540451632365	398	2023-09-09	RU2583803436511360000518303822185	внутренняя	7721237.9740	25.6191	доставлена	\N
3275	RU5183803436588801456118987264753	978	2023-02-16	RU2983803436539974076802515756241	внутренняя	6391544.7629	804.2908	доставлена	\N
3276	RU8183803436532187852215520403243	978	2023-03-04	RU5983803436513359014201161572816	внутренняя	190561.4538	80.1307	доставлена	\N
3277	RU6383803436517724803474176712817	643	2023-10-14	RU5083803436563140090168469536649	внутренняя	7852168.5369	302.9924	отправлена	\N
3278	RU3783803436562091905141244310726	978	2023-02-15	PT8647828461130709068866470	международная	6364966.2748	573.0077	отправлена	SOGEFRPP
3279	RU8483803436523751116997614384937	978	2023-11-02	RU8483803436597380246113206833117	внутренняя	4720997.3433	842.4930	отменена	\N
3280	RU4383803436559640804885433764330	840	2023-06-10	AL7747901295731834519929499	международная	7893897.2438	430.3010	отменена	CHASUS33
3281	RU4583803436576777630615652907536	156	2023-01-03	BY3232526967384454838265665	международная	7863248.7381	209.1771	отменена	BKCHCNBJ
3282	RU1283803436545193525808988988532	398	2023-09-26	RU6983803436551969328605594993446	внутренняя	629262.2346	44.1042	отправлена	\N
3283	RU8483803436586135450040789229889	356	2023-03-24	RU5083803436556786327042016836549	внутренняя	5521299.2609	711.5523	отменена	\N
3284	RU4083803436534430125114460530795	398	2023-07-17	VN9053402979598473068378693	международная	2707162.4153	826.5991	отправлена	CASPKZKAXXX
3285	RU2483803436580851808318436691458	398	2023-06-13	KZ4034789299492628078169423	международная	8943899.7585	469.2517	отменена	CASPKZKAXXX
3286	RU1683803436543683792461716245841	356	2023-07-07	KZ2159988507802332842856734	международная	3422390.7529	641.5716	отменена	SBININBBXXX
3287	RU5383803436537654175631942789109	643	2023-08-16	RU9683803436571883645805733128714	внутренняя	9726220.3720	30.2916	отправлена	\N
3288	RU2283803436588289284937975921944	978	2023-10-07	RU5783803436568341660520010753753	внутренняя	9596785.9097	552.6444	доставлена	\N
3289	RU6683803436575472065287991925682	156	2023-12-25	KZ7664967929959539185502550	международная	1745271.8989	260.1994	доставлена	BKCHCNBJ
3290	RU8483803436576032684947735830335	398	2023-06-16	AL4266476504481536579604072	международная	3547546.1092	265.2435	отправлена	CASPKZKAXXX
3291	RU3383803436551883036237842733910	978	2023-07-01	AL3666720966620323550288160	международная	2965332.3085	570.8598	отменена	DEUTDEFFXXX
3292	RU6583803436547384322379422553840	356	2023-03-10	RU7699545691394304075737379	внутренняя	4730968.7944	768.0294	отменена	\N
3293	RU4383803436538414207445829899653	643	2023-07-01	IN4898955778844665288291349	внутренняя	8300557.3788	581.3886	отменена	\N
3294	RU1983803436537997284898110055528	398	2023-07-31	IN6924293939685179020112645	международная	7810275.0991	355.9562	отправлена	CASPKZKAXXX
3295	RU1683803436583298094705869717304	398	2023-09-03	VN3088169526485269871513674	международная	9117388.1467	998.6638	отправлена	CASPKZKAXXX
3296	RU3983803436583730529285495292571	643	2023-03-14	RU4183803436575456526806163894045	внутренняя	7418621.7207	563.6098	доставлена	\N
3297	RU6383803436541953279771793851240	840	2023-01-19	RU6483803436595566817980742907742	внутренняя	5383755.3169	30.2445	доставлена	\N
3298	RU8683803436558409197465918354522	978	2023-11-13	RU6583803436552414284054924599360	внутренняя	9192242.1579	564.0787	отменена	\N
3299	RU2783803436515955219320238454317	643	2023-02-16	ES9563742373359067121652942	внутренняя	8623839.2051	42.9517	отменена	\N
3300	RU5583803436525031727011657164177	356	2023-01-16	RU6483803436599929208547720213297	внутренняя	9777395.4967	700.5047	отправлена	\N
3301	RU2283803436551819000625747494652	398	2023-07-20	VN5926009724592803902966332	международная	2922361.6091	482.0769	доставлена	CASPKZKAXXX
3302	RU7583803436545511345420608427589	398	2023-08-20	BY9544558748414715869094102	международная	4371680.5429	684.8618	доставлена	CASPKZKAXXX
3303	RU9183803436523189940915642395180	156	2023-06-07	RU4783803436556925313909023616425	внутренняя	3857366.5684	446.5711	отменена	\N
3304	RU4683803436584135461455281070651	356	2023-03-15	RU8483803436552375991404578719285	внутренняя	6897989.8172	933.2219	отправлена	\N
3305	RU4083803436561171626967381260937	156	2023-04-11	AD4326706455800134916356094	международная	2062336.2412	447.7835	доставлена	BKCHCNBJ
3306	RU2283803436555228451424548337941	398	2023-09-04	KZ9663890976944135231957291	международная	5215400.7523	748.4447	отправлена	CASPKZKAXXX
3307	RU8583803436593152008036708778596	156	2023-03-21	RU1383803436565139777755041333233	внутренняя	9482569.3698	990.7787	доставлена	\N
3308	RU8483803436517523304653033637180	398	2023-07-17	RU6883803436521704893234788177503	внутренняя	2002798.6684	895.5954	отменена	\N
3309	RU4283803436571605132393354830061	978	2023-07-07	AD2365056447110598653327945	международная	1671384.9967	774.5488	отменена	RZBAATWW
3310	RU9483803436588743613330942629999	356	2023-09-23	RU4583803436576777630615652907536	внутренняя	2192969.6047	928.1990	отправлена	\N
3311	RU8883803436592173067148862634991	356	2023-12-14	PT5833012622900738564495698	международная	2037194.5395	145.6715	доставлена	SBININBBXXX
3312	RU7483803436560908970835757520521	356	2023-06-25	RU8983803436550652073660555482382	внутренняя	9559130.8559	638.3636	отменена	\N
3313	RU1683803436543683792461716245841	398	2023-11-24	DE7181516637004638135128741	международная	6925260.1847	380.3552	доставлена	CASPKZKAXXX
3314	RU6283803436561107985248905256058	398	2023-05-17	RU3383803436530100232705488681423	внутренняя	1566434.3918	308.4656	доставлена	\N
3315	RU2283803436577856579987093576845	978	2023-04-04	RU9583803436515959194321808018014	внутренняя	4300227.3357	220.5812	отправлена	\N
3316	RU2083803436518033160343253894367	398	2023-02-23	BY9442817217967025069440192	международная	8549866.8318	506.4423	доставлена	CASPKZKAXXX
3317	RU7383803436567535429961689788567	398	2023-06-22	RU5583803436581992686445972740236	внутренняя	6550626.2570	820.3182	доставлена	\N
3318	RU3483803436534657689181631833463	356	2023-03-19	RU5183803436588244188761426669013	внутренняя	6082536.4346	111.4843	отправлена	\N
3319	RU4083803436537218400436107027314	840	2023-05-19	RU3983803436562540544761068231244	внутренняя	4795416.4759	723.1957	отправлена	\N
3320	RU7183803436535160662680026565691	978	2023-04-27	RU3883803436554504516286459147223	внутренняя	5837469.1248	408.5799	доставлена	\N
3321	RU4983803436548786021946522460624	643	2023-03-09	BY5749768688937895193466723	внутренняя	324672.6692	768.5070	отправлена	\N
3322	RU3683803436583826961336736431806	356	2023-03-20	RU2083803436536025786076127901648	внутренняя	1227723.7217	259.5527	отправлена	\N
3323	RU9383803436575688788160155647011	356	2023-05-19	PT8575539996658336303790852	международная	8772932.3490	239.5052	доставлена	SBININBBXXX
3324	RU2283803436594102552659582448178	156	2023-10-10	RU6233999137410903143475158	внутренняя	1698902.8307	423.5534	доставлена	\N
3325	RU4983803436522833268295991391237	356	2023-09-01	RU6483803436575827628326698282321	внутренняя	3901128.3937	639.5154	отменена	\N
3326	RU5083803436556786327042016836549	978	2023-10-07	RU8183803436584325139466333599286	внутренняя	7944956.9803	196.8492	отменена	\N
3327	RU1083803436532178175395898264605	156	2023-03-20	AD4020610442130311775269503	международная	9726454.1585	523.0740	доставлена	BKCHCNBJ
3328	RU2683803436532775565489898182986	398	2023-12-21	RU2483803436580851808318436691458	внутренняя	3095540.2007	983.5712	отменена	\N
3329	RU5483803436538988818998904026382	156	2023-02-01	RU9683803436524115739172828059349	внутренняя	2352750.9109	166.5443	отменена	\N
3330	RU1983803436592911874717339237016	156	2023-05-19	KZ4138948514104370318794129	международная	1216351.9182	127.0196	отправлена	BKCHCNBJ
3331	RU3683803436521305656177527242839	398	2023-07-10	RU2083803436593214630941740939011	внутренняя	2920624.6209	972.2613	отправлена	\N
3332	RU5883803436512174556620785995683	156	2023-06-07	KZ5454492612098286320808189	международная	5861358.8461	69.5831	отправлена	BKCHCNBJ
3333	RU8983803436530366335955653516096	840	2023-02-10	AD5415830451413183956121323	международная	3022071.3419	452.7159	отменена	IRVTUS3NXXX
3334	RU7583803436597888322431139189153	398	2023-03-29	DE6066616059706818087117713	международная	1609126.0088	167.0736	отменена	CASPKZKAXXX
3335	RU9383803436575688788160155647011	978	2023-08-09	RU7083803436565850801859363291526	внутренняя	2021674.4874	417.3500	отправлена	\N
3336	RU8083803436567877444686336475183	356	2023-02-09	RU4983803436548786021946522460624	внутренняя	8029197.2473	783.0185	отправлена	\N
3337	RU6283803436561107985248905256058	356	2023-08-01	KZ1822693499661259077295897	международная	2851529.9448	403.6810	отменена	SBININBBXXX
3338	RU9483803436570307762028951954874	156	2023-07-19	PT4678752718872456567516909	международная	4033378.7782	131.5363	отменена	BKCHCNBJ
3339	RU4383803436559640804885433764330	840	2023-07-24	RU7783803436556242953974983768067	внутренняя	4174117.5542	917.5539	отменена	\N
3340	RU8683803436531608639655465618756	356	2023-09-03	RU4083803436537218400436107027314	внутренняя	1863138.2181	419.5305	отменена	\N
3341	RU6983803436596433824452063468541	356	2022-12-27	PT5640481342828448398706831	международная	8203524.8066	597.6875	отменена	SBININBBXXX
3342	RU2983803436539974076802515756241	840	2023-03-01	RU6983803436580831999013679742086	внутренняя	8558424.7596	174.9518	отменена	\N
3343	RU1683803436596193217028081534610	156	2023-06-20	RU1031173031325979541225523	внутренняя	1324029.8306	520.9930	отменена	\N
3344	RU2583803436525056668985275863842	156	2023-01-18	RU2883803436581906276084692901201	внутренняя	351410.0656	523.4579	отменена	\N
3345	RU9383803436568402663247236595753	356	2023-12-01	ES5183163481368094411355699	международная	3695257.9618	758.5992	доставлена	SBININBBXXX
3346	RU7483803436560908970835757520521	643	2023-01-12	BY4098817946850647693581186	внутренняя	5397618.0534	629.7916	отменена	\N
3347	RU6183803436555838927651384339574	643	2023-08-27	RU4783803436576956010684046744289	внутренняя	3428450.3384	961.6184	отменена	\N
3348	RU2883803436581906276084692901201	156	2023-10-21	PT5953794052447733236856193	международная	3640239.6141	89.2892	отменена	BKCHCNBJ
3349	RU2683803436566742853200336170327	840	2023-02-01	RU3683803436583826961336736431806	внутренняя	7612117.7825	856.7272	доставлена	\N
3350	RU4083803436525661046500520760430	356	2023-12-01	RU1583803436575905915250327615306	внутренняя	4241286.2423	607.4590	отправлена	\N
3351	RU4083803436530357399673623809331	356	2023-12-17	ES2569148802190048928647109	международная	1551548.4258	448.7457	доставлена	SBININBBXXX
3352	RU6983803436518663051613263930888	398	2023-04-13	RU9883803436559947701649293062119	внутренняя	3752296.9785	543.6238	доставлена	\N
3353	RU8683803436571821829992754282142	398	2023-05-11	RU9283803436560888794155508079505	внутренняя	3066622.1063	14.9223	отправлена	\N
3354	RU7183803436551143317683635788042	840	2023-06-14	BY2411674871677500625521766	международная	6808916.0962	44.4180	доставлена	IRVTUS3NXXX
3355	RU7783803436536804517087406327796	356	2023-02-10	RU1419082655785100380513415	внутренняя	3998400.5111	889.5926	отправлена	\N
3356	RU4083803436519648806531502670697	643	2023-10-31	RU3083803436572725983728902081378	внутренняя	7788051.9819	543.9857	доставлена	\N
3357	RU9383803436563463129216774786629	156	2023-03-29	DE4276368817781450021791238	международная	4560454.6998	498.5707	отменена	BKCHCNBJ
3358	RU4483803436593534887929979895004	356	2023-08-24	RU2683803436566742853200336170327	внутренняя	8737087.3357	554.0411	отправлена	\N
3359	RU9583803436537234117226554935344	398	2023-02-26	RU7351454708801324038741337	внутренняя	1682024.6790	603.5117	отправлена	\N
3360	RU6483803436531317735484528392559	643	2023-06-26	VN5225295347006948058428771	внутренняя	9232383.1345	477.2068	отменена	\N
3361	RU6383803436599902939219818792376	156	2023-11-10	RU8383803436583878629872361871714	внутренняя	1898059.2850	359.8522	отменена	\N
3362	RU1183803436587920364130887563809	978	2023-06-16	RU4583803436546993711061481413708	внутренняя	219334.2507	939.1118	отменена	\N
3363	RU4083803436526038486689011711230	398	2023-05-04	RU7083803436569474567525801645267	внутренняя	1950125.9546	940.3449	отменена	\N
3364	RU1383803436585969091171133733533	978	2023-04-15	RU3183803436522808312515599877028	внутренняя	695916.6747	741.5810	отправлена	\N
3365	RU1483803436556765140449291811625	978	2023-06-27	RU4083803436519648806531502670697	внутренняя	3915700.4357	486.0829	доставлена	\N
3366	RU1183803436547102061688733775669	156	2023-11-05	RU7883803436577262824038798840088	внутренняя	9986901.9827	792.6568	отменена	\N
3367	RU1983803436518034161993382946183	356	2023-01-21	ES9161199328319763514751659	международная	4291494.8388	695.6440	отправлена	SBININBBXXX
3368	RU4383803436597428452957764955765	398	2023-07-26	RU2483803436563361420871450061347	внутренняя	6273134.2985	20.0183	доставлена	\N
3369	RU1983803436537997284898110055528	398	2023-04-26	PT7046421314418238482838577	международная	3881948.6739	759.2976	доставлена	CASPKZKAXXX
3370	RU6283803436577836700807681117407	978	2023-08-24	ES4861138738294482694588396	международная	5544045.3005	467.1228	доставлена	RZBAATWW
3371	RU7683803436565241249132549566386	156	2023-04-04	AD1147180384002795056969319	международная	5718860.9483	233.9087	доставлена	BKCHCNBJ
3372	RU2683803436532775565489898182986	156	2023-07-06	IN9212134955601560265359534	международная	4502123.3507	47.0392	доставлена	BKCHCNBJ
3373	RU9683803436597203099828784600586	156	2023-12-11	DE1814985371672325671540100	международная	7955233.9790	612.6246	отправлена	BKCHCNBJ
3374	RU3583803436597484588589933917343	978	2023-04-16	RU8383803436543267469021061769102	внутренняя	3382336.3384	502.2190	отправлена	\N
3375	RU2683803436532775565489898182986	356	2023-05-20	RU4938880961493727062994624	внутренняя	948283.6784	519.2429	отменена	\N
3376	RU7883803436577262824038798840088	156	2023-04-12	ES5850098459096866570591199	международная	4495623.9497	546.4515	отменена	BKCHCNBJ
3377	RU9283803436581282514241262822584	978	2022-12-28	RU9383803436546841675173507423577	внутренняя	843226.4280	656.4692	отменена	\N
3378	RU5483803436538988818998904026382	356	2022-12-30	AL6852956276835241675018008	международная	2961340.9891	540.0643	отправлена	SBININBBXXX
3379	RU3683803436521305656177527242839	356	2023-08-09	RU6614112619255022626180679	внутренняя	6503417.4013	630.1090	отправлена	\N
3380	RU1583803436592948110594062864167	356	2023-04-02	RU6183803436536163842184020816729	внутренняя	896531.7557	317.7216	отправлена	\N
3381	RU8183803436555934243334630961587	978	2023-07-02	KZ7581281729589883846221523	международная	3132347.1275	111.2930	отправлена	RZBAATWW
3382	RU6483803436531317735484528392559	643	2023-01-31	PT2431261338016444603869774	внутренняя	3892561.9028	598.3267	доставлена	\N
3383	RU8583803436553386257766521949981	398	2023-08-29	RU4283803436571605132393354830061	внутренняя	6528042.1641	677.5893	отменена	\N
3384	RU9783803436586848496167067081204	840	2023-05-19	AL8059409193011229178360937	международная	9757869.7475	766.2605	доставлена	CHASUS33
3385	RU9583803436537234117226554935344	156	2023-03-13	VN3068506442141682535191059	международная	9854134.2769	757.9831	отменена	BKCHCNBJ
3386	RU5983803436596779338391553657957	398	2023-01-08	RU9583803436557636243711161422858	внутренняя	8265618.9015	843.1625	отменена	\N
3387	RU2883803436581906276084692901201	156	2023-04-20	RU7683803436565241249132549566386	внутренняя	7922249.5216	232.5534	доставлена	\N
3388	RU1183803436512373318427988836252	356	2023-12-17	RU1683803436583298094705869717304	внутренняя	1694344.5139	86.2558	отправлена	\N
3389	RU4283803436583191860084907222827	978	2023-03-14	AD1046940424392557680701716	международная	8634916.2270	937.4193	доставлена	RZBAATWW
3390	RU8483803436552375991404578719285	356	2023-04-04	AL6223761353354581232080061	международная	8372894.0892	897.7145	доставлена	SBININBBXXX
3391	RU6583803436573484995572407857396	643	2023-02-19	AD4225368059525013676057158	внутренняя	878669.0506	910.1086	доставлена	\N
3392	RU6783803436527708547728704282997	978	2023-07-07	RU6283803436561107985248905256058	внутренняя	1773706.0835	687.6214	отменена	\N
3393	RU2983803436585384738431881857607	398	2023-02-15	RU3183803436559935083955185145410	внутренняя	6733489.6400	558.7722	отменена	\N
3394	RU1183803436513944372774322746458	398	2023-04-14	AL5966275505899339518097828	международная	1934703.5449	91.3814	доставлена	CASPKZKAXXX
3395	RU8683803436557989786811096289958	840	2023-01-24	RU3683803436533022850683714599602	внутренняя	8529277.8610	458.8776	отменена	\N
3396	RU5983803436585678890114061651314	643	2023-09-19	BY4944713032759913847777045	внутренняя	817332.2369	667.0908	отменена	\N
3397	RU6583803436546434088553514688778	840	2023-08-15	RU8983803436588264357315670765686	внутренняя	5620538.9666	191.5772	отправлена	\N
3398	RU9383803436515318038329930627155	840	2023-06-05	RU2583803436586349630493889324094	внутренняя	6511298.6356	687.5562	доставлена	\N
3399	RU7783803436536804517087406327796	356	2023-11-04	DE7951159053544481172977195	международная	9017092.5797	128.4108	доставлена	SBININBBXXX
3400	RU8983803436519227550175732694863	643	2023-10-31	ES7268416572977869121410907	внутренняя	4526162.5449	889.0544	отправлена	\N
3401	RU4883803436583846522749125412438	978	2023-09-10	RU3683803436521305656177527242839	внутренняя	2403978.2817	388.7169	отправлена	\N
3402	RU8483803436528403655778834568144	643	2023-10-11	VN8427265479383740892436435	внутренняя	624913.2562	574.9529	доставлена	\N
3403	RU8483803436562780872181379760829	356	2023-10-23	RU4329067075026010773745133	внутренняя	589312.2977	444.8361	отправлена	\N
3404	RU9583803436537234117226554935344	643	2023-11-16	RU1983803436558651220197686454204	внутренняя	2481615.8412	574.2249	отменена	\N
3405	RU9483803436521022327823815694666	156	2023-02-05	VN4126694196381354604598807	международная	1250742.6717	559.0794	доставлена	BKCHCNBJ
3406	RU2683803436575198696607383546599	156	2023-01-10	RU3851775245782358181757994	внутренняя	4802651.4129	862.3422	отменена	\N
3407	RU9083803436513364676730542126445	840	2023-12-15	ES2661375728865114303021606	международная	4286121.3879	834.8283	отменена	IRVTUS3NXXX
3408	RU4683803436521950147450839996450	356	2022-12-30	PT9749359059708553102653498	международная	5746761.2272	241.8915	отменена	SBININBBXXX
3409	RU9083803436548965374028188380728	643	2023-01-17	BY6643711337041861181550244	внутренняя	3502597.0648	346.8725	доставлена	\N
3410	RU7683803436578953117174553181317	978	2023-12-12	RU7683803436578953117174553181317	внутренняя	3892794.8911	962.5931	доставлена	\N
3411	RU4983803436534576819154749347962	398	2023-01-27	PT7259348327392049972263748	международная	3920184.4883	812.7524	отменена	CASPKZKAXXX
3412	RU7783803436520045957277741704368	398	2023-12-07	RU4683803436584135461455281070651	внутренняя	350850.3154	903.8018	отменена	\N
3413	RU9683803436571883645805733128714	156	2023-09-17	BY4655153412082128018767549	международная	3724495.0613	152.6930	доставлена	BKCHCNBJ
3414	RU3383803436530100232705488681423	643	2023-05-23	RU2883803436512412400998624231254	внутренняя	4195736.4880	127.7801	отменена	\N
3415	RU5183803436588244188761426669013	356	2023-09-18	RU1983803436510686315036595318873	внутренняя	4738067.5935	224.6506	доставлена	\N
3416	RU9483803436521022327823815694666	978	2023-05-23	RU6283803436541447099313442593938	внутренняя	7581050.5722	116.1887	отправлена	\N
3417	RU5183803436531460410872953149827	156	2023-12-06	RU4583803436567844239839748091371	внутренняя	7502396.1002	72.2739	отменена	\N
3418	RU7083803436565850801859363291526	643	2023-11-20	RU2183803436535230801413319305895	внутренняя	8210979.1288	919.1565	отменена	\N
3419	RU4983803436522833268295991391237	978	2023-07-30	ES7593088479487044345632537	международная	8723713.6923	831.5121	доставлена	RZBAATWW
3420	RU1983803436549890414007715363567	156	2023-09-13	DE8683112829635552345392372	международная	759651.0345	24.0418	доставлена	BKCHCNBJ
3421	RU8683803436558409197465918354522	156	2023-08-05	RU1183803436512373318427988836252	внутренняя	3168907.4505	374.7335	отправлена	\N
3422	RU6083803436557649065533492172245	840	2023-12-07	RU3083803436572725983728902081378	внутренняя	8201751.9631	546.0355	доставлена	\N
3423	RU5783803436556321671762187197309	978	2023-10-11	RU9283803436581282514241262822584	внутренняя	2379544.2938	366.1924	отменена	\N
3424	RU6683803436546559918630563560759	156	2023-03-07	ES7046864451839252306595669	международная	3006011.9797	280.3045	отменена	BKCHCNBJ
3425	RU2083803436593214630941740939011	156	2023-07-09	RU9083803436513364676730542126445	внутренняя	2276551.3643	280.4974	доставлена	\N
3426	RU9583803436574471411467135718624	156	2023-08-24	RU9383803436568402663247236595753	внутренняя	6863473.6154	815.8050	отменена	\N
3427	RU2583803436569716293278278112122	356	2023-06-26	RU2083803436517185898516741185299	внутренняя	5432743.5299	350.5736	отменена	\N
3428	RU2683803436566742853200336170327	840	2023-10-05	KZ1537212194502231264166045	международная	9691006.8808	659.7004	отправлена	IRVTUS3NXXX
3429	RU3983803436583730529285495292571	840	2023-08-20	BY1815951116247547844773005	международная	5851438.2029	726.9244	отменена	CHASUS33
3430	RU3883803436559428008275215914286	840	2023-08-28	RU4383803436597428452957764955765	внутренняя	1020239.6999	321.7993	доставлена	\N
3431	RU1183803436536239647096212180861	840	2023-10-23	RU1683803436596193217028081534610	внутренняя	4052735.5102	13.7403	доставлена	\N
3432	RU1883803436562141776165180370424	356	2023-02-16	VN5784485556375386628464406	международная	3960803.6192	955.6237	доставлена	SBININBBXXX
3433	RU4983803436534576819154749347962	840	2023-05-25	IN6799200977437916614367445	международная	6021286.6706	831.2323	отправлена	IRVTUS3NXXX
3434	RU9383803436546841675173507423577	398	2023-01-24	PT2418959741142745694642678	международная	9182252.0255	994.3992	отменена	CASPKZKAXXX
3435	RU8683803436511417676206561932357	978	2023-12-04	ES4836030934444479821816246	международная	3583385.7067	864.9837	отправлена	SOGEFRPP
3436	RU3683803436583826961336736431806	840	2023-02-11	RU5083803436521160540176223483455	внутренняя	67003.0126	457.5709	отправлена	\N
3437	RU5983803436513359014201161572816	978	2023-01-22	VN2473129236902903524168465	международная	1865287.1062	401.4131	доставлена	SOGEFRPP
3438	RU9983803436588442958405952112241	356	2023-03-04	PT2928056089597915760938380	международная	3320996.3573	313.4197	доставлена	SBININBBXXX
3439	RU2083803436571871160330810400191	356	2023-10-10	RU1183803436536239647096212180861	внутренняя	7151828.6479	670.3681	отменена	\N
3440	RU9883803436597607312145326011401	156	2023-01-05	ES8852072231520271560042291	международная	8781908.9335	554.3741	отменена	BKCHCNBJ
3441	RU8383803436554622159366581134752	643	2023-03-06	RU8283803436517214496879594083501	внутренняя	5750566.5575	446.6652	отправлена	\N
3442	RU6283803436561107985248905256058	356	2023-09-16	RU9283803436560888794155508079505	внутренняя	7504555.6548	145.4057	отправлена	\N
3443	RU5783803436523742307313248220811	840	2023-08-22	BY4876988854395804004613970	международная	642574.2529	523.6223	отменена	CHASUS33
3444	RU3183803436538368625987340316428	398	2023-08-31	RU4778244135523544024508964	внутренняя	7446938.8265	792.8571	доставлена	\N
3445	RU5183803436599553165549416662045	156	2023-02-02	IN2531971866158307391495349	международная	7480413.1383	0.0000	отправлена	BKCHCNBJ
3446	RU2983803436597155052344917689453	643	2023-06-04	RU2083803436593214630941740939011	внутренняя	4684841.3634	754.6587	отменена	\N
3447	RU2083803436571871160330810400191	398	2023-05-05	RU6983803436521001508692071958064	внутренняя	4736656.8086	982.5003	отправлена	\N
3448	RU8983803436550652073660555482382	398	2023-11-29	RU2983803436597155052344917689453	внутренняя	1482780.2405	476.7332	отменена	\N
3449	RU4083803436534430125114460530795	978	2023-02-19	KZ2753022818521900547562465	международная	4476348.2927	749.5896	отправлена	DEUTDEFFXXX
3450	RU3883803436564256045508064629374	643	2023-12-10	RU9083803436513364676730542126445	внутренняя	2237991.4350	691.1112	отменена	\N
3451	RU3183803436538368625987340316428	356	2023-07-12	KZ5370531854939407607827700	международная	6128231.0470	886.9947	доставлена	SBININBBXXX
3452	RU6083803436557649065533492172245	643	2023-07-02	DE7311802684282045194768802	внутренняя	5026011.9198	631.3803	отправлена	\N
3453	RU2683803436575198696607383546599	356	2023-07-31	BY8375477111608426687675406	международная	5013749.6586	577.6387	доставлена	SBININBBXXX
3454	RU9983803436521153026985692784451	643	2023-03-21	RU8483803436586135450040789229889	внутренняя	6063550.9528	363.4921	отправлена	\N
3455	RU8083803436548053884024737088236	978	2023-02-16	IN1525183957893075552922550	международная	3494263.4624	97.5886	отменена	DEUTDEFFXXX
3456	RU1983803436568263609873115174417	156	2023-01-19	PT4155512572969041588382591	международная	2835745.6782	950.8341	доставлена	BKCHCNBJ
3457	RU7883803436577262824038798840088	356	2023-05-05	ES3913837369447837587943493	международная	4293285.4476	98.4299	доставлена	SBININBBXXX
3458	RU6983803436550083462130199504453	156	2023-09-26	RU7783803436536804517087406327796	внутренняя	9738331.3578	767.3109	отправлена	\N
3459	RU2583803436573489146610412814439	398	2023-08-20	KZ9919554887203851085959658	международная	9038041.4300	179.1912	доставлена	CASPKZKAXXX
3460	RU6583803436552414284054924599360	156	2023-05-03	PT3881132349237030168291925	международная	6810682.1707	296.0400	отправлена	BKCHCNBJ
3461	RU5883803436571013870275428717873	978	2023-07-20	IN8448116833275663852197071	международная	9280115.5461	298.0576	отправлена	RZBAATWW
3462	RU6383803436541953279771793851240	156	2023-06-30	ES5911831558883585693057861	международная	1267883.9580	853.8677	отменена	BKCHCNBJ
3463	RU1683803436536773128968824249362	156	2023-10-27	IN3981179275454372216141697	международная	6896913.8831	660.4727	отменена	BKCHCNBJ
3464	RU7783803436529059332090835348557	156	2023-06-30	KZ2575782703388256132864097	международная	9254880.8505	541.9417	отменена	BKCHCNBJ
3465	RU1683803436510344781123537250392	156	2023-09-25	IN1733141336036361611718155	международная	1743421.0670	541.0949	доставлена	BKCHCNBJ
3466	RU1983803436592911874717339237016	978	2023-04-06	RU7283803436551671539996901196859	внутренняя	2272164.0975	404.8219	отменена	\N
3467	RU3883803436564256045508064629374	156	2023-10-15	RU6983803436580831999013679742086	внутренняя	2364159.3248	121.6979	отменена	\N
3468	RU8283803436558421168306139201398	840	2023-01-25	IN2573766224017051009415503	международная	2247943.9987	718.0180	доставлена	CHASUS33
3469	RU5483803436549562102902686014927	840	2023-09-04	RU1583803436513968949783488654583	внутренняя	4182276.3599	741.4314	отправлена	\N
3470	RU3783803436562091905141244310726	156	2023-06-27	AD9272963685313814097658353	международная	5949734.0134	833.2528	доставлена	BKCHCNBJ
3471	RU7583803436593274051968042799324	840	2023-09-08	KZ6532317466762086625012067	международная	3377439.0197	563.9719	отправлена	IRVTUS3NXXX
3472	RU5183803436523181844916432548416	356	2023-08-28	RU5183803436588801456118987264753	внутренняя	5886748.8424	676.4215	отменена	\N
3473	RU5883803436549838724600410631189	356	2023-06-22	RU3783803436562091905141244310726	внутренняя	5448168.4279	419.1197	отменена	\N
3474	RU6983803436582618731634671628237	978	2023-10-15	RU3883803436554504516286459147223	внутренняя	1932147.5328	150.6088	отправлена	\N
3475	RU6283803436541447099313442593938	978	2023-03-07	RU3683803436542925451475324573982	внутренняя	1183696.8067	927.0898	отменена	\N
3476	RU6783803436527708547728704282997	840	2023-07-24	VN3216815272575303433174015	международная	7031803.4435	44.5235	доставлена	IRVTUS3NXXX
3477	RU2083803436593214630941740939011	978	2023-07-17	PT7661416769674502663009594	международная	5125476.0726	347.5464	отменена	SOGEFRPP
3478	RU4083803436523112590591409946049	156	2023-03-08	RU6383803436541953279771793851240	внутренняя	6794459.9060	879.4018	отправлена	\N
3479	RU4283803436530972916151822377436	978	2023-12-07	RU5483803436547543071206231343471	внутренняя	7435778.4586	962.5470	отправлена	\N
3480	RU2883803436510195395163379960366	840	2023-03-30	RU3083803436556733352794187735054	внутренняя	6961366.6191	577.6834	отправлена	\N
3481	RU2883803436512412400998624231254	643	2023-09-23	RU9083803436548965374028188380728	внутренняя	1559432.2046	346.4538	отправлена	\N
3482	RU8483803436597380246113206833117	840	2023-05-17	DE9690539364836472673294188	международная	6988086.9110	20.7248	отменена	IRVTUS3NXXX
3483	RU6483803436531317735484528392559	643	2023-03-30	RU7483803436591068390387769478580	внутренняя	1394606.5036	526.7271	отменена	\N
3484	RU1983803436592911874717339237016	978	2023-07-18	VN2734972656185104805619205	международная	5051085.6763	539.3217	отправлена	SOGEFRPP
3485	RU1583803436575905915250327615306	356	2023-10-31	IN4731516736152726216579159	международная	6468262.4738	733.5820	отправлена	SBININBBXXX
3486	RU2583803436511360000518303822185	156	2023-04-24	RU7583803436545511345420608427589	внутренняя	3702424.4130	637.4698	отправлена	\N
3487	RU8583803436590890149305918634043	978	2023-11-20	IN5875429187017262117019305	международная	4347491.1127	855.4005	доставлена	SOGEFRPP
3488	RU4783803436576956010684046744289	398	2023-01-14	RU6683803436563942598707878107815	внутренняя	9005394.5302	306.0113	отменена	\N
3489	RU6083803436582119843499506879640	643	2023-04-04	RU9383803436587347167184231490115	внутренняя	4726646.8654	738.5769	отправлена	\N
3490	RU2383803436518501918755699207235	643	2023-09-29	RU4583803436588661449801193641363	внутренняя	1460725.7890	316.7477	отправлена	\N
3491	RU2383803436518501918755699207235	840	2023-03-19	RU1183803436541561390025398925839	внутренняя	7545918.5429	388.8977	отменена	\N
3492	RU3783803436562091905141244310726	156	2023-06-28	AL3462084691727240283094644	международная	8749171.3729	223.9926	отправлена	BKCHCNBJ
3493	RU4583803436571583967013936520660	840	2023-01-19	AL7193029025152568961257278	международная	2642580.3540	787.0608	доставлена	CHASUS33
3494	RU7483803436529598231033100377224	356	2023-10-30	RU9283803436529032721317031749293	внутренняя	2394089.1972	129.7417	отменена	\N
3495	RU2483803436537933507280624045523	840	2023-02-10	DE2566288837414162898298756	международная	4416166.7716	114.2886	отправлена	CHASUS33
3496	RU5183803436588801456118987264753	840	2023-10-05	AD4233924223207985833019909	международная	5160551.5156	670.2700	отправлена	CHASUS33
3497	RU6183803436555838927651384339574	840	2023-05-04	RU9383803436587347167184231490115	внутренняя	8596540.8965	932.0692	отправлена	\N
3498	RU4383803436586323329892508459044	356	2023-09-04	IN2914168143729210382941998	международная	9299731.7759	746.2673	доставлена	SBININBBXXX
3499	RU1183803436512373318427988836252	840	2023-02-09	RU7795035785613676163938181	внутренняя	5805272.0432	558.3821	отправлена	\N
3500	RU3383803436551883036237842733910	156	2023-10-17	AD7056030074457655418745481	международная	3345014.7802	219.9398	отменена	BKCHCNBJ
3501	RU6183803436556503720110500069421	978	2023-08-13	VN2366129288145404051278179	международная	629480.7404	476.5641	отменена	DEUTDEFFXXX
3502	RU2083803436517185898516741185299	156	2023-06-18	RU6483803436599929208547720213297	внутренняя	8197436.8522	828.8264	доставлена	\N
3503	RU7783803436529059332090835348557	978	2023-04-17	AD7478731803383652936619790	международная	8879831.4129	165.8937	отменена	RZBAATWW
3504	RU4083803436526038486689011711230	356	2023-09-15	RU1183803436536239647096212180861	внутренняя	2900958.2685	827.4865	отправлена	\N
3505	RU2883803436564862346362051659673	156	2023-06-17	PT5886517707534311457189373	международная	5885083.3742	676.1419	доставлена	BKCHCNBJ
3506	RU8383803436583878629872361871714	356	2023-03-24	RU2983803436530272226005609138408	внутренняя	2633825.2996	408.4702	доставлена	\N
3507	RU5783803436598085342824416355658	840	2023-02-13	RU9683803436559214297350823715344	внутренняя	388962.2909	91.6328	доставлена	\N
3508	RU3783803436585191546282680625888	398	2023-10-19	KZ1141662449039737361679397	международная	4658477.9206	652.7058	отправлена	CASPKZKAXXX
3509	RU4083803436525661046500520760430	156	2023-02-07	RU5483803436551418630110242560620	внутренняя	5650888.7061	177.4387	отправлена	\N
3510	RU2183803436586747579379810386651	978	2023-03-19	RU3383803436533625475503259998648	внутренняя	8936726.1201	612.1306	доставлена	\N
3511	RU7383803436567535429961689788567	398	2023-01-09	RU6783803436527708547728704282997	внутренняя	653067.6081	500.0400	отменена	\N
3512	RU5283803436570838144716210841495	978	2023-04-03	IN6533311255252842038050394	международная	6650753.3642	755.3388	отменена	RZBAATWW
3513	RU8583803436548069379320039967893	356	2023-07-02	KZ8910030499867156371586084	международная	1417940.2612	712.5374	отправлена	SBININBBXXX
3514	RU9183803436523189940915642395180	356	2023-03-12	RU3883803436515226766320509995235	внутренняя	1409477.6396	942.0993	отправлена	\N
3515	RU1583803436578714315409224923820	356	2023-12-23	IN4764789566084128499869466	международная	6595989.5879	91.4703	доставлена	SBININBBXXX
3516	RU4583803436546993711061481413708	156	2023-05-16	PT4462533311813800209303257	международная	2992682.1793	734.0980	доставлена	BKCHCNBJ
3517	RU6983803436518663051613263930888	156	2023-05-31	AD2440958135406168432444558	международная	9181901.6654	902.1090	доставлена	BKCHCNBJ
3518	RU2583803436511360000518303822185	398	2023-07-05	DE1935920681116856863410797	международная	4569309.6902	594.6887	отменена	CASPKZKAXXX
3519	RU6183803436555838927651384339574	356	2023-04-18	RU4583803436546993711061481413708	внутренняя	3516251.4108	33.2434	отправлена	\N
3520	RU9083803436548965374028188380728	398	2023-06-17	IN1977440241293167813157132	международная	380034.4473	210.3259	доставлена	CASPKZKAXXX
3521	RU8583803436590890149305918634043	840	2023-04-05	IN3373603527660079544651067	международная	1454357.5451	995.4308	отменена	IRVTUS3NXXX
3522	RU3283803436579852018195047883736	156	2023-01-24	RU8783803436544746989208687599320	внутренняя	2323974.8726	519.8124	доставлена	\N
3523	RU1183803436513944372774322746458	643	2023-04-12	RU8883803436542351475891948314875	внутренняя	3887168.3842	496.6112	доставлена	\N
3524	RU4583803436588661449801193641363	978	2023-08-18	RU3083803436572725983728902081378	внутренняя	2721004.5217	155.9783	отменена	\N
3525	RU5483803436538988818998904026382	398	2023-09-01	BY9419448051371792774996358	международная	7428883.8009	272.1010	отправлена	CASPKZKAXXX
3526	RU2083803436573246597416370413406	643	2023-09-27	VN2889609602000510003330461	внутренняя	5053978.9595	527.9786	отправлена	\N
3527	RU6583803436552414284054924599360	356	2023-11-03	VN3517853654155789027374734	международная	6218743.3429	989.7886	отправлена	SBININBBXXX
3528	RU9083803436513364676730542126445	643	2023-06-16	KZ7623048662491584499732852	внутренняя	274929.1208	672.5921	отменена	\N
3529	RU3683803436533022850683714599602	398	2023-06-07	AL3270557131617014955562925	международная	3096610.0110	211.5376	доставлена	CASPKZKAXXX
3530	RU2483803436550335144467075253432	356	2023-03-12	AL1377140237164058634818901	международная	4266835.2980	773.2264	доставлена	SBININBBXXX
3531	RU7383803436534050516387288663509	398	2023-04-14	RU8883803436592173067148862634991	внутренняя	6456770.6215	46.8918	отправлена	\N
3532	RU4983803436534576819154749347962	356	2023-07-08	AD1573657947864675678960935	международная	4170888.6872	21.7932	отменена	SBININBBXXX
3533	RU5583803436516539388298963058164	398	2023-11-13	AD3535610044132456464908452	международная	525660.1887	374.0863	доставлена	CASPKZKAXXX
3534	RU9083803436513364676730542126445	398	2023-01-28	AD3178153741654690672772271	международная	9106312.5495	45.5385	доставлена	CASPKZKAXXX
3535	RU8083803436567877444686336475183	978	2023-06-16	RU5783803436556321671762187197309	внутренняя	5885879.1636	224.8149	доставлена	\N
3536	RU3683803436542925451475324573982	643	2023-04-12	RU8983803436551003507571679577910	внутренняя	9904906.1884	94.9066	отправлена	\N
3537	RU1683803436596193217028081534610	643	2023-09-23	AD6019662365120288095202906	внутренняя	7979786.4326	218.9960	доставлена	\N
3538	RU6483803436513432249664452306210	978	2023-09-17	IN6969632054016581033407599	международная	2014476.2034	483.5785	отменена	DEUTDEFFXXX
3539	RU5683803436573106663960342062340	840	2023-08-28	PT2837648133592579025219374	международная	5388668.0664	652.3485	отменена	CHASUS33
3540	RU6383803436517724803474176712817	978	2023-09-04	RU2783803436580745382811010865973	внутренняя	6187890.1263	907.7443	отменена	\N
3541	RU4083803436565489336932623834655	643	2023-01-02	RU7183803436546875767014611813689	внутренняя	2921241.8654	372.3395	отправлена	\N
3542	RU4083803436530357399673623809331	643	2023-12-10	RU8783803436519169154241731281817	внутренняя	4213996.9055	323.8009	доставлена	\N
3543	RU1583803436597114679330016317094	978	2023-10-06	RU4083803436526038486689011711230	внутренняя	9136225.9456	660.2907	отправлена	\N
3544	RU6583803436592149423686806465410	978	2023-09-11	RU2283803436527235231809863175226	внутренняя	5019707.4070	750.3976	доставлена	\N
3545	RU8683803436520349379894661014091	840	2023-02-01	AL3550636216936323109286986	международная	4010566.7069	451.6203	доставлена	IRVTUS3NXXX
3546	RU5983803436518386216122030936247	840	2023-03-19	VN6079253123620987245178764	международная	7937982.9462	941.6627	отправлена	IRVTUS3NXXX
3547	RU7683803436565241249132549566386	356	2023-01-07	RU8283803436536082355231514909614	внутренняя	6675950.9581	858.7355	отправлена	\N
3548	RU7083803436575256167282941443393	643	2023-05-09	RU7783803436557425582753958788900	внутренняя	4152290.0267	972.4568	отменена	\N
3549	RU6483803436599929208547720213297	156	2023-02-19	RU9083803436542335742968981386823	внутренняя	4908041.1751	408.1104	доставлена	\N
3550	RU3483803436534657689181631833463	978	2023-03-21	RU3283803436579852018195047883736	внутренняя	9642682.5823	222.1642	отменена	\N
3551	RU7183803436584925378313266803439	978	2023-06-04	DE5983746488517459981536794	международная	4600670.2866	645.0363	отправлена	SOGEFRPP
3552	RU5783803436598085342824416355658	840	2023-10-03	BY7638333716995975461581389	международная	9205216.1019	545.9957	отправлена	IRVTUS3NXXX
3553	RU3683803436542925451475324573982	156	2023-06-16	RU5783803436568341660520010753753	внутренняя	4078717.4162	314.4157	отменена	\N
3554	RU3683803436583826961336736431806	356	2023-04-20	KZ4496339757671818639852819	международная	3408580.0814	406.7036	отменена	SBININBBXXX
3555	RU2283803436594102552659582448178	156	2023-04-12	IN4287142497642376296751150	международная	9387476.7278	76.1824	доставлена	BKCHCNBJ
3556	RU5583803436556151120487866130687	978	2023-10-02	RU5883803436551017474710608700284	внутренняя	6307763.1045	808.9186	доставлена	\N
3557	RU4183803436512683300418013703414	156	2023-08-05	VN4899259382866982915703245	международная	2318335.0817	69.6350	отправлена	BKCHCNBJ
3558	RU3383803436548623436381587682007	398	2023-08-19	RU9483803436588743613330942629999	внутренняя	8770156.3365	489.3966	доставлена	\N
3559	RU7083803436565850801859363291526	978	2023-02-21	RU6583803436546434088553514688778	внутренняя	6896749.9308	861.5935	доставлена	\N
3560	RU1383803436537041354890218533954	840	2023-10-28	IN2320894174839284880775281	международная	6527973.0597	738.8622	доставлена	CHASUS33
3561	RU9283803436581282514241262822584	643	2023-10-15	RU5683803436522754650880470438385	внутренняя	1979804.7257	171.9453	доставлена	\N
3562	RU2483803436537933507280624045523	978	2023-04-22	VN6867214498477720642680287	международная	6600178.1458	219.5618	отправлена	RZBAATWW
3563	RU4983803436522833268295991391237	356	2023-07-31	AD9155651838506589343028555	международная	6823951.1622	56.1249	доставлена	SBININBBXXX
3564	RU8283803436593409912626065485368	643	2023-07-17	RU2983803436572636545308279163382	внутренняя	4986639.7714	468.1954	доставлена	\N
3565	RU5983803436565674700991182664479	356	2023-02-03	AL9827614388631023267328322	международная	8751935.5545	843.4692	отменена	SBININBBXXX
3566	RU2983803436510489846489627969282	978	2023-10-29	VN7026082308630201989932414	международная	8749554.8946	963.3046	доставлена	DEUTDEFFXXX
3567	RU9083803436548965374028188380728	643	2023-12-11	RU7083803436569474567525801645267	внутренняя	7466162.8412	352.3894	отправлена	\N
3568	RU9383803436587347167184231490115	643	2023-08-04	PT4347651857750265254412209	внутренняя	3463783.9713	71.8904	отменена	\N
3569	RU8483803436523751116997614384937	398	2023-07-17	VN6292909413159045885323362	международная	2205810.3954	240.7142	доставлена	CASPKZKAXXX
3570	RU1283803436591782126481419856685	156	2023-01-02	RU3765982949534508929313164	внутренняя	5410505.0107	68.6100	отправлена	\N
3571	RU6683803436547011171926119923803	840	2023-04-04	ES2812586131903173070090578	международная	1798146.3976	253.6892	отправлена	CHASUS33
3572	RU9683803436511276549947859990709	643	2023-11-04	RU9083803436527710172880684864084	внутренняя	9197421.1532	671.9490	отменена	\N
3573	RU3683803436589669964829443545971	978	2023-04-24	ES6911299411628342161380635	международная	1526191.8737	600.2260	отменена	RZBAATWW
3574	RU5983803436518386216122030936247	156	2023-03-03	KZ5232493123063857432265669	международная	3915900.9716	370.5742	отменена	BKCHCNBJ
3575	RU3983803436583730529285495292571	643	2022-12-29	RU2383803436569895097903578030814	внутренняя	6513760.5999	589.0378	отправлена	\N
3576	RU4883803436561825246742556433732	398	2023-09-27	RU6379195097362093452429200	внутренняя	9660492.7772	784.3286	отменена	\N
3577	RU5883803436576828712243252221562	643	2023-03-08	RU1683803436543683792461716245841	внутренняя	9952744.8200	604.0784	отправлена	\N
3578	RU8983803436518961229187913059129	398	2023-05-10	RU5683803436539120556194350818141	внутренняя	9153487.1450	573.1655	доставлена	\N
3579	RU4583803436576777630615652907536	398	2023-08-16	RU6983803436521001508692071958064	внутренняя	6779098.4924	837.8100	отправлена	\N
3580	RU8183803436584325139466333599286	643	2023-03-25	VN6499173682717735966128490	внутренняя	2669101.3793	168.5257	отправлена	\N
3581	RU8983803436550652073660555482382	356	2023-09-18	RU9683803436559214297350823715344	внутренняя	2517530.6674	863.5449	отправлена	\N
3582	RU9283803436560888794155508079505	978	2023-03-13	RU3583803436543438797337964557116	внутренняя	6105935.7258	892.5485	отправлена	\N
3583	RU3383803436548623436381587682007	840	2023-09-23	RU2983803436510489846489627969282	внутренняя	1693040.2670	928.5840	отправлена	\N
3584	RU7183803436584925378313266803439	156	2023-04-19	KZ9512339809222703413750624	международная	1972650.3716	132.7088	отменена	BKCHCNBJ
3585	RU4683803436521950147450839996450	356	2023-01-14	RU5583803436525031727011657164177	внутренняя	6773733.3234	653.4423	доставлена	\N
3586	RU1583803436597114679330016317094	978	2023-09-26	RU1683803436549082108439124677076	внутренняя	7734947.2113	516.6443	отправлена	\N
3587	RU4583803436535138140020222748384	356	2023-02-01	RU3683803436542925451475324573982	внутренняя	9009718.1536	601.1368	отменена	\N
3588	RU4883803436561825246742556433732	643	2023-07-21	RU9583803436562562119396535016715	внутренняя	9428738.4946	523.3763	отменена	\N
3589	RU1083803436516100547774990634896	978	2023-09-11	RU9183803436594783043422280553530	внутренняя	3508547.5819	69.1168	отправлена	\N
3591	RU5183803436588244188761426669013	356	2023-03-11	PT9182395302820231636546425	международная	7517586.4182	400.1990	отправлена	SBININBBXXX
3592	RU1383803436585969091171133733533	398	2023-03-22	BY2112019149139175677492051	международная	2929181.5818	543.9703	отправлена	CASPKZKAXXX
3593	RU4383803436535637847836978327691	978	2023-03-30	KZ6018419201211075034754254	международная	9173210.1200	910.3247	отменена	SOGEFRPP
3594	RU6583803436546434088553514688778	978	2023-01-15	RU4483803436574648344464338946055	внутренняя	8874464.4965	65.4750	доставлена	\N
3595	RU4383803436538414207445829899653	356	2023-12-02	RU9483803436522220035875117822565	внутренняя	3898147.3115	182.9396	отменена	\N
3596	RU1083803436516100547774990634896	356	2023-01-18	AL2116105149485312951988444	международная	1277369.2616	759.8236	доставлена	SBININBBXXX
3597	RU1983803436558651220197686454204	840	2023-12-08	ES3771233504739274974839577	международная	6547716.8436	0.0000	отменена	CHASUS33
3598	RU2983803436572636545308279163382	643	2023-08-11	VN7352598794709580640326977	внутренняя	770715.6152	586.4342	доставлена	\N
3599	RU5983803436518386216122030936247	356	2023-06-27	AD2837114698320449362234349	международная	3774081.3840	998.4397	отменена	SBININBBXXX
3600	RU4283803436515276086545867508581	978	2023-04-19	IN7532350578453887772455716	международная	1549590.1929	772.1892	отправлена	SOGEFRPP
3601	RU3683803436589669964829443545971	643	2023-06-19	RU7483803436529598231033100377224	внутренняя	7976214.9524	848.4559	отменена	\N
3602	RU4483803436537144245226352938256	398	2023-12-25	RU2083803436536025786076127901648	внутренняя	9733673.3061	696.7703	доставлена	\N
3603	RU8783803436544746989208687599320	840	2023-02-27	RU9883803436596118671708861810646	внутренняя	6798363.5440	478.0030	отменена	\N
3604	RU9883803436510697875492928159959	643	2023-06-11	RU4726316559844769210341671	внутренняя	497118.2949	136.7174	отменена	\N
3605	RU7183803436513501317784267991188	978	2023-12-03	RU3383803436530100232705488681423	внутренняя	7607009.0518	608.8602	отменена	\N
3606	RU8983803436550652073660555482382	356	2023-08-05	KZ3575251604165768004881965	международная	3565846.0307	620.7640	доставлена	SBININBBXXX
3607	RU7483803436512314763652680872976	398	2023-09-28	DE8133833309291382709647861	международная	7378573.3588	559.7398	отменена	CASPKZKAXXX
3608	RU3983803436583094600516227232333	840	2023-11-10	VN1427219258229843952666877	международная	2902356.6690	894.0603	доставлена	CHASUS33
3609	RU3883803436571430516571621799878	156	2023-03-14	IN5725378192381843568160911	международная	5440167.4811	40.8326	доставлена	BKCHCNBJ
3610	RU3683803436526413764026311806751	840	2023-08-15	RU4683803436521950147450839996450	внутренняя	8808783.9755	471.7758	отменена	\N
3611	RU8883803436592173067148862634991	978	2023-03-03	RU7383803436569356631218275502161	внутренняя	9386692.6811	249.8054	отправлена	\N
3612	RU4283803436583191860084907222827	156	2023-12-18	RU4983803436548786021946522460624	внутренняя	7414146.7694	63.5468	отправлена	\N
3613	RU9183803436594783043422280553530	840	2023-10-19	PT3846083963550576560613222	международная	2495809.2334	292.2425	доставлена	IRVTUS3NXXX
3614	RU1583803436592948110594062864167	356	2023-06-19	RU3683803436589669964829443545971	внутренняя	1821706.8062	785.0689	доставлена	\N
3615	RU9783803436586848496167067081204	156	2022-12-28	RU8220545735277710147650931	внутренняя	3090771.6232	352.8132	отправлена	\N
3616	RU3383803436530100232705488681423	356	2023-12-20	IN1797860081025788874852060	международная	3730340.7487	215.8593	отправлена	SBININBBXXX
3617	RU4283803436583191860084907222827	398	2023-09-10	KZ1655991213846303862446469	международная	9443091.8690	341.1187	доставлена	CASPKZKAXXX
3618	RU9283803436560888794155508079505	643	2023-09-19	DE7581037999534336938023396	внутренняя	3629833.8287	501.0995	отменена	\N
3619	RU4483803436593534887929979895004	156	2023-01-22	RU8983803436551003507571679577910	внутренняя	6531534.9186	171.1883	отправлена	\N
3620	RU5383803436532276110708298062956	840	2023-06-16	BY4940786901517525090219816	международная	8423625.1954	99.9143	доставлена	IRVTUS3NXXX
3621	RU7683803436578953117174553181317	840	2023-10-16	RU3183803436538368625987340316428	внутренняя	1128748.2360	630.9862	отправлена	\N
3622	RU5183803436573013692902081587761	156	2023-09-19	AL1980800789804269974310260	международная	9041434.1222	164.4338	отправлена	BKCHCNBJ
3623	RU5783803436556321671762187197309	643	2023-06-21	KZ3575161504596621327073397	внутренняя	3033529.0397	507.8063	отменена	\N
3624	RU3083803436518573891716312234719	643	2023-01-31	RU5683803436573106663960342062340	внутренняя	9707898.7514	733.3587	отправлена	\N
3625	RU5583803436533254773648721597711	840	2023-02-19	RU9683803436579408636311341559980	внутренняя	5446260.4475	275.6411	отправлена	\N
3626	RU7383803436534050516387288663509	356	2023-11-01	RU4883803436561825246742556433732	внутренняя	2974278.7437	610.0830	отправлена	\N
3627	RU2283803436551819000625747494652	356	2023-02-14	RU9312588792265022302536421	внутренняя	7604002.0769	292.1346	отменена	\N
3628	RU1383803436523658112524214881297	156	2023-02-12	RU8783803436519169154241731281817	внутренняя	1143537.8069	508.9315	доставлена	\N
3629	RU3983803436583730529285495292571	643	2023-04-21	KZ7884986974091456424339522	внутренняя	6037292.9309	844.4272	доставлена	\N
3630	RU2883803436538134433783624054557	356	2023-09-23	IN7442342089518944446137753	международная	2958717.3205	862.3538	доставлена	SBININBBXXX
3631	RU9383803436575688788160155647011	356	2023-10-02	RU6483803436595566817980742907742	внутренняя	5017153.6324	29.9875	доставлена	\N
3632	RU8383803436543267469021061769102	978	2023-09-11	RU7325715091669196150082625	внутренняя	6045487.4224	994.1102	доставлена	\N
3633	RU6083803436583599210196850890015	398	2023-12-19	AD4844830679832043249526243	международная	3370116.9607	299.9972	отменена	CASPKZKAXXX
3634	RU8583803436598717986670697262250	398	2023-06-03	RU1383803436537041354890218533954	внутренняя	9208856.3768	364.0956	доставлена	\N
3635	RU9683803436559214297350823715344	398	2023-06-04	RU7583803436593621382878998665048	внутренняя	9002085.2711	973.5600	отправлена	\N
3636	RU6583803436546434088553514688778	356	2023-04-23	ES1753463078552635999491289	международная	6662059.8580	79.6882	отправлена	SBININBBXXX
3637	RU1983803436568263609873115174417	156	2023-12-04	RU7583803436593621382878998665048	внутренняя	121848.9754	287.2476	доставлена	\N
3638	RU3083803436572725983728902081378	156	2023-11-08	RU2083803436573246597416370413406	внутренняя	697062.9505	833.6454	отменена	\N
3639	RU5983803436585678890114061651314	356	2023-08-06	RU7683803436589524723383129532286	внутренняя	1775219.7974	433.1500	доставлена	\N
3640	RU2483803436559904294875702128517	840	2023-07-29	RU9083803436513364676730542126445	внутренняя	4605292.1787	666.9692	доставлена	\N
3641	RU2783803436529440294678710752920	398	2023-02-05	RU9783803436566819882292917709885	внутренняя	4695164.4191	40.2037	отменена	\N
3642	RU8383803436557193853878723819444	156	2023-03-15	DE3652881318663495164947251	международная	5640235.9275	627.1591	отменена	BKCHCNBJ
3643	RU5683803436575772290627280121203	398	2023-10-28	KZ6073142019199133116710286	международная	2132683.2226	292.5159	отправлена	CASPKZKAXXX
3644	RU7483803436595528340078834029783	840	2023-03-25	RU1317269036236862911638331	внутренняя	2417996.3356	628.2573	отправлена	\N
3645	RU7483803436512314763652680872976	356	2023-01-15	AD6414496675108521273345335	международная	606375.5343	297.9675	доставлена	SBININBBXXX
3646	RU6483803436527000884469712767990	156	2023-11-12	RU7883803436577262824038798840088	внутренняя	4651225.9255	581.4618	отменена	\N
3647	RU2183803436538160023828199079683	156	2023-07-13	RU1183803436541561390025398925839	внутренняя	1838796.1389	944.3822	отменена	\N
3648	RU6483803436575827628326698282321	643	2023-10-16	RU7483803436544936047225386728318	внутренняя	5065635.0117	790.7471	доставлена	\N
3649	RU6083803436583599210196850890015	398	2023-08-25	KZ1646129192574736050300821	международная	8439301.9056	768.7047	отправлена	CASPKZKAXXX
3650	RU3283803436579852018195047883736	978	2023-06-26	RU7483803436516612664745741202549	внутренняя	2346224.4733	474.6764	отменена	\N
3651	RU3683803436533022850683714599602	156	2023-10-15	RU3383803436540416635821116917223	внутренняя	9777496.2247	268.7122	отменена	\N
3652	RU4283803436530972916151822377436	643	2023-07-01	RU5083803436521160540176223483455	внутренняя	829864.3033	269.2131	отправлена	\N
3653	RU1983803436537997284898110055528	643	2023-10-17	RU8971192275692791842448462	внутренняя	4298080.8475	81.6905	доставлена	\N
3654	RU1183803436513944372774322746458	643	2023-03-25	VN8429856009910331460916098	внутренняя	7997075.4657	660.5363	отправлена	\N
3655	RU6283803436577836700807681117407	840	2023-06-22	ES2579979268726718103183768	международная	8289274.7951	664.8553	отменена	IRVTUS3NXXX
3656	RU2083803436571871160330810400191	356	2023-09-10	KZ4214658227062545077391497	международная	4871851.6486	511.9702	отменена	SBININBBXXX
3657	RU6783803436527708547728704282997	643	2023-08-30	RU2083803436571871160330810400191	внутренняя	4770143.9565	381.3238	доставлена	\N
3658	RU3083803436572725983728902081378	398	2023-03-23	RU7783803436529059332090835348557	внутренняя	7214876.5129	330.6449	отменена	\N
3659	RU6583803436565551879254347008316	978	2023-01-30	RU1983803436510686315036595318873	внутренняя	481785.9228	709.8931	доставлена	\N
3660	RU1283803436513390712190126736747	978	2023-08-29	RU6183803436551232797419519235346	внутренняя	6774099.7202	818.9740	доставлена	\N
3661	RU8483803436528403655778834568144	356	2023-10-20	PT7793389652175440100179354	международная	1154885.0155	718.7488	отправлена	SBININBBXXX
3662	RU4183803436575456526806163894045	156	2023-01-26	RU6383803436541953279771793851240	внутренняя	810871.2382	742.8203	отменена	\N
3663	RU3583803436531844714480494060517	840	2023-06-25	RU6083803436582119843499506879640	внутренняя	1082819.4384	265.9920	отменена	\N
3664	RU8483803436514025076841381077297	356	2023-01-02	RU1683803436596193217028081534610	внутренняя	3986858.8408	984.3769	отправлена	\N
3665	RU3983803436583094600516227232333	840	2023-06-13	RU6183803436556503720110500069421	внутренняя	2045044.2033	256.4429	отменена	\N
3666	RU2283803436555228451424548337941	398	2023-02-02	RU3883803436571430516571621799878	внутренняя	2868650.1565	184.9623	отправлена	\N
3667	RU5283803436570838144716210841495	156	2023-05-13	BY3137884034448858635726343	международная	5565314.7242	364.0168	доставлена	BKCHCNBJ
3668	RU5583803436556151120487866130687	840	2023-09-08	RU9583803436562562119396535016715	внутренняя	7933587.4262	156.2201	отменена	\N
3669	RU6583803436526807323529165700056	356	2023-01-27	RU6183803436571932790348770462135	внутренняя	9308579.0521	759.5460	отправлена	\N
3670	RU9683803436511276549947859990709	356	2023-02-11	RU9642306266406611518644289	внутренняя	3354709.9455	947.2320	отправлена	\N
3671	RU5583803436525031727011657164177	156	2023-09-23	ES3440471483819106859606885	международная	3435814.0418	931.4782	отправлена	BKCHCNBJ
3672	RU6383803436512605200896614597744	643	2023-01-03	RU4183803436593654490331448399606	внутренняя	7570606.1329	340.3378	отменена	\N
3673	RU8783803436562772820294479967682	398	2023-02-18	IN1471725726344529391341324	международная	4616004.6595	272.0307	отменена	CASPKZKAXXX
3674	RU5583803436544105301147510534206	398	2023-06-16	RU4883803436577275200947611443039	внутренняя	3367391.9055	395.2396	отправлена	\N
3675	RU6583803436526807323529165700056	398	2023-12-07	RU3983803436562540544761068231244	внутренняя	7347087.0051	213.8288	отменена	\N
3676	RU9583803436547610609904791788853	978	2023-10-09	RU8983803436543970357311304848339	внутренняя	1551704.4802	936.7590	доставлена	\N
3677	RU8583803436580493050529274956761	398	2023-02-18	RU1026048878980050402035332	внутренняя	5060014.1476	760.2884	отправлена	\N
3678	RU2283803436577856579987093576845	643	2023-04-24	AD8994006914984427018589066	внутренняя	2938982.2832	905.9214	отправлена	\N
3679	RU2183803436555308456329784386702	643	2023-07-11	RU5983803436563752601230784661821	внутренняя	2349011.9244	348.0125	доставлена	\N
3680	RU6683803436547011171926119923803	398	2023-04-11	KZ5435802985187057490004058	международная	7492768.5602	526.0848	доставлена	CASPKZKAXXX
3681	RU9583803436515959194321808018014	978	2023-05-24	BY4060098892164715472439895	международная	7025367.0622	857.8529	отправлена	DEUTDEFFXXX
3682	RU3383803436533625475503259998648	840	2023-04-26	RU8383803436543267469021061769102	внутренняя	375666.2395	244.8535	отменена	\N
3683	RU1283803436545193525808988988532	156	2023-04-30	RU1583803436597114679330016317094	внутренняя	4393601.7851	84.0869	отправлена	\N
3684	RU6983803436542868245387240901621	398	2023-08-15	BY4849640888206159536027439	международная	6091282.8689	79.6707	отправлена	CASPKZKAXXX
3685	RU2683803436556115738690945420927	840	2023-03-04	RU8399644487084666797650530	внутренняя	3360310.5943	145.3395	доставлена	\N
3686	RU8883803436542351475891948314875	840	2023-09-25	AD7023024508679327302977432	международная	7853804.0400	322.2744	доставлена	CHASUS33
3687	RU3783803436559423561964096195262	840	2023-03-25	RU6183803436556503720110500069421	внутренняя	8100948.9232	671.9171	отменена	\N
3688	RU3183803436522808312515599877028	840	2023-12-14	ES5532778506717969219277055	международная	9003194.8608	782.1414	доставлена	CHASUS33
3689	RU3283803436579852018195047883736	156	2023-04-20	RU5883803436549838724600410631189	внутренняя	8778405.2757	210.8387	отправлена	\N
3690	RU4583803436588661449801193641363	156	2023-04-23	DE1383712122666359744409463	международная	9777632.4906	25.3806	доставлена	BKCHCNBJ
3691	RU2183803436555308456329784386702	156	2023-08-21	AL4970383561171789617308757	международная	3641188.9112	849.6777	отменена	BKCHCNBJ
3692	RU1583803436522600904788279282430	978	2023-11-24	RU3683803436526413764026311806751	внутренняя	3270082.6710	99.1509	отправлена	\N
3693	RU9283803436564588409350021574669	156	2023-07-02	RU5883803436537252361294139722938	внутренняя	2878836.5702	284.8548	отменена	\N
3694	RU5583803436556151120487866130687	398	2023-06-04	ES3211752912207521667114829	международная	9370079.3788	311.9355	доставлена	CASPKZKAXXX
3695	RU2983803436572636545308279163382	356	2023-08-21	RU5783803436568341660520010753753	внутренняя	8917344.1470	788.4343	отменена	\N
3696	RU4683803436518754352401343547893	840	2023-01-21	IN3474873581300726313197470	международная	5536068.7067	142.2102	доставлена	CHASUS33
3697	RU2983803436539974076802515756241	840	2023-04-09	RU6583803436588261503476787515721	внутренняя	33993.2195	624.5484	отправлена	\N
3698	RU1283803436545193525808988988532	978	2023-07-25	RU1012774434749237857818620	внутренняя	53243.6103	850.8082	отменена	\N
3699	RU7483803436575212193030608824580	156	2023-02-27	IN6341005751450086781338404	международная	6181846.6575	349.2813	отправлена	BKCHCNBJ
3700	RU3183803436556325220643083039724	840	2023-02-11	KZ5993397533745126939614218	международная	4682231.7979	216.0859	отменена	CHASUS33
3701	RU2483803436563361420871450061347	398	2023-06-01	AL7388793826429639171425986	международная	9855426.3534	99.9623	доставлена	CASPKZKAXXX
3702	RU6983803436550083462130199504453	356	2023-08-12	RU5878019264722491507791488	внутренняя	3718800.0700	823.2714	отправлена	\N
3703	RU9383803436546841675173507423577	156	2023-02-02	BY8696664997298311076422995	международная	5456735.7394	165.6143	отменена	BKCHCNBJ
3704	RU6283803436577836700807681117407	978	2023-08-22	RU5783803436573951128453151787227	внутренняя	9669347.2164	382.4774	доставлена	\N
3705	RU4383803436583134155448910498762	398	2023-04-29	RU8783803436562772820294479967682	внутренняя	9056383.1082	590.3537	доставлена	\N
3706	RU4383803436594641659799774635872	398	2023-10-28	AD7883138441132718207513017	международная	1395353.5037	989.4563	доставлена	CASPKZKAXXX
3707	RU1983803436592911874717339237016	978	2023-03-02	PT7151025291560362792169460	международная	3324549.4040	631.5154	отправлена	DEUTDEFFXXX
3708	RU6583803436599318340096840026283	356	2023-11-19	RU3683803436521305656177527242839	внутренняя	4583212.2087	869.5000	отменена	\N
3709	RU4683803436521950147450839996450	398	2023-12-22	AD2121002614963009950568004	международная	5922007.0227	901.3478	доставлена	CASPKZKAXXX
3710	RU6783803436582018660242960957244	356	2023-03-09	VN1796274873285330994573079	международная	4723831.1919	823.2001	отправлена	SBININBBXXX
3711	RU3683803436521305656177527242839	356	2023-04-17	RU4583803436546993711061481413708	внутренняя	3852647.1101	463.8452	отменена	\N
3712	RU5783803436598085342824416355658	840	2023-03-29	RU6383803436519000124215462920616	внутренняя	3516992.8139	696.3105	отправлена	\N
3713	RU5183803436550941857646482749776	398	2023-09-15	RU9483803436570307762028951954874	внутренняя	3701798.6076	176.5678	доставлена	\N
3714	RU5583803436544105301147510534206	978	2023-07-02	RU1583803436513968949783488654583	внутренняя	6602449.6268	98.6435	отменена	\N
3715	RU1983803436510712914540451632365	978	2023-06-06	RU3683803436542925451475324573982	внутренняя	8386676.6735	417.5767	отменена	\N
3716	RU4583803436544769415444430855700	643	2023-11-21	PT1951574859118919339402992	внутренняя	4044763.5722	334.3130	отправлена	\N
3717	RU2783803436515955219320238454317	156	2023-05-21	IN6797346095334520501503281	международная	4146252.0745	918.8295	доставлена	BKCHCNBJ
3718	RU9783803436531316283778462589484	978	2023-06-29	RU9983803436588442958405952112241	внутренняя	7238220.6011	886.6349	отправлена	\N
3719	RU3383803436540416635821116917223	356	2023-01-18	RU8583803436580493050529274956761	внутренняя	42868.0417	697.2433	отправлена	\N
3720	RU6683803436534213789698830771682	978	2023-03-06	AL1177202088731196864610164	международная	2942730.5976	501.8411	отправлена	SOGEFRPP
3721	RU8483803436562780872181379760829	356	2023-02-12	RU7483803436591068390387769478580	внутренняя	9582446.4942	329.1772	доставлена	\N
3722	RU5783803436598085342824416355658	643	2023-08-30	RU8183803436576908594301902139271	внутренняя	3730047.7174	332.2374	отменена	\N
3723	RU6783803436534011789886956964173	156	2023-03-18	RU6983803436557684576294868357987	внутренняя	3407442.0058	104.3397	доставлена	\N
3724	RU3383803436527231938190662146888	978	2023-01-08	RU9483803436521022327823815694666	внутренняя	2431888.1720	248.6741	доставлена	\N
3725	RU8183803436566794763466227027850	840	2023-08-18	RU4483803436537144245226352938256	внутренняя	3695152.6819	599.8233	доставлена	\N
3726	RU3783803436559423561964096195262	840	2023-07-28	AL9019093073838682102041589	международная	857290.0242	51.1139	доставлена	CHASUS33
3727	RU9683803436571883645805733128714	840	2023-04-19	ES6022432909584412466699158	международная	2078568.8256	552.9946	отправлена	IRVTUS3NXXX
3728	RU8083803436588746463552823930061	356	2023-01-03	RU8683803436557989786811096289958	внутренняя	4591339.9610	242.1274	отправлена	\N
3729	RU4583803436546993711061481413708	840	2023-05-11	PT2077143762457187035807316	международная	1970730.5013	817.8324	отменена	IRVTUS3NXXX
3730	RU3183803436559935083955185145410	978	2023-10-31	IN8973902124301678025916699	международная	1533963.0346	917.5070	доставлена	SOGEFRPP
3731	RU4883803436563163057705977553405	356	2023-03-15	BY1281316562962230706127721	международная	3383102.2646	514.5052	отправлена	SBININBBXXX
3732	RU1183803436547102061688733775669	840	2023-08-18	IN8130429367329404753572790	международная	400114.7614	53.6537	доставлена	CHASUS33
3733	RU1183803436513944372774322746458	643	2023-09-05	RU6983803436550083462130199504453	внутренняя	1654909.8775	941.0422	отправлена	\N
3734	RU9183803436512467785925904841435	398	2023-06-22	IN9639333459244306477557281	международная	1297893.0219	150.2701	отменена	CASPKZKAXXX
3735	RU1983803436549890414007715363567	840	2023-08-12	KZ3095268669222437980509342	международная	6183723.3522	445.0925	отменена	CHASUS33
3736	RU5783803436568341660520010753753	156	2023-12-20	RU3983803436583094600516227232333	внутренняя	2527413.3424	379.0346	доставлена	\N
3737	RU2583803436573489146610412814439	398	2023-08-05	RU6383803436541953279771793851240	внутренняя	4829046.4141	846.2110	доставлена	\N
3738	RU3783803436562091905141244310726	840	2023-01-03	RU8183803436576334203563049364101	внутренняя	1330952.1737	132.2571	отправлена	\N
3739	RU7183803436513501317784267991188	978	2023-11-17	DE6843628205710405377888704	международная	7117395.2906	833.7618	отменена	SOGEFRPP
3740	RU4883803436561825246742556433732	840	2023-06-02	RU3283803436579852018195047883736	внутренняя	5296754.6957	764.7424	отправлена	\N
3741	RU5683803436573106663960342062340	398	2023-03-25	RU3983803436569376600246742084811	внутренняя	2407288.2511	890.9779	доставлена	\N
3742	RU4483803436574648344464338946055	156	2023-11-02	ES7322312506176014308864687	международная	4508063.1512	768.5713	отменена	BKCHCNBJ
3743	RU2683803436566742853200336170327	978	2023-05-13	RU9683803436526786707929300961979	внутренняя	6902546.0764	860.9197	отправлена	\N
3744	RU9483803436522220035875117822565	156	2023-04-08	RU9683803436520170153501466272589	внутренняя	3383740.9105	551.6405	доставлена	\N
3745	RU7783803436578403910419087666263	643	2023-03-13	BY3131789454435456475334663	внутренняя	5487851.6069	118.0998	отправлена	\N
3746	RU9383803436515318038329930627155	356	2023-05-27	PT2990323322802223819497165	международная	6698157.6122	226.0666	отправлена	SBININBBXXX
3747	RU9683803436571883645805733128714	840	2023-11-16	KZ4510575802705272524828702	международная	6321576.5876	134.1906	доставлена	CHASUS33
3748	RU5683803436573106663960342062340	398	2023-10-20	RU7383803436546512723534280739575	внутренняя	381721.4061	145.4521	отправлена	\N
3749	RU3383803436540416635821116917223	398	2023-02-20	PT7987802698696091286144928	международная	4446033.6852	561.7135	отменена	CASPKZKAXXX
3750	RU8483803436552375991404578719285	840	2023-09-02	BY2051710645171650490640674	международная	6071622.2557	96.2316	доставлена	IRVTUS3NXXX
3751	RU3183803436522808312515599877028	840	2023-11-01	RU3983803436554516084539411139147	внутренняя	5441127.3403	308.4601	отменена	\N
3752	RU3983803436554516084539411139147	643	2023-03-16	VN6851409584128063200679310	внутренняя	261895.2499	517.0819	доставлена	\N
3753	RU7783803436536804517087406327796	356	2023-07-06	RU6683803436547011171926119923803	внутренняя	5654993.2964	857.2542	отправлена	\N
3754	RU1683803436543683792461716245841	643	2023-07-30	RU6783803436527708547728704282997	внутренняя	267184.5058	943.2744	доставлена	\N
3755	RU1083803436532178175395898264605	978	2023-11-24	PT2247308207339612107013450	международная	6561617.6787	522.9393	доставлена	SOGEFRPP
3756	RU9783803436586848496167067081204	840	2023-01-11	AL5245007264348823852445815	международная	5280658.6555	455.3085	отменена	IRVTUS3NXXX
3757	RU9783803436566819882292917709885	356	2023-05-18	BY5456845493621991682826852	международная	1651482.9269	215.6215	доставлена	SBININBBXXX
3758	RU4383803436557380827011382643653	156	2023-08-20	PT4738162194122208424155136	международная	9708260.2443	314.5989	доставлена	BKCHCNBJ
3759	RU6483803436527000884469712767990	643	2023-07-23	RU4283803436530972916151822377436	внутренняя	5518463.8139	107.6725	доставлена	\N
3760	RU2983803436597155052344917689453	398	2023-10-06	IN4087886005305960341715066	международная	7839125.9846	787.2692	доставлена	CASPKZKAXXX
3761	RU5483803436549562102902686014927	156	2023-11-07	IN3589219076280355647435885	международная	9872964.5371	580.6819	отправлена	BKCHCNBJ
3762	RU1983803436518034161993382946183	156	2023-05-31	BY5125150294715836047278662	международная	6766509.7047	198.1020	отменена	BKCHCNBJ
3763	RU7583803436597888322431139189153	156	2023-03-01	RU9483803436522220035875117822565	внутренняя	6906560.9536	578.2697	отправлена	\N
3764	RU7583803436545511345420608427589	978	2023-07-08	DE3961528261966354850962080	международная	5790913.4975	971.4490	доставлена	SOGEFRPP
3765	RU4483803436593534887929979895004	840	2023-10-09	RU4283803436515276086545867508581	внутренняя	1821095.2088	373.6076	отменена	\N
3766	RU5183803436596697120047636808100	643	2023-12-08	RU9883803436510697875492928159959	внутренняя	7834142.0571	208.8501	отправлена	\N
3767	RU4483803436537144245226352938256	643	2023-11-15	RU3783803436585191546282680625888	внутренняя	8636420.0667	309.6614	отправлена	\N
3768	RU3083803436518573891716312234719	840	2023-06-21	RU8983803436530366335955653516096	внутренняя	3448477.4738	962.3697	отменена	\N
3769	RU5883803436512174556620785995683	398	2023-10-15	RU9583803436562562119396535016715	внутренняя	1092217.5374	241.5384	отменена	\N
3770	RU2983803436545911307181108696312	156	2023-11-12	KZ2264366088572582037086833	международная	3931544.8101	266.1654	отправлена	BKCHCNBJ
3771	RU5183803436599553165549416662045	978	2023-04-28	AL5841636971828292016636164	международная	6854561.7975	935.0227	отправлена	DEUTDEFFXXX
3772	RU1983803436510712914540451632365	978	2023-09-28	ES7083401089805418332818202	международная	7940313.2066	147.5086	отправлена	SOGEFRPP
3773	RU6583803436599318340096840026283	840	2023-06-22	ES3340608345689929235417981	международная	4005512.6308	562.7022	отменена	IRVTUS3NXXX
3774	RU9483803436585469145832242711561	643	2023-04-28	AL3413817177378352299087711	внутренняя	1704334.5735	338.8822	отправлена	\N
3775	RU2983803436585384738431881857607	840	2023-05-13	RU7881366045995916023000633	внутренняя	9769237.4802	620.8610	доставлена	\N
3776	RU3083803436548755847047281062638	398	2023-06-25	RU4683803436584135461455281070651	внутренняя	6592445.7458	871.0696	доставлена	\N
3777	RU1283803436597755454846611928328	978	2023-08-03	BY7691312289004254401711621	международная	5695345.0082	54.6231	отменена	RZBAATWW
3778	RU4883803436583846522749125412438	840	2023-01-04	VN7610867091973285602051089	международная	6630208.0073	445.9293	доставлена	IRVTUS3NXXX
3779	RU6183803436547326038705936576601	398	2023-07-15	RU5483803436551418630110242560620	внутренняя	4565057.2291	471.0743	доставлена	\N
3780	RU2283803436551819000625747494652	840	2023-05-03	RU1883803436562141776165180370424	внутренняя	4907767.6873	387.6502	отправлена	\N
3781	RU3983803436569376600246742084811	356	2023-08-31	KZ1130251737599304155216666	международная	3884380.1214	453.1158	отправлена	SBININBBXXX
3782	RU6483803436599929208547720213297	840	2023-05-07	AL7624401964902329162069477	международная	5711075.4720	565.4476	доставлена	CHASUS33
3783	RU5883803436571013870275428717873	840	2022-12-31	RU8183803436546948351691601253240	внутренняя	6603650.0178	168.0788	отменена	\N
3784	RU3983803436569376600246742084811	156	2023-12-10	RU1371022721682923409157035	внутренняя	9715588.5602	719.4429	доставлена	\N
3785	RU8283803436558421168306139201398	156	2023-12-06	RU7130373644780168349431449	внутренняя	5642189.2202	722.7221	отправлена	\N
3786	RU7583803436593274051968042799324	978	2023-11-02	AD9623932581200470251368640	международная	6703949.2540	616.3563	отменена	DEUTDEFFXXX
3787	RU2183803436551906716086082339754	840	2023-03-01	RU3083803436556733352794187735054	внутренняя	9787913.3616	352.1849	отменена	\N
3788	RU5783803436556321671762187197309	398	2023-12-23	RU6083803436557649065533492172245	внутренняя	8750989.3917	976.9052	отменена	\N
3789	RU7683803436565241249132549566386	643	2023-03-11	ES1847834223505625144578043	внутренняя	9723244.2600	630.8805	отправлена	\N
3790	RU9983803436581801115411623274695	156	2023-01-20	RU4683803436521950147450839996450	внутренняя	4760955.7721	936.8258	отменена	\N
3791	RU2583803436569716293278278112122	978	2023-10-03	KZ8048079228495273053451897	международная	8024692.7545	517.6832	отменена	SOGEFRPP
3792	RU2283803436521727957364583057084	398	2023-10-17	RU4283803436515276086545867508581	внутренняя	5589007.0550	170.4153	отменена	\N
3793	RU9383803436515318038329930627155	978	2023-07-30	VN4047827101997183909020462	международная	4758244.2324	953.9677	отменена	DEUTDEFFXXX
3794	RU9583803436537234117226554935344	156	2023-06-16	BY7786049853218778823743117	международная	9600014.0820	652.8931	отменена	BKCHCNBJ
3795	RU2383803436569895097903578030814	156	2023-06-12	PT2428671946886950193434482	международная	3785746.3720	859.6263	отменена	BKCHCNBJ
3796	RU9783803436586848496167067081204	356	2023-04-26	DE1835648382983755495255136	международная	3200373.9734	858.0854	доставлена	SBININBBXXX
3797	RU2283803436551819000625747494652	156	2023-09-24	RU4383803436535637847836978327691	внутренняя	4689786.9129	255.3824	отменена	\N
3798	RU6283803436561107985248905256058	398	2023-02-26	RU9283803436560888794155508079505	внутренняя	2734825.3042	302.3553	доставлена	\N
3799	RU1883803436547883958852583813660	356	2023-10-24	KZ5576498179726435653845828	международная	1932114.4322	933.2919	отправлена	SBININBBXXX
3800	RU5583803436581992686445972740236	398	2023-10-13	BY9160350393393288038714098	международная	7415938.8751	803.1477	отправлена	CASPKZKAXXX
3801	RU8983803436530366335955653516096	840	2023-02-02	BY9012766336542332412221858	международная	469861.1439	914.3699	отменена	CHASUS33
3802	RU4683803436521950147450839996450	156	2023-05-15	KZ1390751429478410523955180	международная	1210334.6788	24.3069	отменена	BKCHCNBJ
3803	RU3183803436538368625987340316428	356	2023-07-31	KZ9622758807528615557909369	международная	7923672.7201	97.5228	доставлена	SBININBBXXX
3804	RU2083803436573246597416370413406	156	2023-10-18	RU4583803436588661449801193641363	внутренняя	2912690.3554	385.8062	отправлена	\N
3805	RU1983803436592911874717339237016	356	2023-02-06	DE9836428472408798204895472	международная	3085704.6440	667.7490	отменена	SBININBBXXX
3806	RU3583803436543438797337964557116	398	2023-05-29	RU8983803436588264357315670765686	внутренняя	4514821.7201	234.2320	отправлена	\N
3807	RU5483803436538988818998904026382	840	2023-09-22	AD7811584168282494091576352	международная	6968681.5926	581.4962	отправлена	IRVTUS3NXXX
3808	RU1983803436592911874717339237016	356	2023-02-02	RU3883803436519845868206132784952	внутренняя	9563568.3111	489.6738	доставлена	\N
3809	RU9683803436541591047480784615833	978	2023-06-03	ES9231616661128564980822097	международная	4188787.1045	452.7269	отправлена	SOGEFRPP
3810	RU6883803436521704893234788177503	840	2023-02-04	AL2296812271435072755118141	международная	968938.0691	571.9846	отменена	CHASUS33
3811	RU7083803436575256167282941443393	978	2023-09-26	DE7962528834624450205739431	международная	2515063.8721	980.8309	отправлена	DEUTDEFFXXX
3812	RU2283803436555228451424548337941	156	2023-06-07	RU6583803436546434088553514688778	внутренняя	3014101.5501	509.5934	отменена	\N
3813	RU6783803436582018660242960957244	398	2023-05-26	RU7283803436582085910615477000049	внутренняя	9268586.8354	314.9437	доставлена	\N
3814	RU1183803436587920364130887563809	840	2023-02-15	RU8183803436555934243334630961587	внутренняя	4319284.8650	267.6330	отправлена	\N
3815	RU3783803436585191546282680625888	356	2023-11-01	DE3727985366518597332183943	международная	8026729.6512	809.1626	отменена	SBININBBXXX
3816	RU9883803436596118671708861810646	978	2023-11-12	PT1374450536268827911948009	международная	472785.6687	523.9699	отправлена	SOGEFRPP
3817	RU6583803436599318340096840026283	840	2023-06-02	AD1065614825562612780320505	международная	2242753.8450	555.8976	отправлена	IRVTUS3NXXX
3818	RU4183803436593654490331448399606	356	2023-02-17	RU7183803436546875767014611813689	внутренняя	5646385.9884	857.8844	доставлена	\N
3819	RU6283803436561107985248905256058	356	2023-07-29	RU4383803436559640804885433764330	внутренняя	2060281.4840	680.3113	отменена	\N
3820	RU7383803436534050516387288663509	978	2023-02-01	AL5388361504706394968872265	международная	8872387.5489	540.2376	отменена	RZBAATWW
3821	RU7783803436529059332090835348557	398	2023-06-15	RU5883803436576828712243252221562	внутренняя	7733073.2808	19.4890	отменена	\N
3822	RU6983803436582618731634671628237	978	2023-03-27	VN8961470208611172858015127	международная	3191465.3326	911.6499	отменена	DEUTDEFFXXX
3823	RU2983803436597155052344917689453	643	2023-08-15	PT3020864812691649617422711	внутренняя	2121523.7529	959.7651	доставлена	\N
3824	RU8483803436546395435496825405512	840	2023-07-16	AL6374661625600874581305924	международная	40600.5236	181.7980	отправлена	CHASUS33
3825	RU3183803436522808312515599877028	398	2023-07-30	RU8583803436548069379320039967893	внутренняя	2858641.6404	187.5979	отменена	\N
3826	RU2983803436572678251629055132350	643	2023-01-23	RU3183803436522808312515599877028	внутренняя	8236073.7963	708.3781	отправлена	\N
3827	RU5683803436522754650880470438385	840	2023-08-29	BY6135675715950709586407830	международная	3134851.3634	728.9963	доставлена	CHASUS33
3828	RU9583803436547610609904791788853	156	2023-09-09	KZ1619071569848575309884434	международная	907244.0006	796.8527	отменена	BKCHCNBJ
3829	RU5883803436537252361294139722938	978	2023-07-27	RU7265037349792884759871850	внутренняя	5240132.5647	748.5890	доставлена	\N
3830	RU7883803436577262824038798840088	356	2023-01-24	AD2179610593684542766904971	международная	9481157.6637	122.6263	доставлена	SBININBBXXX
3831	RU4283803436532641085536208083176	978	2023-12-27	RU7183803436513501317784267991188	внутренняя	9498478.6199	448.8806	отправлена	\N
3832	RU6783803436527708547728704282997	978	2023-10-08	BY2561100899265272161562310	международная	7693559.4018	419.7958	отменена	DEUTDEFFXXX
3833	RU9283803436560888794155508079505	356	2023-04-05	VN3472868706460773740021975	международная	7535669.2310	947.6773	отправлена	SBININBBXXX
3834	RU1683803436583298094705869717304	398	2023-10-13	VN7255165099480200624665054	международная	9940504.8900	323.3886	отправлена	CASPKZKAXXX
3835	RU2283803436527235231809863175226	840	2023-02-22	RU1483803436552189189819570176682	внутренняя	2337914.9162	357.2018	отправлена	\N
3836	RU8183803436532187852215520403243	398	2023-02-25	RU1183803436587920364130887563809	внутренняя	7321372.9827	480.8896	отправлена	\N
3837	RU7383803436567535429961689788567	398	2023-04-27	AL5564881261125975252572797	международная	6947609.0953	366.7046	отправлена	CASPKZKAXXX
3838	RU4083803436530357399673623809331	156	2023-04-19	RU2083803436573246597416370413406	внутренняя	7853013.3591	379.0357	доставлена	\N
3839	RU7183803436596080848426828093950	840	2022-12-27	RU5083803436521160540176223483455	внутренняя	661014.9617	347.4547	отменена	\N
3840	RU1983803436574962372646294489745	840	2023-12-11	RU2983803436597155052344917689453	внутренняя	4571348.2518	775.6502	доставлена	\N
3841	RU5883803436512174556620785995683	840	2023-08-09	DE9243452383268950654990709	международная	3345174.6311	833.7732	доставлена	CHASUS33
3842	RU8683803436557989786811096289958	643	2023-10-10	RU1183803436513944372774322746458	внутренняя	1879294.8440	595.2174	отправлена	\N
3843	RU1983803436568263609873115174417	398	2023-08-28	PT7335663517582304819642855	международная	7006593.4184	846.4239	отменена	CASPKZKAXXX
3844	RU6483803436513432249664452306210	840	2023-12-19	RU4183803436555804329090528802664	внутренняя	2249751.3709	836.9129	отменена	\N
3845	RU5183803436550941857646482749776	356	2023-10-15	AL4463183193589672965692934	международная	6869152.5119	529.5063	отменена	SBININBBXXX
3846	RU3383803436551883036237842733910	398	2023-10-24	RU5183803436573013692902081587761	внутренняя	1627022.7245	227.5959	отправлена	\N
3847	RU7483803436591068390387769478580	398	2023-05-07	RU1183803436587920364130887563809	внутренняя	8446833.0674	16.1090	отменена	\N
3848	RU2983803436572636545308279163382	840	2023-05-24	RU1383803436596151895061926683764	внутренняя	8127220.1438	468.6249	отменена	\N
3849	RU5583803436541779385547740767657	840	2023-08-28	RU7183803436535160662680026565691	внутренняя	8732621.9211	626.7470	отправлена	\N
3850	RU8183803436576908594301902139271	356	2023-06-19	RU5083803436563140090168469536649	внутренняя	2061528.6057	73.9728	доставлена	\N
3851	RU9483803436516702191580023603147	840	2023-10-31	RU4083803436537218400436107027314	внутренняя	211988.3064	407.9490	доставлена	\N
3852	RU3483803436534657689181631833463	840	2023-03-28	IN7914185801045651863874276	международная	7436779.4544	199.0328	доставлена	CHASUS33
3853	RU7383803436567535429961689788567	840	2023-10-10	VN5448664986354818223138239	международная	6260880.5441	671.8102	отменена	IRVTUS3NXXX
3854	RU4183803436575456526806163894045	978	2023-03-20	DE9541627376495842383425256	международная	5046724.4237	290.9412	доставлена	SOGEFRPP
3855	RU9983803436588442958405952112241	643	2023-06-19	RU7683803436578953117174553181317	внутренняя	2656076.4181	348.9015	отправлена	\N
3856	RU3583803436580986023375789999847	398	2023-05-04	PT2562278855718442611063900	международная	8119283.0862	465.5960	доставлена	CASPKZKAXXX
3857	RU9483803436570307762028951954874	156	2023-08-25	PT1340800173352905836530160	международная	33807.4676	504.6636	отменена	BKCHCNBJ
3858	RU2483803436559904294875702128517	156	2023-09-12	RU7383803436546512723534280739575	внутренняя	9110076.3129	368.3174	доставлена	\N
3859	RU8583803436529401978461350257287	398	2023-07-06	RU9883803436580908913943520973504	внутренняя	1769456.5176	996.0436	доставлена	\N
3860	RU6583803436588261503476787515721	356	2023-05-02	RU3683803436521305656177527242839	внутренняя	6075328.9146	0.0000	отправлена	\N
3861	RU3383803436530100232705488681423	840	2023-10-31	RU6383803436512605200896614597744	внутренняя	6442757.7775	475.9712	доставлена	\N
3862	RU3783803436562091905141244310726	356	2023-07-11	RU9583803436537234117226554935344	внутренняя	3626475.6514	708.0905	отправлена	\N
3863	RU8483803436576032684947735830335	398	2023-04-06	RU1683803436596193217028081534610	внутренняя	7691988.7797	61.0479	доставлена	\N
3864	RU4083803436565489336932623834655	643	2023-05-21	VN7676843012361957992154430	внутренняя	7708982.8207	577.1996	доставлена	\N
3865	RU9383803436568402663247236595753	156	2023-09-28	ES8924255196615007233650652	международная	9307326.7518	811.7181	отменена	BKCHCNBJ
3866	RU1983803436518034161993382946183	978	2023-12-25	BY9911705537563039873987910	международная	1304162.1552	886.3349	отменена	RZBAATWW
3867	RU1083803436563162471160560931522	398	2023-02-17	ES8218709177386617418649221	международная	2112281.6611	808.3554	доставлена	CASPKZKAXXX
3868	RU2283803436577856579987093576845	398	2023-06-18	IN3624489934864343494050829	международная	7358789.2177	0.0000	отправлена	CASPKZKAXXX
3869	RU5983803436558435772787343054218	978	2023-01-13	AL1698939456655710011382924	международная	6513802.6574	850.3932	отправлена	SOGEFRPP
3870	RU4383803436586323329892508459044	356	2023-09-03	RU2183803436586747579379810386651	внутренняя	6929686.3654	176.8023	доставлена	\N
3871	RU9383803436575688788160155647011	978	2023-02-03	RU1083803436532178175395898264605	внутренняя	6611034.3544	220.3076	отправлена	\N
3872	RU5083803436563140090168469536649	643	2023-02-05	VN7347504813558210900555142	внутренняя	3125179.0154	21.2713	доставлена	\N
3873	RU6483803436557881046066137062384	156	2023-03-24	ES4855373861039904670413393	международная	9055801.6468	863.8828	отправлена	BKCHCNBJ
3874	RU2783803436529440294678710752920	643	2023-02-01	VN4915608238910999754478299	внутренняя	5098713.9633	185.1616	отменена	\N
3875	RU1083803436588429797000364388942	978	2023-04-04	KZ9879825311622668593956366	международная	4551033.2133	638.2718	отправлена	SOGEFRPP
3876	RU3683803436521305656177527242839	978	2023-02-28	AL7496788448295018229798477	международная	2226771.2392	983.1639	отменена	DEUTDEFFXXX
3877	RU2483803436580851808318436691458	398	2023-02-01	IN5149478869737677970219847	международная	7863095.0037	661.5911	отправлена	CASPKZKAXXX
3878	RU4383803436535637847836978327691	398	2023-10-09	RU2683803436566742853200336170327	внутренняя	1261140.3770	29.2518	доставлена	\N
3879	RU5583803436525031727011657164177	840	2023-06-21	IN8411015074246648024456577	международная	6957207.8113	30.5845	доставлена	IRVTUS3NXXX
3880	RU7283803436565335970635584506660	156	2023-12-21	RU9683803436579408636311341559980	внутренняя	758017.7893	146.4127	отменена	\N
3881	RU2183803436535230801413319305895	356	2023-05-24	RU8383803436543267469021061769102	внутренняя	8963797.4602	343.5246	доставлена	\N
3882	RU7383803436515152831562897371432	643	2023-07-21	ES5525831423765024033091404	внутренняя	4176849.8889	845.1693	отправлена	\N
3883	RU2083803436536025786076127901648	398	2023-01-15	KZ8613454905265714406309545	международная	6022663.7009	813.8919	доставлена	CASPKZKAXXX
3884	RU9183803436594783043422280553530	978	2023-08-09	IN7853736954239472490593792	международная	4477635.1359	120.2727	доставлена	SOGEFRPP
3885	RU4583803436588661449801193641363	356	2023-08-01	DE4360214079178663868229693	международная	3832220.0194	112.2712	отменена	SBININBBXXX
3886	RU7783803436536804517087406327796	156	2023-10-12	RU5683803436539120556194350818141	внутренняя	4350619.4183	367.8544	отправлена	\N
3887	RU5183803436596697120047636808100	840	2023-12-18	VN7879813742221075416544041	международная	5042364.3246	256.3716	отменена	IRVTUS3NXXX
3888	RU5183803436596697120047636808100	978	2023-02-15	PT3471056861056366217902735	международная	7376881.2315	396.5385	доставлена	SOGEFRPP
3889	RU8183803436576908594301902139271	356	2023-12-14	RU2883803436512412400998624231254	внутренняя	7478255.9057	97.6970	доставлена	\N
3890	RU5583803436581992686445972740236	978	2023-03-20	PT6461509069826227986282614	международная	3118446.4960	423.9769	отменена	SOGEFRPP
3891	RU4283803436571605132393354830061	840	2023-07-04	PT7979848801076121711777202	международная	9813104.9515	32.8097	отменена	IRVTUS3NXXX
3892	RU7483803436529598231033100377224	840	2023-05-22	DE3224440928487393207864340	международная	6841436.4482	654.5646	доставлена	CHASUS33
3893	RU5783803436553735504938098098542	643	2023-02-20	VN8076962348739627502299613	внутренняя	5292212.2547	655.5259	доставлена	\N
3894	RU2483803436537933507280624045523	398	2023-01-10	ES2019529054045309841499978	международная	7531845.2900	137.5960	отменена	CASPKZKAXXX
3895	RU1383803436546084241558471107471	978	2023-11-11	RU2367675177736868828839157	внутренняя	9443840.2047	882.0564	отменена	\N
3896	RU5983803436561671607015303339932	643	2023-11-06	AD8173393158126410992381299	внутренняя	8729574.4571	808.0574	отправлена	\N
3897	RU6683803436534213789698830771682	643	2023-11-29	RU1683803436510344781123537250392	внутренняя	304843.0448	113.8491	доставлена	\N
3898	RU6783803436583735354795738130605	840	2023-01-15	BY3225777919908908539771649	международная	584587.8097	554.6816	отменена	IRVTUS3NXXX
3899	RU6783803436582018660242960957244	156	2023-01-20	RU5783803436598085342824416355658	внутренняя	3756584.6486	750.4196	отправлена	\N
3900	RU9483803436588743613330942629999	398	2023-04-23	KZ5684528058880521696047457	международная	4935328.6177	397.9737	отменена	CASPKZKAXXX
3901	RU4883803436577275200947611443039	398	2023-12-16	RU3183803436538368625987340316428	внутренняя	9317894.0184	903.6381	отменена	\N
3902	RU8583803436590890149305918634043	978	2023-11-03	KZ6171888082477550121945715	международная	1812457.6683	126.0407	отправлена	SOGEFRPP
3903	RU2283803436521727957364583057084	978	2023-08-29	RU6483803436513432249664452306210	внутренняя	6971062.7446	566.8844	отправлена	\N
3904	RU2283803436577856579987093576845	356	2023-01-09	RU3283803436579852018195047883736	внутренняя	3549833.1950	340.0484	отменена	\N
3905	RU2983803436572636545308279163382	356	2023-01-26	DE5334735596833950997381116	международная	3054528.2431	823.0188	отменена	SBININBBXXX
3906	RU1883803436537462946976236392804	840	2023-03-10	RU2283803436527235231809863175226	внутренняя	417200.4496	669.4132	отправлена	\N
3907	RU5983803436585678890114061651314	643	2023-10-04	DE2156201009961373029263461	внутренняя	204644.4546	667.5335	доставлена	\N
3908	RU8783803436519169154241731281817	356	2023-10-09	RU8983803436588264357315670765686	внутренняя	4481793.4238	140.7126	отправлена	\N
3909	RU4583803436576777630615652907536	978	2023-01-20	KZ7583979214224377345053259	международная	4821765.6607	356.0893	отправлена	SOGEFRPP
3910	RU5583803436533254773648721597711	398	2023-06-14	RU3030260699840486353990370	внутренняя	436110.2406	632.1716	отправлена	\N
3911	RU2883803436538134433783624054557	356	2023-09-18	RU3183803436583121152517184662518	внутренняя	6748377.1066	674.6082	доставлена	\N
3912	RU6583803436592149423686806465410	156	2023-07-16	AD4324639787768429307534079	международная	1938215.2978	284.6391	доставлена	BKCHCNBJ
3913	RU1583803436533479152204865778047	398	2023-09-24	RU2483803436537933507280624045523	внутренняя	2899593.1433	137.5590	отправлена	\N
3914	RU9683803436511276549947859990709	356	2023-07-19	AL5573723622831168726537407	международная	2082650.3356	149.9022	отправлена	SBININBBXXX
3915	RU8583803436580493050529274956761	356	2023-07-28	ES6171652041879451694440153	международная	5501908.6189	224.0134	доставлена	SBININBBXXX
3916	RU9683803436526786707929300961979	156	2023-05-17	RU3549469396288459582260278	внутренняя	1942239.3116	957.4570	отменена	\N
3917	RU8683803436531608639655465618756	156	2023-04-29	IN8483966757900330669333854	международная	8252230.2299	303.2028	отменена	BKCHCNBJ
3918	RU8783803436519169154241731281817	398	2023-01-09	RU4083803436537218400436107027314	внутренняя	2842691.1463	797.5681	доставлена	\N
3919	RU8283803436536082355231514909614	398	2023-08-02	RU1583803436592948110594062864167	внутренняя	3679355.6664	502.0256	отменена	\N
3920	RU6683803436563942598707878107815	356	2023-05-23	ES1144570472308539566657377	международная	6589728.2405	619.6096	доставлена	SBININBBXXX
3921	RU1583803436578714315409224923820	356	2023-07-19	AL5812743041084875946974756	международная	7523399.9625	812.8808	доставлена	SBININBBXXX
3922	RU6583803436588261503476787515721	840	2023-11-12	RU2983803436545911307181108696312	внутренняя	5345129.6720	56.2549	доставлена	\N
3923	RU9683803436579408636311341559980	356	2023-09-12	RU2283803436551819000625747494652	внутренняя	7928963.1540	678.2174	отправлена	\N
3924	RU5583803436581992686445972740236	643	2023-05-18	RU3583803436580986023375789999847	внутренняя	5658155.4101	272.3422	доставлена	\N
3925	RU8383803436583878629872361871714	978	2023-08-14	RU5137923669712102296253923	внутренняя	2544659.2318	400.5059	доставлена	\N
3926	RU3883803436515226766320509995235	978	2023-11-26	DE1589467145068949129584499	международная	699368.3593	530.8702	доставлена	RZBAATWW
3927	RU7383803436569356631218275502161	156	2023-01-01	RU9783803436586848496167067081204	внутренняя	5376763.7797	623.5443	доставлена	\N
3928	RU4583803436588661449801193641363	398	2023-09-09	RU3783803436562139250445157080524	внутренняя	2262776.3009	143.1558	отменена	\N
3929	RU9683803436559214297350823715344	978	2023-10-15	IN6949557529988160260410751	международная	8952903.9829	782.2950	отменена	DEUTDEFFXXX
3930	RU1983803436510686315036595318873	356	2023-10-23	AL8438456602996477762268351	международная	6430934.9720	457.3689	отменена	SBININBBXXX
3931	RU5883803436544935035293164341064	978	2023-06-16	RU2983803436545911307181108696312	внутренняя	3945028.6636	389.8044	отменена	\N
3932	RU5083803436521160540176223483455	978	2023-06-21	AD7412893325342324291047092	международная	948103.5658	101.3991	отправлена	SOGEFRPP
3933	RU8783803436519169154241731281817	398	2023-08-17	RU3583803436543438797337964557116	внутренняя	7176910.6596	943.5766	доставлена	\N
3934	RU4583803436567844239839748091371	156	2023-12-25	KZ3036468755229671702333076	международная	9061419.6670	857.3172	отправлена	BKCHCNBJ
3935	RU8183803436576334203563049364101	643	2023-09-29	RU6983803436582618731634671628237	внутренняя	5015505.9763	137.1362	доставлена	\N
3936	RU9483803436516702191580023603147	398	2023-10-08	AL8698493558358441685472015	международная	278394.4141	365.0560	доставлена	CASPKZKAXXX
3937	RU5783803436573951128453151787227	156	2023-09-07	DE6694282615259390615230925	международная	8503336.7875	659.2952	отправлена	BKCHCNBJ
3938	RU2283803436551819000625747494652	978	2023-03-24	ES8610168333345014729995280	международная	7836696.1008	139.4263	доставлена	DEUTDEFFXXX
3939	RU9483803436522220035875117822565	643	2023-08-29	BY9939939313735523065753088	внутренняя	8401044.0458	695.9713	отменена	\N
3940	RU2483803436559904294875702128517	840	2023-07-02	KZ5858644712514751636522648	международная	1325116.0483	694.1203	отправлена	CHASUS33
3941	RU8483803436552375991404578719285	643	2023-04-25	IN7236112017415989416279520	внутренняя	2362618.3726	229.5586	отправлена	\N
3942	RU6583803436565551879254347008316	840	2023-03-11	VN7165194377691289762298874	международная	6433478.8105	855.6485	отправлена	CHASUS33
3943	RU4683803436584135461455281070651	840	2023-10-03	RU1283803436597755454846611928328	внутренняя	8718771.3009	968.5408	доставлена	\N
3944	RU2583803436511360000518303822185	398	2023-05-28	AD7435836474422266051423706	международная	7473961.1467	912.4149	отменена	CASPKZKAXXX
3945	RU7083803436595909521339223196614	978	2023-06-05	RU6183803436573612137819734816326	внутренняя	365491.4030	421.7531	отменена	\N
3946	RU3683803436529963181547651499120	398	2023-05-05	AL5589148264318491396679341	международная	5698865.7523	107.1588	отменена	CASPKZKAXXX
3947	RU3783803436562139250445157080524	156	2023-05-24	KZ7797531414534841669891802	международная	6960335.9213	812.6228	отменена	BKCHCNBJ
3948	RU1983803436592911874717339237016	643	2023-10-21	AD1326374867932384011069146	внутренняя	7878992.4483	32.0371	отправлена	\N
3949	RU2983803436530272226005609138408	840	2023-08-29	RU6583803436573484995572407857396	внутренняя	4514986.4362	565.6171	отправлена	\N
3950	RU5983803436533405804846460378377	398	2023-04-30	RU3573201164945686199386754	внутренняя	1404976.6248	736.1057	доставлена	\N
3951	RU9083803436527710172880684864084	978	2023-06-06	BY6190940074775578092024309	международная	7495068.2034	499.7277	доставлена	SOGEFRPP
3952	RU5383803436532276110708298062956	643	2023-03-19	AL4137570664174860456871557	внутренняя	189099.0167	711.2352	доставлена	\N
3953	RU1483803436552189189819570176682	840	2023-11-15	ES2970418378441838054930227	международная	6558453.4304	461.8951	отменена	IRVTUS3NXXX
3954	RU7683803436578953117174553181317	643	2023-11-05	AD4863812769940317257654260	внутренняя	3774428.4436	108.2847	доставлена	\N
3955	RU2683803436556115738690945420927	978	2023-09-23	PT4745121422847605174165973	международная	1125681.0472	538.0231	отменена	SOGEFRPP
3956	RU7383803436585863943754594310819	978	2023-06-29	RU6183803436573612137819734816326	внутренняя	4303635.6227	696.1107	доставлена	\N
3957	RU1983803436510686315036595318873	978	2023-08-28	ES5115672187755923615956738	международная	7974400.9829	496.4452	отменена	RZBAATWW
3958	RU2683803436532775565489898182986	356	2023-02-25	PT3658080605754215136266343	международная	6987391.4231	849.5327	отменена	SBININBBXXX
3959	RU5183803436531460410872953149827	398	2023-07-08	RU7383803436585863943754594310819	внутренняя	2447848.7019	790.5245	отменена	\N
3960	RU2083803436518033160343253894367	156	2023-12-04	IN3577381157950423487063884	международная	9514368.4718	256.0333	отправлена	BKCHCNBJ
3961	RU1983803436568263609873115174417	156	2023-12-18	RU5883803436537252361294139722938	внутренняя	6320309.5973	316.8189	отправлена	\N
3962	RU2283803436555228451424548337941	398	2023-04-14	KZ5761700695640800206864458	международная	4728545.9117	371.9421	отправлена	CASPKZKAXXX
3963	RU7383803436546512723534280739575	643	2023-09-10	AD7961015956429412616652146	внутренняя	6201721.3946	994.1789	доставлена	\N
3964	RU2083803436593214630941740939011	978	2023-11-26	VN5435071844353291445158694	международная	5466893.6646	800.1089	отправлена	DEUTDEFFXXX
3965	RU6983803436518663051613263930888	840	2023-11-25	RU3483803436534657689181631833463	внутренняя	427313.7231	472.5474	отправлена	\N
3966	RU5683803436575772290627280121203	356	2023-05-29	BY6911933545791154130563759	международная	5297683.9566	899.8392	отправлена	SBININBBXXX
3967	RU9583803436537234117226554935344	356	2023-05-09	PT1895779861524244275612901	международная	3536104.0753	874.1552	отменена	SBININBBXXX
3968	RU5183803436588244188761426669013	156	2023-06-28	AL4948227389746896113026629	международная	2232401.0979	654.0037	доставлена	BKCHCNBJ
3969	RU3983803436580604058878329162478	978	2023-12-16	RU1883803436562141776165180370424	внутренняя	6073186.0015	288.9097	отменена	\N
3970	RU6183803436551232797419519235346	356	2023-06-17	RU4083803436537218400436107027314	внутренняя	2226446.9738	600.2344	отправлена	\N
3971	RU7483803436544936047225386728318	840	2023-03-20	ES7523982309743897244214204	международная	9292535.6771	854.3597	отправлена	IRVTUS3NXXX
3972	RU4583803436544769415444430855700	840	2023-05-02	RU9183803436594783043422280553530	внутренняя	623529.3814	443.6621	отправлена	\N
3973	RU4583803436576777630615652907536	978	2023-03-09	RU7483803436560908970835757520521	внутренняя	379699.2397	827.1422	отправлена	\N
3974	RU4383803436597428452957764955765	978	2023-04-30	KZ9793182073396180672525714	международная	9029054.8249	950.3115	отменена	DEUTDEFFXXX
3975	RU2283803436527235231809863175226	156	2023-08-01	RU9483803436570307762028951954874	внутренняя	9427740.0327	519.1479	доставлена	\N
3976	RU3283803436579852018195047883736	643	2023-06-11	RU7483803436591068390387769478580	внутренняя	3940806.1012	812.3906	отправлена	\N
3977	RU5583803436556151120487866130687	978	2023-08-04	VN3786705679836656182677891	международная	822658.3168	374.2684	отменена	SOGEFRPP
3978	RU9683803436511276549947859990709	840	2023-04-14	RU8183803436576908594301902139271	внутренняя	3117750.7987	174.9377	отменена	\N
3979	RU8183803436564595439284009293487	398	2023-01-20	RU1983803436574962372646294489745	внутренняя	9025121.4804	307.8046	отменена	\N
3980	RU3283803436579852018195047883736	156	2023-02-03	RU8183803436576908594301902139271	внутренняя	3137645.2872	987.4056	отменена	\N
3981	RU2183803436586747579379810386651	978	2023-12-10	RU8183803436513368239655842198331	внутренняя	9073825.6209	729.4632	доставлена	\N
3982	RU1983803436592911874717339237016	840	2023-10-19	VN2179722918868099299227938	международная	5116240.6559	33.5181	отменена	CHASUS33
3983	RU2883803436512412400998624231254	398	2023-09-21	DE9964063886230785462521410	международная	551459.1176	419.1905	отправлена	CASPKZKAXXX
3984	RU3883803436564256045508064629374	398	2023-04-26	RU4383803436535637847836978327691	внутренняя	3731919.2561	825.5081	доставлена	\N
3985	RU8983803436530366335955653516096	643	2023-08-26	RU4383803436538414207445829899653	внутренняя	2738089.1073	557.1870	отменена	\N
3986	RU6183803436555838927651384339574	643	2023-08-24	RU9583803436557636243711161422858	внутренняя	9112100.9462	54.9445	доставлена	\N
3987	RU7883803436577262824038798840088	643	2023-09-15	RU6983803436557684576294868357987	внутренняя	1738435.3734	844.0947	доставлена	\N
3988	RU8483803436597380246113206833117	156	2023-08-04	VN9425501201713560285393840	международная	6429857.7511	992.5234	доставлена	BKCHCNBJ
3989	RU6483803436513432249664452306210	356	2023-11-11	RU6183803436536163842184020816729	внутренняя	8437115.6606	737.1003	доставлена	\N
3990	RU5983803436561671607015303339932	643	2023-10-17	KZ9555033905161276276541941	внутренняя	7104963.1505	29.6795	доставлена	\N
3991	RU6483803436599929208547720213297	643	2023-12-16	VN9353598074250421794390585	внутренняя	6807147.2840	520.4439	отменена	\N
3992	RU1383803436546084241558471107471	840	2023-12-25	ES1483574526421294967104128	международная	3859565.6296	11.4822	доставлена	IRVTUS3NXXX
3993	RU5883803436576828712243252221562	356	2023-11-20	ES2790325745287543794526047	международная	5366698.7227	756.9067	отправлена	SBININBBXXX
3994	RU1983803436558651220197686454204	643	2023-05-06	IN1971936041937416904992159	внутренняя	8326278.8848	890.5542	отправлена	\N
3995	RU2083803436571871160330810400191	398	2023-09-17	RU7283803436528848493351990702937	внутренняя	1842350.6058	475.7553	отменена	\N
3996	RU8583803436553386257766521949981	356	2023-03-13	RU3083803436572725983728902081378	внутренняя	9923650.0930	353.9476	отменена	\N
3997	RU8483803436586135450040789229889	356	2023-11-07	RU3783803436559423561964096195262	внутренняя	5121290.7169	209.0214	отправлена	\N
3998	RU8483803436546395435496825405512	978	2023-01-05	RU5683803436522754650880470438385	внутренняя	1863384.4033	473.3215	отменена	\N
3999	RU6583803436546434088553514688778	840	2023-04-17	RU6683803436547011171926119923803	внутренняя	272077.3668	364.2435	отменена	\N
4000	RU4183803436544525596730636267692	356	2023-02-24	ES7314698484971007378938282	международная	6147687.5437	381.8158	отправлена	SBININBBXXX
4001	RU6683803436534213789698830771682	840	2023-04-25	VN4737403326357243108419836	международная	8376491.3818	762.2022	отменена	IRVTUS3NXXX
4002	RU9583803436547610609904791788853	156	2023-12-04	AD7242783904187292631164116	международная	1782142.5857	736.5545	отменена	BKCHCNBJ
4003	RU8983803436550652073660555482382	398	2023-05-23	RU8483803436562780872181379760829	внутренняя	4345046.3615	687.7235	доставлена	\N
4004	RU1083803436516100547774990634896	978	2023-02-19	BY8571963484424941665536093	международная	2077338.7444	985.3615	отменена	RZBAATWW
4005	RU7783803436585076163513647706071	840	2023-08-24	PT5994650482476518284067860	международная	8212427.6730	639.1721	отменена	CHASUS33
4006	RU9083803436548965374028188380728	156	2023-10-18	RU4383803436557380827011382643653	внутренняя	422471.8390	322.5478	отменена	\N
4007	RU2183803436555308456329784386702	156	2023-09-01	RU8083803436567877444686336475183	внутренняя	3265657.6902	63.4159	отменена	\N
4008	RU9083803436548965374028188380728	398	2023-09-03	IN8917855162020201070019204	международная	7812879.2448	954.8724	отправлена	CASPKZKAXXX
4009	RU9383803436568402663247236595753	643	2023-06-15	DE9599175401500854685315164	внутренняя	2484280.3673	171.5299	доставлена	\N
4010	RU9183803436512467785925904841435	840	2023-05-11	AD2761199956811404702999140	международная	9956032.8957	0.0000	доставлена	CHASUS33
4011	RU8283803436558421168306139201398	356	2023-05-01	RU5883803436537252361294139722938	внутренняя	8500605.0604	206.2494	доставлена	\N
4012	RU4383803436557380827011382643653	356	2023-06-25	AD6510657927626824267934878	международная	1689697.9331	508.7561	доставлена	SBININBBXXX
4013	RU4283803436544879224116585983050	643	2023-10-01	RU2683803436512319317744369021772	внутренняя	5851900.3506	92.0329	доставлена	\N
4014	RU4383803436557380827011382643653	978	2023-12-16	KZ2499507692801987947713532	международная	6193328.5800	482.8088	отменена	SOGEFRPP
4015	RU6083803436557649065533492172245	356	2023-11-20	RU9483803436516702191580023603147	внутренняя	5231642.7148	641.3472	отправлена	\N
4016	RU8083803436567877444686336475183	840	2023-02-21	AD6423784205116918459092313	международная	6928865.4413	781.6766	отправлена	IRVTUS3NXXX
4017	RU2583803436525056668985275863842	398	2023-07-05	RU7862138116958673154178615	внутренняя	4925062.6926	84.5540	доставлена	\N
4018	RU6583803436552414284054924599360	156	2023-04-04	RU7383803436569356631218275502161	внутренняя	8867032.7124	72.8107	отменена	\N
4019	RU4083803436519648806531502670697	643	2023-02-24	RU6183803436555838927651384339574	внутренняя	7730826.8388	237.9354	отправлена	\N
4020	RU4183803436593654490331448399606	356	2023-10-23	RU6983803436551969328605594993446	внутренняя	4662219.7129	320.8762	отправлена	\N
4021	RU5183803436585063037953141711870	840	2023-03-08	BY3655759075925899118160167	международная	7607928.1533	280.0455	отменена	IRVTUS3NXXX
4022	RU1983803436518034161993382946183	398	2023-05-19	RU4383803436594641659799774635872	внутренняя	7009468.7163	799.6902	доставлена	\N
4023	RU6183803436573612137819734816326	356	2023-06-29	DE7398082869144270030188418	международная	124459.9113	937.1831	доставлена	SBININBBXXX
4024	RU1183803436512373318427988836252	398	2023-09-01	IN1980847296905846678982146	международная	1824841.0907	46.6524	отправлена	CASPKZKAXXX
4025	RU7583803436597888322431139189153	156	2023-12-24	ES9233870768836331044636730	международная	2786691.6511	85.7795	отменена	BKCHCNBJ
4026	RU5583803436544105301147510534206	356	2023-11-12	RU2183803436551906716086082339754	внутренняя	5095125.5966	396.3178	отменена	\N
4027	RU5883803436537252361294139722938	978	2023-02-28	PT2911607973083022430041132	международная	3163821.9187	479.3475	отменена	RZBAATWW
4028	RU4983803436534576819154749347962	398	2023-07-11	RU7583803436593274051968042799324	внутренняя	1951225.7594	646.1462	отменена	\N
4029	RU1683803436549082108439124677076	356	2023-12-19	RU5183803436585063037953141711870	внутренняя	7759952.1457	986.0063	отменена	\N
4030	RU9583803436557636243711161422858	398	2023-12-22	AL9339894679581672655084190	международная	4754059.7838	112.4723	отменена	CASPKZKAXXX
4031	RU1283803436521770311179326367954	156	2023-03-25	BY4355820888642859304721324	международная	6885206.2544	318.1628	отменена	BKCHCNBJ
4032	RU8083803436548053884024737088236	356	2023-03-20	RU9883803436559947701649293062119	внутренняя	4209343.5446	331.4553	отправлена	\N
4033	RU1683803436583298094705869717304	398	2023-11-07	IN8942986844497041799981522	международная	1068656.9877	536.6647	отменена	CASPKZKAXXX
4034	RU3683803436529963181547651499120	156	2022-12-28	KZ4926347695123115544704068	международная	571463.6171	304.4818	отправлена	BKCHCNBJ
4035	RU1983803436510686315036595318873	643	2023-09-24	KZ2137846349064365926326308	внутренняя	1292915.3054	126.0123	доставлена	\N
4036	RU3583803436543438797337964557116	356	2023-11-19	RU4883803436563163057705977553405	внутренняя	5277136.1999	773.6015	доставлена	\N
4037	RU9683803436520170153501466272589	840	2023-09-24	BY4970347404425038062072905	международная	2133485.6723	269.7518	отправлена	IRVTUS3NXXX
4038	RU7183803436551143317683635788042	156	2023-06-23	RU2183803436586747579379810386651	внутренняя	7558868.1042	443.9781	отправлена	\N
4039	RU6183803436571932790348770462135	840	2023-10-26	RU5183803436599553165549416662045	внутренняя	3690110.0985	322.9246	отменена	\N
4040	RU7183803436551143317683635788042	356	2023-05-08	RU5783803436567884889437805923129	внутренняя	253271.3406	111.1226	доставлена	\N
4041	RU5883803436549838724600410631189	978	2023-09-09	RU9683803436511276549947859990709	внутренняя	7107984.5286	716.8058	отправлена	\N
4042	RU6483803436531317735484528392559	978	2023-09-27	RU9383803436563463129216774786629	внутренняя	8449876.3404	992.2362	доставлена	\N
4043	RU2883803436564862346362051659673	156	2023-06-21	VN2039362992559470884553918	международная	8144212.2240	429.7860	доставлена	BKCHCNBJ
4044	RU7583803436597888322431139189153	840	2023-06-28	DE7727276917676546797940193	международная	6200203.5434	535.3886	отменена	CHASUS33
4045	RU5083803436563140090168469536649	643	2023-05-12	AD5837341173527504105504785	внутренняя	7111974.5614	345.2096	отменена	\N
4046	RU2083803436593214630941740939011	643	2023-02-23	AD5898592154524477704629284	внутренняя	1937211.1019	331.6076	отправлена	\N
4047	RU9683803436597203099828784600586	156	2023-12-08	RU5183803436599553165549416662045	внутренняя	8154491.0868	863.6309	отправлена	\N
4048	RU6283803436561107985248905256058	840	2023-07-27	AL9171425277185418140749522	международная	241300.8588	266.6866	отправлена	IRVTUS3NXXX
4049	RU7583803436593274051968042799324	398	2022-12-28	IN5237938058873483152208606	международная	7539720.5107	294.9733	доставлена	CASPKZKAXXX
4050	RU6483803436575827628326698282321	356	2023-01-25	ES3060607295541069606618411	международная	7104380.7233	754.0902	доставлена	SBININBBXXX
4051	RU9383803436568402663247236595753	398	2023-05-15	RU5983803436596779338391553657957	внутренняя	2714336.6351	523.2598	отменена	\N
4052	RU6183803436551232797419519235346	156	2023-03-12	RU9665970349021502594483219	внутренняя	7986207.8229	609.7658	отменена	\N
4053	RU8583803436593152008036708778596	840	2023-09-27	ES8686167089887017977984105	международная	5468945.2018	83.6517	отправлена	IRVTUS3NXXX
4054	RU5683803436575772290627280121203	978	2022-12-28	RU4583803436571583967013936520660	внутренняя	8994386.2896	392.1698	отправлена	\N
4055	RU1383803436546084241558471107471	156	2023-05-28	RU7813157659629853471133236	внутренняя	7638074.9685	103.2142	доставлена	\N
4056	RU9683803436541591047480784615833	398	2023-07-24	RU5245959849819035341933995	внутренняя	3199099.4961	109.4921	доставлена	\N
4057	RU8183803436576908594301902139271	978	2023-01-06	RU9983803436563015974445739907644	внутренняя	952662.8823	291.0292	отправлена	\N
4058	RU7583803436545511345420608427589	356	2023-03-10	RU9583803436547610609904791788853	внутренняя	7992898.3548	40.6686	доставлена	\N
4059	RU9083803436542335742968981386823	840	2023-05-27	AL2040160895900977235209183	международная	7045566.6269	438.8551	доставлена	IRVTUS3NXXX
4060	RU3683803436529963181547651499120	840	2023-10-27	AL2992529674904682186092980	международная	4970673.2307	714.0989	доставлена	CHASUS33
4061	RU3083803436572725983728902081378	978	2023-07-25	RU3183803436545750333950215053352	внутренняя	6984388.6797	281.2476	отправлена	\N
4062	RU7783803436578403910419087666263	978	2023-01-14	ES9065023124744065783957695	международная	5615305.9644	411.5752	доставлена	SOGEFRPP
4063	RU4983803436548786021946522460624	398	2023-05-05	RU7383803436569356631218275502161	внутренняя	2952674.5787	925.5447	отправлена	\N
4064	RU3383803436548623436381587682007	978	2023-08-06	RU4583803436567844239839748091371	внутренняя	3554553.3511	894.6871	отменена	\N
4065	RU1383803436598073263367823117200	840	2023-05-15	BY5253327998817244284192353	международная	5179932.7807	171.4900	доставлена	CHASUS33
4066	RU8183803436576908594301902139271	156	2023-04-05	VN5617076841395446774023489	международная	8134727.6741	136.8510	отправлена	BKCHCNBJ
4067	RU2183803436538160023828199079683	643	2023-07-26	RU9883803436596118671708861810646	внутренняя	4973359.9790	558.5542	отправлена	\N
4068	RU5583803436525031727011657164177	978	2023-06-25	RU4869295497490982099017073	внутренняя	7544030.7828	120.8401	доставлена	\N
4069	RU7483803436591068390387769478580	643	2023-06-23	RU1983803436549890414007715363567	внутренняя	796522.9226	531.9019	отправлена	\N
4070	RU3783803436585191546282680625888	356	2023-02-23	RU4985431803187492462465149	внутренняя	7973937.6310	513.0480	отправлена	\N
4071	RU4383803436586323329892508459044	840	2023-10-08	PT9744313979193942405406766	международная	6645593.3908	274.0183	отменена	IRVTUS3NXXX
4072	RU1183803436541561390025398925839	356	2023-06-10	AD6988379087491514616450435	международная	1022301.6273	697.6802	отправлена	SBININBBXXX
4073	RU2583803436573489146610412814439	398	2023-07-13	IN2973123092043260678290525	международная	1073718.3523	190.1013	отправлена	CASPKZKAXXX
4074	RU7883803436577262824038798840088	978	2023-05-11	KZ1175241423863034180899809	международная	2243272.3720	873.2604	доставлена	SOGEFRPP
4075	RU4383803436535637847836978327691	398	2023-01-13	VN3467826411267550912082602	международная	1845755.9301	991.0383	доставлена	CASPKZKAXXX
4076	RU8483803436576032684947735830335	978	2023-07-20	RU6283803436561107985248905256058	внутренняя	1665984.1905	330.2888	доставлена	\N
4077	RU9683803436579408636311341559980	840	2023-07-10	PT1369182705337434486122608	международная	272069.4121	121.0146	отменена	CHASUS33
4078	RU5483803436551418630110242560620	156	2023-07-04	RU3183803436556325220643083039724	внутренняя	6323532.9849	519.7336	доставлена	\N
4079	RU6383803436530975100435134167112	643	2023-03-26	RU2283803436588289284937975921944	внутренняя	7231680.8691	195.7615	доставлена	\N
4080	RU8683803436557989786811096289958	398	2023-02-24	AL8712433057956671192486534	международная	5945421.3093	576.0244	отменена	CASPKZKAXXX
4081	RU6983803436557684576294868357987	398	2023-10-02	AD9158970645082199592781302	международная	957932.8786	763.7788	доставлена	CASPKZKAXXX
4082	RU3183803436583121152517184662518	840	2023-05-02	AD3527117549764193560104552	международная	2727289.0931	352.1293	отменена	CHASUS33
4083	RU8483803436576032684947735830335	643	2023-10-17	KZ3814207453866548199262017	внутренняя	7668354.2450	965.1704	отправлена	\N
4084	RU6783803436582018660242960957244	978	2023-04-29	PT6585299809373748631320216	международная	4574547.9217	257.7846	отправлена	SOGEFRPP
4085	RU2983803436572636545308279163382	156	2023-08-23	RU5183803436596697120047636808100	внутренняя	5644549.9772	491.3041	отправлена	\N
4086	RU6983803436580831999013679742086	156	2023-10-18	RU7568857733078995852149807	внутренняя	3964664.0098	817.8610	отправлена	\N
4087	RU2883803436564862346362051659673	643	2023-10-03	RU5783803436573951128453151787227	внутренняя	9655378.2769	760.8074	доставлена	\N
4088	RU4483803436574648344464338946055	156	2023-01-19	RU4883803436561825246742556433732	внутренняя	2917822.4849	715.9168	отменена	\N
4089	RU6983803436518663051613263930888	156	2023-08-25	RU1228574246343209490726690	внутренняя	5343687.9631	145.2529	отправлена	\N
4090	RU7783803436529059332090835348557	398	2023-08-30	BY5165714158459161994706184	международная	4904044.0883	439.7478	отменена	CASPKZKAXXX
4091	RU8683803436511417676206561932357	840	2023-04-12	RU8583803436567351126582917385267	внутренняя	3135412.1668	393.4682	отменена	\N
4092	RU6983803436596433824452063468541	643	2022-12-28	RU4683803436521950147450839996450	внутренняя	6661769.5938	742.8557	отправлена	\N
4093	RU8483803436593374085227717891522	356	2023-04-25	RU9883803436559947701649293062119	внутренняя	1117459.2926	378.5372	доставлена	\N
4094	RU8383803436583878629872361871714	978	2023-03-28	DE7394465175260063161766503	международная	5973252.1285	269.0091	отправлена	DEUTDEFFXXX
4095	RU7183803436513501317784267991188	840	2023-09-24	KZ1261964955235280428449332	международная	6429398.1496	727.1798	отправлена	CHASUS33
4096	RU1083803436588429797000364388942	840	2023-10-09	RU3783803436562139250445157080524	внутренняя	349948.5859	261.2567	отменена	\N
4097	RU5983803436558435772787343054218	398	2023-01-24	AD8792460908040006076696269	международная	7866052.3087	289.5194	отправлена	CASPKZKAXXX
4098	RU7283803436528848493351990702937	156	2023-10-25	RU3083803436572725983728902081378	внутренняя	785423.6415	436.9793	отменена	\N
4099	RU1483803436556765140449291811625	356	2023-06-10	IN9861787887307268824388660	международная	1454068.4630	378.6487	отменена	SBININBBXXX
4100	RU4183803436598422593606583773593	978	2023-07-03	VN2671513736301067038418201	международная	6982322.7351	647.7717	доставлена	RZBAATWW
4101	RU7383803436585863943754594310819	840	2023-09-26	BY1735200479642709938404741	международная	4903782.6739	397.2375	отправлена	IRVTUS3NXXX
4102	RU2483803436537933507280624045523	356	2023-12-27	VN7932511695352640722390088	международная	7541027.2724	368.4333	доставлена	SBININBBXXX
4103	RU6583803436588261503476787515721	840	2023-04-16	RU8483803436514025076841381077297	внутренняя	8243692.7988	937.0657	отправлена	\N
4104	RU7483803436529598231033100377224	840	2023-06-16	RU2783803436598441945275189813351	внутренняя	6563422.4705	190.5448	отменена	\N
4105	RU4583803436588661449801193641363	840	2023-02-21	BY5967609758465721189640504	международная	181437.2957	176.4065	отправлена	CHASUS33
4106	RU4083803436530357399673623809331	398	2023-03-19	PT1767055383927256013902978	международная	8983212.3351	983.3380	отменена	CASPKZKAXXX
4107	RU8683803436520349379894661014091	643	2023-01-09	RU3583803436531844714480494060517	внутренняя	4855844.4926	719.7927	отменена	\N
4108	RU8183803436546948351691601253240	156	2023-12-15	DE8447895803540599770228400	международная	3093032.2111	911.6806	отменена	BKCHCNBJ
4109	RU7583803436597888322431139189153	643	2023-06-30	KZ8345500253002490862139301	внутренняя	8642425.9333	750.9543	отменена	\N
4110	RU8683803436558409197465918354522	156	2023-12-01	RU5183803436550941857646482749776	внутренняя	7545505.4265	911.2879	отправлена	\N
4111	RU6083803436569163727288631654599	356	2023-02-01	KZ8519709932313876187020388	международная	6168352.7168	154.6348	отправлена	SBININBBXXX
4112	RU8183803436532187852215520403243	356	2023-04-26	RU5683803436522754650880470438385	внутренняя	8269675.1988	633.5952	доставлена	\N
4113	RU1483803436555535016685486735994	398	2023-11-22	RU8683803436520349379894661014091	внутренняя	294082.2039	0.0000	доставлена	\N
4114	RU4083803436534430125114460530795	356	2023-06-02	RU7483803436595528340078834029783	внутренняя	2333782.2913	394.6357	доставлена	\N
4115	RU4083803436523112590591409946049	156	2023-11-20	RU5083803436521160540176223483455	внутренняя	5522998.3811	536.1803	доставлена	\N
4116	RU2283803436594102552659582448178	156	2023-05-19	RU7483803436512314763652680872976	внутренняя	623495.9357	825.2835	отправлена	\N
4117	RU7483803436595528340078834029783	840	2023-06-30	RU4046924736666341177813014	внутренняя	6094264.3587	686.7867	доставлена	\N
4118	RU2683803436566742853200336170327	978	2023-08-04	IN7733155532753423664688585	международная	813679.2451	364.8046	отправлена	DEUTDEFFXXX
4119	RU7483803436595528340078834029783	356	2023-05-28	PT4466329846348569880619998	международная	5155343.5792	353.0767	отправлена	SBININBBXXX
4120	RU1683803436596193217028081534610	643	2023-01-19	BY2818685322276162990081064	внутренняя	7096247.5221	616.6588	отправлена	\N
4121	RU7483803436595027677837710467368	978	2023-01-07	AD9389746405136924592999339	международная	5480578.3549	59.1209	отменена	SOGEFRPP
4122	RU9283803436564588409350021574669	356	2023-06-03	RU3083803436518573891716312234719	внутренняя	1275820.2214	512.5050	отменена	\N
4123	RU8483803436512925144599170278485	356	2023-10-27	RU3583803436531844714480494060517	внутренняя	5484809.4215	620.7156	отменена	\N
4124	RU5583803436533254773648721597711	978	2023-06-26	AD4198121206211351349966303	международная	9693046.0169	791.4533	отменена	RZBAATWW
4125	RU5983803436518386216122030936247	643	2023-07-13	ES7141557584134185079918553	внутренняя	2887266.4052	554.3541	отменена	\N
4126	RU4083803436525661046500520760430	840	2023-07-27	AL6431958553247671676146857	международная	1682608.5247	414.3016	доставлена	IRVTUS3NXXX
4127	RU2983803436530272226005609138408	398	2023-10-21	RU2983803436545911307181108696312	внутренняя	4860754.8729	650.0615	доставлена	\N
4128	RU2983803436585384738431881857607	978	2023-10-16	RU9983803436588442958405952112241	внутренняя	5593664.8695	760.0694	отменена	\N
4129	RU1283803436597755454846611928328	156	2023-03-08	RU3683803436583826961336736431806	внутренняя	518708.0832	687.4782	доставлена	\N
4130	RU9083803436527710172880684864084	840	2023-01-07	PT5982358477094362313164140	международная	4484490.1752	115.4446	доставлена	CHASUS33
4131	RU3983803436583730529285495292571	398	2023-01-11	AD3393253857832823516075459	международная	388582.8030	523.6387	доставлена	CASPKZKAXXX
4132	RU5783803436567884889437805923129	643	2023-12-26	KZ9066690874649121156954843	внутренняя	8015104.1345	789.0331	доставлена	\N
4133	RU3883803436554504516286459147223	643	2023-10-09	AD8227603377777078053224443	внутренняя	8779211.4399	332.9968	отправлена	\N
4134	RU5783803436567884889437805923129	156	2023-01-02	PT5979246583537561824400310	международная	858053.8489	810.1066	доставлена	BKCHCNBJ
4135	RU5383803436532276110708298062956	356	2023-04-30	RU4483803436537144245226352938256	внутренняя	8764905.9566	129.1997	отменена	\N
4136	RU9683803436541591047480784615833	978	2023-09-21	RU9683803436597203099828784600586	внутренняя	2103979.4124	342.7548	отправлена	\N
4137	RU3383803436548623436381587682007	643	2023-07-04	AL1561280815647528913975005	внутренняя	446978.6998	891.8170	отправлена	\N
4138	RU3383803436533625475503259998648	978	2023-08-31	ES4145123997703122654098843	международная	2176126.2249	651.7455	доставлена	SOGEFRPP
4139	RU7383803436567535429961689788567	156	2023-01-26	RU2483803436580851808318436691458	внутренняя	2581614.4421	528.7319	доставлена	\N
4140	RU6583803436552414284054924599360	398	2023-10-29	RU8383803436583878629872361871714	внутренняя	7560405.0659	54.5270	отправлена	\N
4141	RU9383803436515318038329930627155	840	2023-08-16	RU8283803436517214496879594083501	внутренняя	8439450.6635	303.8468	отменена	\N
4142	RU9683803436511276549947859990709	156	2023-04-28	RU6683803436547011171926119923803	внутренняя	8667798.5843	722.9999	доставлена	\N
4143	RU8883803436592173067148862634991	978	2023-05-12	KZ6434316664382356347013081	международная	2856473.2166	600.3892	отменена	SOGEFRPP
4144	RU5783803436556321671762187197309	840	2023-09-02	AL6492503099150377017455919	международная	4379982.1992	504.5298	отправлена	CHASUS33
4145	RU8183803436576908594301902139271	356	2023-05-30	VN4020612096770873467996599	международная	5749994.9672	305.5667	отменена	SBININBBXXX
4146	RU4283803436538514172142523078432	643	2023-07-01	DE8040261465155962387170064	внутренняя	5194636.9988	734.8590	отправлена	\N
4147	RU5983803436533405804846460378377	840	2023-05-24	RU9183803436523189940915642395180	внутренняя	9628186.4824	728.0131	доставлена	\N
4149	RU3983803436583094600516227232333	156	2023-08-01	RU5583803436555177704368963744222	внутренняя	8403254.9115	177.8654	доставлена	\N
4150	RU1383803436565139777755041333233	156	2023-09-13	IN9343917871520107194877446	международная	6372723.9279	208.9815	доставлена	BKCHCNBJ
4151	RU9983803436581801115411623274695	840	2023-12-14	RU2083803436571871160330810400191	внутренняя	9117148.7124	363.8755	доставлена	\N
4152	RU5083803436556786327042016836549	978	2023-09-30	DE7961721071688046823224359	международная	5106304.5303	551.9443	отправлена	DEUTDEFFXXX
4153	RU4683803436584135461455281070651	643	2023-11-09	ES5520965484166306187819732	внутренняя	5126916.1627	607.0055	отправлена	\N
4154	RU4683803436521950147450839996450	156	2023-12-18	DE6926213763554434442678655	международная	4578313.4265	477.8391	доставлена	BKCHCNBJ
4155	RU3683803436526413764026311806751	356	2023-11-13	IN5028055596139307520815273	международная	4106029.2984	21.4958	отменена	SBININBBXXX
4156	RU6183803436536163842184020816729	356	2023-01-28	IN9338078702794390713280099	международная	7349753.9884	327.7212	отправлена	SBININBBXXX
4157	RU8183803436546948351691601253240	643	2023-10-28	RU8983803436543970357311304848339	внутренняя	4234387.4764	123.2133	отменена	\N
4158	RU2283803436551819000625747494652	978	2023-07-25	RU8083803436588746463552823930061	внутренняя	9755251.2270	704.1979	доставлена	\N
4159	RU1183803436513944372774322746458	156	2023-02-04	IN1496073582038210842761158	международная	5369520.4507	684.6881	отменена	BKCHCNBJ
4160	RU7483803436575212193030608824580	643	2023-01-19	DE3775067947676244985518011	внутренняя	5491096.1458	915.3768	доставлена	\N
4161	RU5583803436556151120487866130687	398	2022-12-31	RU6483803436595566817980742907742	внутренняя	7640620.5540	923.4685	доставлена	\N
4162	RU8483803436586135450040789229889	356	2023-08-21	ES1897142191534444291715961	международная	2025399.7651	960.3982	отправлена	SBININBBXXX
4163	RU2983803436539974076802515756241	356	2023-07-03	AD5021077077507178353818959	международная	8428657.9733	650.2771	отправлена	SBININBBXXX
4164	RU9783803436531316283778462589484	156	2023-10-14	RU4943093694135684804436003	внутренняя	9325406.0794	75.7452	доставлена	\N
4165	RU8083803436548053884024737088236	978	2023-05-15	RU5586638424698393633379388	внутренняя	7382039.2384	941.4452	отправлена	\N
4166	RU8883803436592173067148862634991	398	2023-10-05	RU4283803436571605132393354830061	внутренняя	8455172.2413	319.0704	отправлена	\N
4167	RU7483803436595528340078834029783	978	2023-07-14	AL7427311796991178702678802	международная	7733935.4352	195.4410	доставлена	DEUTDEFFXXX
4168	RU6583803436573484995572407857396	156	2023-10-12	ES7448490676248553024332265	международная	7477422.6318	863.0268	доставлена	BKCHCNBJ
4169	RU6283803436541447099313442593938	398	2023-01-05	RU8372022562631038074876250	внутренняя	8581330.2639	515.0084	доставлена	\N
4170	RU6383803436541953279771793851240	356	2023-06-03	RU4583803436535138140020222748384	внутренняя	3257702.4139	254.6293	отменена	\N
4171	RU1983803436574962372646294489745	978	2023-06-23	RU5983803436558435772787343054218	внутренняя	9649722.3938	844.8420	доставлена	\N
4172	RU4483803436574648344464338946055	356	2023-10-01	RU6583803436526807323529165700056	внутренняя	8423984.6665	583.2226	отправлена	\N
4173	RU8183803436576908594301902139271	643	2023-05-30	RU4583803436576777630615652907536	внутренняя	4832319.4771	602.7902	отправлена	\N
4174	RU5583803436555177704368963744222	156	2023-11-04	RU4383803436597428452957764955765	внутренняя	19372.0445	173.5022	доставлена	\N
4175	RU1683803436543683792461716245841	156	2023-10-26	AD5622644058764467411461376	международная	7058150.0742	362.4167	отменена	BKCHCNBJ
4176	RU8183803436559528710172368223769	398	2023-11-29	RU7283803436583841985241060182740	внутренняя	786038.2364	755.6259	отправлена	\N
4177	RU6883803436521704893234788177503	840	2023-08-02	RU2983803436572636545308279163382	внутренняя	7502967.9134	852.5382	отправлена	\N
4178	RU6583803436599318340096840026283	978	2023-07-14	RU8683803436571821829992754282142	внутренняя	5550611.0157	579.3670	отменена	\N
4179	RU3883803436531800763308499008852	356	2023-03-17	ES1343507613655065827539756	международная	8558847.5383	448.5527	отправлена	SBININBBXXX
4180	RU1183803436547102061688733775669	356	2023-06-16	AD6741932596169079463681628	международная	5614023.1038	606.7466	доставлена	SBININBBXXX
4181	RU5583803436533254773648721597711	840	2023-08-03	RU5983803436596779338391553657957	внутренняя	3165284.2680	789.3775	отменена	\N
4182	RU3083803436518573891716312234719	398	2023-04-15	RU6083803436569163727288631654599	внутренняя	9604604.2615	525.2796	отменена	\N
4183	RU6983803436548066705729944547736	156	2023-01-16	VN2220307783767701817889247	международная	2716959.2605	848.1138	доставлена	BKCHCNBJ
4184	RU4683803436521950147450839996450	356	2023-08-16	RU5183803436585063037953141711870	внутренняя	7891984.8792	180.6164	отменена	\N
4185	RU7183803436513501317784267991188	840	2023-05-10	RU5883803436549838724600410631189	внутренняя	7956152.8215	869.2109	доставлена	\N
4186	RU1083803436563162471160560931522	643	2023-10-10	RU4183803436598422593606583773593	внутренняя	7066935.8564	679.6126	доставлена	\N
4187	RU5483803436551418630110242560620	356	2023-11-17	RU4783803436556925313909023616425	внутренняя	8960743.5585	831.2044	доставлена	\N
4188	RU5583803436525031727011657164177	156	2023-11-17	RU7383803436569356631218275502161	внутренняя	5968631.5999	138.5704	отменена	\N
4189	RU6583803436565551879254347008316	643	2023-12-27	RU5683803436539120556194350818141	внутренняя	9424562.7151	866.5872	отменена	\N
4190	RU8383803436583878629872361871714	398	2023-04-14	RU8683803436557989786811096289958	внутренняя	8379650.3404	504.7647	отменена	\N
4191	RU9683803436526786707929300961979	398	2023-01-17	RU1683803436510344781123537250392	внутренняя	2819834.1902	531.3848	отменена	\N
4192	RU1983803436549890414007715363567	398	2023-02-07	RU1683803436510344781123537250392	внутренняя	505724.6777	548.8495	отменена	\N
4193	RU1183803436512373318427988836252	356	2023-04-17	VN7624049491206681202125093	международная	6603398.2998	516.8988	отменена	SBININBBXXX
4194	RU6183803436571932790348770462135	156	2023-06-16	AL6890193008229898478986135	международная	8538438.2673	423.8356	отменена	BKCHCNBJ
4195	RU5783803436556321671762187197309	398	2023-12-16	DE4039427962020816222271243	международная	512725.7100	204.3222	доставлена	CASPKZKAXXX
4196	RU6183803436573612137819734816326	840	2023-12-01	RU2983803436572636545308279163382	внутренняя	5200418.9732	579.7036	отправлена	\N
4197	RU9283803436560888794155508079505	643	2023-03-03	ES1821218943525564571793534	внутренняя	5229684.0484	527.1972	отменена	\N
4198	RU4283803436571605132393354830061	643	2023-07-28	RU5183803436573013692902081587761	внутренняя	4263557.8530	413.4876	доставлена	\N
4199	RU5683803436573106663960342062340	643	2023-09-07	BY8864352362515921936621743	внутренняя	6194388.6477	52.7397	отправлена	\N
4200	RU9683803436524115739172828059349	840	2023-09-09	RU7783803436536804517087406327796	внутренняя	5272604.4719	814.2151	отправлена	\N
4201	RU4083803436561171626967381260937	978	2023-06-18	VN2246580482812793319790928	международная	1268904.2949	144.7685	отменена	RZBAATWW
4202	RU3883803436515226766320509995235	978	2023-05-04	RU3383803436530100232705488681423	внутренняя	5027895.6547	769.6245	отменена	\N
4203	RU6283803436561107985248905256058	978	2023-09-27	RU8583803436598717986670697262250	внутренняя	6492723.7001	392.0962	отправлена	\N
4204	RU7283803436582085910615477000049	840	2023-01-01	AD2629906295623989512615065	международная	9787752.1205	196.5830	отменена	IRVTUS3NXXX
4205	RU2783803436512588965300606208370	840	2023-03-16	RU3748532427314578946519311	внутренняя	5113797.5190	805.6261	доставлена	\N
4206	RU6783803436527708547728704282997	156	2023-07-24	PT8927257827072732505053040	международная	3764121.7215	386.2801	доставлена	BKCHCNBJ
4207	RU6483803436575827628326698282321	356	2023-02-06	DE4563193562975418902843935	международная	2670077.9556	131.6486	отменена	SBININBBXXX
4208	RU5783803436567884889437805923129	398	2023-03-08	RU2183803436535230801413319305895	внутренняя	5715646.6733	961.9642	отправлена	\N
4209	RU9083803436513364676730542126445	978	2023-12-05	DE5931775499559757836152488	международная	4972592.6121	236.9364	отменена	RZBAATWW
4210	RU2083803436536025786076127901648	398	2023-07-31	KZ4594568463718574398327149	международная	6143637.6630	508.9247	отправлена	CASPKZKAXXX
4211	RU9883803436559947701649293062119	398	2023-08-19	DE3645847517650743723077221	международная	6913199.2978	440.5204	доставлена	CASPKZKAXXX
4212	RU1183803436512373318427988836252	978	2023-05-03	ES9079661296144452183314178	международная	6214772.3698	807.0897	доставлена	RZBAATWW
4213	RU6583803436547384322379422553840	156	2023-01-23	RU8583803436529401978461350257287	внутренняя	8786303.9705	397.7060	отменена	\N
4214	RU5383803436532276110708298062956	356	2023-06-20	RU6383803436517724803474176712817	внутренняя	8609355.4113	62.3960	отправлена	\N
4215	RU3683803436526413764026311806751	398	2023-02-04	PT7393114939302574389568202	международная	1588445.5007	561.6885	отменена	CASPKZKAXXX
4216	RU6883803436521704893234788177503	398	2023-09-20	RU6533738537682215667611922	внутренняя	8612819.3057	481.2550	доставлена	\N
4217	RU1383803436585969091171133733533	398	2023-12-02	RU9683803436559214297350823715344	внутренняя	9013378.8017	852.6647	отменена	\N
4218	RU3483803436537283842522563725379	398	2023-06-17	RU5183803436573013692902081587761	внутренняя	6102964.6287	163.1421	отменена	\N
4219	RU6783803436510078136565817264354	398	2023-04-30	IN4477611853050061685176036	международная	7823385.5834	489.9075	отменена	CASPKZKAXXX
4220	RU5983803436563752601230784661821	978	2023-08-24	AD1696265056285934686911853	международная	4226948.0989	758.6224	отправлена	RZBAATWW
4221	RU9983803436515137760640096699879	356	2023-09-22	DE3648189375865066498037809	международная	6840479.7216	376.7771	отправлена	SBININBBXXX
4222	RU2483803436580851808318436691458	978	2023-08-28	RU4258872012728750674155315	внутренняя	9081198.6148	966.1141	доставлена	\N
4223	RU3183803436559935083955185145410	356	2023-10-05	RU3783803436559423561964096195262	внутренняя	5349635.8063	645.4782	отправлена	\N
4224	RU7283803436528848493351990702937	398	2023-09-07	RU7083803436565850801859363291526	внутренняя	7484841.0026	872.7768	отправлена	\N
4225	RU2983803436572678251629055132350	978	2023-02-23	RU7383803436567535429961689788567	внутренняя	6727662.3022	82.3295	отменена	\N
4226	RU1283803436597755454846611928328	643	2023-10-25	AD9918805081177688143642112	внутренняя	4053569.0924	650.8770	отменена	\N
4227	RU2883803436564862346362051659673	398	2023-12-09	RU5783803436567884889437805923129	внутренняя	4662349.7815	262.2432	отменена	\N
4228	RU4383803436557380827011382643653	840	2023-02-16	AL8853083321786153329331525	международная	3734686.9513	252.3599	доставлена	IRVTUS3NXXX
4229	RU8983803436551003507571679577910	978	2023-04-03	RU4483803436574648344464338946055	внутренняя	1322730.4710	504.9579	отправлена	\N
4230	RU4383803436586323329892508459044	156	2023-05-06	RU2483803436559904294875702128517	внутренняя	1553488.2060	22.3462	отменена	\N
4231	RU3883803436531800763308499008852	356	2023-01-04	AD7676473739710778220571485	международная	394442.5777	56.3189	доставлена	SBININBBXXX
4232	RU5883803436512174556620785995683	398	2023-02-09	BY4139675084096963015149994	международная	9394120.4253	120.5468	доставлена	CASPKZKAXXX
4233	RU1883803436537462946976236392804	643	2023-11-19	RU1583803436597114679330016317094	внутренняя	3691699.5506	243.0742	доставлена	\N
4234	RU1683803436583298094705869717304	356	2023-02-04	RU7583803436593621382878998665048	внутренняя	2937232.9454	18.0554	отправлена	\N
4235	RU9183803436594783043422280553530	398	2023-06-21	RU2083803436593214630941740939011	внутренняя	3376266.7480	16.3103	доставлена	\N
4236	RU1183803436541561390025398925839	156	2023-01-16	BY4074118428244503233879469	международная	2772655.3193	632.9431	доставлена	BKCHCNBJ
4237	RU4083803436523112590591409946049	978	2023-06-11	RU5183803436531460410872953149827	внутренняя	266084.2682	222.9281	отменена	\N
4238	RU1183803436512373318427988836252	643	2023-12-02	RU5783803436573951128453151787227	внутренняя	9377551.5767	187.3239	отправлена	\N
4239	RU1583803436513968949783488654583	356	2023-10-29	RU6683803436563942598707878107815	внутренняя	389178.8252	310.7753	доставлена	\N
4240	RU5883803436544935035293164341064	356	2023-04-01	AL6477257816787437506599276	международная	5733725.2543	277.9284	отправлена	SBININBBXXX
4241	RU2183803436555308456329784386702	978	2023-11-30	RU8483803436517523304653033637180	внутренняя	9988332.7736	473.7709	доставлена	\N
4242	RU8183803436564595439284009293487	398	2023-04-05	RU8183803436576908594301902139271	внутренняя	5043106.9958	847.4964	отправлена	\N
4243	RU2183803436555308456329784386702	156	2023-01-06	RU3783803436559423561964096195262	внутренняя	5036769.0277	485.2862	доставлена	\N
4244	RU4183803436512683300418013703414	398	2023-09-20	AD6035483885524518882981193	международная	3971856.0232	503.5392	отменена	CASPKZKAXXX
4245	RU8683803436531608639655465618756	398	2023-08-09	RU6983803436596433824452063468541	внутренняя	5329415.1343	546.1855	отправлена	\N
4246	RU9583803436562562119396535016715	156	2023-10-17	ES2418750617558421486088584	международная	2912873.1279	735.5318	отправлена	BKCHCNBJ
4247	RU4383803436583134155448910498762	643	2023-02-04	RU4983803436522833268295991391237	внутренняя	7164152.1230	433.0225	доставлена	\N
4248	RU9883803436559947701649293062119	156	2023-12-02	ES9095380945746848403369740	международная	5690098.2582	723.8854	доставлена	BKCHCNBJ
4249	RU5883803436576828712243252221562	398	2023-12-19	AL1666531895714742965167118	международная	7590929.7981	787.8694	доставлена	CASPKZKAXXX
4250	RU6583803436588261503476787515721	840	2023-03-09	RU7383803436585863943754594310819	внутренняя	1974037.9616	319.4311	доставлена	\N
4251	RU9783803436586848496167067081204	643	2023-06-03	KZ9398593166871658868043323	внутренняя	3628858.9617	356.1056	отправлена	\N
4252	RU7783803436536804517087406327796	156	2023-01-18	AL2269222774041593629267839	международная	3032928.9665	183.3361	отправлена	BKCHCNBJ
4253	RU3883803436559428008275215914286	398	2023-09-26	RU7383803436534050516387288663509	внутренняя	1647136.7861	624.0160	доставлена	\N
4254	RU7583803436597888322431139189153	840	2022-12-27	KZ1229592474515046126981034	международная	3960865.5486	158.5325	отменена	CHASUS33
4255	RU2983803436572678251629055132350	978	2023-02-15	IN1953630262206134398017810	международная	8349413.8545	784.6218	отменена	SOGEFRPP
4256	RU3083803436572725983728902081378	398	2023-06-11	AL2364260815888115257746084	международная	4306397.9029	427.2191	отправлена	CASPKZKAXXX
4257	RU6983803436580831999013679742086	356	2023-06-06	VN2732488445254690535849174	международная	7394403.7922	675.1551	отправлена	SBININBBXXX
4258	RU5983803436585678890114061651314	398	2023-01-30	RU6083803436582119843499506879640	внутренняя	1594369.9309	454.1237	отменена	\N
4259	RU7183803436578006903833632767386	840	2023-12-09	AD3285816368365847556228658	международная	1551553.4260	873.5358	отправлена	CHASUS33
4260	RU5883803436551017474710608700284	978	2023-03-25	RU7483803436591068390387769478580	внутренняя	6415016.6575	685.7364	доставлена	\N
4261	RU1983803436510686315036595318873	398	2023-11-07	RU4483803436574648344464338946055	внутренняя	1914219.9494	539.8845	доставлена	\N
4262	RU9183803436594783043422280553530	978	2023-11-16	RU8983803436518961229187913059129	внутренняя	974951.6827	727.2784	доставлена	\N
4263	RU1183803436541561390025398925839	356	2023-06-08	RU8383803436557193853878723819444	внутренняя	4859413.4328	362.2250	доставлена	\N
4264	RU3783803436562139250445157080524	398	2023-05-01	RU3683803436533022850683714599602	внутренняя	9845119.5560	573.7326	отправлена	\N
4265	RU2683803436512319317744369021772	978	2023-04-11	PT1561393834659222036088961	международная	1663381.0220	404.7978	отменена	RZBAATWW
4266	RU6483803436527000884469712767990	840	2023-01-30	RU2983803436539974076802515756241	внутренняя	3571901.6729	936.3886	отменена	\N
4267	RU1083803436516100547774990634896	398	2023-09-25	RU6983803436550083462130199504453	внутренняя	5539113.6617	413.3007	отменена	\N
4268	RU2783803436529440294678710752920	643	2023-04-08	RU8183803436559528710172368223769	внутренняя	7954661.4066	914.0329	отменена	\N
4269	RU1583803436513968949783488654583	356	2023-08-17	RU9483803436588743613330942629999	внутренняя	6406719.0730	138.1193	отправлена	\N
4270	RU2183803436538160023828199079683	156	2023-05-27	RU5583803436555177704368963744222	внутренняя	5954501.5681	507.7069	отменена	\N
4271	RU5483803436547543071206231343471	643	2023-07-31	KZ7346761962008382045189079	внутренняя	3149391.6783	911.6905	доставлена	\N
4272	RU9983803436563015974445739907644	978	2023-10-12	RU1183803436513944372774322746458	внутренняя	3345839.7649	912.9111	отменена	\N
4273	RU8583803436548069379320039967893	840	2023-01-07	RU4883803436583846522749125412438	внутренняя	6508751.4872	783.5298	отправлена	\N
4274	RU1083803436588429797000364388942	156	2023-09-13	RU5497101862360614318048322	внутренняя	2321005.3700	950.1825	отправлена	\N
4275	RU5583803436516539388298963058164	643	2023-04-22	AL8377084126321823283320383	внутренняя	629020.4651	337.0206	отменена	\N
4276	RU8983803436543970357311304848339	156	2023-08-27	RU8283803436593409912626065485368	внутренняя	8076905.8022	97.0312	отменена	\N
4277	RU1083803436563162471160560931522	840	2023-02-13	DE8586988252753323007013471	международная	8031148.8444	918.7600	доставлена	CHASUS33
4278	RU2783803436515955219320238454317	398	2023-05-07	AL6878670195728970925489093	международная	2733442.2169	161.4780	доставлена	CASPKZKAXXX
4279	RU7283803436582085910615477000049	156	2023-08-13	RU5383803436537654175631942789109	внутренняя	4467957.2836	223.0707	отменена	\N
4280	RU2483803436559904294875702128517	978	2023-10-07	RU8983803436588264357315670765686	внутренняя	5170991.5890	602.5017	отправлена	\N
4281	RU4283803436571605132393354830061	398	2023-06-02	AD8196278465846736159039889	международная	5772327.5075	887.6748	доставлена	CASPKZKAXXX
4282	RU3383803436540416635821116917223	643	2023-03-24	DE5262481796631190411952875	внутренняя	1098244.3266	603.3665	доставлена	\N
4283	RU1283803436521770311179326367954	978	2023-12-26	IN5117520622168803303782396	международная	6159428.5024	656.0137	отправлена	SOGEFRPP
4284	RU9683803436520170153501466272589	978	2023-03-18	RU9583803436515959194321808018014	внутренняя	3861716.3339	593.7163	отправлена	\N
4285	RU3983803436583730529285495292571	643	2023-05-31	RU3383803436548623436381587682007	внутренняя	7334581.3705	593.6209	доставлена	\N
4286	RU5783803436567884889437805923129	398	2023-10-15	AL1955389951985102069254016	международная	2767929.7220	768.5163	отправлена	CASPKZKAXXX
4287	RU1183803436541561390025398925839	398	2023-11-26	RU7183803436551143317683635788042	внутренняя	2135038.2691	951.1134	доставлена	\N
4288	RU8683803436558409197465918354522	156	2023-03-17	RU3183803436559935083955185145410	внутренняя	8984620.2165	655.3414	отменена	\N
4289	RU5783803436567884889437805923129	356	2023-08-15	VN2273643056976389385427510	международная	633511.1366	480.4096	отменена	SBININBBXXX
4290	RU2583803436525056668985275863842	643	2023-02-16	RU6383803436541953279771793851240	внутренняя	3525356.2640	696.9253	отправлена	\N
4291	RU3183803436583121152517184662518	840	2023-05-31	RU8683803436558409197465918354522	внутренняя	3594513.2303	641.2572	доставлена	\N
4292	RU5783803436598085342824416355658	398	2023-06-06	KZ6089890717539020118982199	международная	376506.8031	821.8679	отменена	CASPKZKAXXX
4293	RU4283803436530972916151822377436	398	2023-11-16	IN8087218915350403932822755	международная	1448247.0285	698.1206	отправлена	CASPKZKAXXX
4294	RU6383803436517724803474176712817	356	2023-08-22	RU8483803436528403655778834568144	внутренняя	1106509.9030	547.4254	отменена	\N
4295	RU2783803436515955219320238454317	840	2023-12-23	KZ4222657715755518439912650	международная	2838181.1392	127.7772	отправлена	IRVTUS3NXXX
4296	RU8883803436542351475891948314875	643	2023-05-17	RU5083803436556786327042016836549	внутренняя	3853993.8535	304.2221	отправлена	\N
4297	RU9383803436563463129216774786629	643	2023-02-28	RU4583803436546993711061481413708	внутренняя	9697088.6174	118.5265	отправлена	\N
4298	RU6383803436530975100435134167112	356	2023-11-26	AL1886165207681821823424161	международная	4824852.4206	343.6472	отменена	SBININBBXXX
4299	RU4283803436538514172142523078432	978	2023-02-19	RU6583803436588261503476787515721	внутренняя	8323739.8790	920.6567	отменена	\N
4300	RU6583803436565551879254347008316	156	2023-05-26	RU3383803436530100232705488681423	внутренняя	2105997.0776	755.0593	отменена	\N
4301	RU9283803436564588409350021574669	398	2023-11-17	RU4083803436537218400436107027314	внутренняя	2847072.3506	816.8158	отменена	\N
4302	RU5683803436575772290627280121203	840	2023-05-04	ES3092852713506711577515592	международная	8671152.1096	448.5537	доставлена	CHASUS33
4303	RU3383803436530100232705488681423	643	2023-04-13	RU9183803436523189940915642395180	внутренняя	7389813.9821	490.1200	отправлена	\N
4304	RU1583803436597114679330016317094	156	2023-04-20	RU9583803436547610609904791788853	внутренняя	4869974.7418	210.6614	отправлена	\N
4305	RU4983803436522833268295991391237	643	2023-09-18	RU8483803436583598027317615125571	внутренняя	5277433.4028	497.5753	отправлена	\N
4306	RU4383803436557380827011382643653	643	2023-06-06	RU7583803436545511345420608427589	внутренняя	2594983.7519	139.1708	доставлена	\N
4307	RU3583803436597484588589933917343	156	2023-06-14	BY7336997265228940988770610	международная	5609246.2206	444.0086	отправлена	BKCHCNBJ
4308	RU1683803436536773128968824249362	643	2023-04-06	RU7683803436565241249132549566386	внутренняя	6581097.6105	537.1481	отменена	\N
4309	RU3883803436564256045508064629374	398	2023-04-05	BY7493788776399790832723611	международная	3321863.3031	239.9030	доставлена	CASPKZKAXXX
4310	RU4383803436559640804885433764330	643	2023-01-11	RU6983803436548066705729944547736	внутренняя	3554979.9334	197.8100	доставлена	\N
4311	RU8183803436576334203563049364101	156	2023-07-25	PT6473313416695803931454366	международная	4618184.3666	242.6068	доставлена	BKCHCNBJ
4312	RU4083803436525661046500520760430	356	2023-05-28	AL9840287107523253896044131	международная	5660894.8171	136.7032	отправлена	SBININBBXXX
4313	RU3883803436564256045508064629374	840	2023-06-12	ES1998886955975122267030024	международная	8460710.0994	640.1373	отправлена	IRVTUS3NXXX
4314	RU6583803436588261503476787515721	978	2023-10-03	RU2183803436586747579379810386651	внутренняя	4700186.6181	837.3369	отправлена	\N
4315	RU4083803436530357399673623809331	398	2023-04-29	RU8283803436536082355231514909614	внутренняя	4629121.0512	968.4029	отменена	\N
4316	RU9683803436579408636311341559980	398	2023-09-09	RU5883803436551017474710608700284	внутренняя	2303575.8111	669.9722	отправлена	\N
4317	RU8583803436548069379320039967893	978	2023-03-19	RU9483803436516702191580023603147	внутренняя	4655928.7807	144.1485	отменена	\N
4318	RU5983803436533405804846460378377	398	2023-01-16	AL8398803325588063844551604	международная	7623048.9303	856.0580	отправлена	CASPKZKAXXX
4319	RU1983803436574962372646294489745	643	2023-03-02	RU1283803436513390712190126736747	внутренняя	2146986.0754	844.0499	отменена	\N
4320	RU4383803436535637847836978327691	840	2023-10-02	AL2114276062301599648261939	международная	1668296.1658	623.2523	доставлена	IRVTUS3NXXX
4321	RU3783803436562139250445157080524	978	2023-07-08	AL3268359195712537561988680	международная	3219063.1032	0.0000	доставлена	SOGEFRPP
4322	RU4483803436534969190676238532628	156	2023-11-01	ES2894847968568001796209836	международная	7564969.2326	618.7198	отменена	BKCHCNBJ
4323	RU6283803436541447099313442593938	398	2023-06-19	RU1383803436598073263367823117200	внутренняя	8623279.8425	301.3015	отменена	\N
4324	RU6683803436534213789698830771682	978	2023-05-22	RU5083803436583492295875343805447	внутренняя	3295780.3484	368.1028	доставлена	\N
4325	RU3983803436580604058878329162478	978	2023-02-27	ES1892296453704125567457529	международная	5794811.0499	573.1938	отменена	DEUTDEFFXXX
4326	RU9583803436589245078784775619456	398	2023-12-11	RU4883803436510661666911089208306	внутренняя	815672.3065	158.0464	отменена	\N
4327	RU2683803436566742853200336170327	643	2023-10-15	BY4994361893594590822960057	внутренняя	8972784.8242	664.4655	отправлена	\N
4328	RU9683803436520170153501466272589	398	2023-05-22	RU7383803436567535429961689788567	внутренняя	8250298.4913	984.8422	отменена	\N
4329	RU9683803436526786707929300961979	978	2023-08-01	RU3683803436583826961336736431806	внутренняя	6629120.0954	817.6026	доставлена	\N
4330	RU8683803436511417676206561932357	840	2023-07-27	RU7383803436585863943754594310819	внутренняя	1091800.0302	449.6182	отправлена	\N
4331	RU8983803436530366335955653516096	398	2023-04-30	DE6573836235662740045018713	международная	8219344.1783	156.8051	отправлена	CASPKZKAXXX
4332	RU9683803436520170153501466272589	356	2023-09-30	RU5683803436539120556194350818141	внутренняя	8893322.8044	245.4927	отправлена	\N
4333	RU8483803436552375991404578719285	398	2023-01-28	ES4138440032329804335469425	международная	560662.3933	432.6560	отменена	CASPKZKAXXX
4334	RU7083803436575256167282941443393	356	2023-10-07	RU8683803436531608639655465618756	внутренняя	711275.5851	0.0000	отменена	\N
4335	RU7083803436565850801859363291526	978	2023-08-17	RU3683803436542925451475324573982	внутренняя	9730944.2704	973.4753	отменена	\N
4336	RU1683803436549082108439124677076	643	2023-06-02	RU8183803436566794763466227027850	внутренняя	1283250.1402	602.6661	отправлена	\N
4337	RU7483803436595528340078834029783	643	2023-01-21	RU4883803436510661666911089208306	внутренняя	312885.3787	837.8648	доставлена	\N
4338	RU8683803436557989786811096289958	156	2023-03-03	RU4683803436584135461455281070651	внутренняя	4822413.8129	121.4580	отменена	\N
4339	RU3383803436551883036237842733910	643	2023-03-11	BY5636211428590104679845999	внутренняя	7000431.9504	564.9955	отменена	\N
4340	RU2883803436538134433783624054557	978	2023-09-04	RU6783803436583735354795738130605	внутренняя	1547196.3663	595.4770	отменена	\N
4341	RU9183803436523189940915642395180	978	2023-10-12	RU6683803436575472065287991925682	внутренняя	7445133.2025	916.8890	доставлена	\N
4342	RU4683803436521950147450839996450	840	2023-09-22	AL1038204953088750414215889	международная	2072807.7904	653.8608	отменена	CHASUS33
4343	RU5783803436567884889437805923129	156	2023-06-02	AD6277833878348321731870326	международная	1236229.4960	714.5015	отменена	BKCHCNBJ
4344	RU8483803436586135450040789229889	156	2023-06-18	RU6283803436541447099313442593938	внутренняя	6042987.4590	440.0141	отправлена	\N
4345	RU6983803436557684576294868357987	156	2023-05-01	RU5083803436521160540176223483455	внутренняя	6107724.7097	846.9968	отправлена	\N
4346	RU5983803436513359014201161572816	356	2023-01-23	RU8183803436559528710172368223769	внутренняя	5865139.1517	163.8319	доставлена	\N
4347	RU4383803436559640804885433764330	398	2023-05-05	RU2283803436521727957364583057084	внутренняя	8765254.5831	157.0442	отменена	\N
4348	RU8283803436517214496879594083501	156	2023-12-08	KZ6366990677998651907750542	международная	231829.6620	430.9354	отправлена	BKCHCNBJ
4349	RU1383803436546084241558471107471	840	2023-03-16	AL1211126299565322386151392	международная	9463565.2994	685.0332	отправлена	IRVTUS3NXXX
4350	RU1383803436537041354890218533954	643	2023-06-26	RU7783803436529059332090835348557	внутренняя	5747295.0532	780.8049	отправлена	\N
4351	RU9183803436523189940915642395180	978	2023-02-02	RU7183803436578006903833632767386	внутренняя	7020648.9212	678.3847	отправлена	\N
4352	RU9683803436559214297350823715344	978	2023-11-10	RU8583803436593152008036708778596	внутренняя	5234997.3371	889.9724	отменена	\N
4353	RU1283803436521770311179326367954	398	2023-10-10	BY9875356338187141130219299	международная	6790864.8788	608.9268	доставлена	CASPKZKAXXX
4354	RU5883803436544935035293164341064	356	2023-07-22	ES7692856009024182182013502	международная	105839.0347	315.1482	отправлена	SBININBBXXX
4355	RU9283803436564588409350021574669	356	2023-09-11	RU1628042307075400889110539	внутренняя	5403959.8727	239.9680	отменена	\N
4356	RU2883803436564862346362051659673	156	2023-12-20	RU7483803436560908970835757520521	внутренняя	5313055.3766	110.1079	отправлена	\N
4357	RU9383803436563463129216774786629	978	2023-12-03	IN2650995151608664812288952	международная	1391574.3328	179.4298	доставлена	RZBAATWW
4358	RU4383803436535637847836978327691	643	2023-04-07	VN9038098991780645350827457	внутренняя	5921345.7413	579.0789	отправлена	\N
4359	RU2883803436581906276084692901201	156	2023-09-17	RU6983803436582618731634671628237	внутренняя	4672253.1223	985.7787	отменена	\N
4360	RU6483803436575827628326698282321	398	2023-10-12	ES4344590058191853361730484	международная	3919749.4752	562.4786	доставлена	CASPKZKAXXX
4361	RU5583803436544105301147510534206	356	2023-07-30	VN8911308032566393424897198	международная	3517356.6719	222.6689	доставлена	SBININBBXXX
4362	RU6283803436561107985248905256058	156	2023-07-16	RU1883803436562141776165180370424	внутренняя	4732391.9588	796.0030	отменена	\N
4363	RU2983803436572636545308279163382	840	2023-05-20	RU1683803436536773128968824249362	внутренняя	5873175.9822	923.0421	доставлена	\N
4364	RU3183803436583121152517184662518	978	2023-03-15	RU9783803436586848496167067081204	внутренняя	2050480.6120	166.6799	доставлена	\N
4365	RU1983803436549890414007715363567	978	2023-12-20	RU9683803436520170153501466272589	внутренняя	2062206.1457	685.2348	отправлена	\N
4366	RU8383803436583878629872361871714	356	2022-12-28	RU6083803436582119843499506879640	внутренняя	676171.9200	820.4007	отправлена	\N
4367	RU3683803436583826961336736431806	840	2023-12-27	AD2212548986921213940201887	международная	4459135.0326	617.6680	отправлена	IRVTUS3NXXX
4368	RU9283803436529032721317031749293	156	2023-03-25	RU8183803436576334203563049364101	внутренняя	4258955.0940	399.6218	отправлена	\N
4369	RU6683803436563942598707878107815	643	2023-04-27	ES9263636576935919483119654	внутренняя	6722906.9411	851.8880	доставлена	\N
4370	RU2483803436537933507280624045523	398	2023-05-01	DE7766640808228763196939582	международная	1991655.5382	283.4939	доставлена	CASPKZKAXXX
4371	RU4583803436546993711061481413708	156	2023-07-04	KZ8391571969314514058213743	международная	3739667.0340	117.6876	отправлена	BKCHCNBJ
4372	RU8483803436576032684947735830335	398	2023-06-28	RU3983803436583094600516227232333	внутренняя	3359239.1688	878.8860	отправлена	\N
4373	RU2083803436593214630941740939011	356	2023-07-26	RU4183803436544525596730636267692	внутренняя	7269836.2255	794.0694	доставлена	\N
4374	RU1383803436565139777755041333233	398	2023-08-11	RU3883803436559428008275215914286	внутренняя	9652038.0256	433.5567	отменена	\N
4375	RU5683803436539120556194350818141	398	2023-05-03	DE7448232711669782817097873	международная	192951.3344	338.9833	отправлена	CASPKZKAXXX
4376	RU4583803436544769415444430855700	398	2022-12-27	DE5717372464130201786876325	международная	610628.0547	446.8405	доставлена	CASPKZKAXXX
4377	RU9383803436546841675173507423577	356	2023-05-01	RU7183803436596080848426828093950	внутренняя	715934.2624	580.5442	отправлена	\N
4378	RU6583803436556215016292535847892	398	2023-10-15	PT5773871727850241027771040	международная	5402753.2058	630.1814	отменена	CASPKZKAXXX
4379	RU4183803436544525596730636267692	840	2023-06-22	RU9483803436570307762028951954874	внутренняя	2834166.8568	894.8137	отменена	\N
4380	RU7583803436593274051968042799324	978	2023-12-10	RU6983803436550083462130199504453	внутренняя	560941.7212	696.4335	отправлена	\N
4381	RU1583803436533479152204865778047	398	2023-11-20	IN9931107439461945675976239	международная	2647770.8340	254.4630	отправлена	CASPKZKAXXX
4382	RU7383803436546512723534280739575	398	2023-04-20	RU6483803436513432249664452306210	внутренняя	5868641.5136	96.3669	отправлена	\N
4383	RU6983803436521001508692071958064	156	2023-01-24	AD3266588874411602830315312	международная	3464266.0597	153.8437	отправлена	BKCHCNBJ
4384	RU6783803436582018660242960957244	356	2023-10-11	RU7483803436581386287039618321410	внутренняя	9300648.6181	930.5706	доставлена	\N
4385	RU2883803436564862346362051659673	643	2023-01-16	RU6983803436580831999013679742086	внутренняя	3218013.9318	528.6205	отправлена	\N
4386	RU6983803436548066705729944547736	978	2023-06-01	RU8392656781012912225337604	внутренняя	2782259.9877	129.7420	отправлена	\N
4387	RU7583803436593621382878998665048	356	2023-07-10	DE9983544444024502044189370	международная	9102447.5637	684.2182	отменена	SBININBBXXX
4388	RU4283803436583191860084907222827	643	2023-05-19	VN3585964375090475654467608	внутренняя	2285618.0985	743.3718	доставлена	\N
4389	RU7283803436583841985241060182740	156	2023-11-09	PT8598368949529578843310885	международная	2494323.6083	93.0159	отменена	BKCHCNBJ
4390	RU3383803436533625475503259998648	840	2023-06-11	RU1283803436545193525808988988532	внутренняя	9718483.4137	871.9087	отменена	\N
4391	RU1983803436558651220197686454204	840	2023-02-16	RU4383803436586323329892508459044	внутренняя	2296071.7098	435.7776	отменена	\N
4392	RU8983803436513229118545499417330	356	2023-06-08	RU8183803436532187852215520403243	внутренняя	4187291.0160	373.5794	отменена	\N
4393	RU9483803436588743613330942629999	398	2023-10-11	RU6914623614855455418063050	внутренняя	4479385.1836	242.8920	отправлена	\N
4394	RU1683803436510344781123537250392	840	2022-12-28	RU4283803436571605132393354830061	внутренняя	7633426.3643	437.2708	отправлена	\N
4395	RU3383803436548623436381587682007	840	2023-04-10	RU3683803436526413764026311806751	внутренняя	1056042.4315	332.0066	отправлена	\N
4396	RU5883803436544935035293164341064	356	2023-08-07	VN8135740775457831233657089	международная	6697321.3679	883.3486	отправлена	SBININBBXXX
4397	RU2083803436593214630941740939011	643	2023-02-22	RU6583803436565551879254347008316	внутренняя	7033655.1680	341.1480	отправлена	\N
4398	RU5483803436551418630110242560620	978	2023-10-16	PT1228250157921521174127769	международная	117789.4450	154.8729	отменена	SOGEFRPP
4399	RU3183803436538368625987340316428	356	2023-12-16	RU6983803436542868245387240901621	внутренняя	8613238.0946	225.7184	доставлена	\N
4400	RU2283803436521727957364583057084	398	2023-08-04	RU9483803436570307762028951954874	внутренняя	2333149.1521	802.8748	отправлена	\N
4401	RU3983803436562540544761068231244	156	2023-03-02	DE8235689468975037876436042	международная	655897.9442	11.1021	отменена	BKCHCNBJ
4402	RU6483803436557881046066137062384	978	2023-09-14	AD6323045041110522518965151	международная	5493733.0174	502.7020	отправлена	DEUTDEFFXXX
4403	RU8483803436562780872181379760829	978	2023-11-27	RU8183803436513368239655842198331	внутренняя	5523598.0673	249.7790	доставлена	\N
4404	RU8483803436562780872181379760829	643	2023-06-21	DE4335729131222763246720989	внутренняя	3268573.1963	414.7802	отправлена	\N
4405	RU8283803436558421168306139201398	643	2023-12-18	AD5548047949271449043057183	внутренняя	1384969.4634	54.5577	отправлена	\N
4406	RU3383803436540416635821116917223	978	2023-04-19	IN9527660324776709625258728	международная	1361888.1421	817.7205	отменена	RZBAATWW
4407	RU2083803436571871160330810400191	840	2023-08-22	RU6483803436599929208547720213297	внутренняя	4683664.2494	494.5039	отменена	\N
4408	RU9483803436588743613330942629999	643	2023-01-19	VN8260281424130091808407502	внутренняя	2378309.7767	213.2729	отправлена	\N
4409	RU3783803436585191546282680625888	398	2023-07-31	KZ8382106802228809047870274	международная	3649637.5234	10.5660	отменена	CASPKZKAXXX
4410	RU8483803436597380246113206833117	356	2023-02-16	DE6932389822819391401053770	международная	4776973.2342	977.3956	отправлена	SBININBBXXX
4411	RU2183803436538160023828199079683	398	2023-01-24	RU3683803436589669964829443545971	внутренняя	21942.3850	386.8484	отправлена	\N
4412	RU5983803436533405804846460378377	643	2023-09-09	RU1583803436597114679330016317094	внутренняя	8765147.7086	862.0408	отправлена	\N
4413	RU6583803436588261503476787515721	398	2023-05-14	RU5248247135670834726416914	внутренняя	1396594.5607	90.0362	доставлена	\N
4414	RU9483803436516702191580023603147	356	2023-03-10	RU8183803436555934243334630961587	внутренняя	9701612.8748	838.2547	отменена	\N
4415	RU2083803436517185898516741185299	978	2023-10-06	RU4183803436544525596730636267692	внутренняя	3406678.8545	345.9511	отменена	\N
4416	RU9183803436594783043422280553530	978	2023-10-04	RU9083803436548965374028188380728	внутренняя	3810239.1580	315.2190	отменена	\N
4417	RU5983803436563752601230784661821	356	2023-03-19	RU6483803436595566817980742907742	внутренняя	1032915.5526	836.8206	доставлена	\N
4418	RU7483803436512314763652680872976	156	2023-12-08	RU6583803436552414284054924599360	внутренняя	8918627.7191	690.3625	отменена	\N
4419	RU1183803436541561390025398925839	156	2023-01-14	IN6596141939670620585283913	международная	962106.0120	697.2646	отправлена	BKCHCNBJ
4420	RU1983803436510686315036595318873	356	2023-12-20	RU2383803436518501918755699207235	внутренняя	3960599.5139	722.3490	отправлена	\N
4421	RU8183803436576334203563049364101	398	2023-09-16	RU4283803436515276086545867508581	внутренняя	1443161.7849	925.9425	доставлена	\N
4422	RU6583803436526807323529165700056	643	2023-04-24	RU6483803436513432249664452306210	внутренняя	6353902.1040	541.8613	доставлена	\N
4423	RU9983803436515137760640096699879	356	2023-07-30	PT9659750917430185190260450	международная	1095036.5083	75.4202	отменена	SBININBBXXX
4424	RU8983803436518961229187913059129	356	2023-11-03	RU4283803436583191860084907222827	внутренняя	2997483.3611	503.9455	доставлена	\N
4425	RU1983803436510712914540451632365	398	2023-11-02	RU2935251709342167084984301	внутренняя	8352623.1510	687.6693	доставлена	\N
4426	RU7383803436567535429961689788567	643	2023-05-31	RU2783803436515955219320238454317	внутренняя	6106302.9174	628.6605	доставлена	\N
4427	RU7683803436578953117174553181317	840	2023-07-08	AD6345485759504278569398693	международная	2128192.9029	325.7244	отменена	CHASUS33
4428	RU8183803436564595439284009293487	978	2023-01-22	RU6383803436599902939219818792376	внутренняя	3747568.4858	403.4432	отправлена	\N
4429	RU9283803436529032721317031749293	398	2023-09-29	RU5483803436547543071206231343471	внутренняя	5291389.2305	698.5191	доставлена	\N
4430	RU1983803436549890414007715363567	643	2023-05-03	RU6983803436582618731634671628237	внутренняя	9328713.3267	548.8262	отменена	\N
4431	RU6483803436599929208547720213297	398	2023-12-06	RU1583803436522600904788279282430	внутренняя	7834551.5301	336.8308	доставлена	\N
4432	RU9383803436587347167184231490115	156	2023-05-12	AL5516649253653189131888757	международная	3606391.0361	945.4304	доставлена	BKCHCNBJ
4433	RU9183803436594783043422280553530	356	2023-10-07	AL1377732636387793105251882	международная	2805421.7849	708.8417	отменена	SBININBBXXX
4434	RU8983803436518961229187913059129	398	2023-05-10	RU1083803436563162471160560931522	внутренняя	2389733.9651	178.4362	отменена	\N
4435	RU8183803436576908594301902139271	978	2023-10-02	RU5318289962021738852652160	внутренняя	7545782.7115	175.4258	отправлена	\N
4436	RU1683803436530784164352439032526	156	2023-06-18	BY1565949567884205067731949	международная	2727798.6772	49.3672	доставлена	BKCHCNBJ
4437	RU9183803436523189940915642395180	356	2023-05-20	KZ5662799572503315485230503	международная	2216810.5251	541.3007	отправлена	SBININBBXXX
4438	RU1283803436591782126481419856685	643	2023-01-10	RU8183803436576334203563049364101	внутренняя	169648.2330	331.0022	отправлена	\N
4439	RU3983803436583730529285495292571	398	2023-11-29	RU7283803436582085910615477000049	внутренняя	3461418.6969	958.4686	доставлена	\N
4440	RU8483803436576032684947735830335	356	2023-09-25	RU1883803436537462946976236392804	внутренняя	1527406.8946	343.6668	отменена	\N
4441	RU6583803436599318340096840026283	643	2023-04-09	RU7483803436595528340078834029783	внутренняя	7681777.6330	671.7381	доставлена	\N
4442	RU1183803436512373318427988836252	156	2023-02-21	RU5883803436549838724600410631189	внутренняя	4750683.5215	310.1528	отменена	\N
4443	RU2283803436521727957364583057084	978	2023-04-19	PT9550414687715950744048432	международная	9789958.5061	506.0598	отменена	DEUTDEFFXXX
4444	RU4583803436571583967013936520660	156	2023-10-21	DE1430288653797340045854209	международная	7373809.9341	13.3024	отменена	BKCHCNBJ
4445	RU5783803436553735504938098098542	643	2023-03-17	VN7063752676460250390114906	внутренняя	106423.2816	435.8501	отправлена	\N
4446	RU2583803436511360000518303822185	156	2023-04-16	RU1983803436558651220197686454204	внутренняя	7751353.7734	357.6508	отправлена	\N
4447	RU1583803436575905915250327615306	643	2023-10-21	VN4910026666770435675412714	внутренняя	9063849.2416	969.7080	отправлена	\N
4448	RU8483803436562780872181379760829	398	2023-04-03	RU8983803436519227550175732694863	внутренняя	7901342.7831	975.2848	отменена	\N
4449	RU2583803436511360000518303822185	978	2023-02-22	KZ9660235094948372614024027	международная	4573302.1226	729.7675	отменена	SOGEFRPP
4450	RU6583803436573484995572407857396	356	2023-04-14	RU6483803436599929208547720213297	внутренняя	8533434.5735	120.8700	отправлена	\N
4451	RU4183803436575456526806163894045	398	2023-12-27	RU5983803436565674700991182664479	внутренняя	5507386.5557	32.2993	отменена	\N
4452	RU2183803436586747579379810386651	156	2023-10-21	IN6068918197452045955173766	международная	9629398.7733	534.1818	отправлена	BKCHCNBJ
4453	RU2983803436572636545308279163382	978	2023-08-09	ES6842464728142405152062438	международная	1844869.9407	276.5196	доставлена	RZBAATWW
4454	RU3883803436554504516286459147223	398	2023-08-18	RU1183803436513944372774322746458	внутренняя	4160806.9328	774.2577	доставлена	\N
4455	RU3183803436538368625987340316428	398	2023-01-27	DE5180443088222140388587925	международная	6804559.1695	547.1632	отправлена	CASPKZKAXXX
4456	RU9683803436511276549947859990709	156	2023-02-27	AL3850646005187075029733164	международная	4725940.6728	29.6044	отменена	BKCHCNBJ
4457	RU5583803436525031727011657164177	643	2023-01-23	RU8783803436519169154241731281817	внутренняя	5089710.5898	865.0483	доставлена	\N
4458	RU9783803436531316283778462589484	643	2023-11-05	IN8117941333926886159309377	внутренняя	9767779.1872	412.1111	отправлена	\N
4459	RU9283803436529032721317031749293	978	2023-01-12	RU5053909812913889383588965	внутренняя	2699514.5580	363.3686	отправлена	\N
4460	RU6583803436552414284054924599360	356	2023-03-10	RU9283803436564588409350021574669	внутренняя	7965073.8759	476.3675	доставлена	\N
4461	RU5783803436573951128453151787227	643	2023-09-05	RU5083803436537344339331652897359	внутренняя	5827666.2892	869.6948	отправлена	\N
4462	RU3283803436579852018195047883736	156	2023-12-02	RU2083803436593214630941740939011	внутренняя	3909283.3274	531.4367	отправлена	\N
4463	RU5583803436525031727011657164177	840	2023-06-05	RU4283803436515276086545867508581	внутренняя	440749.9302	950.9030	отменена	\N
4464	RU4983803436522833268295991391237	398	2023-03-30	RU5583803436516539388298963058164	внутренняя	9308066.0477	891.3570	отправлена	\N
4465	RU5183803436523181844916432548416	398	2023-09-19	RU8183803436559528710172368223769	внутренняя	5668662.0839	230.6243	отправлена	\N
4466	RU3883803436559428008275215914286	978	2023-01-20	RU1083803436563162471160560931522	внутренняя	1907428.5730	100.6393	доставлена	\N
4467	RU7583803436593274051968042799324	840	2023-10-15	ES7915801572929426221929406	международная	4638769.8663	413.8826	отправлена	CHASUS33
4468	RU6683803436547011171926119923803	978	2023-03-20	RU7583803436593621382878998665048	внутренняя	4164365.8523	845.2094	отменена	\N
4469	RU6183803436536163842184020816729	643	2023-05-27	RU2483803436563361420871450061347	внутренняя	9914710.7697	46.6542	доставлена	\N
4470	RU8483803436552375991404578719285	643	2023-03-14	RU2283803436521727957364583057084	внутренняя	8502295.6251	361.2160	отменена	\N
4471	RU1383803436546084241558471107471	156	2023-02-14	RU8583803436598717986670697262250	внутренняя	3374505.1570	577.1932	отправлена	\N
4472	RU9683803436559214297350823715344	398	2023-08-01	RU7183803436584925378313266803439	внутренняя	4962986.7451	335.8763	отменена	\N
4473	RU4383803436557380827011382643653	978	2023-12-25	BY7333475135220655133978453	международная	5797029.1718	280.4534	отменена	SOGEFRPP
4474	RU2283803436527235231809863175226	156	2023-09-28	ES1088936969196368925505577	международная	9883815.7866	692.8536	отправлена	BKCHCNBJ
4475	RU3083803436518573891716312234719	643	2023-11-30	RU4183803436593654490331448399606	внутренняя	1255925.5897	977.1373	отменена	\N
4476	RU5683803436564237501745383797829	978	2023-05-16	RU1372597946833871759755486	внутренняя	5917146.7352	245.7882	отправлена	\N
4477	RU1183803436569972795023903837949	156	2023-08-15	RU7783803436520045957277741704368	внутренняя	418591.5650	313.4321	доставлена	\N
4478	RU8583803436586707949034749896750	840	2023-04-27	RU5183803436585063037953141711870	внутренняя	1628015.2246	598.1762	доставлена	\N
4479	RU9883803436510697875492928159959	840	2023-03-19	RU5783803436556321671762187197309	внутренняя	2383412.5275	584.1124	отменена	\N
4480	RU2983803436572678251629055132350	840	2023-11-03	RU7283803436528848493351990702937	внутренняя	8687845.0013	973.8088	отправлена	\N
4481	RU3983803436554516084539411139147	840	2023-05-30	VN8357954515221686078588545	международная	1917710.2943	314.7519	отправлена	CHASUS33
4482	RU5083803436563140090168469536649	356	2023-09-09	RU1183803436536239647096212180861	внутренняя	67084.4985	368.3542	отправлена	\N
4483	RU1283803436521770311179326367954	978	2023-02-06	AD6639516575738579729109500	международная	3040208.3915	464.7108	отменена	SOGEFRPP
4484	RU4283803436583191860084907222827	978	2023-08-01	RU3983803436562540544761068231244	внутренняя	9706117.4230	863.7511	отправлена	\N
4485	RU5283803436570838144716210841495	398	2023-08-18	BY8184415364714900164061499	международная	2753523.1444	133.4306	отправлена	CASPKZKAXXX
4486	RU9683803436559214297350823715344	840	2023-09-20	AL2915715086271701971597277	международная	8705548.8536	637.6121	отправлена	IRVTUS3NXXX
4487	RU9683803436571883645805733128714	156	2023-09-03	AL7073086264927143800490553	международная	336160.3559	644.6695	доставлена	BKCHCNBJ
4488	RU6983803436517488129268543865126	978	2023-05-18	KZ9152037668181099620551564	международная	4787752.6302	854.1855	доставлена	SOGEFRPP
4489	RU9383803436575688788160155647011	356	2023-03-11	RU9383803436563463129216774786629	внутренняя	221333.8992	498.7474	отменена	\N
4490	RU5883803436549838724600410631189	978	2023-10-17	RU9183803436523189940915642395180	внутренняя	7789154.4697	93.3620	отправлена	\N
4491	RU5983803436561671607015303339932	356	2023-08-17	RU5531454704469363539820033	внутренняя	870626.5845	712.1835	отправлена	\N
4492	RU6283803436577836700807681117407	978	2023-06-19	RU9583803436547610609904791788853	внутренняя	9568892.1083	899.5321	отменена	\N
4493	RU6583803436588261503476787515721	643	2023-01-29	RU4283803436515276086545867508581	внутренняя	7292838.6673	285.7346	отправлена	\N
4494	RU4183803436593654490331448399606	643	2023-10-07	RU5625160245393572824797039	внутренняя	3663888.9439	130.1549	отменена	\N
4495	RU6983803436582618731634671628237	356	2023-03-09	RU7483803436529598231033100377224	внутренняя	5030684.5296	167.3967	отправлена	\N
4496	RU7283803436528848493351990702937	643	2023-04-16	AL8519808141051131343035587	внутренняя	8338920.1806	870.7146	отменена	\N
4497	RU5383803436532276110708298062956	156	2023-05-26	RU2283803436527235231809863175226	внутренняя	6704076.4401	225.7247	отменена	\N
4498	RU9083803436548965374028188380728	356	2023-09-26	RU3535398719584513197007848	внутренняя	720567.0081	276.3057	отправлена	\N
4499	RU7083803436575256167282941443393	643	2023-12-04	RU9683803436541591047480784615833	внутренняя	3546364.8926	733.7429	доставлена	\N
4500	RU3283803436579852018195047883736	398	2023-06-25	RU1283803436513390712190126736747	внутренняя	4174060.6397	55.9336	отправлена	\N
4501	RU9283803436564588409350021574669	156	2023-04-12	RU3283803436586063041663029658571	внутренняя	3434274.5508	469.7700	отменена	\N
4502	RU5483803436538988818998904026382	156	2023-05-15	RU7683803436589524723383129532286	внутренняя	5430561.9966	648.6872	доставлена	\N
4503	RU8483803436546395435496825405512	840	2023-02-16	RU1583803436513968949783488654583	внутренняя	3019090.5631	245.5628	отменена	\N
4504	RU4783803436576956010684046744289	156	2023-01-09	VN4720053824138026152008675	международная	7689383.6444	60.4864	доставлена	BKCHCNBJ
4505	RU9183803436512467785925904841435	356	2023-12-15	AD1560120035496243104270735	международная	4779858.7354	684.7759	отменена	SBININBBXXX
4506	RU2283803436551819000625747494652	398	2023-01-13	RU3683803436533022850683714599602	внутренняя	8423389.2128	326.4879	отправлена	\N
4507	RU6483803436599929208547720213297	156	2023-12-17	AL3626834753457032070911799	международная	7515140.8823	386.7952	отменена	BKCHCNBJ
4508	RU8283803436517214496879594083501	398	2023-07-16	RU6183803436556503720110500069421	внутренняя	9504585.3943	14.2982	отправлена	\N
4509	RU9383803436563463129216774786629	840	2023-09-01	RU1210314927513450226653569	внутренняя	912057.5427	745.2291	доставлена	\N
4510	RU3083803436572725983728902081378	643	2023-11-02	IN2977428034693889971911283	внутренняя	2960548.7361	804.2052	доставлена	\N
4511	RU3683803436583826961336736431806	978	2023-12-16	VN8245788201784366351562009	международная	7192540.4775	103.4335	доставлена	SOGEFRPP
4512	RU3183803436538368625987340316428	356	2023-06-03	VN4711986635292083634873155	международная	3802469.3425	756.6188	доставлена	SBININBBXXX
4513	RU6383803436530975100435134167112	978	2023-03-20	VN3925725124078204849412558	международная	4612324.4395	291.8205	отправлена	SOGEFRPP
4514	RU4383803436557380827011382643653	398	2023-10-25	PT6415243676446590472898004	международная	1816083.8114	982.0566	доставлена	CASPKZKAXXX
4515	RU4883803436510661666911089208306	398	2023-09-08	KZ1522439114588393010742456	международная	3372257.5529	981.8742	отправлена	CASPKZKAXXX
4516	RU6783803436527708547728704282997	643	2023-07-12	RU4983803436522833268295991391237	внутренняя	417236.9081	752.5783	отменена	\N
4517	RU8783803436522200736153030297680	398	2023-06-05	IN7933790758963567294228841	международная	3848666.3354	74.9792	отправлена	CASPKZKAXXX
4518	RU1083803436588429797000364388942	978	2023-03-24	AD7173252569862945775203525	международная	760780.5590	244.7454	отменена	SOGEFRPP
4519	RU3283803436579852018195047883736	643	2023-06-17	RU8845308358397838006869075	внутренняя	5487063.4380	903.6696	отправлена	\N
4520	RU9683803436541591047480784615833	643	2023-08-04	RU4483803436534969190676238532628	внутренняя	3582495.1083	150.2802	отправлена	\N
4521	RU8583803436553386257766521949981	156	2023-02-21	ES6829080682409785590794269	международная	9425589.9814	920.8804	доставлена	BKCHCNBJ
4522	RU9183803436512467785925904841435	840	2023-11-09	RU8483803436576032684947735830335	внутренняя	6912720.8786	141.7726	отправлена	\N
4523	RU4583803436588661449801193641363	840	2023-11-08	AD7612406701008434389956725	международная	4130153.3543	901.6016	отправлена	CHASUS33
4524	RU8483803436517523304653033637180	398	2022-12-31	RU1082894093004958133165841	внутренняя	1741274.8550	724.5952	доставлена	\N
4525	RU5583803436533254773648721597711	978	2023-01-20	RU6183803436547326038705936576601	внутренняя	2787077.7293	783.6134	отправлена	\N
4526	RU8983803436519227550175732694863	398	2023-09-27	RU4083803436530357399673623809331	внутренняя	4814355.1686	722.3176	отправлена	\N
4527	RU9383803436515318038329930627155	978	2023-02-11	RU4583803436544769415444430855700	внутренняя	8411626.7974	297.1856	отправлена	\N
4528	RU6183803436555838927651384339574	156	2023-10-25	RU9783803436531316283778462589484	внутренняя	2153723.6524	749.3413	отменена	\N
4529	RU3983803436562540544761068231244	643	2023-08-13	VN2810090346957514939374926	внутренняя	7018872.9161	235.2178	отправлена	\N
4530	RU1983803436568263609873115174417	978	2023-09-14	ES2198685814016616026658845	международная	1378083.5866	766.4719	доставлена	RZBAATWW
4531	RU8183803436513368239655842198331	840	2023-02-04	RU9218382563776915468924723	внутренняя	7217028.2295	628.5936	отменена	\N
4532	RU7283803436565335970635584506660	156	2023-08-19	AD2520083523016320676536103	международная	8044707.6917	537.6092	отправлена	BKCHCNBJ
4533	RU2983803436545911307181108696312	356	2023-08-19	RU6783803436534011789886956964173	внутренняя	1065162.7845	119.0444	доставлена	\N
4534	RU8683803436557989786811096289958	840	2023-12-16	ES1176731992392732963162435	международная	1868927.0829	686.0204	отменена	IRVTUS3NXXX
4535	RU2983803436597155052344917689453	840	2022-12-28	AL5964602224869516257904925	международная	7451360.4927	117.2128	доставлена	CHASUS33
4536	RU7083803436569474567525801645267	398	2023-07-31	RU7886013249477490004580266	внутренняя	1158918.2795	418.2624	доставлена	\N
4537	RU8683803436511417676206561932357	840	2023-01-16	VN4621410768394989775039150	международная	8971590.4976	833.0835	отменена	IRVTUS3NXXX
4538	RU8183803436576334203563049364101	398	2023-10-16	RU5513553195795752754887483	внутренняя	5517529.3329	338.5971	доставлена	\N
4539	RU2183803436538160023828199079683	840	2023-11-10	KZ5461929452612048421289449	международная	8529322.1490	651.9774	отменена	CHASUS33
4540	RU7483803436529598231033100377224	643	2023-08-26	RU7483803436516612664745741202549	внутренняя	7677609.9179	324.4874	доставлена	\N
4541	RU5483803436549562102902686014927	156	2023-08-17	RU4983803436534576819154749347962	внутренняя	1906300.8902	464.4526	доставлена	\N
4542	RU3683803436526413764026311806751	643	2023-06-26	RU3699049951754960628843654	внутренняя	953441.2961	686.8495	доставлена	\N
4543	RU5083803436563140090168469536649	978	2023-06-09	RU8583803436598717986670697262250	внутренняя	2968900.3259	827.7677	отправлена	\N
4544	RU8683803436511417676206561932357	978	2023-12-21	KZ8284917617476076051002183	международная	5206066.6339	182.8376	отправлена	RZBAATWW
4545	RU3783803436562091905141244310726	356	2023-01-25	RU7583803436597888322431139189153	внутренняя	1251368.0996	74.3153	доставлена	\N
4546	RU8783803436544746989208687599320	398	2023-01-10	RU8983803436545494349013660032430	внутренняя	1179740.5312	514.6391	отправлена	\N
4547	RU8983803436588264357315670765686	398	2023-06-03	RU8883803436592173067148862634991	внутренняя	3910802.0344	246.0954	доставлена	\N
4548	RU9583803436562562119396535016715	356	2023-07-28	RU8134182786220661075777004	внутренняя	5293618.1713	879.4472	доставлена	\N
4549	RU3083803436556733352794187735054	356	2023-02-06	RU6783803436534011789886956964173	внутренняя	6244103.5404	742.4466	доставлена	\N
4550	RU9583803436574471411467135718624	356	2023-03-06	VN7273511557834009218692110	международная	1010194.1266	981.3738	доставлена	SBININBBXXX
4551	RU6983803436580831999013679742086	398	2023-06-21	DE7799232553452450483003999	международная	8057353.7102	533.8274	отправлена	CASPKZKAXXX
4552	RU2583803436573489146610412814439	978	2023-03-12	RU6583803436526807323529165700056	внутренняя	8671293.2113	673.1259	доставлена	\N
4553	RU1583803436575905915250327615306	643	2023-03-15	AL5736296439580144158172123	внутренняя	5015997.9284	944.8326	отменена	\N
4554	RU9583803436589245078784775619456	156	2023-08-04	RU5183803436550941857646482749776	внутренняя	3777461.8142	147.9683	доставлена	\N
4555	RU6183803436573612137819734816326	398	2023-06-14	AL7027346712017337518847532	международная	6050693.9956	0.0000	доставлена	CASPKZKAXXX
4556	RU1383803436537041354890218533954	840	2023-10-17	RU5783803436568341660520010753753	внутренняя	4708503.6637	184.5096	отправлена	\N
4557	RU2883803436510195395163379960366	978	2022-12-29	RU8983803436550652073660555482382	внутренняя	4928117.9009	365.2644	доставлена	\N
4558	RU7383803436546512723534280739575	978	2023-10-04	RU8483803436586135450040789229889	внутренняя	3280612.1684	861.0086	отправлена	\N
4559	RU2083803436518033160343253894367	398	2023-08-08	DE9870042456037549674047394	международная	5135587.9487	697.2232	отправлена	CASPKZKAXXX
4560	RU9883803436510697875492928159959	840	2023-04-05	RU3152562552971450179549479	внутренняя	1535363.3355	299.7579	отменена	\N
4561	RU6783803436527708547728704282997	356	2023-08-12	AD4735978326656927276789541	международная	893122.1425	76.7969	отменена	SBININBBXXX
4562	RU5883803436571013870275428717873	840	2023-11-26	RU4183803436512683300418013703414	внутренняя	6165803.5604	862.3412	отправлена	\N
4563	RU4583803436588661449801193641363	356	2023-05-30	RU3220474449893841092628460	внутренняя	640896.3400	87.1451	доставлена	\N
4564	RU4283803436530972916151822377436	156	2023-05-14	IN8756001981146011286444941	международная	7681710.8807	717.0624	доставлена	BKCHCNBJ
4565	RU9983803436515137760640096699879	978	2023-07-23	RU6983803436548066705729944547736	внутренняя	3888977.9885	518.8285	отменена	\N
4566	RU8183803436576908594301902139271	643	2023-05-21	RU8283803436558421168306139201398	внутренняя	7164391.5229	599.5320	отменена	\N
4567	RU7583803436593621382878998665048	356	2023-12-21	PT7421704292083642928557195	международная	1684129.9814	60.9406	доставлена	SBININBBXXX
4568	RU1183803436536239647096212180861	356	2023-04-03	RU7483803436516612664745741202549	внутренняя	8160720.4432	785.1273	доставлена	\N
4569	RU5983803436565674700991182664479	643	2023-05-25	AL6589015115817048188571902	внутренняя	9610761.8801	409.6275	отменена	\N
4570	RU6283803436561107985248905256058	398	2023-03-21	RU9583803436515959194321808018014	внутренняя	1143728.0625	737.2034	отменена	\N
4571	RU6483803436513432249664452306210	398	2023-01-19	RU2079207268158653354138598	внутренняя	3422435.8380	436.8313	доставлена	\N
4572	RU2083803436571871160330810400191	398	2023-08-30	PT2211487866568335479023703	международная	3281605.7966	291.2657	отменена	CASPKZKAXXX
4573	RU5683803436581377733469772235779	156	2023-08-19	IN2120947549902409722654755	международная	8055533.6858	496.1835	отправлена	BKCHCNBJ
4574	RU6683803436534213789698830771682	156	2023-12-19	KZ4298332705522077809790170	международная	5045758.7681	231.5082	отменена	BKCHCNBJ
4575	RU6283803436577836700807681117407	156	2023-05-10	RU3483803436534657689181631833463	внутренняя	4083068.0195	243.3117	доставлена	\N
4576	RU8583803436586707949034749896750	156	2023-05-01	IN6486624723073655332232742	международная	9870317.8956	907.0225	отменена	BKCHCNBJ
4577	RU6983803436557684576294868357987	643	2023-10-11	AD7199136364551024386648699	внутренняя	5542530.9494	314.0018	отменена	\N
4578	RU3083803436572725983728902081378	156	2023-05-19	RU3683803436533022850683714599602	внутренняя	5198495.8139	897.0774	отменена	\N
4579	RU1183803436547102061688733775669	156	2023-09-16	RU8483803436583598027317615125571	внутренняя	229116.3278	447.1918	доставлена	\N
4580	RU1983803436518034161993382946183	643	2023-10-20	KZ4426114202498252754727762	внутренняя	9419893.1195	907.2613	доставлена	\N
4581	RU4883803436510661666911089208306	840	2023-11-23	RU3683803436521305656177527242839	внутренняя	6578993.7934	177.2923	доставлена	\N
4582	RU7683803436565241249132549566386	643	2023-03-22	RU5183803436588801456118987264753	внутренняя	7524126.8394	43.8533	отменена	\N
4583	RU2483803436563361420871450061347	643	2023-01-17	RU6383803436599902939219818792376	внутренняя	5206549.2486	863.9768	отправлена	\N
4584	RU6683803436563942598707878107815	156	2023-12-13	AL4585764673817334399198635	международная	2304772.1807	562.0057	отправлена	BKCHCNBJ
4585	RU3083803436548755847047281062638	398	2023-05-16	RU6983803436551969328605594993446	внутренняя	1799221.3485	706.4798	отправлена	\N
4586	RU6683803436546559918630563560759	398	2023-08-25	RU4483803436593534887929979895004	внутренняя	5638880.4188	879.1477	отменена	\N
4587	RU5483803436559214869633349674125	398	2023-02-26	IN4780431665530757693453364	международная	2486932.9542	657.2794	доставлена	CASPKZKAXXX
4588	RU9583803436515959194321808018014	156	2023-09-24	AL5340382443888901688105200	международная	1135219.5097	901.6111	отменена	BKCHCNBJ
4589	RU8683803436571821829992754282142	398	2023-04-15	RU9283803436564588409350021574669	внутренняя	4374023.4188	251.7670	доставлена	\N
4590	RU6483803436513432249664452306210	356	2023-11-27	RU8183803436576908594301902139271	внутренняя	4778009.2992	776.9358	отменена	\N
4591	RU1183803436536239647096212180861	978	2023-07-31	ES6171572124424392830190428	международная	4673049.9784	250.8101	доставлена	DEUTDEFFXXX
4592	RU3283803436586063041663029658571	356	2023-01-08	ES8462388688824511450599431	международная	5897389.2828	554.3420	доставлена	SBININBBXXX
4593	RU6583803436552414284054924599360	398	2023-04-13	VN6854597747062869678428128	международная	1653720.1585	841.8230	доставлена	CASPKZKAXXX
4594	RU5683803436522754650880470438385	643	2023-09-13	RU4283803436532641085536208083176	внутренняя	5287314.9169	587.3023	отправлена	\N
4595	RU2183803436551906716086082339754	356	2023-04-29	RU6983803436580831999013679742086	внутренняя	1774184.8568	623.8134	доставлена	\N
4596	RU1183803436569972795023903837949	398	2023-07-02	VN9328156564637210378890863	международная	7650951.2986	690.0415	отменена	CASPKZKAXXX
4597	RU4383803436583134155448910498762	398	2023-04-01	RU5583803436555177704368963744222	внутренняя	3526619.1255	569.1096	доставлена	\N
4598	RU2883803436581906276084692901201	840	2023-02-15	RU9560474402132115347787648	внутренняя	8419665.3038	547.0761	доставлена	\N
4599	RU1683803436510344781123537250392	840	2023-11-10	VN9964216796066615622806107	международная	3527628.8696	577.4965	отправлена	CHASUS33
4600	RU7883803436577262824038798840088	356	2023-07-18	IN7578864045815969216012222	международная	6328619.2015	138.2097	доставлена	SBININBBXXX
4601	RU7383803436567535429961689788567	398	2023-09-26	VN7774557991652823330951057	международная	8413998.0877	912.1192	доставлена	CASPKZKAXXX
4602	RU4583803436544769415444430855700	978	2023-09-16	PT1575954238995385976606082	международная	7299851.6968	526.5116	доставлена	DEUTDEFFXXX
4603	RU6783803436583735354795738130605	840	2023-01-12	RU9383803436575688788160155647011	внутренняя	1013464.3390	261.4615	отправлена	\N
4604	RU1683803436596193217028081534610	643	2023-12-26	RU8383803436557193853878723819444	внутренняя	4443774.4096	914.2870	доставлена	\N
4605	RU5883803436544935035293164341064	840	2023-05-28	RU5083803436556786327042016836549	внутренняя	9259140.3916	297.0894	доставлена	\N
4606	RU2083803436571871160330810400191	840	2023-12-18	RU3183803436538368625987340316428	внутренняя	9508471.7973	226.6531	отправлена	\N
4607	RU3583803436556382446278007957702	978	2023-03-24	RU3683803436583826961336736431806	внутренняя	9536618.8833	560.4241	отменена	\N
4608	RU2583803436511360000518303822185	356	2023-04-28	RU6983803436596433824452063468541	внутренняя	1604078.4312	45.5066	доставлена	\N
4609	RU9283803436564588409350021574669	978	2023-05-07	BY6535378476546537023670421	международная	1364655.2511	332.1769	отправлена	SOGEFRPP
4610	RU8583803436580493050529274956761	398	2023-04-18	PT9396872422820966440035242	международная	5519139.4390	902.7248	отменена	CASPKZKAXXX
4611	RU7383803436515152831562897371432	398	2023-06-07	RU6283803436577836700807681117407	внутренняя	9830257.7125	79.0324	доставлена	\N
4612	RU7783803436536804517087406327796	356	2023-12-12	RU1683803436510344781123537250392	внутренняя	4511082.9439	505.5708	отменена	\N
4613	RU9883803436580908913943520973504	840	2023-06-16	RU7183803436578006903833632767386	внутренняя	7291388.9641	308.5200	отправлена	\N
4614	RU6683803436534213789698830771682	356	2023-01-21	RU6983803436596433824452063468541	внутренняя	9075306.1028	191.7929	отменена	\N
4615	RU8783803436519169154241731281817	840	2023-03-29	BY6512445869453147024922374	международная	9908822.6380	343.1539	отправлена	CHASUS33
4616	RU6083803436582119843499506879640	643	2023-09-18	ES7965174165995608977514210	внутренняя	4396139.2448	814.1341	отправлена	\N
4617	RU4583803436567844239839748091371	840	2023-06-16	ES5322035015431016781325813	международная	7974757.8523	926.8393	отменена	IRVTUS3NXXX
4618	RU9583803436547610609904791788853	840	2023-12-21	AD6315312966359753849832939	международная	6293279.9647	48.0597	доставлена	CHASUS33
4619	RU4183803436575456526806163894045	978	2023-11-28	VN4992425278193388104164860	международная	3312626.5880	493.0649	отменена	SOGEFRPP
4620	RU5883803436549838724600410631189	156	2023-12-14	RU4483803436534969190676238532628	внутренняя	2034076.4058	577.7770	доставлена	\N
4621	RU8283803436593409912626065485368	156	2023-03-12	IN3815945374591663796778766	международная	3638576.0524	16.0382	отправлена	BKCHCNBJ
4622	RU9483803436516702191580023603147	840	2023-01-26	RU5683803436581377733469772235779	внутренняя	2103315.6502	406.9870	отменена	\N
4623	RU9183803436594783043422280553530	840	2023-07-23	VN4047342689849836817103360	международная	5711918.8276	820.3465	отправлена	IRVTUS3NXXX
4624	RU3383803436540416635821116917223	840	2023-12-04	RU3683803436529963181547651499120	внутренняя	8559599.5873	66.6396	отменена	\N
4625	RU3983803436580604058878329162478	643	2023-08-07	RU9683803436571883645805733128714	внутренняя	8453885.0096	881.5460	отменена	\N
4626	RU4583803436546993711061481413708	398	2023-10-20	PT2056171761384313449683729	международная	6392767.8576	539.9010	отправлена	CASPKZKAXXX
4627	RU3983803436554516084539411139147	643	2023-03-24	AD7655972606415101614770847	внутренняя	7542408.5275	156.5134	отменена	\N
4628	RU6183803436556503720110500069421	156	2023-01-30	ES3981508183241354093818853	международная	6507072.0643	619.5484	отменена	BKCHCNBJ
4629	RU8983803436513229118545499417330	643	2023-09-03	RU5220529581536752876817102	внутренняя	6132964.6802	742.5667	отменена	\N
4630	RU5183803436596697120047636808100	156	2023-01-14	KZ1320346977273139873256256	международная	3075732.6464	671.7040	отправлена	BKCHCNBJ
4631	RU4583803436567844239839748091371	978	2023-02-11	PT2695514138324034352952637	международная	1930458.6374	563.1582	отменена	SOGEFRPP
4632	RU2183803436555308456329784386702	840	2023-12-26	RU7383803436569356631218275502161	внутренняя	9621250.8965	466.2235	отправлена	\N
4633	RU9483803436522220035875117822565	643	2023-08-28	RU6583803436556215016292535847892	внутренняя	123707.9834	763.1417	отменена	\N
4634	RU6383803436599902939219818792376	356	2023-04-18	PT7252196505526930276152914	международная	1644921.4469	457.0409	доставлена	SBININBBXXX
4635	RU1083803436563162471160560931522	356	2023-04-07	RU7583803436593274051968042799324	внутренняя	9356395.3251	758.9345	отменена	\N
4636	RU3883803436571430516571621799878	156	2023-04-01	RU5483803436551418630110242560620	внутренняя	4632810.4527	85.5777	отменена	\N
4637	RU3683803436589669964829443545971	840	2023-10-11	RU3783803436562139250445157080524	внутренняя	8153533.1684	385.5802	отправлена	\N
4638	RU8283803436517214496879594083501	840	2023-12-18	RU9883803436597607312145326011401	внутренняя	4735989.5197	607.2398	доставлена	\N
4639	RU1383803436523658112524214881297	978	2022-12-27	KZ3043845243194900239973526	международная	9540254.7387	786.2601	доставлена	DEUTDEFFXXX
4640	RU7183803436551143317683635788042	356	2023-06-21	RU2583803436573489146610412814439	внутренняя	3046166.5173	611.8354	доставлена	\N
4641	RU7283803436582085910615477000049	840	2023-09-10	RU6983803436557684576294868357987	внутренняя	8844477.8263	587.7830	отменена	\N
4642	RU4683803436584135461455281070651	643	2023-03-25	DE1419864598820897868957725	внутренняя	915314.0402	276.7554	отправлена	\N
4643	RU5683803436522754650880470438385	840	2023-03-29	BY8537170617872983805035637	международная	416024.6490	669.5664	отправлена	IRVTUS3NXXX
4644	RU6183803436547326038705936576601	840	2023-08-30	BY7498829117804756625805866	международная	5123906.8518	378.9072	доставлена	IRVTUS3NXXX
4645	RU7583803436593274051968042799324	356	2023-10-04	DE3286405128022465828809868	международная	6488448.6835	845.1796	доставлена	SBININBBXXX
4646	RU8783803436522200736153030297680	643	2023-02-18	AL2698338637496933422469550	внутренняя	4295864.6373	737.1585	отменена	\N
4647	RU8483803436597380246113206833117	156	2022-12-27	RU8083803436548053884024737088236	внутренняя	2463839.3608	726.1752	отменена	\N
4648	RU1383803436537041354890218533954	398	2023-05-30	RU2883803436512412400998624231254	внутренняя	2077736.7037	508.9256	отменена	\N
4649	RU9783803436531316283778462589484	356	2023-01-22	ES7070911658012947794203169	международная	7233089.4849	405.8754	доставлена	SBININBBXXX
4650	RU5083803436521160540176223483455	643	2023-10-17	RU9383803436563463129216774786629	внутренняя	1474703.7412	435.7359	отправлена	\N
4651	RU2283803436577856579987093576845	356	2023-08-15	IN1628283764955222703519593	международная	1597153.4217	816.9968	отменена	SBININBBXXX
4652	RU6583803436546434088553514688778	978	2023-03-16	PT1667763525539238782175139	международная	6269105.6840	413.6970	отменена	SOGEFRPP
4653	RU6983803436596433824452063468541	840	2023-10-31	ES8599820246068461514532537	международная	7730900.0430	434.4151	отправлена	CHASUS33
4654	RU5983803436565674700991182664479	156	2023-07-24	RU9383803436546841675173507423577	внутренняя	6562947.3977	997.6340	доставлена	\N
4655	RU4583803436576777630615652907536	156	2023-11-09	BY2956653839308218806156463	международная	7537079.1589	448.4217	доставлена	BKCHCNBJ
4656	RU8383803436557193853878723819444	398	2023-01-19	ES7617646798184659485378617	международная	4381505.1209	90.0563	доставлена	CASPKZKAXXX
4657	RU2783803436515955219320238454317	840	2023-07-04	RU5083803436556786327042016836549	внутренняя	8267652.0107	621.7648	отменена	\N
4658	RU1283803436545193525808988988532	356	2023-03-23	RU5330569847169874502583177	внутренняя	280397.7969	838.0038	доставлена	\N
4659	RU1683803436510344781123537250392	356	2023-02-12	BY2020989761794028314199639	международная	5876459.4802	599.6319	доставлена	SBININBBXXX
4660	RU4683803436584135461455281070651	978	2023-01-24	RU4283803436512174946847064448344	внутренняя	3795660.6123	927.1727	отправлена	\N
4661	RU1083803436563162471160560931522	356	2023-08-06	ES1825847694303706054343408	международная	2329761.3168	733.9591	доставлена	SBININBBXXX
4662	RU1583803436522600904788279282430	840	2023-04-06	KZ3250360308022459253612435	международная	2755717.8441	474.6491	отправлена	CHASUS33
4663	RU2883803436538134433783624054557	156	2023-08-10	ES1862915848742327911232117	международная	5772783.7427	919.4033	отменена	BKCHCNBJ
4664	RU7783803436556242953974983768067	398	2023-01-05	RU5583803436581992686445972740236	внутренняя	7550971.3899	992.9026	отправлена	\N
4665	RU2083803436593214630941740939011	156	2023-12-09	RU2483803436537933507280624045523	внутренняя	9034561.0158	663.1727	отменена	\N
4666	RU8183803436513368239655842198331	356	2023-08-22	AD7228903399040582966743224	международная	6402965.3213	660.8175	доставлена	SBININBBXXX
4667	RU8583803436590890149305918634043	840	2023-10-24	RU6583803436588261503476787515721	внутренняя	5177486.6065	914.0257	отправлена	\N
4668	RU7783803436557425582753958788900	356	2023-09-12	IN2816947483584913369661487	международная	7709932.3175	924.0314	отправлена	SBININBBXXX
4669	RU4183803436512683300418013703414	978	2023-01-21	RU3783803436562091905141244310726	внутренняя	2774446.4249	514.4846	доставлена	\N
4670	RU3283803436579852018195047883736	398	2023-02-16	DE8275703281363661096471504	международная	2248753.4997	134.7124	доставлена	CASPKZKAXXX
4671	RU5483803436547543071206231343471	398	2023-05-01	RU2883803436512412400998624231254	внутренняя	8519497.6999	319.1267	отправлена	\N
4672	RU4583803436535138140020222748384	356	2023-11-11	RU5983803436513359014201161572816	внутренняя	9582598.3489	956.4363	отменена	\N
4673	RU5483803436551418630110242560620	156	2023-01-07	ES4127284774483359593920311	международная	5065987.1274	631.1933	доставлена	BKCHCNBJ
4674	RU9083803436548965374028188380728	398	2022-12-30	RU1183803436513944372774322746458	внутренняя	2691393.7802	788.4306	отправлена	\N
4675	RU7783803436557425582753958788900	398	2022-12-31	RU1983803436510712914540451632365	внутренняя	9284792.3791	571.5985	отправлена	\N
4676	RU4283803436544879224116585983050	356	2023-04-21	RU6583803436556215016292535847892	внутренняя	4408040.7063	926.6339	отменена	\N
4677	RU2683803436556115738690945420927	356	2023-02-26	ES1566444767686572085855725	международная	7161477.6413	573.5674	отменена	SBININBBXXX
4678	RU6783803436534011789886956964173	156	2023-03-15	RU1283803436545193525808988988532	внутренняя	6106734.1177	809.8101	отправлена	\N
4679	RU9083803436548965374028188380728	840	2023-10-11	VN6078147259172697825620608	международная	9660044.5030	930.9171	отправлена	IRVTUS3NXXX
4680	RU4283803436571605132393354830061	840	2023-10-25	RU8483803436562780872181379760829	внутренняя	8975818.5828	73.5052	отправлена	\N
4681	RU5283803436570838144716210841495	643	2023-12-12	VN1595459728725483425746572	внутренняя	2336457.5543	387.0720	отправлена	\N
4682	RU7483803436581386287039618321410	978	2023-12-24	RU7483803436581386287039618321410	внутренняя	6865898.9648	463.8739	отправлена	\N
4683	RU8583803436593152008036708778596	643	2023-02-20	AD6766204591816771962357225	внутренняя	2990471.0031	954.4771	доставлена	\N
4684	RU9683803436531094862059243712475	840	2023-06-02	RU2483803436563361420871450061347	внутренняя	7862462.2456	516.6672	отправлена	\N
4685	RU7483803436560908970835757520521	978	2023-10-01	DE7135667414095368468112918	международная	4431301.4234	453.8754	отменена	RZBAATWW
4686	RU4283803436538514172142523078432	398	2023-05-04	RU8583803436590890149305918634043	внутренняя	876461.6983	727.2863	отправлена	\N
4687	RU1583803436533479152204865778047	978	2023-07-10	AL8371128725799351842261392	международная	8488366.2165	50.4427	отменена	RZBAATWW
4688	RU1283803436597755454846611928328	156	2023-02-15	RU7783803436578403910419087666263	внутренняя	8651273.0128	121.0886	отменена	\N
4689	RU5983803436558435772787343054218	978	2023-09-16	RU9975147223856501774684121	внутренняя	7632037.8353	568.1150	доставлена	\N
4690	RU4083803436523112590591409946049	643	2023-08-02	RU1483803436555535016685486735994	внутренняя	3746123.9471	867.6456	отменена	\N
4691	RU2183803436586747579379810386651	156	2023-03-25	AL9532528412712727442847755	международная	2224947.5771	326.3218	отменена	BKCHCNBJ
4692	RU6383803436530975100435134167112	398	2023-08-23	ES6413191137539909832795780	международная	5041920.5263	543.9045	отменена	CASPKZKAXXX
4693	RU4183803436544525596730636267692	643	2023-01-08	RU1583803436513968949783488654583	внутренняя	8617981.7399	846.9128	отправлена	\N
4694	RU2183803436586747579379810386651	398	2023-02-08	RU4383803436535637847836978327691	внутренняя	430518.6460	754.1673	отменена	\N
4695	RU2983803436545911307181108696312	398	2023-04-06	BY2775920668676635710029318	международная	7617520.7693	642.8262	отменена	CASPKZKAXXX
4696	RU2883803436538134433783624054557	840	2023-10-29	RU9283803436560888794155508079505	внутренняя	5752422.7695	565.5963	отменена	\N
4697	RU1183803436513944372774322746458	643	2023-11-17	RU5483803436538988818998904026382	внутренняя	3168521.2227	113.9714	доставлена	\N
4698	RU1283803436545193525808988988532	156	2023-04-24	RU4183803436593654490331448399606	внутренняя	1587484.9911	549.4626	отменена	\N
4699	RU8983803436551003507571679577910	643	2023-11-09	RU9183803436594783043422280553530	внутренняя	9397381.8799	472.6919	доставлена	\N
4700	RU1583803436597114679330016317094	978	2023-05-25	RU7183803436596080848426828093950	внутренняя	8552662.9342	943.5366	доставлена	\N
4701	RU2983803436585384738431881857607	840	2023-06-28	PT3052554403288028732225990	международная	1888466.9936	904.0345	отправлена	IRVTUS3NXXX
4702	RU5183803436585063037953141711870	840	2023-06-08	RU8583803436529401978461350257287	внутренняя	6609433.2330	915.0503	доставлена	\N
4703	RU5683803436539120556194350818141	156	2023-05-04	PT6820823611104626108423885	международная	8355233.4013	111.1506	отменена	BKCHCNBJ
4704	RU4083803436519648806531502670697	840	2023-10-18	DE1637241934007066363873515	международная	3141889.9984	466.5044	отправлена	IRVTUS3NXXX
4705	RU7783803436557425582753958788900	156	2023-08-12	RU8683803436520349379894661014091	внутренняя	8141946.2306	604.9524	отменена	\N
4706	RU8683803436511417676206561932357	978	2023-01-13	ES2393615236699061884911490	международная	5311488.3818	829.5876	отправлена	RZBAATWW
4707	RU8183803436559528710172368223769	978	2023-03-31	RU2083803436517185898516741185299	внутренняя	3013213.8412	45.8537	доставлена	\N
4708	RU8183803436555934243334630961587	643	2023-10-01	IN7042522235695677917901186	внутренняя	8631645.2741	674.7175	доставлена	\N
4709	RU7483803436516612664745741202549	156	2023-02-23	PT2424442047362438542816128	международная	541827.3403	972.2390	отменена	BKCHCNBJ
4710	RU4083803436561171626967381260937	840	2023-05-18	RU2983803436539974076802515756241	внутренняя	8901338.6893	310.1993	отправлена	\N
4711	RU5683803436573106663960342062340	398	2023-04-23	RU9083803436542335742968981386823	внутренняя	5588783.3753	609.6316	доставлена	\N
4712	RU3383803436551883036237842733910	356	2023-12-26	PT8445875103803806892847290	международная	2734620.8778	383.3424	отменена	SBININBBXXX
4713	RU9383803436563463129216774786629	643	2023-01-18	RU2583803436573489146610412814439	внутренняя	9389469.1697	750.9143	отменена	\N
4714	RU4483803436531766422461159975910	398	2023-02-25	KZ1643096413445284335926394	международная	3854472.5182	855.9011	отменена	CASPKZKAXXX
4715	RU6483803436599929208547720213297	356	2023-10-06	RU1083803436516100547774990634896	внутренняя	3148293.8202	634.3997	доставлена	\N
4716	RU2783803436580745382811010865973	356	2023-12-16	RU6036796861867675451679901	внутренняя	5780576.1668	760.0838	доставлена	\N
4717	RU4183803436593654490331448399606	840	2023-02-17	RU4473044765617983642835051	внутренняя	6658873.7086	595.9516	отправлена	\N
4718	RU7483803436595528340078834029783	156	2023-03-19	RU8283803436517214496879594083501	внутренняя	7740694.6614	98.1825	доставлена	\N
4719	RU3083803436556733352794187735054	840	2023-07-29	RU8183803436513368239655842198331	внутренняя	7144239.1339	47.7376	отправлена	\N
4720	RU2283803436521727957364583057084	643	2023-01-25	DE9531715095478455685775652	внутренняя	1328980.5765	712.7131	отменена	\N
4721	RU3283803436579852018195047883736	398	2023-08-03	PT4074807027975504905818320	международная	5831147.5005	905.7562	доставлена	CASPKZKAXXX
4722	RU4783803436556925313909023616425	643	2023-02-05	RU8283803436536082355231514909614	внутренняя	1809189.9572	517.3743	доставлена	\N
4723	RU5983803436563752601230784661821	156	2023-02-25	RU2583803436569716293278278112122	внутренняя	6800704.7797	621.2806	доставлена	\N
4724	RU8083803436567877444686336475183	356	2023-04-02	BY2236536427554242465890794	международная	4098753.5068	121.9404	отменена	SBININBBXXX
4725	RU9183803436512467785925904841435	840	2023-01-17	DE2714805162200842247953274	международная	335939.6575	285.1431	отправлена	CHASUS33
4726	RU6483803436599929208547720213297	978	2023-12-05	KZ8963960279224304878658178	международная	4787276.1842	657.6472	отменена	SOGEFRPP
4727	RU8983803436518961229187913059129	356	2023-12-16	RU6783803436510078136565817264354	внутренняя	1058805.2771	631.9480	отменена	\N
4728	RU8583803436598717986670697262250	156	2023-10-05	VN7426302793109220423574451	международная	6646632.2497	289.4018	отменена	BKCHCNBJ
4729	RU1383803436565139777755041333233	643	2023-01-14	RU3683803436521305656177527242839	внутренняя	7761919.8649	723.1157	отменена	\N
4730	RU2583803436573489146610412814439	643	2023-11-14	PT5519973032080410021858432	внутренняя	1753056.2502	469.1075	отменена	\N
4731	RU7183803436546875767014611813689	156	2023-08-11	RU4883803436540069564759439339493	внутренняя	2448157.1656	102.9315	доставлена	\N
4732	RU9883803436580908913943520973504	398	2023-06-29	PT1954599236554305756165082	международная	971873.1262	399.3869	доставлена	CASPKZKAXXX
4733	RU9483803436570307762028951954874	978	2023-01-24	VN4367077064931046663808539	международная	3121312.7164	962.2800	отправлена	RZBAATWW
4734	RU4083803436526038486689011711230	398	2023-08-04	KZ8930289251864839349359354	международная	8803655.8042	413.3814	доставлена	CASPKZKAXXX
4735	RU9083803436513364676730542126445	398	2023-11-03	PT2597427453938036198371902	международная	5301054.8866	511.1353	отправлена	CASPKZKAXXX
4736	RU6983803436542868245387240901621	840	2023-07-07	IN1299212799962169026642155	международная	9333687.4157	356.4086	отправлена	IRVTUS3NXXX
4737	RU7683803436589524723383129532286	398	2023-11-07	RU6583803436547384322379422553840	внутренняя	218792.2388	822.5765	отправлена	\N
4738	RU8983803436518961229187913059129	356	2023-11-16	IN5685416923084638546930511	международная	9036096.1132	801.4903	доставлена	SBININBBXXX
4739	RU1083803436588429797000364388942	398	2023-12-25	DE9928223358776587773866641	международная	7276558.7331	61.7341	отправлена	CASPKZKAXXX
4740	RU3783803436559423561964096195262	643	2023-11-29	BY9324855084184840704128010	внутренняя	5699704.5277	74.1464	отменена	\N
4741	RU7483803436544936047225386728318	840	2023-11-08	VN4687824561176657711069769	международная	599278.5217	384.7203	отменена	CHASUS33
4742	RU5583803436581992686445972740236	156	2023-03-21	RU6983803436582618731634671628237	внутренняя	5509980.1967	234.7001	отменена	\N
4743	RU5883803436571013870275428717873	840	2023-08-03	RU1983803436510686315036595318873	внутренняя	7366343.7433	849.8950	отменена	\N
4744	RU6383803436512605200896614597744	978	2023-01-10	RU2183803436555308456329784386702	внутренняя	818360.4241	759.6684	отменена	\N
4745	RU5783803436568341660520010753753	156	2023-07-07	RU9983803436563015974445739907644	внутренняя	7475767.6536	516.3349	отменена	\N
4746	RU4383803436538414207445829899653	840	2023-04-29	PT6555121499620899583802501	международная	8136968.5734	459.3001	доставлена	CHASUS33
4747	RU8383803436557193853878723819444	978	2023-05-10	ES4826371043020035416687519	международная	5185908.2933	348.4524	отправлена	SOGEFRPP
4748	RU2583803436510413813910694958748	398	2023-09-23	AL5657148054129108857009980	международная	8881855.1622	698.0778	доставлена	CASPKZKAXXX
4749	RU9683803436597203099828784600586	398	2023-05-09	RU6683803436575472065287991925682	внутренняя	2790139.9431	642.6082	отменена	\N
4750	RU2983803436530272226005609138408	156	2023-11-23	RU8683803436557989786811096289958	внутренняя	5386434.6965	808.9941	отменена	\N
4751	RU7283803436551671539996901196859	398	2023-03-17	RU5783803436523742307313248220811	внутренняя	3350693.1921	987.1444	доставлена	\N
4752	RU5683803436564237501745383797829	398	2023-02-22	RU4983803436548786021946522460624	внутренняя	6512390.8797	993.0278	отправлена	\N
4753	RU6183803436536163842184020816729	978	2023-09-30	RU9683803436541591047480784615833	внутренняя	7532686.9830	564.3546	доставлена	\N
4754	RU3783803436559423561964096195262	978	2023-11-14	BY6344517817821706964858357	международная	3115470.9910	520.7122	доставлена	SOGEFRPP
4755	RU2583803436511360000518303822185	978	2023-11-16	RU4283803436571605132393354830061	внутренняя	5261393.1972	956.7109	доставлена	\N
4756	RU9083803436513364676730542126445	156	2023-07-28	IN2734210461748321266873564	международная	29406.1261	794.8907	отменена	BKCHCNBJ
4757	RU3983803436569376600246742084811	356	2023-03-27	RU4383803436557380827011382643653	внутренняя	6947974.3001	940.9507	доставлена	\N
4758	RU2283803436521727957364583057084	356	2023-10-28	RU8783803436544746989208687599320	внутренняя	4743938.3730	848.2715	отменена	\N
4759	RU1183803436513944372774322746458	356	2023-07-06	RU7283803436551671539996901196859	внутренняя	8350700.9413	197.1019	отменена	\N
4760	RU6583803436552414284054924599360	156	2023-01-06	RU1583803436597114679330016317094	внутренняя	3509412.9594	867.0256	доставлена	\N
4761	RU3583803436597484588589933917343	356	2023-10-27	VN6576045644970932440062928	международная	1792579.1938	29.2662	отправлена	SBININBBXXX
4762	RU5783803436523742307313248220811	356	2023-06-13	BY6844625527783733716559833	международная	9853441.2726	394.2687	доставлена	SBININBBXXX
4763	RU1583803436592948110594062864167	643	2023-06-07	VN4113422294489096421529849	внутренняя	7796317.3474	844.2024	доставлена	\N
4764	RU1983803436568263609873115174417	978	2023-03-08	RU8383803436554622159366581134752	внутренняя	6380952.0774	346.1415	доставлена	\N
4765	RU7783803436578403910419087666263	978	2023-07-05	VN9839526921260584408803692	международная	37034.5834	543.2158	доставлена	DEUTDEFFXXX
4766	RU7483803436595027677837710467368	156	2023-04-07	IN5973451586445489963195479	международная	9794314.1698	41.4684	отправлена	BKCHCNBJ
4767	RU7583803436545511345420608427589	356	2023-07-17	RU5883803436576828712243252221562	внутренняя	5028251.2803	379.2101	отправлена	\N
4768	RU2683803436575198696607383546599	398	2023-01-10	RU4683803436584135461455281070651	внутренняя	2610651.7585	795.6384	отправлена	\N
4769	RU2783803436529440294678710752920	643	2023-03-29	AL1972148128081466880587549	внутренняя	1336318.5124	421.8342	доставлена	\N
4770	RU8183803436546948351691601253240	398	2023-02-21	RU9252703709394753370714913	внутренняя	4878466.7588	381.2077	доставлена	\N
4771	RU6583803436588261503476787515721	156	2023-08-24	AD4481629246611331725074686	международная	4888546.9144	576.0879	доставлена	BKCHCNBJ
4772	RU8983803436545494349013660032430	398	2023-07-24	RU4383803436538414207445829899653	внутренняя	912931.5628	868.9303	отправлена	\N
4773	RU3983803436583730529285495292571	356	2023-09-11	AL9937611855583207732028814	международная	5884504.2680	117.3371	отменена	SBININBBXXX
4774	RU4383803436538414207445829899653	840	2023-07-31	BY1311982251254473535740137	международная	9456018.1581	974.7128	отменена	IRVTUS3NXXX
4775	RU6183803436551232797419519235346	398	2023-08-17	RU7083803436569474567525801645267	внутренняя	4637345.4680	384.9716	доставлена	\N
4776	RU8683803436511417676206561932357	156	2023-09-25	RU2083803436518033160343253894367	внутренняя	5204102.8881	779.0986	отменена	\N
4777	RU4383803436559640804885433764330	398	2023-12-04	RU4283803436571605132393354830061	внутренняя	8733533.7867	825.9901	доставлена	\N
4778	RU1083803436588429797000364388942	643	2023-12-07	AD8236944511032744471105362	внутренняя	9251804.7979	979.4438	отправлена	\N
4779	RU8783803436522200736153030297680	643	2023-12-17	IN9615139421296824792484987	внутренняя	5204365.0980	372.4974	отменена	\N
4780	RU7683803436578953117174553181317	643	2023-05-12	RU1583803436533479152204865778047	внутренняя	2575063.8885	99.1185	отменена	\N
4781	RU6383803436512605200896614597744	156	2023-01-03	RU2783803436529440294678710752920	внутренняя	2361693.3994	995.3021	отправлена	\N
4782	RU3483803436537283842522563725379	356	2023-10-16	RU3083803436548755847047281062638	внутренняя	6086596.0957	992.6892	отправлена	\N
4783	RU3183803436538368625987340316428	978	2023-11-14	RU6783803436582018660242960957244	внутренняя	9505076.9045	511.8107	отменена	\N
4784	RU2083803436517185898516741185299	398	2023-09-27	RU5883803436576828712243252221562	внутренняя	5784261.6823	178.9557	доставлена	\N
4785	RU3683803436542925451475324573982	356	2022-12-27	DE3372942865669127126158197	международная	7388563.3285	373.7974	отменена	SBININBBXXX
4786	RU1983803436592911874717339237016	398	2023-06-03	RU1383803436546084241558471107471	внутренняя	1641477.1282	374.2894	отменена	\N
4787	RU9683803436531094862059243712475	356	2023-05-16	IN6485979487950059493055435	международная	1164937.1462	597.3073	доставлена	SBININBBXXX
4788	RU5183803436596697120047636808100	643	2023-05-18	RU8383803436583878629872361871714	внутренняя	5911681.8763	29.8842	отправлена	\N
4789	RU3883803436564256045508064629374	398	2023-07-22	RU2683803436566742853200336170327	внутренняя	2468241.4551	660.4096	доставлена	\N
4790	RU1083803436532178175395898264605	840	2023-01-04	RU8583803436590890149305918634043	внутренняя	1857216.8456	585.4713	отправлена	\N
4791	RU5083803436521160540176223483455	356	2023-04-16	DE8276254689819145195046062	международная	3141402.1788	880.2462	отменена	SBININBBXXX
4792	RU7383803436569356631218275502161	356	2023-01-16	RU6983803436596433824452063468541	внутренняя	708191.0741	369.6900	отправлена	\N
4793	RU8783803436519169154241731281817	840	2023-12-11	RU8383803436583878629872361871714	внутренняя	7022368.6835	929.6360	отменена	\N
4794	RU8783803436519169154241731281817	398	2023-10-27	PT9033179491598736368919982	международная	8510888.2832	470.8001	доставлена	CASPKZKAXXX
4795	RU4583803436571583967013936520660	643	2023-02-05	AD3585424727571108002699024	внутренняя	6326439.9953	25.4860	отменена	\N
4796	RU2183803436586747579379810386651	156	2023-04-06	AL1770604305473196943438995	международная	3911390.6232	990.5005	отправлена	BKCHCNBJ
4797	RU5183803436588801456118987264753	978	2023-07-05	DE6491009824598158218473021	международная	2192274.1765	534.1860	доставлена	DEUTDEFFXXX
4798	RU7183803436513501317784267991188	840	2023-04-02	RU6383803436519000124215462920616	внутренняя	2432204.9029	507.3893	отменена	\N
4799	RU4783803436576956010684046744289	978	2023-11-09	RU4483803436534969190676238532628	внутренняя	7502906.5588	439.4445	отменена	\N
4800	RU1583803436575905915250327615306	840	2023-08-01	PT3530512649132986323644208	международная	1693302.7381	742.3409	отменена	IRVTUS3NXXX
4801	RU3583803436543438797337964557116	156	2023-08-14	ES7429333164151697655279264	международная	4368011.0470	840.6727	доставлена	BKCHCNBJ
4802	RU4583803436535138140020222748384	840	2023-05-16	RU5183803436585063037953141711870	внутренняя	2354308.4077	174.1902	отправлена	\N
4803	RU6483803436531317735484528392559	978	2023-07-24	IN2364198976711654936276401	международная	4459073.3499	227.9625	отменена	SOGEFRPP
4804	RU6783803436510078136565817264354	840	2023-08-25	RU5983803436518386216122030936247	внутренняя	640989.1306	555.4938	доставлена	\N
4805	RU5983803436558435772787343054218	156	2023-05-26	RU3883803436554504516286459147223	внутренняя	7015915.8981	401.3889	доставлена	\N
4806	RU6983803436596433824452063468541	643	2023-11-29	BY8265019812410835620143506	внутренняя	1476683.6670	450.7849	отменена	\N
4807	RU3183803436564747839620735247465	356	2023-09-08	RU3283803436586063041663029658571	внутренняя	8730336.7940	617.0931	отправлена	\N
4808	RU3083803436572725983728902081378	978	2023-06-05	IN6734396001806243110088208	международная	1143492.2019	841.2129	отправлена	SOGEFRPP
4809	RU7683803436589524723383129532286	840	2023-07-01	AL6636295292624276513243121	международная	8685776.3115	632.8165	отправлена	IRVTUS3NXXX
4810	RU8483803436514025076841381077297	356	2023-10-15	RU6783803436582018660242960957244	внутренняя	6030522.0778	875.0987	доставлена	\N
4811	RU2283803436521727957364583057084	643	2023-07-12	PT1897497937010298662273457	внутренняя	7341322.0783	564.6553	отправлена	\N
4812	RU7483803436512314763652680872976	398	2023-11-01	BY6285504216707939127266845	международная	5698737.8189	378.8173	отменена	CASPKZKAXXX
4813	RU4583803436546993711061481413708	398	2023-11-26	RU9483803436588743613330942629999	внутренняя	1022957.7236	230.0871	доставлена	\N
4814	RU9683803436524115739172828059349	356	2023-01-01	RU8883803436592173067148862634991	внутренняя	2372455.1438	502.1695	доставлена	\N
4815	RU4483803436534969190676238532628	840	2023-02-05	VN9519387579761247817775951	международная	4515949.0267	48.9515	доставлена	CHASUS33
4816	RU7083803436575256167282941443393	398	2023-06-19	RU4183803436544525596730636267692	внутренняя	6872508.3791	171.8937	доставлена	\N
4817	RU3383803436551883036237842733910	398	2023-12-20	RU7083803436595909521339223196614	внутренняя	7720340.5165	900.1741	отправлена	\N
4818	RU9483803436585469145832242711561	840	2023-05-08	RU5183803436531460410872953149827	внутренняя	727121.6497	0.0000	отправлена	\N
4819	RU8283803436536082355231514909614	840	2023-08-31	RU2983803436545911307181108696312	внутренняя	8586279.9969	453.2357	отменена	\N
4820	RU8583803436567351126582917385267	643	2023-12-04	RU1083803436563162471160560931522	внутренняя	2535901.7162	482.1090	доставлена	\N
4821	RU8583803436567351126582917385267	643	2023-07-07	RU8183803436559528710172368223769	внутренняя	9565789.9220	377.1954	отменена	\N
4822	RU4283803436544879224116585983050	156	2023-11-29	RU2983803436539974076802515756241	внутренняя	8533335.3475	803.1766	отменена	\N
4823	RU6583803436526807323529165700056	356	2023-11-25	KZ3164109372805941261552242	международная	1218715.5715	517.2763	отменена	SBININBBXXX
4824	RU4583803436544769415444430855700	156	2023-06-16	RU3383803436530100232705488681423	внутренняя	901642.2982	301.5870	отправлена	\N
4825	RU9383803436563463129216774786629	356	2023-09-14	RU6383803436599902939219818792376	внутренняя	4829041.6505	131.5855	доставлена	\N
4826	RU9883803436596118671708861810646	156	2023-12-04	RU9383803436563463129216774786629	внутренняя	1713501.1472	433.8423	отменена	\N
4827	RU9683803436579408636311341559980	643	2023-04-23	RU8483803436593374085227717891522	внутренняя	6975864.4465	541.7235	отправлена	\N
4828	RU9483803436516702191580023603147	840	2023-03-08	BY4895628133080751709958750	международная	2476213.5493	891.1013	отменена	CHASUS33
4829	RU8183803436584325139466333599286	840	2023-06-13	RU8283803436536082355231514909614	внутренняя	7145576.2009	124.1525	доставлена	\N
4830	RU2483803436563361420871450061347	643	2023-03-28	VN2264984217399993825543905	внутренняя	6545429.4650	416.5175	отменена	\N
4831	RU1683803436549082108439124677076	356	2023-03-07	ES2586596836314668587424288	международная	3899568.0282	787.4819	отправлена	SBININBBXXX
4832	RU3483803436534657689181631833463	398	2023-01-20	VN8563575687037109351504070	международная	8635833.6862	780.5650	отменена	CASPKZKAXXX
4833	RU6183803436536163842184020816729	356	2023-08-09	RU9283803436560888794155508079505	внутренняя	5981062.4869	746.1345	отменена	\N
4834	RU1983803436510712914540451632365	840	2023-03-09	IN4148357022504540213604784	международная	2461585.2017	474.9697	отправлена	IRVTUS3NXXX
4835	RU5783803436556321671762187197309	643	2023-08-05	KZ4717937475812788647584333	внутренняя	229000.5838	920.1925	отправлена	\N
4836	RU4783803436556925313909023616425	398	2023-08-04	BY5443642654491354120377736	международная	6761835.1352	536.1065	отменена	CASPKZKAXXX
4837	RU3583803436580986023375789999847	840	2023-03-12	RU8583803436598717986670697262250	внутренняя	4878811.5069	432.4091	отменена	\N
4838	RU1683803436549082108439124677076	840	2023-12-02	DE8060226561323504530572532	международная	9557227.4208	899.0102	отменена	IRVTUS3NXXX
4839	RU1483803436556765140449291811625	643	2023-01-14	RU9423937936449988682689600	внутренняя	4410307.0375	703.6771	отправлена	\N
4840	RU5483803436547543071206231343471	978	2023-11-17	RU4983803436548786021946522460624	внутренняя	5774302.0192	110.9558	отменена	\N
4841	RU5783803436523742307313248220811	978	2023-12-04	ES9530120309482219378845589	международная	7759861.9793	353.6089	доставлена	RZBAATWW
4842	RU5683803436564237501745383797829	643	2023-10-11	RU6983803436557684576294868357987	внутренняя	4497535.8993	505.4420	доставлена	\N
4843	RU2883803436510195395163379960366	978	2023-05-10	RU5783803436573951128453151787227	внутренняя	3589708.2962	162.9649	доставлена	\N
4844	RU5983803436513359014201161572816	398	2023-06-25	RU3183803436545750333950215053352	внутренняя	9207130.4423	980.7413	отменена	\N
4845	RU2883803436510195395163379960366	398	2023-09-21	RU4483803436574648344464338946055	внутренняя	9296150.5316	317.9752	отправлена	\N
4846	RU5583803436541779385547740767657	643	2023-12-06	VN9920822564987096479342371	внутренняя	7574886.8100	385.1033	доставлена	\N
4847	RU9683803436526786707929300961979	398	2023-02-11	RU9283803436529032721317031749293	внутренняя	6411528.9437	201.5211	доставлена	\N
4848	RU1083803436516100547774990634896	840	2023-09-01	RU6483803436513432249664452306210	внутренняя	5367236.2153	288.3138	отменена	\N
4849	RU2983803436539974076802515756241	398	2023-05-28	RU4883803436577275200947611443039	внутренняя	5493858.0397	565.3381	отправлена	\N
4850	RU3883803436515226766320509995235	398	2023-11-19	RU7183803436535160662680026565691	внутренняя	2790980.3733	514.6671	отменена	\N
4851	RU6983803436542868245387240901621	356	2023-09-17	RU1583803436592948110594062864167	внутренняя	1018866.9129	170.0540	отменена	\N
4852	RU7083803436595909521339223196614	156	2023-02-12	KZ4788119177328064070074753	международная	5539099.5389	159.8837	отменена	BKCHCNBJ
4853	RU9283803436581282514241262822584	356	2023-10-26	RU1983803436549890414007715363567	внутренняя	466630.3343	403.0731	доставлена	\N
4854	RU7183803436535160662680026565691	356	2023-10-02	RU8483803436517523304653033637180	внутренняя	6856957.9282	51.8494	доставлена	\N
4855	RU4783803436576956010684046744289	643	2023-09-08	VN9467709643745495421943141	внутренняя	1499356.2729	266.8045	отправлена	\N
4856	RU3083803436556733352794187735054	156	2023-10-21	RU2483803436580851808318436691458	внутренняя	8958800.2496	612.1749	отправлена	\N
4857	RU7583803436593274051968042799324	643	2023-04-16	BY8984108667700820017422751	внутренняя	27508.8409	960.6696	отправлена	\N
4858	RU3683803436589669964829443545971	398	2023-07-02	RU2783803436512588965300606208370	внутренняя	9992138.0737	207.6305	отправлена	\N
4859	RU3883803436571430516571621799878	356	2023-01-23	RU5183803436599553165549416662045	внутренняя	1337488.7202	184.9121	отправлена	\N
4860	RU8383803436554622159366581134752	978	2023-12-03	RU7883803436577262824038798840088	внутренняя	1221352.1572	372.5057	доставлена	\N
4861	RU1283803436521770311179326367954	978	2023-04-11	RU9998792058847666597603258	внутренняя	9428656.5285	607.5171	доставлена	\N
4862	RU9883803436597607312145326011401	356	2023-05-14	VN6459591978246048669076912	международная	8987623.8615	284.5095	доставлена	SBININBBXXX
4863	RU7283803436528848493351990702937	840	2023-11-27	DE4753754492803725570172883	международная	6876171.5436	182.3790	доставлена	IRVTUS3NXXX
4864	RU9083803436548965374028188380728	643	2023-05-19	BY9316149071790859444488131	внутренняя	4766064.7254	795.1421	доставлена	\N
4865	RU6583803436546434088553514688778	978	2023-05-24	RU6783803436527708547728704282997	внутренняя	2620312.7724	214.0838	доставлена	\N
4866	RU8883803436592173067148862634991	978	2023-01-27	RU5583803436516539388298963058164	внутренняя	9064204.4756	103.3544	отправлена	\N
4867	RU9383803436515318038329930627155	398	2023-05-03	DE9181643979238927061238127	международная	5112335.1561	125.4603	доставлена	CASPKZKAXXX
4868	RU4683803436518754352401343547893	840	2023-02-27	RU9640957124197908169735651	внутренняя	7810178.5345	915.3716	отменена	\N
4869	RU7783803436585076163513647706071	398	2023-02-25	RU4883803436583846522749125412438	внутренняя	7392362.0960	140.1777	доставлена	\N
4870	RU9583803436574471411467135718624	643	2023-01-18	KZ7654477221207836849101254	внутренняя	1491278.0457	758.2807	отправлена	\N
4871	RU2883803436538134433783624054557	840	2023-02-04	RU8083803436567877444686336475183	внутренняя	760874.9943	917.7236	доставлена	\N
4872	RU8483803436552375991404578719285	356	2023-10-13	AD5779603284770872969411035	международная	824437.0704	181.9128	доставлена	SBININBBXXX
4873	RU3983803436562540544761068231244	840	2023-01-25	AD4831762141163479791354154	международная	1254624.1748	308.5756	отправлена	IRVTUS3NXXX
4874	RU8383803436554622159366581134752	978	2023-10-15	RU7583803436593274051968042799324	внутренняя	8041507.9917	854.8096	доставлена	\N
4875	RU2483803436580851808318436691458	840	2023-10-08	RU7383803436515152831562897371432	внутренняя	870438.7084	659.9384	отменена	\N
4876	RU1983803436537997284898110055528	356	2023-01-13	RU1183803436541561390025398925839	внутренняя	1938765.5756	364.0269	доставлена	\N
4877	RU2683803436566742853200336170327	643	2023-12-18	AL4939576672220992770827376	внутренняя	2948959.5406	466.3994	доставлена	\N
4878	RU9483803436521022327823815694666	978	2023-11-21	AL9776629745379239282822837	международная	5940176.5272	287.2856	отменена	DEUTDEFFXXX
4879	RU4483803436537144245226352938256	156	2023-04-12	AL6180689129374425696531941	международная	9992022.7581	846.8377	доставлена	BKCHCNBJ
4880	RU5183803436523181844916432548416	978	2023-03-02	RU8983803436588264357315670765686	внутренняя	500227.4881	902.6240	отправлена	\N
4881	RU1983803436568263609873115174417	978	2023-10-02	RU4783803436556925313909023616425	внутренняя	7978306.3611	798.8742	отправлена	\N
4882	RU5183803436550941857646482749776	356	2023-12-05	RU6583803436547384322379422553840	внутренняя	6646966.4188	667.9192	отменена	\N
4883	RU6783803436527708547728704282997	398	2023-04-11	PT3396318443504871026889027	международная	7372510.4729	288.8145	доставлена	CASPKZKAXXX
4884	RU8583803436598717986670697262250	156	2023-03-29	RU3383803436533625475503259998648	внутренняя	9839055.7398	821.1437	отменена	\N
4885	RU8783803436519169154241731281817	156	2023-01-29	IN4171672956843315434507466	международная	2822534.7776	842.7106	отменена	BKCHCNBJ
4886	RU2983803436545911307181108696312	978	2023-09-01	AL6284043358572858569408977	международная	7221474.1612	451.9928	отправлена	RZBAATWW
4887	RU5483803436559214869633349674125	356	2023-12-23	RU9883803436559947701649293062119	внутренняя	3701901.0303	567.1976	отправлена	\N
4888	RU3783803436562091905141244310726	978	2023-11-11	BY7392445016126413449639755	международная	5732368.8821	514.6616	отменена	DEUTDEFFXXX
4889	RU3983803436583094600516227232333	978	2023-12-11	RU3334278909124133337084628	внутренняя	112265.9491	795.1768	доставлена	\N
4890	RU9283803436564588409350021574669	643	2023-08-15	RU5383803436532276110708298062956	внутренняя	5518520.8210	81.4912	отправлена	\N
4891	RU9283803436529032721317031749293	643	2023-12-18	RU5883803436537252361294139722938	внутренняя	349555.9479	656.4292	отправлена	\N
4892	RU5183803436531460410872953149827	398	2023-05-02	RU3077470632941096295479355	внутренняя	6993842.9827	905.0237	отменена	\N
4893	RU3183803436538368625987340316428	156	2023-05-20	RU8983803436550652073660555482382	внутренняя	8801581.1336	228.1963	отправлена	\N
4894	RU8983803436518961229187913059129	643	2023-07-13	RU2483803436550335144467075253432	внутренняя	3051697.5244	179.9794	доставлена	\N
4895	RU7783803436578403910419087666263	840	2023-06-18	IN8645317696340542621076013	международная	604740.7109	518.9673	доставлена	IRVTUS3NXXX
4896	RU8983803436550652073660555482382	840	2023-11-23	ES5368098347277504557095898	международная	1968144.6761	367.4316	доставлена	CHASUS33
4897	RU1083803436563162471160560931522	643	2023-10-25	RU1983803436510712914540451632365	внутренняя	4594344.2702	305.1382	отменена	\N
4898	RU2583803436525056668985275863842	840	2023-11-30	RU3183803436583121152517184662518	внутренняя	1924943.6490	166.7803	доставлена	\N
4899	RU8983803436550652073660555482382	643	2023-10-03	AD7988599315257782594128397	внутренняя	4175062.9730	480.8615	отправлена	\N
4900	RU1683803436510344781123537250392	978	2023-10-19	RU4183803436598422593606583773593	внутренняя	3144187.9195	456.6483	доставлена	\N
4901	RU3183803436522808312515599877028	643	2023-06-07	KZ2850371414682110101404163	внутренняя	2709583.9741	426.9024	отправлена	\N
4902	RU8483803436528403655778834568144	978	2023-02-23	ES4412024912005326744091974	международная	2632256.3935	295.3504	отправлена	DEUTDEFFXXX
4903	RU4383803436535637847836978327691	356	2023-08-04	ES6173772367426835466229560	международная	9189997.6484	477.6604	отправлена	SBININBBXXX
4904	RU8483803436512925144599170278485	398	2023-12-17	KZ8815846776305995024563762	международная	8070113.6290	473.6950	отменена	CASPKZKAXXX
4905	RU4383803436597428452957764955765	356	2023-03-28	RU5783803436553735504938098098542	внутренняя	4140559.8191	768.3504	доставлена	\N
4906	RU1983803436549890414007715363567	978	2023-11-12	AD1142083123771667055692768	международная	1858284.5517	204.0789	отправлена	DEUTDEFFXXX
4907	RU1983803436568263609873115174417	978	2023-05-23	DE1586309602960149458930754	международная	642271.4596	970.0799	доставлена	SOGEFRPP
4908	RU7383803436534050516387288663509	356	2023-04-11	IN3264112279513110544393292	международная	7174686.2189	672.5531	отправлена	SBININBBXXX
4909	RU4283803436530972916151822377436	356	2023-08-23	RU3783803436562091905141244310726	внутренняя	374682.0701	96.9433	отменена	\N
4910	RU2383803436569895097903578030814	398	2023-03-04	RU2283803436551819000625747494652	внутренняя	7579234.5125	264.8128	отправлена	\N
4911	RU8983803436530366335955653516096	156	2023-07-10	RU5883803436544935035293164341064	внутренняя	1559941.7804	166.4687	доставлена	\N
4912	RU2983803436510489846489627969282	643	2023-09-22	RU6253227468929035683713061	внутренняя	5087046.1633	446.6941	отправлена	\N
4913	RU9683803436526786707929300961979	643	2023-10-01	IN4756950215193535757402671	внутренняя	4634112.3001	814.6611	отправлена	\N
4914	RU3883803436554504516286459147223	643	2023-04-04	RU8855317209400925550609275	внутренняя	1045046.1173	306.5635	доставлена	\N
4915	RU2883803436510195395163379960366	398	2023-11-13	ES4695965601600578390587756	международная	1935537.7654	175.9806	доставлена	CASPKZKAXXX
4916	RU1083803436563162471160560931522	643	2023-10-06	RU7383803436534050516387288663509	внутренняя	6368814.4629	655.8703	доставлена	\N
4917	RU8383803436583878629872361871714	978	2023-07-18	AD7727038466622039209936199	международная	4326889.2837	871.5974	отменена	SOGEFRPP
4918	RU6283803436561107985248905256058	156	2023-02-12	RU9583803436589245078784775619456	внутренняя	1196871.6547	328.3163	доставлена	\N
4919	RU9183803436523189940915642395180	156	2023-03-10	BY7978643783388624299502136	международная	368543.1590	179.1388	доставлена	BKCHCNBJ
4920	RU8483803436512925144599170278485	840	2023-10-22	VN8823824793222766712360785	международная	6119662.6943	221.0941	отменена	IRVTUS3NXXX
4921	RU3883803436531800763308499008852	840	2023-11-14	RU4083803436561171626967381260937	внутренняя	1893186.0198	506.9566	отменена	\N
4922	RU5083803436583492295875343805447	398	2023-08-06	PT2047413044105873083935732	международная	5303979.3356	194.2598	отправлена	CASPKZKAXXX
4923	RU7183803436584925378313266803439	978	2023-02-08	RU4583803436567844239839748091371	внутренняя	8410414.8401	26.7871	отменена	\N
4924	RU9483803436522220035875117822565	356	2023-04-18	RU8583803436586707949034749896750	внутренняя	6054896.2204	983.3110	отменена	\N
4925	RU9683803436524115739172828059349	978	2023-06-17	RU3983803436580604058878329162478	внутренняя	9619336.2842	556.9251	доставлена	\N
4926	RU2983803436572636545308279163382	643	2023-02-07	IN9124344488246370184393655	внутренняя	1595144.3712	838.4094	доставлена	\N
4927	RU7483803436581386287039618321410	356	2023-01-23	RU4483803436531766422461159975910	внутренняя	7638683.5965	569.1640	отменена	\N
4928	RU6183803436556503720110500069421	156	2023-01-26	KZ6611638793289258928890128	международная	3770334.6797	661.5695	отправлена	BKCHCNBJ
4929	RU5183803436588801456118987264753	398	2023-09-27	PT3342057139419207961370543	международная	3292568.9397	625.7590	доставлена	CASPKZKAXXX
4930	RU3783803436562139250445157080524	840	2023-01-01	RU1583803436575905915250327615306	внутренняя	8383914.1802	207.3057	доставлена	\N
4931	RU5483803436538988818998904026382	398	2023-06-19	KZ4313573662420987329736833	международная	4393988.6057	976.5661	отменена	CASPKZKAXXX
4932	RU1583803436578714315409224923820	840	2023-11-03	RU7783803436557425582753958788900	внутренняя	815558.3232	441.8194	отменена	\N
4933	RU6783803436527708547728704282997	156	2022-12-30	RU3383803436533625475503259998648	внутренняя	1996809.8565	182.7400	доставлена	\N
4934	RU1083803436563162471160560931522	840	2023-05-20	RU9862812962851569399894591	внутренняя	1227955.7173	952.0011	отменена	\N
4935	RU7183803436551143317683635788042	356	2023-10-12	PT4293231991875218716876196	международная	1548935.5702	212.6317	отменена	SBININBBXXX
4936	RU7483803436595528340078834029783	156	2023-06-28	IN2060489009852988379477208	международная	318613.0463	298.2653	отменена	BKCHCNBJ
4937	RU2883803436581906276084692901201	356	2023-09-05	RU3383803436527231938190662146888	внутренняя	7793259.7550	166.2923	отменена	\N
4938	RU7383803436546512723534280739575	978	2023-10-12	RU4483803436537144245226352938256	внутренняя	2294590.4274	234.4488	отправлена	\N
4939	RU9083803436548965374028188380728	840	2023-09-14	RU8183803436576334203563049364101	внутренняя	2189002.6736	538.9977	отправлена	\N
4940	RU8583803436567351126582917385267	356	2023-04-03	RU4183803436593654490331448399606	внутренняя	5563476.6164	331.2858	доставлена	\N
4941	RU5483803436547543071206231343471	840	2023-12-17	RU3083803436548755847047281062638	внутренняя	1883993.2139	228.7373	отправлена	\N
4942	RU8983803436513229118545499417330	840	2023-04-20	BY8226866349726953805247972	международная	9418451.0529	810.5390	отправлена	IRVTUS3NXXX
4943	RU8183803436564595439284009293487	398	2023-10-23	RU1083803436563162471160560931522	внутренняя	5106119.2103	253.0635	отменена	\N
4944	RU6483803436575827628326698282321	840	2023-03-14	RU4083803436523112590591409946049	внутренняя	6862848.7750	785.0002	доставлена	\N
4945	RU6883803436521704893234788177503	156	2023-08-29	PT3486015904233823567493744	международная	4621797.5305	401.9319	доставлена	BKCHCNBJ
4946	RU1583803436575905915250327615306	356	2023-09-27	RU5183803436588244188761426669013	внутренняя	3661930.3533	279.3232	отменена	\N
4947	RU3383803436548623436381587682007	356	2023-01-12	RU6983803436596433824452063468541	внутренняя	3594472.2745	142.8522	отменена	\N
4948	RU2483803436563361420871450061347	398	2023-01-26	AD8518605281726433959166333	международная	6734103.8943	860.6963	доставлена	CASPKZKAXXX
4949	RU8583803436593152008036708778596	978	2023-10-28	RU1183803436513944372774322746458	внутренняя	9367198.9391	634.7675	отменена	\N
4950	RU6483803436595566817980742907742	643	2023-10-09	RU6583803436546434088553514688778	внутренняя	7378501.1364	556.2318	доставлена	\N
4951	RU6583803436592149423686806465410	156	2023-02-28	VN2340176535774841037169813	международная	6727350.2857	430.3036	отправлена	BKCHCNBJ
4952	RU2883803436538134433783624054557	398	2023-04-28	RU1983803436592911874717339237016	внутренняя	1581141.7747	417.3323	отменена	\N
4953	RU3983803436569376600246742084811	398	2023-08-13	PT5534084882041622520310733	международная	7047069.2590	881.5161	отменена	CASPKZKAXXX
4954	RU4083803436565489336932623834655	356	2023-01-24	IN4968032557048313280559180	международная	6250646.1619	68.8416	доставлена	SBININBBXXX
4955	RU5783803436553735504938098098542	978	2023-08-17	RU9683803436571883645805733128714	внутренняя	5279395.3334	357.2844	отменена	\N
4956	RU2983803436539974076802515756241	643	2023-06-19	IN7792395789155801953763038	внутренняя	8608462.0461	150.4867	отменена	\N
4957	RU4783803436576956010684046744289	156	2023-10-21	RU2983803436572678251629055132350	внутренняя	4868946.2450	990.7770	доставлена	\N
4958	RU9183803436594783043422280553530	356	2023-09-29	RU5678234872180279962570261	внутренняя	8575093.0197	763.3458	отменена	\N
4959	RU8483803436546395435496825405512	978	2023-08-19	RU4883803436561825246742556433732	внутренняя	9166872.3201	377.6287	отправлена	\N
4960	RU4283803436515276086545867508581	643	2023-05-19	RU8683803436531608639655465618756	внутренняя	9755739.0431	520.7892	отменена	\N
4961	RU8483803436552375991404578719285	840	2023-08-20	RU8583803436553386257766521949981	внутренняя	6600613.7514	532.6292	доставлена	\N
4962	RU8583803436598717986670697262250	156	2023-06-13	BY4417023773510677254303891	международная	6139735.3812	227.7450	отменена	BKCHCNBJ
4963	RU8983803436550652073660555482382	356	2023-07-25	ES8847682463243586628348951	международная	6641131.2511	559.8190	отменена	SBININBBXXX
4964	RU2483803436537933507280624045523	356	2023-11-21	AD8125319128188182050466765	международная	9425395.2772	16.3007	доставлена	SBININBBXXX
4965	RU3983803436554516084539411139147	156	2023-12-01	RU3183803436559935083955185145410	внутренняя	6151628.4452	50.1919	отправлена	\N
4966	RU7083803436595909521339223196614	398	2023-08-08	RU3183803436583121152517184662518	внутренняя	2338795.4404	577.1362	отправлена	\N
4967	RU9783803436566819882292917709885	840	2023-10-08	RU4583803436588661449801193641363	внутренняя	8523608.9404	92.4588	отменена	\N
4968	RU8183803436576334203563049364101	398	2023-05-22	AL5762796385935583488839626	международная	106026.0946	144.9747	отправлена	CASPKZKAXXX
4969	RU1083803436588429797000364388942	978	2023-11-29	BY1027740541685210241764054	международная	9551342.4052	367.5709	отменена	RZBAATWW
4970	RU5983803436563752601230784661821	398	2023-03-14	KZ6617791179808376142470222	международная	2879360.1871	733.4425	отменена	CASPKZKAXXX
4971	RU5683803436581377733469772235779	156	2023-03-16	BY4967145507794701980651010	международная	6884438.8216	826.4141	отменена	BKCHCNBJ
4972	RU9883803436559947701649293062119	840	2023-11-18	RU9483803436588743613330942629999	внутренняя	3721871.4581	502.9447	доставлена	\N
4973	RU1083803436516100547774990634896	978	2023-11-06	BY4646290956235387357027870	международная	6402952.3998	918.0941	отменена	RZBAATWW
4974	RU3183803436556325220643083039724	643	2023-11-15	RU1883803436562141776165180370424	внутренняя	7790948.9925	547.2580	доставлена	\N
4975	RU6683803436534213789698830771682	356	2023-08-08	BY5645208891867544227635878	международная	8393487.0131	140.5973	отменена	SBININBBXXX
4976	RU4383803436597428452957764955765	398	2023-09-26	RU4483803436537144245226352938256	внутренняя	5648308.5117	309.8104	доставлена	\N
4977	RU7483803436516612664745741202549	978	2023-01-12	AL8147762397100404966459673	международная	3282473.3870	0.0000	отправлена	SOGEFRPP
4978	RU5883803436576828712243252221562	156	2023-06-30	AD8326877836543116078558038	международная	1253165.5014	809.4721	отправлена	BKCHCNBJ
4979	RU1683803436549082108439124677076	643	2023-03-07	RU1083803436588429797000364388942	внутренняя	9094285.3986	988.3176	доставлена	\N
4980	RU3983803436562540544761068231244	398	2023-05-26	PT3343113699709165897951138	международная	3511290.8783	822.4111	отправлена	CASPKZKAXXX
4981	RU8583803436529401978461350257287	840	2023-03-25	RU8783803436562772820294479967682	внутренняя	4056723.3166	478.8149	отменена	\N
4982	RU5183803436588244188761426669013	643	2023-03-27	PT7327120554529878079172919	внутренняя	6549352.6604	883.7282	отменена	\N
4983	RU6483803436531317735484528392559	356	2023-11-26	ES1278044969366385376169267	международная	6240774.1480	558.7546	доставлена	SBININBBXXX
4984	RU7383803436546512723534280739575	643	2023-11-28	DE5349784329112432233902122	внутренняя	918692.9496	602.4589	отменена	\N
4985	RU4083803436523112590591409946049	643	2023-10-05	RU1183803436587920364130887563809	внутренняя	8217956.2444	577.3922	доставлена	\N
4986	RU9383803436563463129216774786629	356	2023-02-27	RU4583803436588661449801193641363	внутренняя	7619710.8232	291.7208	отменена	\N
4987	RU2183803436535230801413319305895	840	2023-02-04	RU7083803436565850801859363291526	внутренняя	3782908.1015	462.3835	отменена	\N
4988	RU2583803436573489146610412814439	398	2023-06-23	AD9225878815603777093234021	международная	6569320.3587	956.7214	доставлена	CASPKZKAXXX
4989	RU3883803436559428008275215914286	643	2023-01-28	KZ4047180959198680064289911	внутренняя	2008473.2961	675.4883	отправлена	\N
4990	RU7683803436578953117174553181317	398	2023-02-05	RU8140885142419255087013486	внутренняя	4158768.9681	497.2191	отправлена	\N
4991	RU9983803436588442958405952112241	978	2023-05-29	KZ9714691166300948421995961	международная	9013474.6595	715.2365	отменена	SOGEFRPP
4992	RU9383803436587347167184231490115	978	2023-07-08	RU6083803436557649065533492172245	внутренняя	990086.6171	108.7231	доставлена	\N
4993	RU2083803436593214630941740939011	978	2023-01-11	KZ2439405143782208294121440	международная	5566839.0119	236.4430	отправлена	DEUTDEFFXXX
4994	RU1183803436541561390025398925839	978	2023-01-07	BY6133000879275410550097765	международная	8346252.6082	266.9814	отправлена	RZBAATWW
4995	RU4083803436525661046500520760430	398	2023-09-16	AD3466411998814829134757703	международная	6881217.1081	739.8647	отправлена	CASPKZKAXXX
4996	RU8983803436543970357311304848339	356	2023-12-04	RU3783803436559423561964096195262	внутренняя	7125345.4736	666.8336	отправлена	\N
4997	RU4383803436557380827011382643653	156	2023-11-16	RU6183803436547326038705936576601	внутренняя	6582055.9935	20.0533	доставлена	\N
4998	RU7383803436534050516387288663509	398	2023-05-19	PT2421283776732184749888105	международная	6318975.1633	910.0279	отправлена	CASPKZKAXXX
4999	RU8483803436517523304653033637180	398	2023-07-31	ES6314106003179033751023121	международная	1002112.3198	11.7822	отменена	CASPKZKAXXX
5000	RU9683803436597203099828784600586	978	2023-05-14	RU8644580225143506617341683	внутренняя	8640722.6373	402.4341	отправлена	\N
\.


--
-- Name: clients_client_id_seq; Type: SEQUENCE SET; Schema: bank; Owner: postgres
--

SELECT pg_catalog.setval('bank.clients_client_id_seq', 100, true);


--
-- Name: deposits_deposit_id_seq; Type: SEQUENCE SET; Schema: bank; Owner: postgres
--

SELECT pg_catalog.setval('bank.deposits_deposit_id_seq', 500, true);


--
-- Name: loans_loan_id_seq; Type: SEQUENCE SET; Schema: bank; Owner: postgres
--

SELECT pg_catalog.setval('bank.loans_loan_id_seq', 500, true);


--
-- Name: personnel_employee_id_seq; Type: SEQUENCE SET; Schema: bank; Owner: postgres
--

SELECT pg_catalog.setval('bank.personnel_employee_id_seq', 300, true);


--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE SET; Schema: bank; Owner: postgres
--

SELECT pg_catalog.setval('bank.transactions_transaction_id_seq', 5000, true);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (account_num);


--
-- Name: banks_cors banks_cors_pkey; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.banks_cors
    ADD CONSTRAINT banks_cors_pkey PRIMARY KEY (swift_code);


--
-- Name: branches branches_phone_key; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.branches
    ADD CONSTRAINT branches_phone_key UNIQUE (phone);


--
-- Name: branches branches_pkey; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.branches
    ADD CONSTRAINT branches_pkey PRIMARY KEY (branch_id);


--
-- Name: clients clients_inn_key; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.clients
    ADD CONSTRAINT clients_inn_key UNIQUE (inn);


--
-- Name: clients clients_passport_key; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.clients
    ADD CONSTRAINT clients_passport_key UNIQUE (passport);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (client_id);


--
-- Name: daily_rates daily_rates_pkey; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.daily_rates
    ADD CONSTRAINT daily_rates_pkey PRIMARY KEY (cur_id, date);


--
-- Name: deposits deposits_pkey; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.deposits
    ADD CONSTRAINT deposits_pkey PRIMARY KEY (deposit_id);


--
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (loan_id);


--
-- Name: personnel personnel_contact_info_key; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.personnel
    ADD CONSTRAINT personnel_contact_info_key UNIQUE (contact_info);


--
-- Name: personnel personnel_pkey; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.personnel
    ADD CONSTRAINT personnel_pkey PRIMARY KEY (employee_id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (transaction_id);


--
-- Name: loans check_loan_status; Type: TRIGGER; Schema: bank; Owner: postgres
--

CREATE TRIGGER check_loan_status BEFORE UPDATE ON bank.loans FOR EACH ROW EXECUTE PROCEDURE bank.update_loan_status();


--
-- Name: accounts validate_account_closure; Type: TRIGGER; Schema: bank; Owner: postgres
--

CREATE TRIGGER validate_account_closure BEFORE UPDATE ON bank.accounts FOR EACH ROW EXECUTE PROCEDURE bank.check_account_balance();


--
-- Name: accounts accounts_client_id_fkey; Type: FK CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.accounts
    ADD CONSTRAINT accounts_client_id_fkey FOREIGN KEY (client_id) REFERENCES bank.clients(client_id);


--
-- Name: branches branches_head_fkey; Type: FK CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.branches
    ADD CONSTRAINT branches_head_fkey FOREIGN KEY (head) REFERENCES bank.personnel(employee_id);


--
-- Name: deposits deposits_client_id_fkey; Type: FK CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.deposits
    ADD CONSTRAINT deposits_client_id_fkey FOREIGN KEY (client_id) REFERENCES bank.clients(client_id);


--
-- Name: loans loans_client_id_fkey; Type: FK CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.loans
    ADD CONSTRAINT loans_client_id_fkey FOREIGN KEY (client_id) REFERENCES bank.clients(client_id);


--
-- Name: personnel personnel_branch_id_fkey; Type: FK CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.personnel
    ADD CONSTRAINT personnel_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES bank.branches(branch_id);


--
-- Name: transactions transactions_bank_cor_swift_fkey; Type: FK CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.transactions
    ADD CONSTRAINT transactions_bank_cor_swift_fkey FOREIGN KEY (bank_cor_swift) REFERENCES bank.banks_cors(swift_code);


--
-- Name: transactions transactions_prpl_account_num_fkey; Type: FK CONSTRAINT; Schema: bank; Owner: postgres
--

ALTER TABLE ONLY bank.transactions
    ADD CONSTRAINT transactions_prpl_account_num_fkey FOREIGN KEY (prpl_account_num) REFERENCES bank.accounts(account_num);


--
-- Name: transactions_rub; Type: MATERIALIZED VIEW DATA; Schema: bank; Owner: postgres
--

REFRESH MATERIALIZED VIEW bank.transactions_rub;


--
-- PostgreSQL database dump complete
--

