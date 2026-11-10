# Lab 1 — WBS Decomposition Practice

**Aligns with:** [Week 3 — Scope & Requirements Planning](../slides/Week-03-Scope-WBS.md) · **Format:** ungraded practice exercise, run before teams decompose their own real project's WBS (the actual graded milestone is in Week 3's slide deck)

## Objective

Practice the mechanics of Work Breakdown Structure decomposition — deliverable-oriented breakdown, the 100% rule, and the "1-2 weeks per work package" depth heuristic — on a sample project, so the whiteboard walkthrough in Week 3 isn't the first time students apply it.

## Worked example (from the lecture)

```
Project: Facility Survey Tool
├── 1. Data Collection Module
│   ├── 1.1 Dynamic form engine
│   ├── 1.2 Offline storage
│   └── 1.3 Sync queue
├── 2. Admin Dashboard
│   ├── 2.1 Submission viewer
│   └── 2.2 Export to CSV
└── 3. Deployment
    ├── 3.1 Hosting setup
    └── 3.2 User onboarding docs
```

Each leaf node is a concrete, estimable deliverable — not a verb like "develop" or "test."

## Practice scenario

**Project:** Campus Club Event Booking App — lets student clubs reserve rooms/equipment and lets the university approve or reject requests.

Partially decomposed WBS — **complete the missing branches**:

```
Project: Campus Club Event Booking App
├── 1. Booking Request Module
│   ├── 1.1 Room/equipment availability calendar
│   ├── 1.2 ?
│   └── 1.3 ?
├── 2. Approval Workflow
│   ├── 2.1 ?
│   └── 2.2 Notification on approve/reject
└── 3. ?
    ├── 3.1 ?
    └── 3.2 ?
```

**Steps:**

1. Fill in the `?` nodes with concrete, deliverable-oriented items (not verbs).
2. Apply the **100% rule**: does your completed tree cover everything a minimal version of this app needs, with nothing extra?
3. Check depth: is every leaf roughly 1-2 weeks of work for a pair of students? Split anything bigger, merge anything smaller.
4. Compare with a neighboring team — where did you decompose differently, and is either wrong, or just a different valid scope call?

## Discussion prompts

- Where did your team disagree about whether something was "one work package" or "two"?
- Did you find anything that felt like a to-do item ("test the calendar") rather than a deliverable? How did you reframe it?

## Related

- [Week 3 — Scope & Requirements Planning](../slides/Week-03-Scope-WBS.md) — full lecture content this lab supports
- [Lab 2 — Planning Poker Practice](Lab-2-Planning-Poker-Practice.md) — next step: estimating the work packages you just built
- [Project Charter Template](../project/Project-Charter-Template.md) — your real project's WBS must trace back to this charter's scope
