-- ============================================================
-- E-commerce Аналитика: SQL-запросы для промышленной выгрузки
-- База данных: PostgreSQL
-- Описание: CTE-запросы, повторяющие анализ из ноутбука
-- ============================================================


-- ------------------------------------------------------------
-- 1. ЕЖЕМЕСЯЧНАЯ ДИНАМИКА ВЫРУЧКИ С ПРИРОСТОМ MoM
-- ------------------------------------------------------------
WITH ежемесячная_выручка AS (
    SELECT
        DATE_TRUNC('month', дата_заказа)::DATE          AS месяц,
        COUNT(DISTINCT order_id)                         AS кол_заказов,
        COUNT(DISTINCT customer_id)                      AS уникальных_клиентов,
        ROUND(SUM(сумма_заказа)::NUMERIC, 2)             AS выручка,
        ROUND(AVG(сумма_заказа)::NUMERIC, 2)             AS средний_чек
    FROM orders
    WHERE статус != 'отменён'
    GROUP BY 1
),
выручка_с_лагом AS (
    SELECT
        месяц,
        кол_заказов,
        уникальных_клиентов,
        выручка,
        средний_чек,
        LAG(выручка) OVER (ORDER BY месяц)               AS выручка_пред_месяца
    FROM ежемесячная_выручка
)
SELECT
    месяц,
    кол_заказов,
    уникальных_клиентов,
    выручка,
    средний_чек,
    -- Прирост выручки месяц к месяцу
    ROUND(
        100.0 * (выручка - выручка_пред_месяца) / NULLIF(выручка_пред_месяца, 0),
        2
    )                                                    AS прирост_mom_pct
FROM выручка_с_лагом
ORDER BY месяц;


-- ------------------------------------------------------------
-- 2. ТОП КЛИЕНТОВ ПО ПОЖИЗНЕННОЙ ЦЕННОСТИ (LTV)
-- ------------------------------------------------------------
WITH заказы_клиентов AS (
    SELECT
        o.customer_id,
        c.канал_привлечения,
        c.дата_регистрации,
        COUNT(DISTINCT o.order_id)                       AS всего_заказов,
        ROUND(SUM(o.сумма_заказа)::NUMERIC, 2)           AS суммарная_выручка,
        MIN(o.дата_заказа)                               AS первый_заказ,
        MAX(o.дата_заказа)                               AS последний_заказ,
        ROUND(AVG(o.сумма_заказа)::NUMERIC, 2)           AS средний_чек,
        MAX(o.дата_заказа) - MIN(o.дата_заказа)          AS дней_активности
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.статус = 'выполнен'
    GROUP BY o.customer_id, c.канал_привлечения, c.дата_регистрации
),
ltv_ранжирование AS (
    SELECT
        *,
        -- Аннуализированный LTV
        ROUND(суммарная_выручка * (365.0 / NULLIF(дней_активности, 0)), 2) AS ltv_годовой,
        NTILE(10) OVER (ORDER BY суммарная_выручка DESC)                    AS ltv_дециль,
        RANK() OVER (ORDER BY суммарная_выручка DESC)                       AS ltv_ранг
    FROM заказы_клиентов
)
SELECT
    ltv_ранг,
    customer_id,
    канал_привлечения,
    всего_заказов,
    суммарная_выручка,
    средний_чек,
    ltv_годовой,
    дней_активности,
    ltv_дециль
FROM ltv_ранжирование
ORDER BY ltv_ранг
LIMIT 100;


