-- ============================================================
-- Финтех Аналитика: SQL-запросы для анализа кредитных карт
-- База данных: PostgreSQL
-- Описание: Аналитические запросы для анализа поведения
--           держателей кредитных карт и оценки рисков
-- ============================================================


-- ------------------------------------------------------------
-- 1. Средняя сумма транзакции по сегментам клиентов
--    Сегменты: Низкий / Средний / Высокий доход
-- ------------------------------------------------------------
WITH сегменты_клиентов AS (
    SELECT
        c.customer_id,
        c.income                                          AS доход,
        c.credit_limit                                    AS кредитный_лимит,
        -- Классификация по доходному сегменту
        CASE
            WHEN c.income < 40000  THEN 'Низкий доход'
            WHEN c.income < 80000  THEN 'Средний доход'
            ELSE                        'Высокий доход'
        END AS доходный_сегмент,
        -- Классификация по возрастной группе
        CASE
            WHEN c.age < 30 THEN '18-29'
            WHEN c.age < 45 THEN '30-44'
            WHEN c.age < 60 THEN '45-59'
            ELSE                  '60+'
        END AS возрастная_группа
    FROM customers c
),
статистика_транзакций AS (
    -- Агрегация транзакций по каждому клиенту
    SELECT
        t.customer_id,
        AVG(t.amount)   AS средняя_сумма_транзакции,
        SUM(t.amount)   AS суммарные_траты,
        COUNT(*)        AS количество_транзакций
    FROM transactions t
    GROUP BY t.customer_id
)
SELECT
    ск.доходный_сегмент,
    ск.возрастная_группа,
    COUNT(ск.customer_id)                          AS количество_клиентов,
    ROUND(AVG(ст.средняя_сумма_транзакции), 2)    AS средняя_сумма_тр,
    ROUND(AVG(ст.суммарные_траты), 2)             AS средние_суммарные_траты,
    ROUND(AVG(ст.количество_транзакций), 1)        AS среднее_кол_транзакций
FROM сегменты_клиентов ск
JOIN статистика_транзакций ст ON ск.customer_id = ст.customer_id
GROUP BY ск.доходный_сегмент, ск.возрастная_группа
ORDER BY
    -- Сортировка по доходному сегменту: Низкий → Средний → Высокий
    CASE ск.доходный_сегмент
        WHEN 'Низкий доход'   THEN 1
        WHEN 'Средний доход'  THEN 2
        WHEN 'Высокий доход'  THEN 3
    END,
    ск.возрастная_группа;


-- ------------------------------------------------------------
-- 2. Ежемесячная динамика трат за последние 12 месяцев
--    С расчётом темпа роста месяц к месяцу (MoM)
-- ------------------------------------------------------------
WITH ежемесячные_итоги AS (
    -- Агрегация транзакций по месяцам
    SELECT
        DATE_TRUNC('month', t.transaction_date)     AS месяц,
        COUNT(DISTINCT t.customer_id)               AS активных_клиентов,
        COUNT(*)                                    AS всего_транзакций,
        ROUND(SUM(t.amount), 2)                     AS суммарные_траты,
        ROUND(AVG(t.amount), 2)                     AS средняя_транзакция
    FROM transactions t
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY DATE_TRUNC('month', t.transaction_date)
),
динамика AS (
    -- Добавляем темп роста через LAG
    SELECT
        месяц,
        активных_клиентов,
        всего_транзакций,
        суммарные_траты,
        средняя_транзакция,
        LAG(суммарные_траты) OVER (ORDER BY месяц) AS траты_прошлого_месяца,
        -- Расчёт процентного изменения MoM
        ROUND(
            100.0 * (суммарные_траты - LAG(суммарные_траты) OVER (ORDER BY месяц))
            / NULLIF(LAG(суммарные_траты) OVER (ORDER BY месяц), 0),
            2
        ) AS темп_роста_mom_pct
    FROM ежемесячные_итоги
)
SELECT
    TO_CHAR(месяц, 'YYYY-MM')          AS месяц_год,
    активных_клиентов,
    всего_транзакций,
    суммарные_траты,
    средняя_транзакция,
    COALESCE(темп_роста_mom_pct, 0)    AS темп_роста_mom_pct
