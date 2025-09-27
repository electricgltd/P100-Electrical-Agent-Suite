```mermaid
flowchart TB
  A[Loop SetUp]-->B[GitHub SetUp]
  B --> C[Issue (scoped & labelled)]
  C --> D[Branch feature/&lt;purpose&gt;]
  D --> E[Codespace (Agent Mode)]
  E --> F[Commits with traceable messages]
  F --> G[Draft PR linked to Issue]
  G --> H[Checks & Quality Gates]
  H --> I[Manual/CLI Deploy to Dev=Test]
  I --> J[Document update (repo + Loop)]
  J --> K[Close Issue & Merge PR]
