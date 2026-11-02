# crm-sto

Skriv til oss og Beskjed til oss støtter meldingsdialog mellom innbyggere og Nav, med innboks for innbyggeren og behandling av samtaler hos Nav.

[![Build](https://github.com/navikt/crm-sto/workflows/%5BPUSH%5D%20Create%20Package/badge.svg)](https://github.com/navikt/crm-sto/actions?query=workflow%3Acreate)
[![GitHub version](https://badgen.net/github/release/navikt/crm-sto/stable)](https://github.com/navikt/crm-sto)
[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://github.com/navikt/crm-sto/blob/master/LICENSE)

## Funksjonalitet

**Skriv til oss (STO)** lar innbyggeren sende spørsmål til Nav og følge opp svaret i samme samtale. **Beskjed til oss (BTO)** brukes til å melde fra om endringer, trekke en søknad eller gi en bestemt beskjed. Temaet i inngangslenken avgjør hvilket skjema brukeren får.

Innboksen samler siste og tidligere meldinger og lar brukeren filtrere på tema. Åpne eller uleste samtaler vises under **Siste meldinger**, mens avsluttede og leste samtaler vises under **Tidligere meldinger**. Eldre innhold kan lastes inn ved behov.

Der personvalget er tilgjengelig, kan brukeren velge **Deg** eller et barn vedkommende har foreldreansvar for. Et nytt besøk starter på Deg; tilbakeknappen beholder personen man kom fra. Barn som har fylt 18 år eller har beskyttede opplysninger skal ikke være tilgjengelige for representasjon.

Informasjon om representasjon vises før brukeren går videre til meldingsskjemaet. Når en forelder skriver for et barn, gjelder samtalen barnet, mens forelderen fortsatt er den originale innsenderen. Andre med foreldreansvar og barnet kan lese, men bare den som startet samtalen kan svare eller avslutte den.

Innbokskort viser hvem som startet samtalen når det var en annen enn den innloggede. Inne i samtalen ser innsenderen barnets navn og alder, andre foreldre ser hvem som skrev på vegne av barnet, og barnet ser ikke et representasjonsbanner i egen samtale. Saksbehandlerens svarhilsen rettes til originale innsender, ikke automatisk til barnet.

Lesestatus skal være personlig: at en annen forelder eller barnet leser en samtale, skal ikke fjerne den innloggedes ulest-merke. Feil ved henting av personvalg, samtaler, svarrett eller lesestatus skal vises tydelig.

**Forutsetning for full testing:** Tilhørende backend-støtte for foreldreansvar, tilgang, svarrett, ruting og personlig lesestatus må være ferdig og integrert før hele løsningen deployes. Testdata og scratch-oppsett erstatter ikke denne funksjonaliteten. Manglende støtte er markert med `ToDo(backend)` i koden.

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

Scratch-testene bruker tre syntetiske foreldre og to barn for å kontrollere personvalg, lesetilgang og dialog på vegne av barn. Integrer nødvendig backend-støtte og deploy prosjektets scratch-oppsett før testene tas i bruk. Se `dummy-data\README.md` for hvorfor de enkelte testfilene finnes.

1. Importer `dummy-data\data\plan.json` og deretter `dummy-data\sto\plan.json`, hvis dette ikke allerede er gjort.
1. Kjør `npm run scratchSetup` mot riktig scratch org. Det oppretter testinnlogginger, fixture-tilgang til Account/Person og eksempelsamtaler/ruting, ikke produksjonsfunksjonalitet.
1. Aktiver community
    1. Gå til Setup -> All Sites -> Workspaces -> Administration
    1. I settings så trykk Activate
    1. I members legg til Permissionsettet Skriv til Oss - Experience Cloud Access
    1. Gå tilbake til All Sites og åpne builderen
    1. Publish siden
1. Åpne en av testpersonkontoene og velg **Log in to Experience as User**.

| Testperson | Syntetisk personident | Forventet backend-ansvar |
| --- | --- | --- |
| Doktor Proktor (Far) | 12345678901 | Beate og Ola |
| Kari Normann (Mor) | 12345678902 | Beate og Ola |
| Anne Normann (Medmor) | 12345678903 | Bare Beate |
| Beate Normann | 12345678904 | Egen innboks, ingen representasjon |
| Ola Normann | 12345678905 | Egen innboks, ingen representasjon |

Testpersonene får separate community-innlogginger, slik at man kan bytte mellom Far, Mor, Medmor og barna. Doktor bruker den ene medlemsbaserte Plus-lisensen; de øvrige bruker login-baserte Plus-lisenser. Alle får ordinær tilgang til innboksen, uten passord i kildekoden.

`scratchSetup.cls` og `scratchFamilySharing.cls` må kjøres i separate transaksjoner for å unngå `MIXED_DML_OPERATION`. Bruker-/permissionset-oppsett og Account/Person-shares er idempotente. Full `scratchSetup` kjører også den eksisterende generatoren av eksempelsamtaler; kjør bare de to skriptene ved oppdatering av eksisterende innlogginger/fixture-tilgang.

Familiedataene oppretter bare testpersoner og nødvendig tilgang til de syntetiske personpostene. De avgjør ikke hvem som kan representere et barn. Ansvar og tilgang til samtaler må komme fra den ordinære backend-løsningen, også i test.

<!-- ToDo(backend): Provide the fixture responsibility responses, production permissions and conversation sharing through the real backend. -->

Fixture-tilgang til testpersonpostene beholdes fordi syntetiske personer ikke allerede har den recordtilgangen som finnes i et ferdig miljø. Oppsettet gir ikke ekstra svarrett eller lokal autorisasjon. Kontroll av ansvar, alder og gradering, tilgang til samtaler og personlig lesestatus må håndteres av backend.

### STO/BTO i verktøylinjen

`npm run scratchRoutingSetup` setter opp den interne scratch-brukerens Service Resource og ferdigheter, deployer eksisterende kø-/fordelingsregelmetadata og oppretter én navngitt STO/Familie og én BTO/Helse fixture med Case, Thread og Message for Doktor Proktor. `npm run scratchSetup` og testdatasteget i `npm run mac:build` bruker samme kommando.

Ruting av disse navngitte testpostene bruker vanlige assignment rules. Gjentatte kjøringer dupliserer ikke dem eller åpner ferdige fixtures på nytt. Oppsettet flytter eller reparerer ikke ekte innsendinger eller andre eksisterende saker; backend må rute ekte STO/BTO. Skriptene avbryter utenfor scratch org.

<!-- ToDo(backend): Complete real case routing/contact handling; do not reintroduce post-setup re-routing of community submissions. -->

## Sider i innboksen

`{BASE_URL}` er adressen til innboksen i valgt miljø, uten avsluttende skråstrek. I produksjon er den `https://innboks.nav.no/s`; i scratch org er den for eksempel `https://<org>.scratch.my.site.com/Innboks/s`. Sidene krever innlogging.

| Funksjon | URL | Beskrivelse |
| --- | --- | --- |
| Innboksen | `{BASE_URL}` | Se siste og tidligere meldinger. |
| Skriv ny STO | `{BASE_URL}/skriv-til-oss?category=<tema>` | Still et spørsmål innen valgt tema. |
| Meld fra om endring (BTO) | `{BASE_URL}/beskjed-til-oss?category=endring-<tema>` | Meld fra om en endring. |
| Trekk en søknad (BTO) | `{BASE_URL}/beskjed-til-oss?category=trekke-soknad-<tema>` | Trekk en søknad. |
| Gi beskjed (BTO) | `{BASE_URL}/beskjed-til-oss?category=beskjed-<tema>` | Gi en beskjed. |
| Vis en STO/STB | `{BASE_URL}/skriv-til-oss/<id>` | Åpne en eksisterende samtale. |
| Vis en BTO | `{BASE_URL}/beskjed-til-oss/visning?samtale=<id>` | Åpne en tidligere innsendt beskjed. |
| Vis en chat | `{BASE_URL}/chat/<id>` | Åpne en chat. |
| Vis et samtalereferat | `{BASE_URL}/samtalereferat/<id>` | Åpne et samtalereferat. |

### Temaer for STO

Bruk verdien som `category`, for eksempel `category=familie`.

| Tema | `category` |
| --- | --- |
| Arbeid | `arbeid` |
| Familie og barn | `familie` |
| Helse og sykdom | `helse` |
| Hjelpemidler og tilrettelegging | `hjelpemidler` |
| Bor eller jobber i utlandet | `internasjonal` |
| Pensjon | `pensjon` |
| Pleiepenger for sykt barn | `pleiepenger` |
| Ufør | `uf%C3%B8r` (URL-kodet `ufør`) |
| Andre hjelpemidler | `andre-hjelpemidler` |

### Temaer for BTO

Sett sammen prefikset og et tema fra samme rad. `category=endring-aap` gjelder endring for arbeidsavklaringspenger; et STO-tema alene er ikke nok.

| Formål | Prefiks | Støttede temaer |
| --- | --- | --- |
| Meld fra om endring | `endring-` | `dagpenger`, `tiltakspenger`, `ventelonn`, `grunn-og-hjelpestonad`, `yrkesskadetrygd`, `omsorg-fosterhjem`, `arbeidsevne`, `enslig`, `barnetrygd`, `kontantstotte`, `bidrag`, `uforetrygd`, `tilleggsstonader`, `aap`, `foreldre`, `sykdom-familien`, `afp-offentlig`, `supplerende-stonad-flyktninger`, `supplerende-stonad-over-67`, `alderspensjon`, `gjenlevende`, `sykepenger`, `utland`, `yrkesskade` |
| Trekk en søknad | `trekke-soknad-` | `arbeid`, `helse`, `utland`, `familie`, `pensjon`, `hjelpemidler`, `ufor` |
| Gi beskjed | `beskjed-` | `trygdeavgift`, `sykepenger`, `menerstatning`, `afp-offentlig`, `afp-privat`, `kontor`, `fullmakt-lege`, `klage`, `taushetsplikt` |

En manglende eller ukjent `category` viser en feilside i stedet for meldingsskjemaet.
