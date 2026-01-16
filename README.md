# The GC Wealth Project

<table align="center" width="80%">
  <tr>
    <td align="center" width="33.33%">
      <img src="logos/stone_logo.png" alt="Stone Logo" style="width:100%;" />
    </td>
    <td align="center" width="33.33%">
      <img src="logos/gc_logo.png" alt="GC Logo" style="width:100%;" />
    </td>
    <td align="center" width="33.33%">
      <img src="logos/roma_tre_logo.png" alt="Roma Tre Logo" style="width:100%;" />
    </td>
  </tr>
</table>

## Introduction

This repository contains both the code necessary to process data from various sources and the resulting structured data warehouse. The Stata scripts provided here clean, estimate, and structure raw data into a consistent format, which can then be used for analysis. The repository also references multiple versions and formats of the data warehouse, stored on Google Drive, ensuring accessibility for different use cases.

## About the GC Wealth Project

The GC Wealth Project, a central project of the Graduate Center's [Stone Center on Socio-Economic Inequality](https://stonecenter.gc.cuny.edu), is a multi-year effort aimed at expanding and consolidating access to the most up-to-date research and information on wealth, wealth inequalities, and wealth transfers and related tax policies, across countries and over time.

The [GC Wealth Project website](https://wealthproject.gc.cuny.edu/index.html) — first launched in June 2023 — is organized around two main components: a data warehouse of gathered and novel data that can be visualized in a variety of ways through the interactive dashboard, and a Digital Library of Research on Wealth Inequality. Both are designed to provide researchers, policymakers, journalists, and others interested in wealth and wealth taxation with open, unlimited access to an array of high-quality information and resources.

## Executing the Stata Code

Below, we provide details on required packages and on how to execute the pipeline and the structure of the codebase.

### Data Folders

- `raw_data/`: This folder contains the large input datasets used by the code.  
- `output/`: This folder stores the generated output files, including processed data and results.

⚠️ **IMPORTANT:** These folders are **not included** in the repository due to GitHub's file size limitations.  
📁 **They are available via Dropbox [here](https://www.dropbox.com/scl/fo/ahwvnausm6yoxu17b145w/AMxF8KlzX2yF5TijX-LlJd8?rlkey=edq66i0ffs3bv09opd92xsjtq&st=f7qqkl5f&dl=0)**

➡️ To run the code, **download the contents** from the Dropbox link and place the `raw_data/` and `output/` folders in the root directory of the project.


### Required Stata packages

* From SSC:

```stata 
ssc install egenmore
ssc install sxpose
ssc install findname
ssc install labmask
ssc install renvarlab
ssc install ereplace
ssc install xfill
```

* From Sealed Envelope:
```stata
net from https://www.sealedenvelope.com/
net install xfill
```

* From The Stata Journal:
```stata
net install gr0034.pkg, from(http://www.stata-journal.com/software/sj8-2/)
```

* From Github:
```stata
net install github, from("https://haghish.github.io/github/")
github install haghish/rcall
```

### How to Run the Pipeline

To run the full pipeline, set your working directory to the repository’s location and execute `run_everything.do`:

```stata
cd "path/to/folder"
do "code/mainstream/run_everything.do"
```

This will process the raw data, generate structured outputs, and store them in the `output` folder. The resulting output files are available for download below.

### Code Structure

- **`mainstream`**: The core processing stream. Running `run_everything.do` from this folder will execute all scripts required to clean and transform the data.
- **`dashboards`**: Scripts dedicated to cleaning, estimating, and arranging data from specific sources.
- **`raw_data`**: Contains unprocessed data used as input. This folder is currently available on demand, since it is approximately 70 Gb.

## The Data Warehouse (v1.2)

### Full Data Warehouse

The data warehouse includes four databases, which correspond to the four sections of the dashboard:
1. Wealth Topography
2. Wealth Inequality Trends
3. Estate, Inheritance, and Gift Taxes
4. Inheritance Trends : coming soon

The data warehouse is also complemented with full metadata descriptive information. The metadata
provide detailed information on sources of data, longer descriptions of variables and the concepts used,
procedures of aggregation and estimation, bibliography links, and complementary information.

- **Download Warehouse with metadata** [Excel](https://docs.google.com/spreadsheets/d/1wmg0CJlN5nLc_M59tCzc6QrV-_gLAqSD/edit?usp=drive_link&ouid=114609468696885316335&rtpof=true&sd=true), [CSV](https://drive.google.com/file/d/1YG9N0HF1m7qI4za1qyS-ckTfQZvQ1Ipw/view?usp=drive_link)
- **Download Warehouse without metadata** [Excel](https://docs.google.com/spreadsheets/d/10iLK7QXcMNSEn4sMNGWR4GBAKm6OPJhM/edit?usp=drive_link&ouid=114609468696885316335&rtpof=true&sd=true), [CSV](https://drive.google.com/file/d/19XLHMezkzPng1kdCsDTj1VR1PVjkQTVX/view?usp=drive_link)

### 1. Wealth Topography

This section includes cross-country data that capture, at the aggregate level, the evolution of household portfolios of assets and debt. Assets are metaphorically represented as “mountains and hills," while debts are visualized as “seas" of debt. The data come from national accounts, household surveys, and a range of research projects and reports.

These data offer a unique view of aggregate household balance sheets. Country-specific portfolios are shaped by, and reflect, national characteristics, including demographic trends, inflation and interest rate dynamics, features of financial and credit markets, the relative importance of stock exchanges versus banking systems, the strength of asset management industries, and the preferential tax treatment of assets, as well as the preferences of households and the generosity of pensions systems.

- [Interactive Dashboard](https://wealthproject.gc.cuny.edu/wealth-topography/)
- **Download the Wealth Topography database with metadata**: [Excel](https://docs.google.com/spreadsheets/d/1XJYk7Exv4D4ilvpe8i50CWMSwld1TQdB/edit?usp=drive_link&ouid=114609468696885316335&rtpof=true&sd=true), [CSV](https://drive.google.com/file/d/19vzSCntJB4e8hDFBgd0ZG_9C1J1OzrSH/view?usp=drive_link)
- **Download the Wealth Topography database without metadata**: [Excel](https://docs.google.com/spreadsheets/d/1d7UxhS7Gqeiy0YVy45_syhMQCXtnmaKY/edit?usp=drive_link&ouid=114609468696885316335&rtpof=true&sd=true), [CSV](https://drive.google.com/file/d/16I6CgJHeNZMMhwbKgR4_S8KlITpbmPJe/view?usp=drive_link)
 
### 2. Wealth Inequality Trends

This section presents a large comprehensive compilation of cross-national time-series data on wealth inequality. This section contains wealth inequality indicators (such as top shares and Gini coefficients) for many countries, as estimated in the existing literature and as derived from existing micro data sources. These data are accompanied by Methodological Tables that provide systematic assessments of the underlying concepts, methods, and sources for the estimation of wealth inequality trends.

This section provides access to, and detailed information about, wealth inequality across countries and over time. To date, there is no comprehensive database that offers “off the shelf” indicators on wealth inequality levels and trends for a variety of different sources. Estimates of wealth distributions are much less settled than those of income distributions, and there is substantial controversy about how wealth inequality has evolved in recent years. A core value-added of this section is that users have access to detailed information about the values provided and methodological information that will help them to navigate the inevitable complexity. Users can also exploit our classification of data types, source types, and unit of analysis to guide the choice of the most suitable indicator for their purpose.

- [Interactive Dashboard](https://wealthproject.gc.cuny.edu/wealth-inequality-trends/)
- **Download the Wealth Inequality Trends database with metadata**: [Excel](https://docs.google.com/spreadsheets/d/1LZegla1y20Pm11zWB9OOxWbJCZaH11bi/edit?usp=drive_link&ouid=114609468696885316335&rtpof=true&sd=true), [CSV](https://drive.google.com/file/d/1myY2OKWAXhr_ipRY1rTfGBr3-3dmTD_I/view?usp=drive_link)
- **Download the Wealth Inequality Trends database without metadata**: [Excel](https://docs.google.com/spreadsheets/d/1KpY4MpPvzAQCbkB3RvV8xFIXMd8WGuY-/edit?usp=drive_link&ouid=114609468696885316335&rtpof=true&sd=true), [CSV](https://drive.google.com/file/d/1lWkNey5DA-k_gU9F1G4XnnTibddRgp-V/view?usp=drive_link)

### 3. Estate, Inheritance, and Gift Taxes

This section contains a comprehensive database on the evolution of estate, inheritance, and gift (EIG) taxation, both across countries and (forthcoming) across the U.S. states. This section focuses on the taxation of wealth transfers, that is, transfers from one household or individual to another, either when the donor is living (inter vivos gifts) or at the time of the donor's death (bequests). When assessing taxes, we distinguish among three types of taxes: those levied on estates (on the total amount bequeathed), on inheritances (on amounts received by individual recipients), and on gifts (given by living donors). The EIG sections contain information on statutory tax schedules, marginal tax rates, top marginal rates, exemption thresholds, and tax revenues. Information on effective taxation is also derived and presented.

Understanding how governments tax these transfers is essential because bequests, inheritances, and inter vivos gifts are crucial economic resources for households and because their scale has increased substantially in recent decades relative to total national income. Very little work has been done to analyze how patterns of wealth transfer taxation affect the extent of these transfers across countries and across households within countries. This systematic compilation of tax data will provide researchers a crucial tool for scholarship and policy analysis focused on the behavioral effects of wealth taxes.

- [Interactive Dashboard](https://wealthproject.gc.cuny.edu/EIG/)
- **Download the Estate, Inheritance, and Gift Taxes database with metadata**: [Excel](https://docs.google.com/spreadsheets/d/1oZhUB1MjjMQZYNqj4TUw9aRWGHvE_Hld/edit?usp=drive_link&ouid=114609468696885316335&rtpof=true&sd=true), [CSV](https://drive.google.com/file/d/1ro5vo6cwvm1GYkTULr5CgE30BX5GBCmt/view?usp=drive_link)
- **Download the Estate, Inheritance, and Gift Taxes database without metadata**: [Excel](https://docs.google.com/spreadsheets/d/1DBJX1Y4h1lvv-vlhzgkEYq0NlyERpBMk/edit?usp=drive_link&ouid=114609468696885316335&rtpof=true&sd=true), [CSV](https://drive.google.com/file/d/1s-fUkZ2x5bY9wlhZj_jUZZh9W57rLaYV/view?usp=drive_link)

### 4. Inheritance Trends (Coming Soon)
This section, forthcoming in 2025, will present cross-country estimates of annual flows of wealth left at death as well as gifts from living donors. The included estimates will be taken from existing works in the literature or derived using a variety of approaches drawing on national accounts data and survey data, as well as estate, inheritance, and gifts tax records.

### 5. Supplementary Variables 
This dataset encompasses a variety of auxiliary variables, such as exchange rates and price indices, crucial for developing the visualizations on our website. Mainly derived from the World Inequality Database ([wid.world](www.wid.world)), these elements are consistently updated and archived to maintain accuracy and reliability in our analyses.
- **Download the supplementary variables (Jul 16, 2024)** [Excel](https://docs.google.com/spreadsheets/d/1kXfY4qOv7JzAuYCQin9f0GwA1C4bWYui/edit?usp=drive_link&ouid=114609468696885316335&rtpof=true&sd=true), [Stata](https://drive.google.com/file/d/1-kNzaMt3Q96YCzihIl21ogUmpGcQSXro/view?usp=drive_link), [CSV](https://drive.google.com/file/d/1TVVDszPqSZ__o4F_X8WOlWn3t2HbdcjW/view?usp=drive_link)

## Resources and Documentation

- **Warehouse Documentation**: A detailed PDF that explains the technical aspects of our data collection, organization, and more. [Link to Documentation](https://github.com/gcwealthproject/warehouse/blob/main/warehouse_documentation.pdf).
  
- **Digital Library of Research on Wealth Inequality**: A vast database that includes abstracts and, when possible, full texts of significant articles, chapters, and books focused on wealth inequality. [Link to Library](https://wealthproject.gc.cuny.edu/digital-library-of-research/), [Download the bib file]().
  
- **Digital Library of Sources**: A list of all sources used in each section of the GC Wealth Project's data warehouse. Available under each reference are BibTeX citations and abstracts. [Link to Library](https://wealthproject.gc.cuny.edu/data/data-sources-library/), [Download the bib file]().

## Warehouse History 

For the sake of space keeping and accessibility, former versions are only accessible in CSV format, which is unlicensed and lighter than the alternatives. 

### First version v1.0 - November 2023 release: 

- Full data warehouse: [download with metadata](https://drive.google.com/file/d/1FmO8qVbBshI0iQqyY321jjp1jfKnvLT_/view?usp=share_link), [download without metadata](https://drive.google.com/file/d/1dEuqsWiyFfhwSDGysY3qLw0H-iYrolhg/view?usp=share_link)
- Supplementary variables (28 sep, 2023): [download](https://drive.google.com/file/d/16LS8NicLEFLfiVh6GqNOgho7SNuSDm2H/view?usp=share_link)
- Documentation: [download](https://osf.io/preprints/socarxiv/ta67n/).

