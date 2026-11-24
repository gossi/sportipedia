---
name: parse-spec
description: Read a spec document and report the facts it states, without deciding any work.
---

# Parse Spec

## Overview

A spec is a human document. This skill reads it and reports what it states, in the
document's own words and order, plus the element addresses its links point at.

It answers one question: **what does the document say**. It never answers what work
follows from that, which is
[plan-spec](../plan-spec/SKILL.md).

**Executed by the software-architect**, in the `plan` and `review` steps of the
[spec recipe](../../recipes/spec.recipe.md). The builder does not run it.

## When to Use This Skill

- You are given a `spec_path` and need what the document states
- You are about to plan work from a spec, or review a result against one

## Input

`spec_path`: the spec markdown file.

## Steps

### Step 1: Read the whole file

Read `${spec_path}` completely, including frontmatter. Do not skim for one section:
the sections outside `## Domain Model` carry requirements the model does not express.

### Step 2: Report the frontmatter

Record `feature`, `subdomain`, `composite`, `constituent` and `scope` as written.
`scope` says which sides of the system the spec covers, so keep its value verbatim
and do not infer a side it does not name. Absent keys are reported as absent.

### Step 3: Report the Domain Model section

The section groups its entries under four labels: `Used Domain Models:`,
`Modified Domain Models:`, `New Domain Models:` and `Removed Domain Models:`. For
every entry record:

- `bucket`: `used`, `modified`, `new` or `removed`
- `kind` and `name`: taken from the link label, for example
  `[Command: catalog-apparatus]` gives kind `command` and name `catalog-apparatus`
- `path`: the link target, as written
- `note`: the purpose text after the colon, verbatim

Entries whose note begins with `Referenced` keep their bucket and are also marked
`referenced: true`. Those are the spec naming another aggregate's model, and they are
facts about dependencies, not about this spec's work.

Keep the document order within each bucket. A missing label means an empty bucket.

### Step 4: Derive element addresses from the links

Each ESDM file is named `<kind>.<name>.esdm.yaml`, so an entry's address is
`kind.name` from the filename, and it must agree with the link label. Report an entry
whose filename and label disagree. Do not open the ESDM files.

### Step 5: Report the remaining sections

Record, per section, the bullets as written, with their section name:

- `### Functional Requirements`, `### Technical Requirements`,
  `### Integration Requirements`, `### User Experience Requirements`
- `## Non-requirements`
- `## Quality Assurance` test scenarios, each by name, with the domain-model file and
  scenario it references when the text names one
- `## Tradeoffs and Concerns`, each title with its `Follow-up` link

An empty section is reported as empty. Do not fill a gap from the model or from code.

### Step 6: Check the document's own links

Resolve every relative link in the document against the spec file's directory. Report
each one that does not exist, with the section it sits in. A wrong `../` depth is the
usual cause. Report it as a document defect and do not repair it, change it, or let
it alter anything else in this result.

### Step 7: Return the result

```json
{
  "frontmatter": { "feature": "…", "subdomain": "…", "composite": "…",
                   "constituent": "…", "scope": "…" },
  "domain_model": [
    { "bucket": "modified", "kind": "command", "name": "catalog-apparatus",
      "address": "command.catalog-apparatus",
      "path": "../../../domain-model/catalog/equipment/command.catalog-apparatus.esdm.yaml",
      "note": "`data` populated with `title`, `slug`, `description` …",
      "referenced": false }
  ],
  "requirements": { "functional": ["…"], "technical": ["…"], "integration": ["…"],
                    "user_experience": ["…"] },
  "non_requirements": ["…"],
  "qa_scenarios": [ { "name": "…", "references": "…" } ],
  "tradeoffs": [ { "title": "…", "follow_up": "…" } ],
  "label_address_mismatches": [],
  "broken_links": [ "## Domain Model → ../../../domain-model/…" ]
}
```

## Verification

- [ ] Did I read every section, not just `## Domain Model`?
- [ ] Did I record `scope` exactly as the frontmatter states it?
- [ ] Did I capture all four domain model buckets, keeping document order?
- [ ] Did I mark entries whose note says `Referenced`?
- [ ] Did I take names from the link labels and addresses from the filenames, and
      report where they disagree?
- [ ] Did I leave out any work decision? (should be: yes, none)
- [ ] Did I avoid opening ESDM files or implementation files? (should be: yes)
- [ ] Did I attempt every relative link and report the failures with their section?
- [ ] Is the output valid JSON with all seven keys?