FROM динамика
ORDER BY месяц;


-- ------------------------------------------------------------
-- 3. Коэффициент использования кредитного лимита на клиента
--    Утилизация = суммарные_траты / кредитный_лимит
-- ------------------------------------------------------------
WITH траты_клиента AS (
    -- Суммарные траты за 12 месяцев
    SELECT
        t.customer_id,
        SUM(t.amount) AS суммарные_траты_12м
    FROM transactions t
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY t.customer_id
),
утилизация AS (
    -- Расчёт коэффициента и присвоение диапазона риска
    SELECT
        c.customer_id,
        c.credit_limit                                           AS кредитный_лимит,
        тк.суммарные_траты_12м,
        ROUND(тк.суммарные_траты_12м / NULLIF(c.credit_limit, 0), 4) AS коэф_утилизации,
        CASE
            WHEN тк.суммарные_траты_12м / NULLIF(c.credit_limit, 0) < 0.30 THEN 'Низкий (< 30%)'
            WHEN тк.суммарные_траты_12м / NULLIF(c.credit_limit, 0) < 0.60 THEN 'Умеренный (30-60%)'
            WHEN тк.суммарные_траты_12м / NULLIF(c.credit_limit, 0) < 0.80 THEN 'Высокий (60-80%)'
            ELSE                                                               'Критический (> 80%)'
        END AS диапазон_утилизации
    FROM customers c
    JOIN траты_клиента тк ON c.customer_id = тк.customer_id
)
SELECT
    customer_id,
    кредитный_лимит,
    суммарные_траты_12м,
    коэф_утилизации,
    диапазон_утилизации
FROM утилизация
ORDER BY коэф_утилизации DESC;


-- ------------------------------------------------------------
-- 4. Клиенты в зоне риска (близко к лимиту или за лимитом)
--    Для проактивного контакта со стороны риск-команды
-- ------------------------------------------------------------
WITH ежемесячные_траты AS (
    -- Траты каждого клиента в разрезе месяца
    SELECT
        t.customer_id,
        DATE_TRUNC('month', t.transaction_date) AS месяц,
        SUM(t.amount)                           AS траты_за_месяц
    FROM transactions t
    GROUP BY t.customer_id, DATE_TRUNC('month', t.transaction_date)
),
риски_клиентов AS (
    -- Вычисляем средние и пиковые показатели + количество «опасных» месяцев
    SELECT
        ет.customer_id,
        c.income                                                            AS доход,
        c.credit_limit                                                      AS кредитный_лимит,
        c.months_on_book                                                    AS месяцев_в_банке,
        ROUND(AVG(ет.траты_за_месяц), 2)                                   AS средние_траты_в_мес,
        ROUND(MAX(ет.траты_за_месяц), 2)                                   AS пиковые_траты_в_мес,
        ROUND(AVG(ет.траты_за_месяц) / NULLIF(c.credit_limit, 0), 4)      AS средняя_утилизация,
        ROUND(MAX(ет.траты_за_месяц) / NULLIF(c.credit_limit, 0), 4)      AS пиковая_утилизация,
        -- Сколько месяцев подряд утилизация превышала 80%
        COUNT(CASE WHEN ет.траты_за_месяц / c.credit_limit > 0.8 THEN 1 END) AS месяцев_свыше_80pct
    FROM ежемесячные_траты ет
    JOIN customers c ON ет.customer_id = c.customer_id
    GROUP BY ет.customer_id, c.income, c.credit_limit, c.months_on_book
)
SELECT
    customer_id,
    доход,
    кредитный_лимит,
    месяцев_в_банке,
    средние_траты_в_мес,
    пиковые_траты_в_мес,
    ROUND(средняя_утилизация * 100, 1)  AS средняя_утилизация_pct,
    ROUND(пиковая_утилизация * 100, 1)  AS пиковая_утилизация_pct,
    месяцев_свыше_80pct,
    -- Присвоение итогового флага риска
    CASE
        WHEN средняя_утилизация > 0.80                           THEN 'ВЫСОКИЙ РИСК'
        WHEN средняя_утилизация > 0.60 OR месяцев_свыше_80pct >= 3 THEN 'СРЕДНИЙ РИСК'
        ELSE                                                          'НИЗКИЙ РИСК'
    END AS флаг_риска
