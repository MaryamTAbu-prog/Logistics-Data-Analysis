/*
 


USE [Logisticscapstoneproject];
GO

DECLARE @StartDate date = '20220101';
DECLARE @EndDateExclusive date = '20250101';

/* 1. REVENUE — total loads, revenue, and mean revenue per load. */
SELECT
    COUNT_BIG(*) AS total_loads,
    SUM(CAST(l.revenue AS decimal(19, 4))) AS total_revenue,
    AVG(CAST(l.revenue AS decimal(19, 4))) AS average_revenue_per_load
FROM dbo.loads AS l
WHERE l.load_date >= @StartDate
  AND l.load_date < @EndDateExclusive;

/* 2. COSTS — fuel purchases and spend; keep records with missing IDs. */
SELECT
    COUNT_BIG(*) AS fuel_purchases,
    SUM(CAST(fp.total_cost AS decimal(19, 4))) AS total_fuel_cost,
    AVG(CAST(fp.total_cost AS decimal(19, 4))) AS average_fuel_purchase
FROM dbo.fuel_purchases AS fp
WHERE fp.purchase_date >= @StartDate
  AND fp.purchase_date < @EndDateExclusive;

/* 3. EFFICIENCY — trip distance, consumed fuel, and recorded MPG. */
SELECT
    COUNT_BIG(*) AS total_trips,
    SUM(CAST(t.actual_distance_miles AS decimal(19, 4))) AS total_distance_miles,
    SUM(CAST(t.fuel_gallons_used AS decimal(19, 4))) AS total_fuel_used_gallons,
    AVG(CAST(t.average_mpg AS decimal(19, 6))) AS average_recorded_mpg,
    CAST(SUM(CAST(t.actual_distance_miles AS decimal(19, 6))) /
         NULLIF(SUM(CAST(t.fuel_gallons_used AS decimal(19, 6))), 0)
         AS decimal(19, 6)) AS calculated_weighted_mpg
FROM [dbo].[trips ] AS t
WHERE t.dispatch_date >= @StartDate
  AND t.dispatch_date < @EndDateExclusive;

/* 4. SERVICE — overall on-time EVENT rate includes all event types.
   Events with a NULL on_time_flag are excluded from the rate denominator and
   counted separately. First result is overall; second breaks down actual
   event_type values so pickup and delivery labels are not guessed. */
