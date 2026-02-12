-- Этап 1. Создание и заполнение БД
CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id INT,
    auto VARCHAR,
    gasoline_consumption NUMERIC,
    price NUMERIC,
    date DATE,
    person VARCHAR,
    phone VARCHAR,
    discount NUMERIC,
    brand_origin VARCHAR
);

ALTER TABLE raw_data.sales 
ALTER COLUMN gasoline_consumption TYPE TEXT; /* изменила тип данных, так как есть значение NULL */

create schema car_shop;

CREATE TABLE car_shop.customers (
    customer_id SERIAL PRIMARY KEY, /* Поля с такими типами данных автоматически увеличивают значения на единицу для каждой новой строки. */
    full_name VARCHAR(100), /*ФИО, ограничение в 100 символов достаточно для большинства ФИО */
    phone VARCHAR(25) /*ограничение в 25 символов достаточно для большинства телефонов */
);

CREATE TABLE car_shop.colors (
    color_id SERIAL PRIMARY KEY, /* Поля с такими типами данных автоматически увеличивают значения на единицу для каждой новой строки. */
    color_name VARCHAR(20) /*название цвета обычно короткое */
);

CREATE TABLE car_shop.countries (
    country_id SERIAL PRIMARY KEY, /* Поля с такими типами данных автоматически увеличивают значения на единицу для каждой новой строки. */
    country_name VARCHAR(50) /*ограничение в 50 символов достаточно для большинства названий стран */
);

CREATE TABLE car_shop.brands (
    brand_id SERIAL PRIMARY KEY, /* Поля с такими типами данных автоматически увеличивают значения на единицу для каждой новой строки. */
    brand_name VARCHAR(50) NOT NULL, /*название бренда может содержать буквы и символы, ограничение в 50 символов достаточно для большинства названий */
    country_id INT REFERENCES car_shop.countries(country_id) /*свзяь с ключом из таблицы СТРАНЫ по id */
);

CREATE TABLE car_shop.car_models (
    model_id SERIAL PRIMARY KEY, /* Поля с такими типами данных автоматически увеличивают значения на единицу для каждой новой строки. */
    brand_id INT REFERENCES car_shop.brands(brand_id),
    model_name VARCHAR(100),/*название модели может содержать буквы и символы, ограничение в 100 символов достаточно для большинства названий */
    gasoline_consumption NUMERIC(3,1)
);

CREATE TABLE car_shop.model_colors (
    model_id INT REFERENCES car_shop.car_models(model_id),/*свзяь с ключом из таблицы модели по id */
    color_id INT REFERENCES car_shop.colors(color_id), /*свзяь с ключом из таблицы ЦВЕТА по id */
    PRIMARY KEY (model_id, color_id)
);
CREATE TABLE car_shop.sales (
    sale_id SERIAL PRIMARY KEY, /* Поля с такими типами данных автоматически увеличивают значения на единицу для каждой новой строки. */
    model_id INT REFERENCES car_shop.car_models(model_id),/*свзяь с ключом из таблицы модели по id */
    customer_id INT REFERENCES car_shop.customers(customer_id), /*свзяь с ключом из таблицы ПОКУПАТЕЛИ по id */
    sale_date DATE,/*по заданию только дата*/
    price NUMERIC(9,2), /*точное число*/
    discount INTEGER
);

INSERT INTO car_shop.customers (full_name, phone)
SELECT DISTINCT 
    person AS full_name,
    phone
FROM raw_data.sales
WHERE person IS NOT NULL
AND phone IS NOT NULL;

INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT 
    TRIM(SPLIT_PART(auto, ',', 2)) AS color
FROM raw_data.sales;

INSERT INTO car_shop.countries (country_name)
SELECT DISTINCT brand_origin
FROM raw_data.sales;

INSERT INTO car_shop.brands (brand_name, country_id)
SELECT 
    SPLIT_PART(auto, ' ', 1) AS brand,
    c.country_id
