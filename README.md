# crm-sto

Metadata supporting the general STO functionality at NAV. This includes components both for external and internal handling of sending and receiving messages through the thread-message solution

[![Build](https://github.com/navikt/crm-sto/workflows/%5BPUSH%5D%20Create%20Package/badge.svg)](https://github.com/navikt/crm-sto/actions?query=workflow%3Acreate)
[![GitHub version](https://badgen.net/github/release/navikt/crm-sto/stable)](https://github.com/navikt/crm-sto)
[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://github.com/navikt/crm-sto/blob/master/LICENSE)

## Dependencies

This package is dependant on the following packages

- [crm-platform-base](https://github.com/navikt/crm-platform-base)
- [crm-community-base](https://github.com/navikt/crm-community-base)
- [crm-platform-access-control](https://github.com/navikt/crm-platform-access-control)
- [crm-platform-oppgave](https://github.com/navikt/crm-platform-oppgave)
- [crm-journal-utilities](https://github.com/navikt/crm-journal-utilities)
- [crm-platform-integration](https://github.com/navikt/crm-platform-integration)
- [crm-henvendelse](https://github.com/navikt/crm-henvendelse)

## Installation

1. Install [npm](https://nodejs.org/en/download/)
1. Install [Salesforce DX CLI](https://developer.salesforce.com/tools/sfdxcli)
    - Alternative: `npm install sfdx-cli --global`
1. Clone this repository ([GitHub Desktop](https://desktop.github.com) is recommended for non-developers)
1. Run `npm install` from the project root folder
1. Install [SSDX](https://github.com/navikt/ssdx)
    - **Non-developers may stop after this step**
1. Install [VS Code](https://code.visualstudio.com) (recommended)
    - Install [Salesforce Extension Pack](https://marketplace.visualstudio.com/items?itemName=salesforce.salesforcedx-vscode)
    - **Install recommended plugins!** A notification should appear when opening VS Code. It will prompt you to install recommended plugins.
1. Install [AdoptOpenJDK](https://adoptopenjdk.net) (only version 8 or 11)
1. Open VS Code settings and search for `salesforcedx-vscode-apex`
1. Under `Java Home`, add the following:
    - macOS: `/Library/Java/JavaVirtualMachines/adoptopenjdk-[VERSION_NUMBER].jdk/Contents/Home`
    - Windows: `C:\\Program Files\\AdoptOpenJDK\\jdk-[VERSION_NUMBER]-hotspot`

## Build

To build locally without using SSDX, do the following:

1. If you haven't authenticated a DX user to production / DevHub, run `sfdx auth:web:login -d -a production` and log in
    - Ask `#crm-platform-team` on Slack if you don't have a user
    - If you change from one repo to another, you can change the default DevHub username in `.sfdx/sfdx-config.json`, but you can also just run the command above
1. Create a scratch org, install dependencies and push metadata:

```bash
sfdx force:org:create -f ./config/project-scratch-def.json --setalias scratch_org --durationdays 1 --setdefaultusername
echo y | sfdx plugins:install sfpowerkit@2.0.1
keys="" && for p in $(sfdx force:package:list --json | jq '.result | .[].Name' -r); do keys+=$p":{key} "; done
sfdx sfpowerkit:package:dependencies:install -u scratch_org -r -a -w 60 -k ${keys}
sfdx force:source:push
sfdx force:org:open
```

# Henvendelser

Enten:
Spørsmål knyttet til koden eller prosjektet kan stilles som issues her på GitHub

## For NAV-ansatte

Interne henvendelser kan sendes via Slack i kanalen #crm-nks.

## Experience setup

To set up the "innboks" experience you need to go through a couple of easy steps.

1. Importer testdata fra `dummy-data/data/plan.json` og deretter `dummy-data/sto/plan.json` hvis dette ikke allerede er gjort ved opprettelse av scratch org. `GenerateData.apex`, som kjøres av neste steg, kobler eksempeltrådene til Doktor Proktors eksisterende personkonto og kontakt.
1. Kjør scratchSetup filen med kommandoen `npm run scratchSetup`. Dette oppretter community-brukere med `STO_experience` for alle tre testpersonene nedenfor.
1. Aktiver community
    1. Gå til Setup -> All Sites -> Workspaces -> Administration
    1. I settings så trykk Activate
    1. I members legg til Permissionsettet Skriv til Oss - Experience Cloud Access
    1. Gå tilbake til All Sites og åpne builderen
    1. Publish siden
1. Gå til personkontoen Doktor Proktor, Beate Normann eller Ola Normann og velg **Log in to Experience as User** for å logge inn i innboksen som denne personen.

<!-- TODO(backend-ready): Replace the scratch family provider with verified responsibility; preserve account ownership and actor attribution. -->

| Testperson     | Syntetisk personident | Innboksvalg                 |
| -------------- | --------------------- | --------------------------- |
| Doktor Proktor | 12345678901           | Egen konto                  |
| Beate Normann  | 12345678904           | Barnets faktiske Account-ID |
| Ola Normann    | 12345678905           | Barnets faktiske Account-ID |

`PersonHandler` fra crm-platform-base oppretter personkonto og kontakt automatisk når `Person__c`-testdata importeres. Brukernavn blir `<fornavn>.<etternavn>@<org-domene>`. Doktor Proktor beholder `Scratch Community Profile`. Barna bruker den egendefinerte `Scratch Community Login Profile` med `Customer Community Plus Login`, siden scratch org bare har én medlemsbasert `Customer Community Plus`-lisens. Begge lisenstypene er aktivert i scratch-konfigurasjonen. Alle tre får `STO_experience`, uten å sette passord i kildekoden.

For en eksisterende scratch org: deploy den nye profilen fra `force-app/scratch-org/profiles`, importer bare de manglende personpostene fra `dummy-data/data/persons.json`, og kjør `sf apex run --file post-scratch/scratchSetup.cls` for å opprette manglende community-brukere og tilganger uten å duplisere eksisterende brukere. `npm run mac:build` kjører også dette etter import av testdata.

<!-- TODO(backend-ready): This is an explicitly scratch-only authorization fixture, not a production responsibility integration. -->

`stoPersonContext` returnerer denne syntetiske familien bare på et faktisk `.scratch.my.salesforce.com`-orgdomene, for Doktor Proktors syntetiske ident og med den eksplisitte `STO_Scratch_Family`-tillatelsen. Den eksisterende `Scratch Community Profile` gir testforelderen tillatelsen og lesetilgang til det syntetiske identfeltet. Deploy også `STO_Scratch_Family.customPermission-meta.xml` og den oppdaterte profilen; bare LWC-/Apex-deploy er ikke tilstrekkelig. Domenesjekken følger mønsteret i crm-community-base og krever ikke tilgang til `Organization` eller `User.Profile`, som community-lisenser ikke kan spørre slik. Sandbox-status alene gir ingen tilgang. Barna får ingen personvelger. Andre brukere får bare egen innboks. Produksjon trenger fortsatt en godkjent foreldreansvarskilde i `authorizedChildren()`; det gis ikke tilgang til vilkårlige kontoer fra klienten.

<!-- TODO(backend-ready): Keep this ownership/query contract and revalidate sharing when the production backend is connected. -->

Ved sending på vegne av et barn sendes barnets faktiske Account-ID til Apex, som validerer valget på nytt. `Thread__c.CRM_Account__c` og `CRM_Contact__c` peker på barnet, mens `CreatedById` og meldingens `CRM_From_Contact__c` beholder den innloggede avsenderen. Personvalget henter ekte tråder fra samme konto, og barnet finner dem i egen innboks ved innlogging. Barnets eksisterende aktive community-brukere får tilgang til den nye tråden; meldingene arver trådtilgangen. Eksisterende `with sharing` beholdes. Nye eller andre foreldres tilgang og tilbakekalling må avklares med produksjonsintegrasjonen; denne endringen oppretter ikke en slik ordning og migrerer ikke eksisterende tråder.

<!-- TODO(backend-ready): Retain these regressions and replace the scratch-profile integration fixture when production integration is available. -->
<!-- TODO(backend-ready): Preserve the reply owner's perspective when replacing inferred sender/owner context with verified backend context. -->

Svarfeltet bruker trådens kontakt, innlogget brukers kontakt og første eksterne meldings avsender for å skille mellom egen samtale og samtale startet på vegne av eieren. En forelder ser representantvarselet; eieren ser et varsel formulert til seg når en annen person startet samtalen. Begge beholder hele varselet om automatisk lagring og utlogging. Vanlige egne samtaler får ikke et representantvarsel. Kategorifilteret har egen toppmarg, også når personvelgeren ikke vises.

Kjør `post-scratch/scratchSetup.cls` på nytt i scratch org etter metadata-deploy for å dele de syntetiske barnas kontoer med testforelderen. Det gir nødvendig konto-/kontakttilgang uten å slå av `with sharing`. Ingen eksisterende tråder flyttes. `stoPersonContextTest`, `stoHelperClass_Test` og `stoInboxHelperTest` dekker opprettelse, avsender, personavgrensning, trådgrenser og barnets egen innlogging. Innloggingstesten bruker profilen til en eksisterende aktiv Plus-community-bruker, og forutsetter at community-oppsettet er utført.

## Backend-ready lifecycle: what to keep, replace or remove

<!-- TODO(backend-ready): KEEP this inventory current while replacing the scratch provider; REMOVE only entries for confirmed retired artifacts. -->

`TODO(backend-ready)` marks integration follow-up, **not** a request to delete the surrounding file. KEEP means retain and revalidate; REPLACE means change the named temporary implementation; REMOVE means retire only that fixture/artifact after its consumers are removed. No production foreldreansvar integration or relationship-revocation lifecycle is implemented yet.

All paths below are relative to the repository root:

| Decision | Paths | Purpose / backend-ready action |
| --- | --- | --- |
| KEEP | `force-app\main\default\classes\stoPersonContext.cls` and `stoPersonContext.cls-meta.xml` | Functional selection/resolution API and required Salesforce descriptor, not failed generation. Keep DTO, self resolution, server-side account validation and `with sharing`. REPLACE only `authorizedChildren()` scratch domain/permission/identity provider with verified foreldreansvar. |
| KEEP / REPLACE fixture | `force-app\main\default\classes\stoPersonContextTest.cls` and `stoPersonContextTest.cls-meta.xml` | Apex regression suite and required descriptor. Keep ownership, creator/sender, limits, denial and citizen-login assertions. Keep the test-only injection seam for unit isolation; replace synthetic profile/identity/custom-permission integration setup with real-provider fixtures. Tests are not runtime authorization. |
| KEEP | `force-app\main\default\classes\stoHelperClass.cls`, `force-app\main\default\classes\stoInboxHelper.cls` | Actual account/contact ownership, scoped fetching/limits and narrowly scoped owner-login sharing. Revalidate sharing against backend access/revocation; do not delete ownership/fetch code or replace `with sharing` with unrestricted access. |
| KEEP / REPLACE inference | `force-app\main\default\lwc\communityThreadViewer\communityThreadViewer.js` and `.html` | Keep complete reply notices. Replace owner/actor/first-message inference with explicit verified representation context when available. |
| KEEP | `force-app\main\default\lwc\stoMessageInbox\stoMessageInbox.js`, `.html`, `.css`; `force-app\main\default\lwc\stoRegisterThread\stoRegisterThread.js`, `registerThreadTemplate.html` | Keep real account selections/queries, conditional dropdown, explicit errors with self availability, spacing and complete notices. The temporary provider is server-side, not these UI contracts. |
| KEEP | `force-app\main\default\permissionsets\STO_Experience.permissionset-meta.xml` | Keep access to the resolver API; this is separate from scratch fixture permission. |
| REMOVE when fixture retired | `force-app\main\default\customPermissions\STO_Scratch_Family.customPermission-meta.xml`; fixture custom-permission and identity-field grants in `force-app\scratch-org\profiles\Scratch Community Profile.profile-meta.xml` | Retire together with the scratch provider checks, never grant as production parental authorization. Keep the rest of the existing profile. |
| KEEP while demo exists | `force-app\scratch-org\profiles\Scratch Community Login Profile.profile-meta.xml`; `post-scratch\scratchSetup.cls` | Login-license profile and idempotent community-user setup support child-login testing. REMOVE only synthetic family AccountShare setup when replacing fixture access; production access/revocation needs an approved implementation. Do not remove unrelated setup. |
| KEEP while demo exists | `bin\install-scratch.sh`; `dummy-data\GenerateData.apex`; `dummy-data\data\persons.json`, `dummy-data\data\plan.json`; `dummy-data\sto\plan.json`, `dummy-data\sto\threads.json` | Scratch import ordering, synthetic people and deterministic sample account/contact linking. Not a production migration. JSON cannot contain TODO comments; this inventory covers its fixture lifecycle. Deleted legacy `dummy-data\data\cases.json` and `dummy-data\sto\accounts.json` were replaced by deterministic setup/PersonHandler, not failed output; do not recreate duplicate accounts/cases. |
| KEEP | `README.md`; `dummy-data\README.md` | Existing project/setup documentation, updated in place. No extra README was generated for this fix. Revise fixture instructions when retiring the provider. |

<!-- TODO(backend-ready): REMOVE candidate sfp.cmd only after owner confirmation; it is not part of the backend implementation. -->

`sfp.cmd` is an **untracked, nonfunctional REMOVE candidate**, not a project dependency or valid sfp launcher: it contains only a machine-specific PATH assignment ending in `--version\PATH.txt`. Git has no tracked version/history for it; its creator cannot be established from this checkout. It has been left unchanged pending confirmation. Do not run it or confuse it with installed CLI shims outside this repository.

<!-- TODO(backend-ready): KEEP Apex regression coverage when replacing the provider; LWC tests were removed at user request. -->

The task-added LWC Jest tests and their dedicated presentation stubs have been removed at user request; Apex tests remain. The task-specific Jest configuration change was reverted, leaving pre-existing tooling/configuration intact. Existing `sfdx-project.json` edits remain outside this fix. No other accidental repository artifacts were identified; no org data or metadata was changed by this cleanup.

## Sider i innboksen

Liste over alle sidene (der BASE_URL er miljøet, eks: https://ruby-data-3845.scratch.my.site.com/Innboks/s/, https://sit2-navdialog.cs162.force.com/Innboks/s/, https://innboks.nav.no/s/):

| Navn                  | URl                               | Parametere                                                                                                                                                                                      |
| --------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Innboksen             | {BASE_URL}                        |                                                                                                                                                                                                 |
| Skriv ny STO          | {BASE_URL}/skriv-til-oss?category | Category: Forteller hvilket tema/kategori STOen skal lages på, se [metadata filen](force-app/main/default/objects/STO_Category__mdt/fields/STO_Category__c.field-meta.xml) for gyldige verdier. |
| Vis en STO/STB        | {BASE_URL}/skriv-til-oss/&lt;id>  | Id: Id til en STO/STB thread.                                                                                                                                                                   |
| Vis en chat           | {BASE_URL}/chat/&lt;id>           | Id: Id til en chat-thread.                                                                                                                                                                      |
| Vis et samtalereferat | {BASE_URL}/samtalereferat/&lt;id> | Id: Id til et samtalereferat.                                                                                                                                                                   |
