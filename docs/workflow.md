# memex Workflow

```mermaid
flowchart TB
    subgraph External["External Sources"]
        Slack[(Slack)]
        Linear[(Linear)]
        Notion[(Notion)]
        GCal[(Google Calendar)]
        SessionLog[(Claude Session Logs)]
    end

    subgraph Collect["Collect Layer"]
        direction LR
        SyncSlack["/sync-slack"]
        SyncLinear["/sync-linear"]
        SyncNotion["/sync-notion"]
        SyncSessions["/sync-sessions"]
    end

    subgraph Orchestrate["Orchestrator"]
        SyncAll["/sync-all"]
    end

    subgraph Vault["Obsidian Vault"]
        subgraph Snapshot["snapshot/YYYY-MM-DD/"]
            SlackMD["slack.md"]
            LinearMD["linear.md"]
            StandupMD["standup.md"]
            ClaudeLog["claude-log.md"]
        end
        subgraph Inbox["inbox/"]
            NotionMD["notion/*.md"]
        end
        subgraph Journal["journal/"]
            Timeline["timeline/YYYY-MM-DD.md"]
            Daily["daily/YYYY-MM-DD.md"]
            Weekly["weekly/YYYY-MM-DD.md"]
            Monthly["monthly/YYYY-MM.md"]
        end
        subgraph Context["context/"]
            ContextFiles["me.md / projects.md\ndomain.md / ..."]
        end
        MemoryMD["MEMORY.md"]
    end

    subgraph Process["Process Layer"]
        DailyPlanner["/daily-planner"]
        JournalSkill["/journal"]
        Reflect["/reflect"]
        Distill["/distill"]
        SyncMemory["/sync-memory"]
    end

    subgraph Output["Commit"]
        CommitVault["scripts/commit-vault.sh"]
    end

    %% External -> Collect
    Slack --> SyncSlack
    Linear --> SyncLinear
    Notion --> SyncNotion
    SessionLog --> SyncSessions

    %% Orchestrator
    SyncAll -->|parallel| SyncSlack
    SyncAll -->|parallel| SyncLinear
    SyncAll -->|parallel| SyncNotion
    SyncAll -->|after sync| SyncSessions

    %% Collect -> Vault
    SyncSlack --> SlackMD
    SyncLinear --> LinearMD
    SyncNotion --> StandupMD
    SyncNotion --> NotionMD
    SyncSessions --> ClaudeLog

    %% Process -> Vault
    GCal --> DailyPlanner
    SlackMD -.->|reads| DailyPlanner
    LinearMD -.->|reads| DailyPlanner
    DailyPlanner --> Timeline

    JournalSkill -->|append| Timeline

    Snapshot -.->|reads| Reflect
    Timeline -.->|reads| Reflect
    Reflect --> Daily
    Reflect --> Weekly
    Reflect --> Monthly

    Snapshot -.->|reads| Distill
    Journal -.->|reads| Distill
    Distill --> ContextFiles

    Context -.->|reads| SyncMemory
    SyncMemory --> MemoryMD

    %% Commit
    Vault --> CommitVault

    %% Styling
    classDef external fill:#e1f5fe,stroke:#0288d1,color:#01579b
    classDef collect fill:#fff3e0,stroke:#f57c00,color:#e65100
    classDef process fill:#f3e5f5,stroke:#7b1fa2,color:#4a148c
    classDef vault fill:#e8f5e9,stroke:#388e3c,color:#1b5e20
    classDef orch fill:#fce4ec,stroke:#c62828,color:#b71c1c

    class Slack,Linear,Notion,GCal,SessionLog external
    class SyncSlack,SyncLinear,SyncNotion,SyncSessions collect
    class DailyPlanner,JournalSkill,Reflect,Distill,SyncMemory process
    class SyncAll orch
```

## Data Flow Summary

| Layer | Skills | Description |
|-------|--------|-------------|
| **Collect** | sync-slack, sync-linear, sync-notion, sync-sessions | External sources -> snapshot/ |
| **Orchestrate** | sync-all | Runs collect skills in parallel |
| **Capture** | journal, daily-planner | User input + calendar -> journal/ |
| **Synthesize** | reflect, distill | snapshot + journal -> context/ |
| **Maintain** | sync-memory | Keep MEMORY.md consistent |