FROM raw_data.sales s
JOIN car_shop.countries c ON s.brand_origin = c.country_name;

INSERT INTO car_shop.car_models (brand_id, model_name, gasoline_consumption)
SELECT 
    b.brand_id,
    TRIM(SPLIT_PART(auto, ' ', 2)) AS model,
    CASE 
        WHEN s.gasoline_consumption IS NULL 
            OR TRIM(s.gasoline_consumption::text) = '' 
            OR s.gasoline_consumption = 'null' 
            OR s.gasoline_consumption = 'NULL' 
        THEN NULL
        ELSE TRIM(s.gasoline_consumption)::NUMERIC(3,1)
    END AS gasoline_consumption
FROM raw_data.sales s
JOIN car_shop.brands b ON SPLIT_PART(s.auto, ' ', 1) = b.brand_name;

INSERT INTO car_shop.model_colors (model_id, color_id)
SELECT 
    cm.model_id,
    c.color_id
FROM raw_data.sales s
JOIN car_shop.car_models cm ON TRIM(SPLIT_PART(s.auto, ' ', 2)) = cm.model_name
JOIN car_shop.colors c ON TRIM(SPLIT_PART(s.auto, ',', 2)) = c.color_name;

INSERT INTO car_shop.sales (model_id, customer_id, sale_date, price, discount)
SELECT 
    cm.model_id,
    cus.customer_id,
    s.date,
    s.price,
    s.discount
FROM raw_data.sales s
JOIN car_shop.car_models cm 
    ON cm.model_name = 
        TRIM(SPLIT_PART(s.auto, ' ', 2))
JOIN car_shop.customers cus 
    ON cus.full_name = s.person 
    AND cus.phone = s.phone
WHERE 
    TRIM(SPLIT_PART(s.auto, ' ', 2)) <> '';





-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.

SELECT
    (COUNT(CASE WHEN gasoline_consumption IS NULL THEN 1 END)::FLOAT / COUNT(*)) * 100 AS nulls_percentage_gasoline_consumption
FROM
    car_shop.car_models;

---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

SELECT
    b.brand_name,
    EXTRACT(YEAR FROM s.sale_date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM
    car_shop.brands b
JOIN
    car_shop.car_models cm ON b.brand_id = cm.brand_id
JOIN
    car_shop.sales s ON cm.model_id = s.model_id
GROUP BY
    b.brand_name,
    EXTRACT(YEAR FROM s.sale_date)
ORDER BY
    b.brand_name ASC,
    year ASC;



---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
SELECT
    EXTRACT(MONTH FROM s.sale_date) AS month,
    2022 AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)),2) AS price_avg
FROM car_shop.sales s
WHERE EXTRACT(YEAR FROM s.sale_date) = 2022
GROUP BY
    EXTRACT(MONTH FROM sale_date)
ORDER BY
    month ASC;




---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.
SELECT
    c.full_name AS person,
    STRING_AGG(b.brand_name || ' ' || cm.model_name, ', ') AS cars
FROM
    car_shop.customers c
JOIN
    car_shop.sales s ON c.customer_id = s.customer_id
JOIN
    car_shop.car_models cm ON s.model_id = cm.model_id
JOIN
    car_shop.brands b ON cm.brand_id = b.brand_id
GROUP BY
    c.full_name
ORDER BY
    c.full_name ASC;


---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.
SELECT
    c.country_name as brand_origin,
    MAX(s.price / (1 - s.discount / 100)) AS price_max,
    MIN(s.price / (1 - s.discount / 100)) AS price_min
from car_shop.countries c 
JOIN car_shop.brands b ON b.country_id = c.country_id
join CAR_SHOP.car_models cm on cm.brand_id = b.brand_id 
JOIN car_shop.sales s ON cm.model_id = s.model_id
GROUP BY
    c.country_name
ORDER BY
    c.country_name;


SELECT COUNT(*) AS persons_from_usa_count
FROM car_shop.customers c
WHERE c.phone LIKE '+1%';



