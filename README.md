# crm-sto

Metadata supporting the general STO functionality at NAV. This includes components both for external and internal handling of sending and receiving messages through the thread-message solution

[![Build](https://github.com/navikt/crm-sto/workflows/%5BPUSH%5D%20Create%20Package/badge.svg)](https://github.com/navikt/crm-sto/actions?query=workflow%3Acreate)
[![GitHub version](https://badgen.net/github/release/navikt/crm-sto/stable)](https://github.com/navikt/crm-sto)
[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://github.com/navikt/crm-sto/blob/master/LICENSE)

## Dependencies

This package is dependant on the following packages

-   [crm-platform-base](https://github.com/navikt/crm-platform-base)
-   [crm-community-base](https://github.com/navikt/crm-community-base)
-   [crm-platform-access-control](https://github.com/navikt/crm-platform-access-control)
-   [crm-platform-oppgave](https://github.com/navikt/crm-platform-oppgave)
-   [crm-journal-utilities](https://github.com/navikt/crm-journal-utilities)
-   [crm-platform-integration](https://github.com/navikt/crm-platform-integration)
-   [crm-henvendelse](https://github.com/navikt/crm-henvendelse)

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

1. Kjør scratchSetup filen med kommandone `npm run scratchSetup`
1. Aktiver community
    1. Gå til Setup -> All Sites -> Workspaces -> Administation
    1. I settings så trykk Activate
    1. I members legg til Permissionsettet Skriv til Oss - Experience Cloud Access
    1. Gå tilbake til All Sites og åpne builderen
    1. Publish siden
1. Gå til kontoen Doktor Proktor for å logge inn i innboksen

## Sider i innboksen

Liste over alle sidene (der BASE_URL er miljøet, eks: https://ruby-data-3845.scratch.my.site.com/Innboks/s/, https://sit2-navdialog.cs162.force.com/Innboks/s/, https://innboks.nav.no/s/):

| Navn                  | URl                               | Parametere                                                                                                                                                                                      |
| --------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Innboksen             | {BASE_URL}                        |                                                                                                                                                                                                 |
| Skriv ny STO          | {BASE_URL}/skriv-til-oss?category | Category: Forteller hvilket tema/kategori STOen skal lages på, se [metadata filen](force-app/main/default/objects/STO_Category__mdt/fields/STO_Category__c.field-meta.xml) for gyldige verdier. |
| Vis en STO/STB        | {BASE_URL}/skriv-til-oss/&lt;id>  | Id: Id til en STO/STB thread.                                                                                                                                                                   |
| Vis en chat           | {BASE_URL}/chat/&lt;id>           | Id: Id til en chat-thread.                                                                                                                                                                      |
| Vis et samtalereferat | {BASE_URL}/samtalereferat/&lt;id> | Id: Id til et samtalereferat.                                                                                                                                                                   |