-- ------------------------------------------------------------
-- 3. РАСЧЁТ RFM-ОЦЕНОК
-- ------------------------------------------------------------
WITH дата_среза AS (
    SELECT MAX(дата_заказа) + INTERVAL '1 day' AS реф_дата
    FROM orders WHERE статус = 'выполнен'
),
rfm_база AS (
    SELECT
        o.customer_id,
        EXTRACT(DAY FROM (s.реф_дата - MAX(o.дата_заказа)))::INT AS давность_дней,
        COUNT(DISTINCT o.order_id)                                AS частота,
        ROUND(SUM(o.сумма_заказа)::NUMERIC, 2)                   AS монетизация
    FROM orders o
    CROSS JOIN дата_среза s
    WHERE o.статус = 'выполнен'
    GROUP BY o.customer_id, s.реф_дата
),
rfm_оценки AS (
    SELECT
        customer_id,
        давность_дней,
        частота,
        монетизация,
        -- R-балл: меньше давность = лучше (оценка 5)
        CASE
            WHEN давность_дней <= PERCENTILE_CONT(0.20) WITHIN GROUP (ORDER BY давность_дней) OVER () THEN 5
            WHEN давность_дней <= PERCENTILE_CONT(0.40) WITHIN GROUP (ORDER BY давность_дней) OVER () THEN 4
            WHEN давность_дней <= PERCENTILE_CONT(0.60) WITHIN GROUP (ORDER BY давность_дней) OVER () THEN 3
            WHEN давность_дней <= PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY давность_дней) OVER () THEN 2
            ELSE 1
        END                                                       AS r_балл,
        -- F-балл: больше частота = лучше
        NTILE(5) OVER (ORDER BY частота ASC)                      AS f_балл,
        -- M-балл: больше монетизация = лучше
        NTILE(5) OVER (ORDER BY монетизация ASC)                  AS m_балл
    FROM rfm_база
),
rfm_сегменты AS (
    SELECT
        customer_id,
        давность_дней,
        частота,
        монетизация,
        r_балл, f_балл, m_балл,
        (r_балл + f_балл + m_балл)                                AS rfm_сумма,
        CASE
            WHEN r_балл >= 4 AND f_балл >= 4 AND m_балл >= 4     THEN 'Чемпионы'
            WHEN r_балл >= 3 AND f_балл >= 3                      THEN 'Лояльные клиенты'
            WHEN r_балл >= 4 AND f_балл <= 2                      THEN 'Новые клиенты'
            WHEN r_балл >= 3 AND m_балл >= 3                      THEN 'Потенциально лояльные'
            WHEN r_балл <= 2 AND f_балл >= 4                      THEN 'Группа риска'
            WHEN r_балл <= 2 AND f_балл >= 2                      THEN 'Нельзя потерять'
            WHEN r_балл <= 2 AND f_балл <= 2                      THEN 'Потерянные'
            ELSE                                                       'Спящие'
        END                                                        AS сегмент
    FROM rfm_оценки
)
SELECT
    сегмент,
    COUNT(customer_id)                                            AS клиентов,
    ROUND(AVG(давность_дней), 1)                                  AS ср_давность_дней,
    ROUND(AVG(частота), 2)                                        AS ср_частота,
    ROUND(AVG(монетизация), 2)                                    AS ср_монетизация,
    ROUND(SUM(монетизация), 2)                                    AS суммарная_выручка,
    ROUND(100.0 * COUNT(customer_id) / SUM(COUNT(customer_id)) OVER (), 2) AS доля_клиентов_pct,
    ROUND(100.0 * SUM(монетизация) / SUM(SUM(монетизация)) OVER (), 2)    AS доля_выручки_pct
FROM rfm_сегменты
GROUP BY сегмент
ORDER BY суммарная_выручка DESC;


-- ------------------------------------------------------------
-- 4. МАТРИЦА КОГОРТНОГО УДЕРЖАНИЯ
-- ------------------------------------------------------------
WITH когорты AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(дата_заказа))::DATE      AS когорта_месяц
    FROM orders
    WHERE статус = 'выполнен'
    GROUP BY customer_id
),
активность AS (
    SELECT
        o.customer_id,
        к.когорта_месяц,
        DATE_TRUNC('month', o.дата_заказа)::DATE         AS месяц_активности,
        EXTRACT(MONTH FROM AGE(
            DATE_TRUNC('month', o.дата_заказа),
            к.когорта_месяц
        ))::INT                                          AS номер_периода
    FROM orders o
    JOIN когорты к ON o.customer_id = к.customer_id
    WHERE o.статус = 'выполнен'
),
размер_когорт AS (
    SELECT когорта_месяц, COUNT(DISTINCT customer_id) AS размер
    FROM когорты GROUP BY когорта_месяц
),
удержание AS (
    SELECT
        а.когорта_месяц,
        а.номер_периода,
        COUNT(DISTINCT а.customer_id)                    AS удержано_клиентов
    FROM активность а
    GROUP BY а.когорта_месяц, а.номер_периода
)
SELECT
    у.когорта_месяц,
    р.размер                                             AS размер_когорты,
    у.номер_периода,
    у.удержано_клиентов,
    -- Коэффициент удержания в процентах
    ROUND(100.0 * у.удержано_клиентов / р.размер, 2)    AS retention_pct
FROM удержание у
JOIN размер_когорт р ON у.когорта_месяц = р.когорта_месяц
WHERE у.номер_периода <= 6
ORDER BY у.когорта_месяц, у.номер_периода;


-- ------------------------------------------------------------
-- 5. ЭФФЕКТИВНОСТЬ КАТЕГОРИЙ ТОВАРОВ
-- ------------------------------------------------------------
WITH метрики_категорий AS (
    SELECT
        категория,
        COUNT(DISTINCT order_id)                             AS кол_заказов,
        COUNT(DISTINCT customer_id)                          AS уникальных_покупателей,
        ROUND(SUM(сумма_заказа)::NUMERIC, 2)                 AS выручка,
        ROUND(AVG(сумма_заказа)::NUMERIC, 2)                 AS средний_чек
    FROM orders
    WHERE статус = 'выполнен'
    GROUP BY категория
),
категории_ранж AS (
    SELECT
        *,
        RANK() OVER (ORDER BY выручка DESC)                  AS ранг_по_выручке,
        ROUND(100.0 * выручка / SUM(выручка) OVER (), 2)    AS доля_выручки_pct,
        -- Накопленный итог для Парето-анализа
        SUM(выручка) OVER (ORDER BY выручка DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS накопл_выручка
    FROM метрики_категорий
)
SELECT
    ранг_по_выручке,
    категория,
    кол_заказов,
    уникальных_покупателей,
    выручка,
    средний_чек,
    доля_выручки_pct,
    -- Накопленный % для Парето (80/20 анализ)
    ROUND(100.0 * накопл_выручка / SUM(выручка) OVER (), 2) AS накопл_доля_pct
FROM категории_ранж
ORDER BY ранг_по_выручке;
