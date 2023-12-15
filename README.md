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

   CSIC[Core Sidecar Ingest Check]-- PR on release -->CO[Core Operator];
   CSIC[Core Sidecar Ingest Check]-- PR on release -->CPR[Core Product Release];

   CO[Core Operator]-- PR on release -->COC[Core Operator chart];
   CO[Core Operator]-- PR on release -->CLI;
   CO[Core Operator]-- PR on release -->COR[Core Operator releases];
   CO[Core Operator]-- PR on release -->CPR[Core Product Release];

   COC[Core Operator chart]-- PR on commit -->PC[Public chart];

   CLI-- PR on release -->CPR[Core Product Release];
   Cloud-- PR on release -->CPR[Core Product Release];
   Frontend-- PR on release -->CPR[Core Product Release];
   CLS[Cloud LUA Sandbox]-- PR on release -->CPR[Core Product Release];

   CPR[Core Product Release]-- PR on release -->SHC[Self hosted chart];
   SHC[Self hosted chart]-- PR on commit -->PC[Public chart];

   CPR[Core Product Release]-- tag -->CD[Core Docs];
```

All target PRs are created directly on release from the source repository.
The Core Product Release repository drives the self-hosted chart updates via a release from here, i.e. create a tag and then it will create a release that also updates the self-hosted updates.

## Tagging


This repository will be tagged with a specific Core Product overall release made up of the various versions for the individual components.
A tag will then indicate a supported set of components as a particular overall product version.
A tag will also drive Core Docs updates with a changelog and any other relevant details.

