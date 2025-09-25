# Labour Pricing Rules - DDD Context Documentation

## Overview

This document outlines the Labour Pricing rules implementation following Domain-Driven Design (DDD) principles, ensuring non-overlapping effective date ranges for Labour Rates.

## Domain Model

### Aggregate Structure

```
Price Policy (Root)
├── beren_pricingpolicyid (Primary Key)
├── beren_pricingpolicyname (Name - unique)
└── beren_active (IsActive boolean)

Labour Role (Reference)
├── beren_labourratesagentid (Primary Key)  
├── beren_name (Labour Role Name - unique)
└── beren_rolecode (Code)

Labour Rate (Child of Price Policy)
├── beren_labourrateseffectiveid (Primary Key)
├── beren_pricingpolicy (PolicyId lookup)
├── beren_labourrole (RoleId lookup)
├── beren_validfrom (StartDate - required)
├── beren_validto (EndDate - nullable)
├── beren_rateperhour (Rate - money)
└── transactioncurrencyid (Currency)
```

## Business Rules

### 1. Non-Overlapping Date Ranges

For any `(PolicyId, RoleId)` combination:
- Date intervals in Labour Rate must NOT overlap
- **Touching is OK**: `prev.EndDate < next.StartDate` 
- **Same-day overlap is NOT OK**: `prev.EndDate = next.StartDate`

### 2. Deterministic Resolution

Given `(PolicyId, RoleId, EffectiveOn)`:
- Select single row where `StartDate <= EffectiveOn <= EndDate` (or EndDate is null)
- **No match** → "no rate" error
- **Multiple matches** → "data integrity" error (shouldn't happen if validation works)

## Example Dataset

### Seed Data

**Price Policy**: "Default 2025" (PolicyId: `guid-policy-1`)
**Labour Role**: "Main Electrician" (RoleId: `guid-role-1`)

**Labour Rates**:
1. Rate ID: `guid-rate-1`
   - Policy: `guid-policy-1`
   - Role: `guid-role-1`
   - ValidFrom: `2025-01-01`
   - ValidTo: `2025-06-30`
   - Rate: £45.00/hour

2. Rate ID: `guid-rate-2`
   - Policy: `guid-policy-1`
   - Role: `guid-role-1`
   - ValidFrom: `2025-07-01`
   - ValidTo: `null` (open-ended)
   - Rate: £50.00/hour

## Resolution Examples

### Example 1: Mid-Year Date (Valid)
- **Input**: PolicyId=`guid-policy-1`, RoleId=`guid-role-1`, EffectiveOn=`2025-04-15`
- **Resolution**: Returns Rate ID `guid-rate-1` (£45.00/hour)
- **Logic**: `2025-01-01 <= 2025-04-15 <= 2025-06-30` ✅

### Example 2: Second Half Year (Valid)
- **Input**: PolicyId=`guid-policy-1`, RoleId=`guid-role-1`, EffectiveOn=`2025-09-15`
- **Resolution**: Returns Rate ID `guid-rate-2` (£50.00/hour)
- **Logic**: `2025-07-01 <= 2025-09-15 <= null` ✅

### Example 3: Future Date (Valid)
- **Input**: PolicyId=`guid-policy-1`, RoleId=`guid-role-1`, EffectiveOn=`2026-12-31`
- **Resolution**: Returns Rate ID `guid-rate-2` (£50.00/hour)
- **Logic**: Open-ended range covers all future dates ✅

## Validation Implementation

### Plugin: `LabourRateOverlapPlugin`

**Registration**:
- Entity: `beren_labourrateseffective`
- Messages: `Create`, `Update`
- Stage: Post-operation (synchronous)
- Filtering Attributes: `beren_pricingpolicy`, `beren_labourrole`, `beren_validfrom`, `beren_validto`

**FetchXML Query**:
```xml
<fetch>
  <entity name="beren_labourrateseffective">
    <attribute name="beren_labourrateseffectiveid" />
    <attribute name="beren_validfrom" />
    <attribute name="beren_validto" />
    <filter type="and">
      <condition attribute="beren_pricingpolicy" operator="eq" value="{PolicyId}" />
      <condition attribute="beren_labourrole" operator="eq" value="{RoleId}" />
      <!-- For updates only: -->
      <condition attribute="beren_labourrateseffectiveid" operator="ne" value="{CurrentRecordId}" />
    </filter>
  </entity>
</fetch>
```

### Error Messages

**Format**: `OVERLAP: Existing [yyyy-MM-dd .. yyyy-MM-dd/null] for Role=<RoleName>, Policy=<PolicyName>`

**Examples**:
- `OVERLAP: Existing [2025-01-01 .. 2025-06-30] for Role=Main Electrician, Policy=Default 2025`
- `OVERLAP: Existing [2025-07-01 .. null] for Role=Apprentice, Policy=Commercial 2025`

## Test Scenarios

### ✅ Valid Cases (Should Pass)
1. **Consecutive ranges**: `[2025-01-01..2025-06-30]` → `[2025-07-01..null]`
2. **Gap between ranges**: `[2025-01-01..2025-05-31]` → `[2025-07-01..2025-12-31]`
3. **Single open-ended**: `[2025-01-01..null]` (no other ranges)

### ❌ Invalid Cases (Should Block)
1. **Same-day overlap**: `[2025-01-01..2025-06-30]` → `[2025-06-30..2025-12-31]`
2. **Inside overlap**: `[2025-01-01..2025-12-31]` → `[2025-06-01..2025-08-31]`
3. **Surrounding overlap**: `[2025-06-01..2025-08-31]` → `[2025-01-01..2025-12-31]`
4. **Duplicate exact range**: `[2025-01-01..2025-06-30]` → `[2025-01-01..2025-06-30]`
5. **Multiple open-ended**: `[2025-01-01..null]` → `[2025-07-01..null]`

## Domain Events (Future Enhancement)

Consider implementing these domain events:
- `LabourRateCreated`
- `LabourRateUpdated`
- `LabourRateOverlapDetected`
- `PricingPolicyActivated`

## Deployment Notes

- **Environment**: Dev/Test only (no Production)
- **Assembly**: `EG.LabourPricing.Validation.dll` (.NET Framework 4.8)
- **Registration**: Manual via Plugin Registration Tool
- **Future**: Include in ALM pipeline automation

## Context Boundaries

This validation is **save-time** only. Separate concerns:
- **Quote/ACI/BOM Snapshot Stamping**: Handled separately
- **Price Resolution Service**: Different aggregate
- **Currency Conversion**: External service integration

## Invariants Maintained

1. No temporal overlaps within `(PolicyId, RoleId)` scope
2. Deterministic rate resolution for any effective date
3. Data integrity across Create/Update operations
4. Clear error messaging for business users