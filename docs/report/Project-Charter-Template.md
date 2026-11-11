# SOFTWARE PROJECT CHARTER

**Course:** Software Project Management  
**Academic Supervisor / Instructor:** Dr. Nguyen Thanh Tuan  
**Submission Deadline:** End of Week 2 (Milestone M1)  
**Document Version:** Version 1.0 (Draft / Approved)  
**Recommended Length:** 3 – 5 pages (Concise, actionable, and bounded — not an exhaustive SRS)

---

> ⚠️ **MANDATORY POLICY — AUTHENTIC PROJECTS ONLY:**  
> Every section in this charter must be populated with **authentic, verifiable data from your team's real software engineering project**. Placeholder text (*lorem ipsum*), imaginary scenarios, and synthetic projects are strictly prohibited. The project must have a live GitHub repository, an active GitHub Project board, real stakeholders or users, and concrete technical constraints. Charters failing the "Authentic Project" criteria will be returned for revision before the team is permitted to proceed to Week 3 Work Breakdown Structure (WBS) decomposition.

---

## 1. PROJECT GENERAL INFORMATION

| Item | Details |
| :--- | :--- |
| **Project Name** | *[Official name of the software application / system]* |
| **Project Acronym / Key** | *[e.g., VKU-STUDY, CAMPUS-AI, RES-FLOW]* |
| **Course Cohort** | `Software Project Management (4)` or `Software Project Management (5)` |
| **Team Name / Identifier** | *[e.g., Team 01 - SmartCampus]* |
| **Creation Date** | DD/MM/2026 |
| **Document Version** | Version 1.0 (Draft / Approved) |
| **Primary GitHub Repository** | `https://github.com/[org-or-username]/[repo-name]` |
| **GitHub Project Board URL** | `https://github.com/orgs/[org]/projects/[id]` or `https://github.com/users/[user]/projects/[id]` |

---

## 2. PROJECT SOURCING & REAL-WORLD CONTEXT

*Select `[x]` one of the three approved sourcing pathways according to the course syllabus:*

- [ ] **Pathway 1: Capstone Project from Concurrent Engineering Course**  
  *(e.g., Capstone project from Cross-Platform Mobile Development, AI Engineering, or Web Engineering)*
- [ ] **Pathway 2: Real External Client / Freelance Project / Industry Partner**  
  *(A genuine external business, startup, or freelance client who will formally review and accept the deliverables)*
- [ ] **Pathway 3: Real Campus / Department / Student Organization Need at VKU**  
  *(An authenticated operational need from a VKU department, academic laboratory, library, or student club with confirmed stakeholders)*

---

## 3. EXECUTIVE SUMMARY & BUSINESS CASE

*Explain why this software project must exist. What observable real-world problem or operational friction does it eliminate? (Provide 1–2 structured paragraphs).*

- **Operational Background:** *[Describe the current state, user environment, and existing workflow prior to this system.]*
- **Core Problem Statement:** *[Specify the key pain points, manual overhead, booking conflicts, lack of visibility, or communication bottlenecks causing measurable inefficiency.]*
- **Proposed Software Solution:** *[Detail what the software application will deliver to directly resolve the core problem, including key system capabilities and expected user benefits.]*

---

## 4. SMART PROJECT OBJECTIVES

*Define 3 to 5 Specific, Measurable, Achievable, Relevant, and Time-bound (SMART) objectives. Avoid vague declarations such as "Build good software".*

1. **Objective 1 (Core Functional Capability):**  
   *[e.g., Implement and deploy the real-time reservation engine with automated conflict prevention and API response times under 500ms before Week 8.]*
2. **Objective 2 (Operational & User Validation):**  
   *[e.g., Onboard at least 30 active university student test users and successfully process a minimum of 50 authentic bookings during the Week 12 pilot trial.]*
3. **Objective 3 (Engineering Rigor & Quality Gate):**  
   *[e.g., Maintain 100% compliance with Conventional Commits, enforce automated GitHub Actions CI builds on all Pull Requests, and ensure zero unreviewed PRs merged into `main`.]*
4. **Objective 4 (Production Deployment & Client Handover):**  
   *[e.g., Deliver a fully operational cloud-hosted production deployment (Vercel/Cloudflare Pages and managed database) and secure formal client acceptance sign-off by Week 13.]*

