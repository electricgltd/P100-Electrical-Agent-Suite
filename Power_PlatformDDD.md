```mermaid
graph TD
    %% Solutions stacked vertically
    S1[Solution: Core Schema]
    S2[Solution: Automation]
    S3[Solution: Apps]
    S4[Solution: Copilot Agents]
    S5[Solution: ALM & Governance]

    %% Components under each solution
    S1 --> |contains| P1[Dataverse Tables]
    S1 --> P2[Choices & Option Sets]
    S1 --> P3[Relationships & Keys]

    S2 --> |contains| F1[Power Automate Flows]
    S2 --> F2[Business Rules]
    S2 --> F3[Calculated & Rollup Columns]

    S3 --> |contains| A1[Model-driven App]
    S3 --> A2[Forms & Views]

    S4 --> |contains| C1[Copilot Studio Agent: Design & Costing]
    S4 --> C2[Copilot Studio Agent: Planning Assistant]

    S5 --> |contains| G1[Environment Variables]
    S5 --> G2[Connection References]
    S5 --> G3[Deployment Pipelines]

    %% Stack order
    S1 --> S2
    S2 --> S3
    S3 --> S4
    S4 --> S5 
  