# E-commerce Sales Analytics: RFM Segmentation & LTV Optimization

## Business Problem

Over the past two quarters, repeat purchase rates have declined by **23%**, directly impacting Customer Lifetime Value (LTV) and overall revenue sustainability. The business needs to understand *which* customer segments are churning, *why* high-value customers are not returning, and *what* revenue can be expected in the coming months to inform marketing budget allocation.

---

## Hypotheses

1. **H1 — RFM-based segmentation reveals a concentrated revenue risk**: The top 20% of customers (Champions + Loyal) account for more than 60% of total revenue, making churn in this segment disproportionately damaging.
2. **H2 — Average Order Value differs significantly between one-time and repeat buyers**: Repeat customers place orders with a statistically significantly higher AOV than first-time buyers (tested via two-sample t-test, α = 0.05).
3. **H3 — Early cohort retention (Month 1 → Month 2) is the strongest predictor of 6-month LTV**: Customers retained through their second purchase month generate at least 3× the LTV of those who churn after the first order.

---

## Key Findings

1. **Champions segment (top RFM) represents ~18% of customers but drives ~54% of revenue** — targeted retention campaigns for this group have the highest ROI potential.
2. **Repeat buyers show a 38% higher Average Order Value** compared to one-time purchasers, confirming H2 and validating investment in loyalty/re-engagement programs.
3. **Linear regression predicts next-month revenue with R² ≈ 0.91**, indicating strong seasonal and trend signals that can guide inventory and ad-spend planning with reasonable confidence.

---

## Stakeholders

| Role | Interest |
|---|---|
| Chief Marketing Officer | Optimize CAC, improve retention campaigns |
| Head of Product | Understand which categories drive repeat purchases |
| Finance / CFO | Revenue forecast accuracy, LTV-to-CAC ratio |
| CRM / Retention Team | Actionable RFM segments for targeted outreach |
| Data Engineering | Pipeline design for recurring monthly refresh |

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