---

## 5. PROJECT SCOPE & BOUNDARIES

### 5.1. In-Scope (Committed Deliverables & Features)
*The concrete capabilities and engineering deliverables the team formally commits to delivering:*
- **Core Module 1:** *[Detailed description of functional capability 1]*
- **Core Module 2:** *[Detailed description of functional capability 2]*
- **Core Module 3:** *[Detailed description of functional capability 3]*
- **Engineering & Governance Deliverables:**
  - Clean GitHub repository with verifiable commit history spanning the entire semester.
  - Active GitHub Project board tracking all tasks through their complete lifecycle.
  - Automated CI/CD pipeline configured via GitHub Actions (linting, testing, preview deployments).
  - System architecture documentation, database schema diagrams, and deployment runbooks.

### 5.2. Explicitly Out-of-Scope (Scope Boundaries)
*Capabilities that will NOT be implemented during this 15-week semester (to prevent scope creep):*
- *[e.g., Real payment gateway settlement with domestic banking APIs (mocked or sandbox environment only)]*
- *[e.g., Native iOS App Store deployment (scope is strictly bounded to Responsive Web and Android APK / PWA)]*
- *[e.g., Enterprise single-sign-on (SSO) integration with external legacy LDAP systems]*
- *[e.g., Multi-region high-availability Kubernetes infrastructure]*

---

## 6. STAKEHOLDER REGISTER & ENGAGEMENT MATRIX

### 6.1. Stakeholder Register

| Stakeholder / Entity | Role in Project | Power | Interest | Engagement Strategy |
| :--- | :--- | :---: | :---: | :--- |
| **Project Sponsor / Client Stakeholder** | Requirements owner & acceptance authority | High | High | **Manage Closely**: Bi-weekly milestone demos, prototype reviews, and formal sign-offs. |
| **Course Instructor / Supervisor** | Academic evaluator & milestone auditor | High | High | **Manage Closely**: Formal checkpoint deliverables (M1–M10) and syllabus compliance. |
| **Project Engineering Team** | Design, development, testing, and delivery | High | High | **Collaborate Daily**: Async GitHub coordination, peer PR reviews, and weekly coordination meetings. |
| **System / Network Administrators** | Hosting infrastructure, domain, & security policies | High | Low | **Keep Satisfied**: Adhere strictly to institutional security standards and zero-cost hosting tiers. |
| **End Users (Students / Staff)** | Primary users testing functionality | Low | High | **Keep Informed**: Usability surveys, pilot testing sessions, and release notifications. |

### 6.2. Power-Interest Matrix

```text
High Power  │  MANAGE CLOSELY                         │  KEEP SATISFIED
            │  - Project Sponsor / Client             │  - System / Infrastructure Admins
            │  - Course Instructor / Supervisor       │
────────────┼─────────────────────────────────────────┼──────────────────────────────
Low Power   │  KEEP INFORMED                          │  MONITOR
            │  - End Users (Students, Staff)          │  - Peer Project Teams
            │  - Pilot Testers & Survey Participants  │  - External Open-Source Community
            └─────────────────────────────────────────┴──────────────────────────────
                           High Interest                           Low Interest
```

---

## 7. PROJECT MANAGEMENT STACK & GITHUB ECOSYSTEM

*The project strictly utilizes the **unified GitHub platform** as its complete engineering and project management suite. External tracking tools (e.g., Jira, Trello, Asana, ClickUp) are not permitted.*

