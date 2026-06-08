# Marketing Analytics: Ad Channel ROI & Conversion Funnel Analysis

## Business Problem

Marketing budgets are frequently wasted on ineffective channels due to a lack of data-driven decision making. Without rigorous attribution and ROI measurement, companies over-invest in channels that generate impressions but not revenue, while under-investing in channels that drive actual conversions. This project analyzes advertising channel effectiveness, conversion funnel performance, and predicts ad budget ROI to enable smarter budget allocation.

## Key Hypotheses

1. **H1:** Google Ads generates a statistically significantly higher ROI than Facebook Ads, justifying a larger budget share.
2. **H2:** There is a strong positive linear relationship between ad spend and revenue — budget alone can predict revenue with R² > 0.7.
3. **H3:** Email marketing has the lowest Cost per Acquisition (CAC) among all channels, making it the most cost-efficient channel for retention campaigns.

## Stakeholders

| Stakeholder | Role | Primary Interest |
|---|---|---|
| CMO | Chief Marketing Officer | Overall budget efficiency, channel mix strategy |
| Performance Marketer | Campaign Manager | Channel-level ROI, CAC, conversion rates |

## Top 3 Findings

1. **Google Ads and Email deliver the highest ROI** — Google Ads averages ~120% ROI while Email marketing achieves ~140% ROI despite lower absolute spend, indicating email is underutilized.
2. **The biggest conversion drop occurs between Click and Conversion** — only ~8–12% of clicks convert to paying customers across all channels, pointing to landing page and checkout funnel issues.
3. **Linear regression explains ~82% of revenue variance (R² ≈ 0.82)** — budget and click volume together are strong predictors of revenue, validating the case for scaling proven channels.

## Technologies Used

| Tool | Purpose |
|---|---|
| Python 3.11 | Core analysis language |
| pandas | Data manipulation and aggregation |
| numpy | Numerical computations |
| matplotlib / seaborn | Static visualizations |
| plotly | Interactive charts |
| scikit-learn | Linear regression model |
| scipy | Statistical hypothesis testing (t-test) |
| Jupyter Notebook | Interactive analysis environment |
| SQL (PostgreSQL syntax) | Channel-level aggregations, funnel queries |

## Project Structure

```
project_3_marketing/
├── README.md               # Project overview and findings
├── analysis.ipynb          # Main Jupyter notebook with full analysis
├── queries.sql             # SQL queries for channel and funnel metrics
├── requirements.txt        # Python dependencies
└── LICENSE                 # MIT License
```

## How to Run

```bash
# Install dependencies
pip install -r requirements.txt

# Launch notebook
jupyter notebook analysis.ipynb
```

## Dataset

Synthetic marketing data is generated inside the notebook (`analysis.ipynb`), simulating a real-world CRM/analytics export with ~200 campaigns across 5 channels (Google Ads, Facebook, Instagram, Email, TikTok) over 12 months.
