# Productivity AI - E2E Testing & Report Framework

This directory contains the automated End-to-End (E2E) testing suite and test case documentation compiler for the **Productivity AI** platform.

## Framework Structure

1. **`generate_test_report.py`**: A python script that compiles 105 unique, detailed test cases covering UI/UX, Functional, Unit, Validation, and Deployable Status, and writes them to a formatted Enterprise Excel spreadsheet with formulas and a graphical dashboard.
2. **`selenium_e2e.py`**: A Selenium automated test script that launches Chrome to run interaction tests (authentication, navigation, focus mode setup, chatbot inputs, and settings updates). It automatically runs the Excel generator when the tests finish.

---

## Installation & Setup

Before running the tests, ensure you have Python installed and run the following command to install the required libraries:

```bash
pip install openpyxl selenium webdriver-manager
```

---

## How to Run the Tests

### Step 1: Run the Flutter App Web Server
In your project directory, launch a local web server compiled for the HTML web renderer on port `8080` (so Selenium can locate DOM input elements):

```bash
flutter run -d chrome --web-renderer html --web-port 8080
```

### Step 2: Run the E2E Test Suite
Open a new terminal window, navigate to the project directory, and run the Selenium test suite:

```bash
python test/e2e/selenium_e2e.py
```

This will run the browser automation, print assertions to the terminal, and automatically output the Excel file:
**`E2E_Test_Report_ProductivityAI_<timestamp>.xlsx`** in the root of your workspace directory.

---

## Run Report Generator Directly (Offline/Without Browser)
If you wish to compile and view the spreadsheet report instantly without launching the Chrome browser and server:

```bash
python test/e2e/generate_test_report.py
```
This generates the `.xlsx` file immediately.

---

## QA Report Structure
The generated Excel report contains 6 sheets:
1. **Summary Dashboard**: Key metadata, deployable status card, totals table, and a 3D Pie Chart highlighting the PASS/FAIL/SKIP ratio.
2. **UI-UX Tests**: 22 test cases assessing animations, layout ratios, overlays, grids, typography, and dark mode colors.
3. **Functional Tests**: 35 test cases verifying registration, logins, focus sessions, tracking databases, reports printing, and AI interactions.
4. **Unit Tests**: 21 test cases validation checking provider states transitions, date aggregates calculations, and text parsing methods.
5. **Validation Tests**: 17 test cases confirming email criteria, password complexity boundaries, and numerical range limits.
6. **Deployable Status**: 10 test cases checking web compilation size, netlify rules, database rules, and oauth credentials key matches.
