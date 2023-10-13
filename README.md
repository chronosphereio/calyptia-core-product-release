# core-product-release

A public repository handling the integrated release of the various
components making up a Calyptia Core product version.

## Release workflow

The following directed graph demonstrates how and where release versions flow between components.
Each arrow indicates a PR.

```mermaid
graph TD;
   LM[LUA Modules]-- PR on release -->CFB[Core Fluent Bit];
   LM[LUA Modules]-- PR on release -->CLS[Cloud LUA Sandbox];
   LM[LUA Modules]-- PR on release -->CPR[Core Product Release];

   CFB[Core Fluent Bit]-- PR on release -->CO[Core Operator];
   CFB[Core Fluent Bit]-- PR on release -->CPR[Core Product Release];

   CO[Core Operator]-- PR on release -->COC[Core Operator chart];
   CO[Core Operator]-- PR on release -->CLI;
   CO[Core Operator]-- PR on release -->COR[Core Operator releases];
   CO[Core Operator]-- PR on release -->CPR[Core Product Release];

   COC[Core Operator chart]-->PC[Public chart];

   Cloud-->CPR[Core Product Release];
   Frontend-->CPR[Core Product Release];
   CLS[Cloud LUA Sandbox]-- PR on release -->CPR[Core Product Release];

   CPR[Core Product Release]-- cron poll -->SHC[Self hosted chart];
   SHC[Self hosted chart]-- PR on release -->PC[Public chart];
```

The Core Product Release repository drives the self-hosted chart updates via a cron job.
All other PRs are created directly on release from the source repository.
