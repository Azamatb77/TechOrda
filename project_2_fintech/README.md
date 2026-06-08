# Fintech Analytics: Credit Card Spending Behavior & Prediction

## Business Problem

Financial institutions face a critical challenge in optimizing credit limits for cardholders. Setting limits too low results in customer dissatisfaction and lost revenue, while setting them too high increases default risk and capital exposure. This project analyzes credit card holder behavior, spending patterns, and creditworthiness to build a predictive model for next-month spending — enabling data-driven credit limit optimization decisions.

**Goal:** Predict next month's customer spending using behavioral and demographic features to help Risk and Product teams make informed decisions about credit limit adjustments.

---

## Key Hypotheses

1. **Income drives spending**: High-income customers (top quartile) spend significantly more per month than low-income customers (bottom quartile), making income the strongest predictor in a linear regression model.
2. **Utilization predicts risk**: Customers with credit utilization above 80% are more likely to miss payments, making utilization rate a reliable early-warning signal for the risk team.
3. **Spending patterns are seasonal**: Monthly transaction volumes show a consistent spike in Q4 (October–December) due to holiday spending, which should be factored into dynamic credit limit adjustments.

---

## Stakeholders

| Stakeholder | Role | Interest |
|---|---|---|
| **Risk Manager** | Credit Risk Department | Identify high-risk customers, set appropriate credit limits, reduce default rates |
| **Product Manager** | Credit Card Products | Understand spending behavior to design targeted offers, loyalty programs, and limit upgrade campaigns |

---

## Top 3 Findings

1. **Income is the strongest predictor of monthly spending** (correlation ~0.72). Customers earning above $80K spend 2.3x more on average than those earning below $40K. The linear regression model achieves R² ≈ 0.68–0.72, confirming income, credit limit, and transaction count as reliable predictors.
2. **~18% of customers are in the high-risk segment** (utilization > 70%). These customers show a pattern of maxing out their cards repeatedly — a clear signal for proactive credit counseling or limit review before default occurs.
3. **Grocery and travel categories dominate spending** (combined ~55% of total transaction volume). Targeted cashback offers in these categories would maximize customer engagement with minimal cost.

---

## Technologies Used

| Technology | Purpose |
|---|---|
| Python 3.11 | Core language |
| pandas 2.1.4 | Data manipulation |
| numpy 1.26.2 | Numerical computing |
| matplotlib 3.8.2 | Static visualizations |
| seaborn 0.13.0 | Statistical plots |
| plotly 5.18.0 | Interactive charts |
| scikit-learn 1.3.2 | Linear regression, metrics |
| scipy 1.11.4 | Hypothesis testing (Mann-Whitney U) |
| Jupyter 1.0.0 | Interactive analysis environment |
| SQL (PostgreSQL syntax) | Data extraction queries with CTEs and window functions |

---

## Project Structure

```
project_2_fintech/
├── README.md            # Project overview, findings, and documentation
├── analysis.ipynb       # Main Jupyter notebook with full analysis pipeline
├── queries.sql          # SQL queries for data extraction and aggregation
├── requirements.txt     # Python dependencies
└── LICENSE              # MIT License
```

### Notebook Sections (`analysis.ipynb`)

1. Business Problem Statement
2. Synthetic Data Generation (simulating DB extraction, ~3000 customers)
3. Data Preprocessing (IQR outlier removal, null handling, type casting)
4. Exploratory Data Analysis (distributions, correlations, category breakdown, monthly trends)
5. Key Business Metrics (utilization rate, risk segmentation)
6. Linear Regression Model (predict next-month spending; R² and MAE reported)
7. Hypothesis Testing (Mann-Whitney U: high-income vs low-income spending)
8. Visualization Summary
9. Business Recommendations for Risk Management

---

## How to Run

```bash
# Install dependencies
pip install -r requirements.txt

# Launch the notebook
jupyter notebook analysis.ipynb
```

---

## License

MIT License — see [LICENSE](LICENSE) for details.