FROM риски_клиентов
WHERE средняя_утилизация > 0.60
   OR месяцев_свыше_80pct >= 2
ORDER BY средняя_утилизация DESC, месяцев_свыше_80pct DESC;


-- ------------------------------------------------------------
-- 5. RFM-анализ клиентов
--    R = Recency (давность), F = Frequency (частота), M = Monetary (сумма)
--    Сегментация клиентов по ценности и активности
-- ------------------------------------------------------------
WITH rfm_база AS (
    -- Базовые показатели для каждого клиента за 12 месяцев
    SELECT
        t.customer_id,
        MAX(t.transaction_date)                                              AS дата_последней_тр,
        CURRENT_DATE - MAX(t.transaction_date)::date                        AS дней_с_последней_тр,
        COUNT(*)                                                             AS частота,
        ROUND(SUM(t.amount), 2)                                              AS денежная_ценность,
        ROUND(AVG(t.amount), 2)                                              AS средняя_сумма,
        COUNT(DISTINCT t.category)                                           AS разных_категорий,
        COUNT(DISTINCT DATE_TRUNC('month', t.transaction_date))              AS активных_месяцев
    FROM transactions t
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY t.customer_id
),
rfm_оценки AS (
    -- Присваиваем оценки от 1 до 5 по каждому измерению RFM
    SELECT
        *,
        NTILE(5) OVER (ORDER BY дней_с_последней_тр ASC)  AS оценка_r,  -- меньше дней = лучше
        NTILE(5) OVER (ORDER BY частота DESC)              AS оценка_f,  -- больше транзакций = лучше
        NTILE(5) OVER (ORDER BY денежная_ценность DESC)    AS оценка_m   -- больше суммы = лучше
    FROM rfm_база
),
rfm_итог AS (
    -- Итоговый RFM-балл и код сегмента
    SELECT
        *,
        (оценка_r + оценка_f + оценка_m)                           AS rfm_итого,
        CONCAT(оценка_r::text, оценка_f::text, оценка_m::text)     AS rfm_код
    FROM rfm_оценки
)
SELECT
    ri.customer_id,
    c.income                     AS доход,
    c.credit_limit               AS кредитный_лимит,
    ri.дней_с_последней_тр,
    ri.частота,
    ri.денежная_ценность,
    ri.средняя_сумма,
    ri.разных_категорий,
    ri.активных_месяцев,
    ri.оценка_r,
    ri.оценка_f,
    ri.оценка_m,
    ri.rfm_итого,
    ri.rfm_код,
    -- Метка RFM-сегмента для маркетинга
    CASE
        WHEN ri.rfm_итого >= 13 THEN 'Чемпионы'
        WHEN ri.rfm_итого >= 10 THEN 'Лояльные клиенты'
        WHEN ri.rfm_итого >= 7  THEN 'Потенциально лояльные'
        WHEN ri.rfm_итого >= 5  THEN 'В зоне риска'
        ELSE                        'Утраченные'
    END AS rfm_сегмент
FROM rfm_итог ri
JOIN customers c ON ri.customer_id = c.customer_id
ORDER BY ri.rfm_итого DESC, ri.денежная_ценность DESC;
