# Logistics Performance Analysis | SQL & Power BI

## Project Overview

How can a logistics business understand its revenue, control fuel expenditure, improve delivery reliability, and strengthen road safety?

This project analyzes logistics data covering January 2022 to December 2024 to examine financial performance, fuel efficiency, delivery timeliness, and safety incidents. I used SQL Server to query and analyze the data and Power BI to build an interactive dashboard for communicating the findings.

## Business Objectives

- Analyze recorded revenue and fuel expenditure.
- Examine truck fuel efficiency using recorded miles-per-gallon figures.
- Evaluate timeliness across pickup and delivery events.
- Assess preventable safety incidents.
- Identify areas that warrant further operational investigation.

## Tools & Skills

- **SQL Server:** Data querying, aggregation, date filtering, and analysis.
- **Power BI:** KPI cards, charts, dashboard design, and data visualization.
- **Data analysis:** Interpreting operational metrics and communicating business findings.

## Key Findings

| Metric | Result |
|---|---:|
| Total recorded revenue | $262,525,800.29 |
| Total loads | 85,410 |
| Total fuel expenditure | $95,592,992.04 |
| Average recorded fuel efficiency | 6.50 MPG |
| Overall on-time event rate | 55.67% |
| Total safety incidents | 170 |
| Preventable safety incidents | 64 |

### What the Results Suggest

- **Delivery reliability:** The overall on-time event rate was 55.67%. This measure includes both pickup and delivery events, so the two event types should also be examined separately.
- **Fuel expenditure:** Recorded fuel purchases totalled approximately $95.59 million, making fuel a major area for cost monitoring.
- **Fuel efficiency:** Average recorded fuel efficiency was 6.50 MPG. Further analysis by truck can help investigate differences in performance.
- **Safety:** 64 of the 170 recorded safety incidents were marked as preventable, highlighting an area for further safety review.

## Recommendations

1. Investigate late pickup and delivery events separately to identify where delays occur.
2. Monitor fuel expenditure over time and investigate unusual changes in spending.
3. Compare truck fuel efficiency and review vehicles with consistently lower recorded MPG.
4. Review preventable safety incidents to identify recurring patterns and opportunities for prevention.

These recommendations identify areas for further investigation; the analysis does not establish the causes of delays, fuel costs, or safety incidents on its own.

## Project Files

- **SQL analysis:** `LOGISTIC CAPSTONE ANALYSIS SQL2.sql`
- **Power BI dashboard:** `capstone.pbix`

## Conclusion

This project demonstrates the use of SQL Server and Power BI to transform logistics data into measurable performance indicators and business-focused insights. It highlights how data analysis can support decisions about costs, operational efficiency, delivery reliability, and safety.
