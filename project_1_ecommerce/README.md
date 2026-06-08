# E-commerce Sales Analytics: RFM Segmentation & LTV Optimization

## Business Problem

Over the past two quarters, repeat purchase rates have declined by **23%**, directly impacting Customer Lifetime Value (LTV) and overall revenue sustainability. The business needs to understand *which* customer segments are churning, *why* high-value customers are not returning, and *what* revenue can be expected in the coming months to inform marketing budget allocation.

---

## Key Hypotheses

1. **Hypothesis 1 (RFM & LTV):** Customers in the "Champions" RFM segment have a significantly higher Lifetime Value (LTV) than customers in the "At-Risk" segment, and targeted re-engagement campaigns can recover at least 15% of churned high-value customers.

2. **Hypothesis 2 (Order Value):** Customers acquired through paid channels (higher CAC) have a lower average order value than organically acquired customers, making paid acquisition unprofitable in the long run.

3. **Hypothesis 3 (Churn Timing):** The majority of customer churn occurs within the first 90 days of the first purchase, suggesting that early onboarding and engagement programs could significantly reduce overall churn rates.

---

## Top 3 Findings

1. **Champions segment (top 20% of customers) generates ~65% of total revenue.** Retaining this segment through loyalty programs and personalized offers is the highest-ROI initiative available.

2. **Average churn occurs at day 73 post first purchase.** Customers who do not make a second purchase within 90 days have a 78% probability of never returning, making the 0–90 day window critical for retention campaigns.

3. **Linear regression model predicts next-month revenue with RMSE < 8% of mean monthly revenue.** Recency and frequency features are the strongest predictors, confirming that RFM-based targeting directly impacts forecasted revenue.

---

## Stakeholders

| Stakeholder | Role | Interest |
|---|---|---|
| Head of Marketing | Primary | Customer segmentation, CAC optimization |
| Product Manager | Primary | Retention features, churn reduction |
| CEO / CFO | Secondary | Revenue forecasting, LTV trends |
| CRM / Retention Team | Supporting | Actionable RFM segments for targeted outreach |
| Data Engineering Team | Supporting | Data pipeline and query optimization |

---

## Technologies Used

| Tool | Purpose |
|---|---|
| Python 3.11 | Core analysis language |
| pandas 2.1.4 | Data manipulation and aggregation |
| numpy 1.26.2 | Numerical operations |
| matplotlib 3.8.2 | Base charting |
| seaborn 0.13.0 | Statistical visualizations |
| plotly 5.18.0 | Interactive charts |
| scikit-learn 1.3.2 | Linear regression, preprocessing |
| scipy 1.11.4 | Statistical hypothesis testing |
| Jupyter 1.0.0 | Interactive notebook environment |
| SQL (PostgreSQL syntax) | Upstream data extraction queries |

---

## Project Structure

```
project_1_ecommerce/
├── analysis.ipynb       # Main analysis notebook (self-contained, generates synthetic data)
├── queries.sql          # SQL queries for production data extraction
├── requirements.txt     # Pinned Python dependencies
├── README.md            # This file
└── LICENSE              # MIT License
```

---

## How to Run

### 1. Set up the environment

```bash
cd /home/user/TechOrda/project_1_ecommerce
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Launch Jupyter

```bash
jupyter notebook analysis.ipynb
```

### 3. Run all cells

Use **Kernel → Restart & Run All** to execute the full notebook end-to-end.

The notebook is **fully self-contained** — it generates ~5,000 synthetic orders across 500 customers and 12 months internally. No external data files are required.

---

## SQL Queries

`queries.sql` contains production-ready CTE-based queries (PostgreSQL syntax) that mirror the analysis performed in the notebook:

- Monthly revenue trends with MoM growth
- Top customers ranked by Lifetime Value
- RFM score calculation using window functions
- Cohort retention matrix
- Product category performance with contribution %

These queries are intended to run against a transactional database and feed the same pipeline the notebook demonstrates on synthetic data.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
