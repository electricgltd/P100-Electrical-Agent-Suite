# JSON → XML Mapping (Grounding File)

**Scope:** Defines how `schema_snapshots/*.entity.json` maps to `out/entities/*.xml`.

## Mapping matrix (high‑level)
JSON source (snapshot)XML target (unpacked)File path (output)CardinalityNotes / DefaultsEntity logical nameEntity name elementout/entities/<logicalName>.xml → /Entity/Name1Also drives the output filenameEntity display nameEntity display label/Entity/DisplayName1Defaults to logicalName if absentEntity descriptionEntity description/Entity/Description1Empty string allowedFields arrayAttributes collection/Entity/Attributes/*Attribute0..NSorted by field name (A→Z)Field nameAttribute logical name/Entity/Attributes/*Attribute/LogicalName1Also used as <DisplayName> (no per‑field UI label yet)Field descriptionAttribute description/Entity/Attributes/*Attribute/Description0..1Empty if absentField type = stringString attribute/Entity/Attributes/StringAttribute0..N<MaxLength> defaults to 100Field type = numberDecimal attribute/Entity/Attributes/DecimalAttribute0..NDefaults: Precision=2, Min=-9,999,999,999, Max=9,999,999,999Field type = booleanBoolean attribute/Entity/Attributes/BooleanAttribute0..NLabels default to Yes/NoField type = dateDateTime attribute/Entity/Attributes/DateTimeAttribute0..NBehavior defaults to DateOnlyField type = lookupLookup attribute/Entity/Attributes/LookupAttribute0..NTargets listed under <Targets>/<Target>Field type = optionsetPicklist attribute/Entity/Attributes/PicklistAttribute0..NIncludes inline <LocalOptionSet> when optionset is providedLocal optionsets listOption set catalog/Entity/OptionSets/LocalOptionSet0..NSorted by name (A→Z)Optionset option valueOption numeric id…/LocalOptionSet/Options/Option/Value1Sorted by value (0→N)Optionset option labelOption label…/LocalOptionSet/Options/Option/Label1Free text, XML‑escaped

## Detailed path map
1) Entity‑level
$.logicalName           → /Entity/Name/text()
$.displayName           → /Entity/DisplayName/text()
$.description           → /Entity/Description/text()
Output file: out/entities/<logicalName>.xml
If displayName missing → uses logicalName.
2) Fields collection
$.fields[*]                                 → /Entity/Attributes/*Attribute
$.fields[*].name                            → …/LogicalName/text()
$.fields[*].description                     → …/Description/text()
Determinism: fields are sorted by name (A→Z) before emission.
DisplayName: currently equals name (no separate UI label key yet).
3) Per‑type mappings
String
$.fields[?(@.type=='string')]               → /Entity/Attributes/StringAttribute
  .maxLength (not yet in schema)            → (default emitted) <MaxLength>100</MaxLength>
Number
$.fields[?(@.type=='number')]               → /Entity/Attributes/DecimalAttribute
  .precision                                → …/Precision/text()    (default 2)
  .min                                      → …/Min/text()          (default -9999999999)
  .max                                      → …/Max/text()          (default  9999999999)
Boolean
$.fields[?(@.type=='boolean')]              → /Entity/Attributes/BooleanAttribute
  (defaults)                                → <TrueLabel>Yes</TrueLabel><FalseLabel>No</FalseLabel>
Date
$.fields[?(@.type=='date')]                 → /Entity/Attributes/DateTimeAttribute
  .behavior ∈ {DateOnly,UserLocal}         → …/Behavior/text()     (default DateOnly)
Lookup
$.fields[?(@.type=='lookup')]               → /Entity/Attributes/LookupAttribute
  .targets[*]                               → …/Targets/Target/text()
Optionset (Picklist)
$.fields[?(@.type=='optionset')]            → /Entity/Attributes/PicklistAttribute
  .optionset (name)                         → inline <LocalOptionSet @name="…"> included under PicklistAttribute
4) Local optionsets catalog
$.optionsets[*]                             → /Entity/OptionSets/LocalOptionSet[@name='…']
$.optionsets[*].name                        → @name
$.optionsets[*].options[*].value            → …/Options/Option/Value/text()
$.optionsets[*].options[*].label            → …/Options/Option/Label/text()
Determinism: sets are sorted by name; entries by value (numeric asc).
Duplication by design: the same <LocalOptionSet> appears:

once under /Entity/OptionSets/… (catalog),
again inline under any PicklistAttribute that references it.

## How it’s put together
Read one *.entity.json (the “snapshot”) per Dataverse entity from schema_snapshots/.
Validate against schema_snapshots/entity.schema.json (strict, draft 2020‑12).
Determine output file path as out/entities/<logicalName>.xml.
Order consistently for deterministic diffs:

Fields by name (A→Z)
Optionsets by name (A→Z)
Options inside each optionset by value (0→N)


Escape all XML text (&, <, >, ", ') to keep output well‑formed.
Emit envelope:

<Entity version="1.0"> with <Name>, <DisplayName>, <Description>
<Attributes> block
<OptionSets> catalog


Emit fields:

One *Attribute element per field (type switch)
Common children: <LogicalName>, <DisplayName> (mirrors name), <Description>
Type‑specific children:

String → <MaxLength> (currently fixed 100)
Number → <Precision>, <Min>, <Max> (defaults applied when absent)
Boolean → <TrueLabel>Yes</TrueLabel>, <FalseLabel>No</FalseLabel>
Date → <Behavior> (default DateOnly)
Lookup → <Targets>/<Target> for each targets entry
Optionset → <PicklistAttribute> + inline <LocalOptionSet> of the named set




Emit catalog (/Entity/OptionSets): every local optionset is reproduced once at entity scope (for discoverability and tooling).

This behavior matches the deterministic Node generator you’re using in the repo (the script we added earlier), and the modelling choices in your P108 Loop specs for Variant Type Master, Project, Circuit Instance, and Task Units.
## Edge cases & verification
Missing logicalName → generation should error (no output).
Unknown optionset name referenced by a field → treat as error (prevents dangling references).
Lookup without targets → generator emits empty <Targets/> or errors (prefer error for clarity).
Empty fields / optionsets → allowed; emits empty sections.
Only these field types are valid: string, number, boolean, date, lookup, optionset (others should error).
Defaults are explicit in XML when JSON omits values (see numeric, date, boolean, string).