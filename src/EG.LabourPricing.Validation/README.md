# EG Labour Pricing Validation Plugin

This plugin validates that Labour Rate effective date ranges do not overlap for the same (PolicyId, RoleId) combination, ensuring data integrity in the pricing system.

## Business Rules

1. **No overlaps**: For any `(PolicyId, RoleId)`, intervals in **Labour Rate** must not overlap
   - *Touching is OK*: `prev.EndDate < next.StartDate` (consecutive ranges)
   - *Same-day overlap is NOT OK*: `prev.EndDate = next.StartDate`

2. **Resolution**: Given `(PolicyId, RoleId, EffectiveOn)`, should return exactly one rate
   - Null `EndDate` represents an open-ended (infinite) range

## Plugin Registration

### Entity and Message
- **Entity**: `beren_labourrateseffective` (Labour Rates Effective)
- **Messages**: `Create`, `Update`
- **Stage**: Post-operation (synchronous)
- **Mode**: Synchronous

### Using Plugin Registration Tool (PRT)

1. **Assembly Registration**:
   - Assembly: `EG.LabourPricing.Validation.dll`
   - Isolation Mode: Sandbox
   - Location: Database

2. **Plugin Step Registration**:
   - Message: `Create`
   - Primary Entity: `beren_labourrateseffective`
   - Event Pipeline Stage: Post-operation
   - Execution Mode: Synchronous
   - Filtering Attributes: `beren_pricingpolicy,beren_labourrole,beren_validfrom,beren_validto`

3. **Repeat for Update Message**:
   - Message: `Update`
   - Same settings as above

### Using Power Platform CLI (pac)

```bash
# Pack the assembly (after building in Visual Studio/dotnet build)
pac plugin init

# Create connection to your environment
pac auth create --url https://yourorg.crm11.dynamics.com

# Deploy the plugin
pac plugin push --settings-file plugin-settings.json
```

### Manual Registration Steps

1. Build the solution in Release mode
2. Copy `EG.LabourPricing.Validation.dll` to your deployment location
3. Open Plugin Registration Tool
4. Connect to your Dataverse environment
5. Register new assembly → Select the DLL file
6. Register new step for the plugin class `LabourRateOverlapPlugin`

## FetchXML Query Used

The plugin uses this QueryExpression to find existing Labour Rates:

```xml
<fetch>
  <entity name="beren_labourrateseffective">
    <attribute name="beren_labourrateseffectiveid" />
    <attribute name="beren_validfrom" />
    <attribute name="beren_validto" />
    <filter type="and">
      <condition attribute="beren_pricingpolicy" operator="eq" value="{PolicyId}" />
      <condition attribute="beren_labourrole" operator="eq" value="{RoleId}" />
      <!-- For updates: exclude current record -->
      <condition attribute="beren_labourrateseffectiveid" operator="ne" value="{CurrentRecordId}" />
    </filter>
  </entity>
</fetch>
```

## Error Messages

When overlap is detected, the plugin throws `InvalidPluginExecutionException` with message format:

```
OVERLAP: Existing [yyyy-MM-dd .. yyyy-MM-dd/null] for Role=<RoleName>, Policy=<PolicyName>
```

Example:
```
OVERLAP: Existing [2025-01-01 .. 2025-06-30] for Role=Main Electrician, Policy=Default 2025
```

## Testing Scenarios

### Valid Cases (Should Pass)
- Consecutive ranges: `[2025-01-01..2025-06-30]` then `[2025-07-01..null]`
- Gap between ranges: `[2025-01-01..2025-05-31]` then `[2025-07-01..2025-12-31]`

### Invalid Cases (Should Block with Error)
- Same-day overlap: `[2025-01-01..2025-06-30]` then `[2025-06-30..2025-12-31]`
- Inside overlap: `[2025-01-01..2025-12-31]` then `[2025-06-01..2025-08-31]`
- Surrounding overlap: `[2025-06-01..2025-08-31]` then `[2025-01-01..2025-12-31]`
- Duplicate exact range: `[2025-01-01..2025-06-30]` then `[2025-01-01..2025-06-30]`

## Development Notes

- **Environment**: Dev/Test only (no Production deployment planned yet)
- **Future**: Will move to pipeline-based deployment
- **Dependencies**: .NET 6, Microsoft CRM SDK
- **Testing**: Unit tests for core logic, manual integration testing in Dataverse

## Deployment with ALM Pipeline

Future enhancement - the plugin will be included in the solution ALM pipeline:

1. Build step compiles the plugin DLL
2. Solution packaging includes the plugin assembly
3. Automated deployment to Test environment
4. Plugin steps registered via solution import

Currently: Manual registration using Plugin Registration Tool during Dev/Test phase.