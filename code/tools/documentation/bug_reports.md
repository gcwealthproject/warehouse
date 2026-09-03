# Source Registry Bug Reports

## 2026-03-16: Data Sources edit flow breaks records where `source != citekey`

### Summary

The Data Sources branch in the local Source Registry UI does not preserve existing records that have a short `source` and a different long-form `citekey`.

This is already true for live records in `metadata/sources/sources.yaml`. For example, the `ABS` record uses:

- `source = "ABS"`
- `citekey = "AustralianBureauofStatistics2022_AustralianNationalAccountsDistributionHousehold"`

When such a record is loaded in edit mode, the UI collapses both values into the single `Source / Citekey` field. The save path then treats that as a key rename, even if the user did not change anything.

### Impact

- Existing Data Sources records with distinct `source` and `citekey` cannot be edited cleanly through the current UI.
- A no-change save can fail with a key-rename error.
- If the key-rename guard is bypassed, the stored `citekey` would be overwritten with the short `source` value.
- This would also create unnecessary alias churn and could break downstream bibliography expectations.

### Code Path

The issue appears to come from the interaction of these points in `code/tools/sources/ui_local.py`:

- `make_candidate()` writes both `"source"` and `"citekey"` from the same `source_key` field.
- `validate_candidate()` enforces `source == citekey`.
- `loadTarget()` loads the edit form field from `rec.source || rec.citekey`, which loses a distinct `citekey`.
- `apply_payload()` detects that hidden change later and raises the key-rename error.

Relevant lines at the time of testing:

- `make_candidate()`: lines 664-680
- `validate_candidate()`: lines 445-449
- `loadTarget()`: lines 1725-1730
- `apply_payload()`: lines 880-906

### Tests Run

All browser testing was run against a temporary `/tmp` copy of the registry and generated artifacts, not against the real repository files.

1. Verified the local UI could launch on a temporary registry copy.
2. Opened the Data Sources branch in the browser and exercised the add flow.
3. Confirmed duplicate-entry validation on a manually entered duplicate `ABS` payload.
4. Switched to Data Sources edit mode.
5. Loaded the existing `ABS` record into the form.
6. Observed that the single `Source / Citekey` field was populated with `ABS`, not the record's stored long-form `citekey`.
7. Regenerated the temporary artifacts so the stale-artifact guard would not be the only blocker in the sandbox.
8. Attempted a no-change save with only an editor name filled in.
9. Confirmed the server rejected the edit path with HTTP 409 from `/api/apply_and_build`, consistent with the hidden key-change path.

### Observed Behavior

- The edit form displayed `ABS` in the combined `Source / Citekey` field after loading the existing record.
- The no-change save path failed instead of round-tripping the record unchanged.

### Expected Behavior

- Loading an existing record should preserve both the stored `source` and the stored `citekey`.
- A no-change save of an existing record should succeed.
- A user should only see a key-rename confirmation if they actually changed a stored key.

### Likely Paths For Solution

#### Option 1: Restore separate fields for Data Sources

This is the most direct and lowest-risk fix.

- Use separate UI fields for `source` and `citekey` in the Data Sources branch.
- Load both fields independently from the stored record.
- Validate uniqueness and duplicates independently.
- Preserve the current single-field behavior only for truly new workflows if that is still desired.

#### Option 2: Keep one displayed field, but preserve the stored citekey on edit

This is possible, but more fragile.

- In add mode, continue mirroring the single input into both `source` and `citekey`.
- In edit mode, retain the original stored `citekey` unless the user explicitly chooses to rename it.
- Track original values separately in the client so the save payload can distinguish "unchanged existing citekey" from "user requested rename".

#### Option 3: Relax the `source == citekey` invariant

This is likely required regardless, because the current registry already violates that invariant.

- Remove the unconditional equality check from the Data Sources validator.
- Replace it with the rules the data model actually needs:
  - `source` uniqueness
  - `citekey` uniqueness
  - explicit rename confirmation only when either stored value changes

### Recommended Direction

The safest path is a combination of Option 1 and Option 3:

- represent `source` and `citekey` separately in edit mode
- stop assuming they must always be identical
- make rename confirmation compare the true stored values against the actual edited values

That matches the current data model and avoids hidden mutations during edit.
