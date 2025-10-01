```mermaid
graph TD
    %% Aggregate Roots
    Project["Aggregate Root: Project"]
    Assembly["Aggregate Root: Assembly Template"]
    Circuit["Aggregate Root: Circuit Instance"]
    TaskUnit["Aggregate Root: Task Unit"]
    Material["Aggregate Root: Material"]

    %% Project Aggregate
    Project --> PD[Project Documents]
    Project --> CF[Compliance Flags]
    Project --> ST[Status & Triggers]

    %% Assembly Aggregate
    Assembly --> AP[Parameters JSON]
    Assembly --> ATU[Linked Task Units]

    %% Circuit Aggregate
    Circuit --> AM[ACI_Material Lines]
    Circuit --> EP[Endpoint Links]

    %% Task Unit Aggregate
    TaskUnit --> VR[Variant Rules]
    TaskUnit --> DU[Duration & Job Type]

    %% Material Aggregate
    Material --> UOM[UoM & Conversion Rules]
    Material --> PP[Pricing Policy]

    %% Linking Table
    TUM["Link: Task Unit ↔ Material"] --> QR[Quantity Rules]
    TUM --> WR[Waste % & Pack Rounding]

    %% Relationships between aggregates
    Project --- Assembly
    Project --- Circuit
    Assembly --- TaskUnit
    TaskUnit --- Material
    TUM --- TaskUnit
    TUM --- Material 