| Project Management Domain | GitHub Tool / Feature | Governance Standard |
| :--- | :--- | :--- |
| **Source Code Repository** | **GitHub Repository** | Standard branch protection on `main`; commit history must follow Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`). |
| **Project Tracking & Board** | **GitHub Projects (Board & Table)** | Kanban columns: `Backlog`, `Ready`, `In Progress`, `In Review`, `Done`. Every active task must be tracked on this board. |
| **Task & Work Package Management** | **GitHub Issues** | One issue per WBS deliverable or feature. Each issue must state clear acceptance criteria, assignee, and milestone. |
| **Code Review & Quality Control** | **GitHub Pull Requests (PRs)** | All changes merged via PR; mandatory self-testing notes and at least 1 peer approval before merge. Direct push to `main` is forbidden. |
| **Milestone Tracking** | **GitHub Milestones** | Milestones configured to match course checkpoints (e.g., `M1: Charter`, `M2: WBS`, `M5: Midterm Demo`, `M8: Release`). |
| **Continuous Integration & Delivery** | **GitHub Actions** | Automated workflows running on every PR to verify linting, code formatting, unit tests, and build stability. |

---

## 8. HIGH-LEVEL MILESTONES & SCHEDULE

*Aligned with the 10 formal checkpoints of the course:*

| Milestone | Target Week | Major Deliverables | Responsible Role |
| :---: | :---: | :--- | :--- |
| **M1** | Week 2 | Approved Project Charter & Initialized GitHub Project Board | Project Lead & Team |
| **M2** | Weeks 3–4 | Work Breakdown Structure (WBS) & Requirements Traceability Matrix (RTM) | Technical Lead / PM |
| **M3** | Week 5 | Iteration 1 Launch (Prioritized Backlog, Work Packages Assigned, Estimates Locked) | Entire Team |
| **M4** | Weeks 6–7 | Risk Register Formalization #1 & Iteration 1 Retrospective Report | QA / Test Engineer |
| **M5** | Weeks 8–9 | Midterm Milestone: Working Product Prototype Demo & Iteration 2 Planning | Entire Team |
| **M6** | Weeks 9–10 | Iteration 2 Delivery, CI/CD Pipeline Automation & Quality Audit | Entire Team |
| **M7** | Weeks 11–12 | Risk Register Formalization #2 & Scope Change Control Log | Project Lead |
| **M8** | Week 13 | Final Client / Stakeholder Acceptance Sign-Off & Project Retrospective | Entire Team |
| **M9** | Week 14 | Complete Evidence Package Submission (Audit Checklist Verification) | Entire Team |
| **M10**| Week 15 | Final Oral Defense and Live System Demonstration before the Evaluation Committee | Entire Team |

---

## 9. DEVELOPMENT METHODOLOGY & CADENCE

### 9.1. Chosen Development Methodology
*Select the software engineering process model that governs your delivery lifecycle:*
- [ ] **Iterative & Incremental Development** (Timeboxed 2–3 week delivery cycles with progressive feature refinement)
- [ ] **Agile Flow / Kanban** (Continuous delivery prioritized by pull limits and work-in-progress constraints)
- [ ] **Hybrid (Milestone-Gated Iterative)** (Predictable architectural and governance milestones combined with flexible feature iterations)
- [ ] **Structured Sequential / Waterfall** (Phase-gated progression suited for strictly fixed, pre-defined technical specifications)

### 9.2. Methodology Justification
*Provide a concise rationale explaining why this methodology is optimal for your project:*
- **Requirement Volatility & Discovery:** *[e.g., End-user booking rules may evolve following initial user testing; iterative cycles enable fast feedback without breaking system foundations.]*
- **Stakeholder Availability:** *[e.g., The client stakeholder is available for progress reviews every two weeks on Friday afternoons.]*
- **Technical Risk Management:** *[e.g., The project involves new cloud and database technologies, necessitating early technical spikes and rapid prototyping.]*

---

## 10. TEAM ORGANIZATION & GOVERNANCE ROLES

*Define team roles and primary responsibilities across the project lifecycle:*

| # | Member Name | Student ID | GitHub Username | Project Role | Primary Responsibilities |
| :-: | :--- | :---: | :---: | :--- | :--- |
| 1 | *[Student Name 1]* | 21ITxxx | `@github_user1` | **Project Lead / PM** | Coordinates milestone schedules, maintains the GitHub Project board, manages risk registers, and leads stakeholder communications. |
| 2 | *[Student Name 2]* | 21ITxxx | `@github_user2` | **Technical Lead / Architect** | Leads system architecture, database design, CI/CD pipeline automation, and critical code reviews. |
| 3 | *[Student Name 3]* | 21ITxxx | `@github_user3` | **Backend Engineer** | Implements API endpoints, database business logic, serverless services, and transaction security. |
| 4 | *[Student Name 4]* | 21ITxxx | `@github_user4` | **Frontend / Mobile Engineer** | Builds responsive user interfaces, client-side state handling, user workflows, and QR scanning features. |
| 5 | *[Student Name 5]* | 21ITxxx | `@github_user5` | **QA & Test Engineer** | Designs test matrices, executes functional and API tests, validates acceptance criteria, and compiles the final audit package. |

---

## 11. CONSTRAINTS, ASSUMPTIONS & INITIAL RISKS

### 11.1. Project Constraints (Triple Constraint)
- **Schedule:** Absolute completion and deployment deadline by Week 14; final defense in Week 15.
- **Budget & Infrastructure:** \$0 total budget. Must utilize free-tier cloud platforms (e.g., Cloudflare Pages, Supabase, Vercel, Render, GitHub Free).
- **Technology Stack:** *[Specify mandatory technologies: e.g., Next.js / Flutter / FastAPI / PostgreSQL / Supabase]*

### 11.2. Key Assumptions
- The project sponsor / client stakeholder will review deliverables within 3 business days of milestone submission.
- Selected free-tier cloud services and third-party APIs will maintain availability throughout the academic term.
- All team members have continuous access to working development machines and reliable Internet connectivity.

### 11.3. Top 3 Initial Project Risks

| Initial Risk | Probability | Impact | Proactive Response & Mitigation Plan |
| :--- | :---: | :---: | :--- |
| **1. Unbalanced workload or unexpected skill gaps** | Medium | High | Decompose work packages into small issues ($\le 2$ days effort); implement pair programming during Week 3 setup. |
| **2. Scope creep from uncontrolled feature additions** | High | High | Enforce Section 5.2 Out-of-Scope boundaries; require formal written Change Requests before accepting any scope adjustments. |
| **3. Client delay in validating milestone acceptance** | Medium | Medium | Schedule recurring review meetings 2 weeks in advance; maintain automated staging environments for immediate inspection. |

---

## 12. SUCCESS CRITERIA & DEFINITION OF DONE (DoD)

### 12.1. Project Success Criteria
1. **Functional Completeness:** 100% of committed In-Scope features are operational in production with zero critical defects.
2. **Authentic Validation:** Formal written acceptance sign-off obtained from the project sponsor/client by Week 13.
3. **Engineering Integrity:** Complete Evidence Package submitted with authentic GitHub commit logs, active board history, automated CI builds, and test coverage evidence.

### 12.2. Engineering Definition of Done (DoD) for Every Work Item
*A GitHub Issue or work item may only be transitioned to the `Done` column on the GitHub Project board when all the following criteria are satisfied:*
- [ ] Source code is implemented, properly formatted, and tested locally.
- [ ] A GitHub Pull Request is opened with a clear description referencing the issue (e.g., `Resolves #24`).
- [ ] At least one designated team member has reviewed and formally approved the Pull Request.
- [ ] Automated GitHub Actions CI workflow (linting, build test) passes with green status.
- [ ] Security scan verified: no API keys, tokens, or environment credentials committed to Git.
- [ ] Code is merged into the integration branch (`main` or `staging`) and deployed to the preview environment.
- [ ] Acceptance criteria specified in the GitHub Issue are fully verified by the QA engineer or tester.
- [ ] The associated GitHub Issue is closed and moved to `Done` on the GitHub Project board.

---

## 13. FORMAL APPROVALS & SIGN-OFF

*By signing below, the signatories endorse this Project Charter, granting the project team formal authorization to proceed with Work Breakdown Structure (WBS) decomposition and project execution in accordance with the defined scope and schedule.*

| Project Lead / Team Representative | Project Sponsor / Client Stakeholder | Academic Supervisor / Course Instructor |
| :---: | :---: | :---: |
| *(Signature & Full Name)* | *(Signature & Full Name)* | *(Signature & Full Name)* |
| <br><br><br> | <br><br><br> | <br><br><br> |
| **[Project Lead Full Name]** | **[Client / Sponsor Full Name]** | **Dr. Nguyen Thanh Tuan** |
| Date: ...... / ...... / 2026 | Date: ...... / ...... / 2026 | Date: ...... / ...... / 2026 |
