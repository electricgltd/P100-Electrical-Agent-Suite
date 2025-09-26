# Copilot Space Context Pack

## Operating Note / Context Pack

This document serves as the comprehensive context pack for the P100 Electrical Agent Suite Copilot Space, providing operational guidance, knowledge references, and structured context for all agent interactions.

## Overview

The P100 Electrical Agent Suite is designed for NICEIC electrical contractors, featuring three primary agents:
- **EA** (Electrical Assistant) - Orchestrates workflows and provides electrical expertise
- **PA** (Planning Assistant) - Handles project planning and resource allocation  
- **DCA** (Design & Costing Assistant) - Manages electrical design and cost estimation

## Operational Context

### Agent Coordination
The agents operate in a coordinated manner with EA serving as the primary orchestrator. Each agent has specific domains of expertise while maintaining awareness of the overall project context.

### Knowledge Sources
- **Industry Standards**: NICEIC guidelines, IET regulations, BS 7671 standards
- **Reference Materials**: EICRs, installation guides, testing procedures
- **Templates**: Power Automate document templates for automated paperwork generation
- **Project Documentation**: Grounding files, operational procedures, compliance notes

### Workflow Patterns
1. **Assessment Phase**: Initial evaluation of electrical requirements
2. **Planning Phase**: Resource allocation and project timeline development
3. **Design Phase**: Technical specifications and system design
4. **Costing Phase**: Material and labor cost estimation
5. **Documentation Phase**: Compliance documentation and reporting

## Grounding File References

### Electrical Assistant (EA)
- **Primary Functions**: Workflow orchestration, technical guidance, compliance oversight
- **Knowledge Areas**: EICR processes, installation procedures, testing protocols
- **Integration Points**: Links with PA for planning, DCA for technical specifications

### Planning Assistant (PA)
- **Primary Functions**: Project timeline management, resource planning
- **Knowledge Areas**: Material requirements, labor allocation, project coordination
- **Integration Points**: Coordinates with EA for technical requirements, DCA for design constraints

### Design and Costing Assistant (DCA)
- **Primary Functions**: Technical design, cost analysis, specification development
- **Knowledge Areas**: Electrical system design, material costs, regulatory compliance
- **Integration Points**: Receives requirements from EA, provides specifications to PA

## Compliance and Standards

### Regulatory Framework
- **NICEIC Compliance**: All work must meet NICEIC standards and certification requirements
- **BS 7671 Adherence**: Electrical installations must comply with current BS 7671 regulations
- **Documentation Standards**: Proper certification and testing documentation required

### Quality Assurance
- **Testing Protocols**: Standardized testing procedures for all installations
- **Certification Process**: Proper documentation and sign-off procedures
- **Change Management**: Controlled process for modifications and updates

## Document Templates

### Power Automate Integration
The suite integrates with Power Automate for automated document generation:
- **EICR Templates**: Standardized Electrical Installation Condition Reports
- **Certificate Templates**: Installation and testing certificates
- **Quote Templates**: Standardized pricing documents
- **Project Reports**: Progress and completion documentation

### Template Categories
1. **Inspection Documents**: EICR forms, testing schedules, compliance checklists
2. **Installation Documents**: Work orders, material lists, progress reports
3. **Certification Documents**: Completion certificates, test results, warranty documentation
4. **Business Documents**: Quotes, invoices, project summaries

## Change Log

### Version History
- **Initial Release**: Base context pack with core operational procedures
- **Update Pending**: Integration with specific Copilot Space content from user

## Usage Guidelines

### Agent Interaction
When interacting with the agents, users should:
1. Provide clear project requirements and constraints
2. Specify compliance and regulatory requirements
3. Indicate preferred documentation formats
4. Communicate any special considerations or limitations

### Best Practices
- **Context Sharing**: Ensure all relevant context is shared across agents
- **Documentation**: Maintain proper documentation throughout all phases
- **Compliance**: Verify regulatory compliance at each stage
- **Quality Control**: Implement quality checks and reviews

## Notes

> **Important**: This context pack is designed to work with the specific content provided in the Copilot Space. The above structure serves as a foundation and should be populated with the actual Operating Note / Context Pack content from the user's Space environment.

> **Integration**: This file integrates with the existing grounding files in `/agents/EA/Grounding Files/`, `/agents/PA/`, and `/agents/DCA/` directories.

---

**Document Status**: Template - Awaiting specific Copilot Space content integration  
**Last Updated**: [Current Date]  
**Version**: 1.0  
**Owner**: P100 Electrical Agent Suite Project