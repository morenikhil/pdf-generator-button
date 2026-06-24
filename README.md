# PDF Generator Button — Salesforce LWC

A **reusable Lightning Web Component** that renders any Salesforce record as a PDF (via a Visualforce page) and saves the result as a **ContentVersion** (Salesforce Files) automatically linked to the source record.

---

## Table of Contents

1. [Features](#features)
2. [Architecture](#architecture)
3. [Component Structure](#component-structure)
4. [Setup & Deployment](#setup--deployment)
5. [Configuration (Design Attributes)](#configuration-design-attributes)
6. [Usage on Record Pages](#usage-on-record-pages)
7. [Extending with a Custom VF Template](#extending-with-a-custom-vf-template)
8. [Running Tests](#running-tests)
9. [Permissions](#permissions)
10. [Known Limitations](#known-limitations)

---

## Features

| Feature | Detail |
|---|---|
| One-click PDF generation | Button on any Lightning record page |
| Reusable across objects | Works for Account, Contact, Opportunity, or any custom object |
| Auto file naming | `<ObjectName>_<RecordId>_<YYYY-MM-DD>.pdf` — or override with a static name |
| Saved to Salesforce Files | Creates `ContentVersion` + `ContentDocumentLink` (linked to record) |
| PDF history table | Shows the 20 most-recent PDFs linked to the record |
| In-line download | Click download icon to open file preview / download |
| Toast notifications | Success & error feedback via `lightning/platformShowToastEvent` |
| Configurable VF template | Point the component at any Visualforce page via a Design Attribute |
| Permission set included | `PdfGenerator` permission set for controlled rollout |

---

## Architecture

```
┌─────────────────────────────────┐
│   Lightning Record Page         │
│  ┌───────────────────────────┐  │
│  │  pdfGeneratorButton (LWC) │  │
│  │  - Generate PDF button    │  │
│  │  - PDF history table      │  │
│  └─────────────┬─────────────┘  │
│                │ @AuraEnabled   │
└────────────────┼────────────────┘
                 │
     ┌───────────▼────────────┐
     │  PdfGeneratorController │  (Apex — with sharing)
     │  generateAndSavePdf()  │
     │  getGeneratedPdfs()    │
     └───────────┬────────────┘
                 │
     ┌───────────▼────────────┐
     │  RecordPdfPage (VF)    │  renderAs="pdf"
     │  ?id=&objectApiName=   │  ◄── PageReference.getContentAsPDF()
     └───────────┬────────────┘
                 │  Blob
     ┌───────────▼────────────┐
     │  ContentVersion        │  Salesforce Files
     │  ContentDocumentLink   │  Linked to source record
     └────────────────────────┘
```

---

## Component Structure

```
pdf-generator-lwc/
├── sfdx-project.json
└── force-app/main/default/
    ├── lwc/
    │   └── pdfGeneratorButton/
    │       ├── pdfGeneratorButton.html          # Template
    │       ├── pdfGeneratorButton.js            # Controller
    │       ├── pdfGeneratorButton.css           # Scoped styles
    │       └── pdfGeneratorButton.js-meta.xml  # Target config & design attributes
    ├── classes/
    │   ├── PdfGeneratorController.cls           # Main Apex controller
    │   ├── PdfGeneratorController.cls-meta.xml
    │   ├── PdfGeneratorControllerTest.cls       # Apex test class
    │   ├── PdfGeneratorControllerTest.cls-meta.xml
    │   ├── RecordPdfPageController.cls          # VF page controller
    │   ├── RecordPdfPageController.cls-meta.xml
    │   ├── RecordPdfPageControllerTest.cls
    │   └── RecordPdfPageControllerTest.cls-meta.xml
    ├── pages/
    │   ├── RecordPdfPage.page                   # Generic VF PDF template
    │   └── RecordPdfPage.page-meta.xml
    └── permissionsets/
        └── PdfGenerator.permissionset-meta.xml
```

---

## Setup & Deployment

### Prerequisites

- Salesforce CLI (`sf` or `sfdx`) installed
- An authorized Dev Hub / sandbox

### 1 — Authorise an org

```bash
sf org login web --alias myOrg --set-default
```

### 2 — Deploy all metadata

```bash
sf project deploy start --source-dir force-app --target-org myOrg
```

### 3 — Assign the permission set

```bash
sf org assign permset --name PdfGenerator --target-org myOrg
```

### 4 — Run Apex tests

```bash
sf apex run test \
  --class-names PdfGeneratorControllerTest,RecordPdfPageControllerTest \
  --result-format human \
  --target-org myOrg
```

---

## Configuration (Design Attributes)

Add the component to any Lightning record page via the **Lightning App Builder**. Three properties are exposed:

| Property | Type | Default | Description |
|---|---|---|---|
| `buttonLabel` | String | `Generate PDF` | Label on the generate button |
| `vfPageName` | String | `RecordPdfPage` | API name of the Visualforce page (without `/apex/` prefix) |
| `pdfFileName` | String | *(auto)* | Static file name. Leave blank to auto-generate. |

---

## Usage on Record Pages

1. Open **Setup → Lightning App Builder**.
2. Edit the record page for the desired object (e.g. Account).
3. Drag **PDF Generator Button** from the Custom section onto the page.
4. Set **Visualforce Page Name** to match the desired VF template.
5. **Save** and **Activate** the page.

---

## Extending with a Custom VF Template

The built-in `RecordPdfPage` renders common fields dynamically. For branded or object-specific layouts:

1. Create a new Visualforce page:

```xml
<apex:page standardController="Opportunity" renderAs="pdf" showHeader="false">
    <!-- your branded layout -->
    <apex:outputField value="{!Opportunity.Name}" />
    ...
</apex:page>
```

2. Set the component's **Visualforce Page Name** design attribute to the new page name.

3. Ensure the permission set (or user's profile) includes access to the new VF page.

---

## Running Tests

```bash
# All tests in the project
sf apex run test --test-level RunLocalTests --target-org myOrg

# Specific classes only
sf apex run test \
  --class-names PdfGeneratorControllerTest \
  --class-names RecordPdfPageControllerTest \
  --result-format human \
  --target-org myOrg
```

Expected result: **all tests pass**, ≥ 85 % code coverage on both Apex classes.

---

## Permissions

The included permission set `PdfGenerator` grants:

| Object / Resource | Access |
|---|---|
| `PdfGeneratorController` (Apex) | Execute |
| `RecordPdfPageController` (Apex) | Execute |
| `RecordPdfPage` (VF page) | Access |
| `ContentVersion` | Read, Create, Edit |
| `ContentDocumentLink` | Read, Create |

Assign it to any user who needs to generate PDFs:

```bash
sf org assign permset --name PdfGenerator --on-behalf-of someUser@example.com --target-org myOrg
```

---

## Known Limitations

| Limitation | Notes |
|---|---|
| `getContentAsPDF()` is Governor Limited | Counts against a single HTTP callout from server-side Apex; cannot be called in batch context. |
| VF page must be accessible | The running user (or the System context) must have access to the named VF page. |
| Large records | Very data-heavy VF pages may exceed the 10 MB response limit for `getContentAsPDF`. |
| Guest users | Guest site users cannot create `ContentDocumentLink` unless file sharing is explicitly configured. |
| Scratch org note | `renderAs="pdf"` requires an active Visualforce page and does **not** render in LWC local dev server preview. |

---

## License

MIT — free to use, modify, and distribute.
