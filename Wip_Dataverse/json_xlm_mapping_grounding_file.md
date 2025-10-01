# JSON → XML Mapping (Grounding File)

**Scope:** Defines how `schema_snapshots/*.entity.json` maps to the deterministic XML written to `out/entities/*.xml`.

**Last updated:** 2025‑09‑30

---

## Table of contents
- [JSON → XML Mapping (Grounding File)](#json--xml-mapping-grounding-file)
  - [Table of contents](#table-of-contents)
  - [Detailed path map](#detailed-path-map)
  - [2.1) Entity‑level](#21-entitylevel)
  - [2.2 Fields collection](#22-fields-collection)
  - [2.3) Per‑type mappings](#23-pertype-mappings)
  - [2.4) Local optionsets catalog](#24-local-optionsets-catalog)
  - [3) How it’s put together](#3-how-its-put-together)
  - [4) Edge cases \& verification](#4-edge-cases--verification)
  - [5) Worked Example — p100\_variant](#5-worked-example--p100_variant)
    - [Why this change?](#why-this-change)

JSON source (snapshot)XML target (unpacked)File path (output)CardinalityNotes / DefaultsEntity logical nameEntity name elementout/entities/<logicalName>.xml → /Entity/Name1Also drives the output filename| Entity display name | Entity display label | `/Entity/DisplayName` | 1 | Defaults to `logicalName` if absent |
| Entity description | Entity description | `/Entity/Description` | 1 | Empty string allowed |
| Fields array | Attributes collection | `/Entity/Attributes/*Attribute` | 0..N | **Sorted by field `name` (A→Z)** |
| Field `name` | Attribute logical name | `/Entity/Attributes/*Attribute/LogicalName` | 1 | Also used as `<DisplayName>` (no per‑field UI label yet) |
| Field `description` | Attribute description | `/Entity/Attributes/*Attribute/Description` | 0..1 | Empty if absent |
| Field type = `string` | String attribute | `/Entity/Attributes/StringAttribute` | 0..N | `<MaxLength>` defaults to **100** |
| Field type = `number` | Decimal attribute | `/Entity/Attributes/DecimalAttribute` | 0..N | Defaults: `Precision=2`, `Min=-9,999,999,999`, `Max=9,999,999,999` |
| Field type = `boolean` | Boolean attribute | `/Entity/Attributes/BooleanAttribute` | 0..N | Labels default to **Yes/No** |
| Field type = `date` | DateTime attribute | `/Entity/Attributes/DateTimeAttribute` | 0..N | `Behavior` defaults to **DateOnly** |
| Field type = `lookup` | Lookup attribute | `/Entity/Attributes/LookupAttribute` | 0..N | Targets listed under `<Targets>/<Target>` |
| Field type = `optionset` | Picklist attribute | `/Entity/Attributes/PicklistAttribute` | 0..N | Includes **inline** `<LocalOptionSet>` when `optionset` is provided |
| Local optionsets list | Option set catalog | `/Entity/OptionSets/LocalOptionSet` | 0..N | **Sorted by `name` (A→Z)** |
| Optionset option value | Option numeric id | `…/LocalOptionSet/Options/Option/Value` | 1 | **Sorted by `value` (0→N)** |
| Optionset option label | Option label | `…/LocalOptionSet/Options/Option/Label` | 1 | Free text, XML‑escaped |

---

## Detailed path map

## 2.1) Entity‑level

$.logicalName           → /Entity/Name/text()
$.displayName           → /Entity/DisplayName/text()
$.description           → /Entity/Description/text()

Output file: out/entities/<logicalName>.xml
If displayName missing → uses logicalName.

## 2.2 Fields collection

$.fields[*]                 → /Entity/Attributes/*Attribute
$.fields[*].name            → …/LogicalName/text()
$.fields[*].description     → …/Description/text()$.fields[*]                 → /Entity/

Determinism: fields are sorted by name (A→Z) before emission.
DisplayName: equals name (no separate UI label in JSON today).

## 2.3) Per‑type mappings

String

$.fields[?(@.type=='string')]           → /Entity/Attributes/StringAttribute

Number

$.fields[?(@.type=='number')]           → /Entity/Attributes/DecimalAttribute
  .precision                            → …/Precision/text()      (default 2)
  .min                                  → …/Min/text()            (default -9999999999)
  .max                                  → …/Max/text()            (default  9999999999)

Boolean

$.fields[?(@.type=='boolean')]          → /Entity/Attributes/BooleanAttribute
  (defaults)                            → <TrueLabel>Yes</TrueLabel><FalseLabel>No</FalseLabel>

Date

$.fields[?(@.type=='date')]             → /Entity/Attributes/DateTimeAttribute
  .behavior ∈ {DateOnly,UserLocal}      → …/Behavior/text()       (default DateOnly)

Lookup

$.fields[?(@.type=='lookup')]           → /Entity/Attributes/LookupAttribute
  .targets[*]                           → …/Targets/Target/text()

Optionset (Picklist)

$.fields[?(@.type=='optionset')]        → /Entity/Attributes/PicklistAttribute
  .optionset (name)                     → inline <LocalOptionSet @name="…"> included under PicklistAttribute

## 2.4) Local optionsets catalog

$.optionsets[*]                         → /Entity/OptionSets/LocalOptionSet[@name='…']
$.optionsets[*].name                    → @name
$.optionsets[*].options[*].value        → …/Options/Option/Value/text()
$.optionsets[*].options[*].label        → …/Options/Option/Label/text()

Determinism: sets sorted by name; entries by numeric value (ascending).
Duplication by design: the same <LocalOptionSet> appears:
    1. under /Entity/OptionSets/… (catalog) and
    2. inline under any <PicklistAttribute> that references it.
   

## 3) How it’s put together

  1. Read one snapshot JSON per entity from schema_snapshots/.
  2. Validate against schema_snapshots/entity.schema.json (strict, draft 2020‑12).
  3. Derive output path: out/entities/<logicalName>.xml.
  4. Deterministic ordering for stable diffs:
   - fields by name (A→Z)
   - optionsets by name (A→Z)
   - options by value (0→N)
  5. Escape XML text (&, <, >, ", ').
  6. Envelope:
  <Entity version="1.0"> → <Name>, <DisplayName>, <Description>, <Attributes>, <OptionSets>.
  7. Attributes: one *Attribute per field with common children plus type‑specific elements.
  8. Catalog: all local optionsets reproduced under /Entity/OptionSets.
   
## 4) Edge cases & verification
- Missing logicalName → stop with error (no output).
- Unknown optionset reference → error (prevents dangling references).
- Lookup with no targets → prefer error over empty <Targets/>.
- Empty fields / optionsets → allowed; emits empty sections.
- Allowed field types: string, number, boolean, date, lookup, optionset (others error)
- Defaults are explicit in XML (string/number/date/boolean as described).

## 5) Worked Example — p100_variant

Input JSON (schema_snapshots/p100_variant.entity.json)
  "logicalName": "p100_variant",
  "displayName": "Variant",
  "description": "Defines product variants",
  "fields": [
    { "name": "variant_name", "type": "string", "description": "Variant name" },
    { "name": "variant_category", "type": "optionset", "optionset": "variant_category_set" },
    { "name": "related_product", "type": "lookup", "targets": ["p100_product"] }
  ],
  "optionsets": [
    {
      "name": "variant_category_set",
      "options": [
        { "value": 1, "label": "Standard" },
        { "value": 2, "label": "Premium" }
      ]
    }
  ]

Output XML (out/entities/p100_variant.xml)

<Entity version="1.0">
  <Name>p100_variant</Name>
  <DisplayName>Variant</DisplayName>
  <Description>Defines product variants</Description>

  <Attributes>
    <!-- Text field -->
    <StringAttribute>
      <LogicalName>variant_name</LogicalName>
      <DisplayName>variant_name</DisplayName>
      <Description>Variant name</Description>
      <MaxLength>100</MaxLength>
    </StringAttribute>

    <!-- Choice (Picklist) field -->
    <PicklistAttribute>
      <LogicalName>variant_category</LogicalName>
      <DisplayName>variant_category</DisplayName>
      <LocalOptionSet name="variant_category_set">
        <Options>
          <Option><Value>1</Value><Label>Standard</Label></Option>
          <Option><Value>2</Value><Label>Premium</Label></Option>
        </Options>
      </LocalOptionSet>
    </PicklistAttribute>

    <!-- Lookup field -->
    <LookupAttribute>
      <LogicalName>related_product</LogicalName>
      <DisplayName>related_product</DisplayName>
      <Targets>
        <Target>p100_product</Target>
      </Targets>
    </LookupAttribute>
  </Attributes>

  <!-- Global OptionSet catalog -->
  <OptionSets>
    <LocalOptionSet name="variant_category_set">
      <Options>
        <Option><Value>1</Value><Label>Standard</Label></Option>
        <Option><Value>2</Value><Label>Premium</Label></Option>
      </Options>
    </LocalOptionSet>
  </OptionSets>
</Entity>

---

### Why this change?
- GitHub will now render the **matrix as a proper table** rather than a single wrapped line.  
- All **paths are fenced** for monospaced readability.  
- The doc is **copy‑paste ready** for reviewers and future you.

If you want, I can also supply a tiny **MD linter** rule (or a pre‑commit hook) to ensure tables and code fences are present before merges.