SELECT
    COUNT_BIG(*) AS event_rows,
    COUNT_BIG(d.on_time_flag) AS events_with_known_on_time_flag,
    SUM(CASE WHEN d.on_time_flag = 1 THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
        AS on_time_events,
    CAST(100.0 * SUM(CASE WHEN d.on_time_flag = 1 THEN 1.0 ELSE 0.0 END) /
         NULLIF(COUNT(d.on_time_flag), 0) AS decimal(9, 4)) AS overall_on_time_event_rate_pct,
    SUM(CASE WHEN d.on_time_flag IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
        AS events_missing_on_time_flag
FROM dbo.delivery AS d
CROSS APPLY (VALUES (TRY_CONVERT(datetime2, NULLIF(LTRIM(RTRIM(d.actual_datetime)), N''), 126))) AS parsed(actual_dt)
WHERE parsed.actual_dt >= @StartDate
  AND parsed.actual_dt < @EndDateExclusive;

SELECT
    d.event_type,
    COUNT_BIG(*) AS event_rows,
    COUNT_BIG(d.on_time_flag) AS events_with_known_on_time_flag,
    CAST(100.0 * SUM(CASE WHEN d.on_time_flag = 1 THEN 1.0 ELSE 0.0 END) /
         NULLIF(COUNT(d.on_time_flag), 0) AS decimal(9, 4)) AS on_time_event_rate_pct
FROM dbo.delivery AS d
CROSS APPLY (VALUES (TRY_CONVERT(datetime2, NULLIF(LTRIM(RTRIM(d.actual_datetime)), N''), 126))) AS parsed(actual_dt)
WHERE parsed.actual_dt >= @StartDate
  AND parsed.actual_dt < @EndDateExclusive
GROUP BY d.event_type
ORDER BY d.event_type;

/* 5. SAFETY — incident counts, flags, and claims. A flag count counts rows
   where the bit is 1; NULL flags are reported separately as unknown. */
SELECT
    COUNT_BIG(*) AS safety_incidents,
    SUM(CASE WHEN s.preventable_flag = 1 THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
        AS preventable_incidents,
    SUM(CASE WHEN s.at_fault_flag = 1 THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
        AS at_fault_incidents,
    SUM(CASE WHEN s.injury_flag = 1 THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
        AS injury_incidents,
    SUM(CAST(s.claim_amount AS decimal(19, 4))) AS total_claim_amount,
    SUM(CASE WHEN s.preventable_flag IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
        AS incidents_missing_preventable_flag,
    SUM(CASE WHEN s.at_fault_flag IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
        AS incidents_missing_at_fault_flag,
    SUM(CASE WHEN s.injury_flag IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
        AS incidents_missing_injury_flag
FROM dbo.safety AS s
WHERE s.incident_date >= @StartDate
  AND s.incident_date < @EndDateExclusive;

/* 6. CUSTOMER REVENUE — use the documented customer_id relationship. */
SELECT TOP (20)
    c.customer_id,
    c.customer_name,
    COUNT_BIG(*) AS loads,
    SUM(CAST(l.revenue AS decimal(19, 4))) AS total_revenue,
    AVG(CAST(l.revenue AS decimal(19, 4))) AS average_revenue_per_load
FROM dbo.loads AS l
LEFT JOIN [dbo].[customer ] AS c ON c.customer_id = l.customer_id
WHERE l.load_date >= @StartDate
  AND l.load_date < @EndDateExclusive
GROUP BY c.customer_id, c.customer_name
ORDER BY total_revenue DESC;

/* 7A. TRUCK EFFICIENCY AND FUEL COST. The trip-level results include only
   trips assigned a truck; section 9 quantifies missing IDs. Fuel costs are
   summed from purchase rows linked by trip_id, preserving all linked fuel
   purchases, including purchases whose own truck_id is missing. */
WITH fuel_by_trip AS (
    SELECT fp.trip_id, SUM(CAST(fp.total_cost AS decimal(19, 4))) AS fuel_cost
    FROM dbo.fuel_purchases AS fp
    WHERE fp.purchase_date >= @StartDate AND fp.purchase_date < @EndDateExclusive
    GROUP BY fp.trip_id
)
SELECT
    t.truck_id,
    COUNT_BIG(*) AS trips,
    SUM(CAST(t.actual_distance_miles AS decimal(19, 4))) AS distance_miles,
    SUM(CAST(t.fuel_gallons_used AS decimal(19, 4))) AS fuel_gallons,
    AVG(CAST(t.average_mpg AS decimal(19, 6))) AS average_recorded_mpg,
    CAST(SUM(CAST(t.actual_distance_miles AS decimal(19, 6))) /
         NULLIF(SUM(CAST(t.fuel_gallons_used AS decimal(19, 6))), 0) AS decimal(19, 6))
         AS calculated_weighted_mpg,
    SUM(COALESCE(fbt.fuel_cost, 0)) AS linked_fuel_cost,
    CAST(SUM(COALESCE(fbt.fuel_cost, 0)) /
         NULLIF(SUM(CAST(t.actual_distance_miles AS decimal(19, 6))), 0) AS decimal(19, 6))
         AS linked_fuel_cost_per_mile
FROM [dbo].[trips ] AS t
LEFT JOIN fuel_by_trip AS fbt ON fbt.trip_id = t.trip_id
WHERE t.dispatch_date >= @StartDate
  AND t.dispatch_date < @EndDateExclusive
  AND NULLIF(LTRIM(RTRIM(t.truck_id)), N'') IS NOT NULL
GROUP BY t.truck_id
ORDER BY calculated_weighted_mpg DESC;

/* 7B. DRIVER efficiency and linked fuel cost, following the same definitions. */
WITH fuel_by_trip AS (
    SELECT fp.trip_id, SUM(CAST(fp.total_cost AS decimal(19, 4))) AS fuel_cost
    FROM dbo.fuel_purchases AS fp
    WHERE fp.purchase_date >= @StartDate AND fp.purchase_date < @EndDateExclusive
    GROUP BY fp.trip_id
)
SELECT
    t.driver_id,
    COUNT_BIG(*) AS trips,
    SUM(CAST(t.actual_distance_miles AS decimal(19, 4))) AS distance_miles,
    SUM(CAST(t.fuel_gallons_used AS decimal(19, 4))) AS fuel_gallons,
    AVG(CAST(t.average_mpg AS decimal(19, 6))) AS average_recorded_mpg,
    CAST(SUM(CAST(t.actual_distance_miles AS decimal(19, 6))) /
         NULLIF(SUM(CAST(t.fuel_gallons_used AS decimal(19, 6))), 0) AS decimal(19, 6))
         AS calculated_weighted_mpg,
    SUM(COALESCE(fbt.fuel_cost, 0)) AS linked_fuel_cost,
    CAST(SUM(COALESCE(fbt.fuel_cost, 0)) /
         NULLIF(SUM(CAST(t.actual_distance_miles AS decimal(19, 6))), 0) AS decimal(19, 6))
         AS linked_fuel_cost_per_mile
FROM [dbo].[trips ] AS t
LEFT JOIN fuel_by_trip AS fbt ON fbt.trip_id = t.trip_id
WHERE t.dispatch_date >= @StartDate
  AND t.dispatch_date < @EndDateExclusive
  AND NULLIF(LTRIM(RTRIM(t.driver_id)), N'') IS NOT NULL
GROUP BY t.driver_id
ORDER BY calculated_weighted_mpg DESC;

/* 7C. CUSTOMER and route efficiency/cost. This joins trips -> loads -> routes
   by shared IDs. Compare joined trip/load counts in section 9: if one load has
   multiple trip rows, each trip is counted (appropriate for trip efficiency),
   while revenue must remain a load-level measure from section 1/6. */
WITH fuel_by_trip AS (
    SELECT fp.trip_id, SUM(CAST(fp.total_cost AS decimal(19, 4))) AS fuel_cost
    FROM dbo.fuel_purchases AS fp
    WHERE fp.purchase_date >= @StartDate AND fp.purchase_date < @EndDateExclusive
    GROUP BY fp.trip_id
)
SELECT
    l.customer_id,
    c.customer_name,
    l.route_id,
    r.origin_city,
    r.origin_state,
    r.destination_city,
    r.destination_state,
    COUNT_BIG(*) AS trips,
    SUM(CAST(t.actual_distance_miles AS decimal(19, 4))) AS distance_miles,
    SUM(CAST(t.fuel_gallons_used AS decimal(19, 4))) AS fuel_gallons,
    AVG(CAST(t.average_mpg AS decimal(19, 6))) AS average_recorded_mpg,
    CAST(SUM(CAST(t.actual_distance_miles AS decimal(19, 6))) /
         NULLIF(SUM(CAST(t.fuel_gallons_used AS decimal(19, 6))), 0) AS decimal(19, 6))
         AS calculated_weighted_mpg,
    SUM(COALESCE(fbt.fuel_cost, 0)) AS linked_fuel_cost,
    CAST(SUM(COALESCE(fbt.fuel_cost, 0)) /
         NULLIF(SUM(CAST(t.actual_distance_miles AS decimal(19, 6))), 0) AS decimal(19, 6))
         AS linked_fuel_cost_per_mile
FROM [dbo].[trips ] AS t
INNER JOIN dbo.loads AS l ON l.load_id = t.load_id
LEFT JOIN [dbo].[customer ] AS c ON c.customer_id = l.customer_id
LEFT JOIN [dbo].[routes ] AS r ON r.route_id = l.route_id
LEFT JOIN fuel_by_trip AS fbt ON fbt.trip_id = t.trip_id
WHERE t.dispatch_date >= @StartDate
  AND t.dispatch_date < @EndDateExclusive
GROUP BY l.customer_id, c.customer_name, l.route_id,
         r.origin_city, r.origin_state, r.destination_city, r.destination_state
ORDER BY linked_fuel_cost_per_mile;

/* 8. POWER BI RECONCILIATION — actual values are calculated from source rows;
   target values below are user-supplied comparison checks, not hardcoded
   analytical outputs. Amount and rate differences are actual minus target. */
WITH actuals AS (
    SELECT N'Total loads' AS metric,
           CAST(COUNT_BIG(*) AS decimal(28, 6)) AS actual_value
    FROM dbo.loads WHERE load_date >= @StartDate AND load_date < @EndDateExclusive
    UNION ALL
    SELECT N'Total revenue', CAST(SUM(CAST(revenue AS decimal(19, 4))) AS decimal(28, 6))
    FROM dbo.loads WHERE load_date >= @StartDate AND load_date < @EndDateExclusive
    UNION ALL
    SELECT N'Average revenue per load', CAST(AVG(CAST(revenue AS decimal(19, 4))) AS decimal(28, 6))
    FROM dbo.loads WHERE load_date >= @StartDate AND load_date < @EndDateExclusive
    UNION ALL
    SELECT N'Fuel purchases', CAST(COUNT_BIG(*) AS decimal(28, 6))
    FROM dbo.fuel_purchases WHERE purchase_date >= @StartDate AND purchase_date < @EndDateExclusive
    UNION ALL
    SELECT N'Total fuel cost', CAST(SUM(CAST(total_cost AS decimal(19, 4))) AS decimal(28, 6))
    FROM dbo.fuel_purchases WHERE purchase_date >= @StartDate AND purchase_date < @EndDateExclusive
    UNION ALL
    SELECT N'Average fuel purchase', CAST(AVG(CAST(total_cost AS decimal(19, 4))) AS decimal(28, 6))
    FROM dbo.fuel_purchases WHERE purchase_date >= @StartDate AND purchase_date < @EndDateExclusive
    UNION ALL
    SELECT N'Total trips', CAST(COUNT_BIG(*) AS decimal(28, 6))
    FROM [dbo].[trips ] WHERE dispatch_date >= @StartDate AND dispatch_date < @EndDateExclusive
    UNION ALL
    SELECT N'Total distance miles', CAST(SUM(CAST(actual_distance_miles AS decimal(19, 4))) AS decimal(28, 6))
    FROM [dbo].[trips ] WHERE dispatch_date >= @StartDate AND dispatch_date < @EndDateExclusive
    UNION ALL
    SELECT N'Total fuel used gallons', CAST(SUM(CAST(fuel_gallons_used AS decimal(19, 4))) AS decimal(28, 6))
    FROM [dbo].[trips ] WHERE dispatch_date >= @StartDate AND dispatch_date < @EndDateExclusive
    UNION ALL
    SELECT N'Average recorded MPG', CAST(AVG(CAST(average_mpg AS decimal(19, 6))) AS decimal(28, 6))
    FROM [dbo].[trips ] WHERE dispatch_date >= @StartDate AND dispatch_date < @EndDateExclusive
    UNION ALL
    SELECT N'Overall on-time event rate percent',
           CAST(100.0 * SUM(CASE WHEN d.on_time_flag = 1 THEN 1.0 ELSE 0.0 END) /
                NULLIF(COUNT(d.on_time_flag), 0) AS decimal(28, 6))
    FROM dbo.delivery AS d
    CROSS APPLY (VALUES (TRY_CONVERT(datetime2, NULLIF(LTRIM(RTRIM(d.actual_datetime)), N''), 126))) AS p(actual_dt)
    WHERE p.actual_dt >= @StartDate AND p.actual_dt < @EndDateExclusive
    UNION ALL
    SELECT N'Safety incidents', CAST(COUNT_BIG(*) AS decimal(28, 6))
    FROM dbo.safety WHERE incident_date >= @StartDate AND incident_date < @EndDateExclusive
    UNION ALL
    SELECT N'Preventable incidents', CAST(SUM(CASE WHEN preventable_flag = 1 THEN 1 ELSE 0 END) AS decimal(28, 6))
    FROM dbo.safety WHERE incident_date >= @StartDate AND incident_date < @EndDateExclusive
    UNION ALL
    SELECT N'At-fault incidents', CAST(SUM(CASE WHEN at_fault_flag = 1 THEN 1 ELSE 0 END) AS decimal(28, 6))
    FROM dbo.safety WHERE incident_date >= @StartDate AND incident_date < @EndDateExclusive
    UNION ALL
    SELECT N'Injury incidents', CAST(SUM(CASE WHEN injury_flag = 1 THEN 1 ELSE 0 END) AS decimal(28, 6))
    FROM dbo.safety WHERE incident_date >= @StartDate AND incident_date < @EndDateExclusive
    UNION ALL
    SELECT N'Total claim amount', CAST(SUM(CAST(claim_amount AS decimal(19, 4))) AS decimal(28, 6))
    FROM dbo.safety WHERE incident_date >= @StartDate AND incident_date < @EndDateExclusive
), targets AS (
    SELECT * FROM (VALUES
        (N'Total loads', CAST(85410 AS decimal(28, 6))),
        (N'Total revenue', CAST(262525800.29 AS decimal(28, 6))),
        (N'Average revenue per load', CAST(3073.71 AS decimal(28, 6))),
        (N'Fuel purchases', CAST(196442 AS decimal(28, 6))),
        (N'Total fuel cost', CAST(95592992.04 AS decimal(28, 6))),
        (N'Average fuel purchase', CAST(486.62 AS decimal(28, 6))),
        (N'Total trips', CAST(85410 AS decimal(28, 6))),
        (N'Total distance miles', CAST(122159201 AS decimal(28, 6))),
        (N'Total fuel used gallons', CAST(18946280.10 AS decimal(28, 6))),
        (N'Average recorded MPG', CAST(6.50 AS decimal(28, 6))),
        (N'Overall on-time event rate percent', CAST(55.67 AS decimal(28, 6))),
        (N'Safety incidents', CAST(170 AS decimal(28, 6))),
        (N'Preventable incidents', CAST(64 AS decimal(28, 6))),
        (N'At-fault incidents', CAST(54 AS decimal(28, 6))),
        (N'Injury incidents', CAST(33 AS decimal(28, 6))),
        (N'Total claim amount', CAST(2653118.82 AS decimal(28, 6)))
    ) AS v(metric, target_value)
)
SELECT a.metric, a.actual_value, t.target_value,
       a.actual_value - t.target_value AS difference_actual_minus_target
FROM actuals AS a
INNER JOIN targets AS t ON t.metric = a.metric
ORDER BY a.metric;

/* 9. DATA QUALITY AND JOIN VALIDATION. These counts expose missing IDs and
   linkage issues without removing those records from sections 1-5/8 totals. */
SELECT N'Trips with missing truck_id' AS check_name, COUNT_BIG(*) AS affected_rows
FROM [dbo].[trips ]
WHERE dispatch_date >= @StartDate AND dispatch_date < @EndDateExclusive
  AND NULLIF(LTRIM(RTRIM(truck_id)), N'') IS NULL
UNION ALL
SELECT N'Trips with missing driver_id', COUNT_BIG(*)
FROM [dbo].[trips ]
WHERE dispatch_date >= @StartDate AND dispatch_date < @EndDateExclusive
  AND NULLIF(LTRIM(RTRIM(driver_id)), N'') IS NULL
UNION ALL
SELECT N'Fuel purchases with missing truck_id', COUNT_BIG(*)
FROM dbo.fuel_purchases
WHERE purchase_date >= @StartDate AND purchase_date < @EndDateExclusive
  AND NULLIF(LTRIM(RTRIM(truck_id)), N'') IS NULL
UNION ALL
SELECT N'Fuel purchases with missing driver_id', COUNT_BIG(*)
FROM dbo.fuel_purchases
WHERE purchase_date >= @StartDate AND purchase_date < @EndDateExclusive
  AND NULLIF(LTRIM(RTRIM(driver_id)), N'') IS NULL
UNION ALL
SELECT N'Fuel purchases with no matching trip_id', COUNT_BIG(*)
FROM dbo.fuel_purchases AS fp
WHERE fp.purchase_date >= @StartDate AND fp.purchase_date < @EndDateExclusive
  AND NOT EXISTS (SELECT 1 FROM [dbo].[trips ] AS t WHERE t.trip_id = fp.trip_id)
UNION ALL
SELECT N'Trips with no matching load_id', COUNT_BIG(*)
FROM [dbo].[trips ] AS t
WHERE t.dispatch_date >= @StartDate AND t.dispatch_date < @EndDateExclusive
  AND NOT EXISTS (SELECT 1 FROM dbo.loads AS l WHERE l.load_id = t.load_id)
UNION ALL
SELECT N'Loads with no matching customer_id', COUNT_BIG(*)
FROM dbo.loads AS l
WHERE l.load_date >= @StartDate AND l.load_date < @EndDateExclusive
  AND NOT EXISTS (SELECT 1 FROM [dbo].[customer ] AS c WHERE c.customer_id = l.customer_id)
UNION ALL
SELECT N'Loads with no matching route_id', COUNT_BIG(*)
FROM dbo.loads AS l
WHERE l.load_date >= @StartDate AND l.load_date < @EndDateExclusive
  AND NOT EXISTS (SELECT 1 FROM [dbo].[routes ] AS r WHERE r.route_id = l.route_id);

/* Delivery timestamp parse coverage across all rows, with failures split by
   blank vs nonblank. Only successfully parsed actual_datetime rows enter the
   reporting-period event-rate calculations above. */
SELECT
    COUNT_BIG(*) AS all_delivery_rows,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(actual_datetime)), N'') IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
        AS blank_actual_datetime_rows,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(actual_datetime)), N'') IS NOT NULL
              AND TRY_CONVERT(datetime2, LTRIM(RTRIM(actual_datetime)), 126) IS NULL
             THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END) AS unparsed_actual_datetime_rows
FROM dbo.delivery;

/* Check multiplicity before interpreting trip-to-load joins. */
SELECT TOP (20)
    load_id,
    COUNT_BIG(*) AS trip_rows_for_load
FROM [dbo].[trips ]
GROUP BY load_id
HAVING COUNT_BIG(*) > 1
ORDER BY trip_rows_for_load DESC, load_id;

/* Data availability: maintenance records were reported as not imported.
   truck_utilization_metrics contains maintenance-like summary columns, but
   they are intentionally not used here as a substitute for maintenance data. */
GO
