# crm-sto

Skriv til oss og Beskjed til oss støtter meldingsdialog mellom innbyggere og Nav, med innboks for innbyggeren og behandling av samtaler hos Nav.

[![Build](https://github.com/navikt/crm-sto/workflows/%5BPUSH%5D%20Create%20Package/badge.svg)](https://github.com/navikt/crm-sto/actions?query=workflow%3Acreate)
[![GitHub version](https://badgen.net/github/release/navikt/crm-sto/stable)](https://github.com/navikt/crm-sto)
[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://github.com/navikt/crm-sto/blob/master/LICENSE)

## Funksjonalitet

**Skriv til oss (STO)** lar innbyggeren sende spørsmål til Nav og følge opp svaret i samme samtale. **Beskjed til oss (BTO)** brukes til å melde fra om endringer, trekke en søknad eller gi en bestemt beskjed. Temaet i inngangslenken avgjør hvilket skjema brukeren får.

Innboksen samler siste og tidligere meldinger og lar brukeren filtrere på tema. Åpne eller uleste samtaler vises under **Siste meldinger**, mens avsluttede og leste samtaler vises under **Tidligere meldinger**. Eldre innhold kan lastes inn ved behov.

Der personvalget er tilgjengelig, kan brukeren velge **Deg** eller et barn vedkommende har foreldreansvar for. Et nytt besøk starter på Deg; tilbakeknappen beholder personen man kom fra. Barn som har fylt 18 år eller har beskyttede opplysninger skal ikke være tilgjengelige for representasjon.

Personvalget i både skriveskjemaet og innboksen bruker det eksisterende `barn()`-kallet til foreldreansvarstjenesten via `stoPersonContext.getRepresentableChildren()`, som returnerer barnelisten direkte. Navn og alder i nedtrekkslisten hentes fra `fornavn`, `etternavn` og `alder` i svaret, og listen sorteres etter disse navnene. Aldersgrensen på 18 år bruker også tjenestens `alder`, ikke fødselsdato lagret i Salesforce. Returnerte personidenter kobles fortsatt til tilgjengelige, ugraderte personkontoer for konto-ID og samtaletilgang. Barn med mangelfulle eller ugyldige opplysninger utelates fra personvalget og logges som datakvalitetsfeil, uten egne varsler til brukeren. Øvrige barn og valget av deg selv er fortsatt tilgjengelige, også når alle barna mangler nødvendige opplysninger. Tjenestefeil eller et ugyldig svarformat gir fortsatt en synlig lastefeil. Det midlertidige `getRepresentableChildrenWithWarnings()`-endepunktet og varseltypene er fjernet; begge LWC-ene bruker liste-endepunktet.

Den eksisterende familiesimuleringen beholdes i scratch org når brukeren har `STO_Scratch_Fixtures`. `barn()` og `verifiser()` følger fortsatt relasjonene i `STO_Foreldreansvar_Family`: Far og Mor har begge barna, Medmor har bare Beate, og barna har ingen barn de kan representere. Det simulerte barnesvaret bruker de komplette barneopplysningene fra tjenestens konfigurerte `POST_FORELDREANSVAR_BARN`-mocksvar i `crm-nks-integration`, filtrert etter familien. Navn og alder hentes ikke fra Salesforce. Uten scratch-opt-in brukes `NKS_ForeldreansvarService` som før. Ingen endringer i integrasjonstjenesten eller det delte mockrammeverket er nødvendige.

Informasjon om representasjon vises før brukeren går videre til meldingsskjemaet. Når en forelder skriver for et barn, gjelder samtalen barnet, mens forelderen fortsatt er den originale innsenderen. Andre med foreldreansvar og barnet kan lese, men bare den som startet samtalen kan svare eller avslutte den.

Ved skriving på vegne av et barn vises ikke spørsmålet om **pleiepenger for sykt barn**, verken under **Helse og sykdom** eller **Familie og barn**. Spørsmålet beholdes når brukeren skriver for seg selv.

Innbokskort viser hvem som startet samtalen når det var en annen enn den innloggede. Inne i samtalen ser innsenderen barnets navn og alder. Andre foreldre og barnet ser hvem som skrev på vegne av barnet, og i en åpen samtale får de samme informasjon om at bare innsenderen kan svare. Et barn som startet sin egen samtale får ikke et representasjonsbanner. Saksbehandlerens svarhilsen rettes til originale innsender, ikke automatisk til barnet.

Lesestatus bruker foreløpig den eksisterende, delte logikken: `CRM_MessageHelperExperience.markAsRead` markerer uleste meldinger som lest når samtalen åpnes. Lesing som én person kan derfor også fjerne ulest-merket for andre som har tilgang til samtalen. Personlig lesestatus håndteres i en separat PR. Feil ved henting av personvalg, samtaler eller svarrett skal vises tydelig.

**Forutsetning for full testing:** Det eksisterende oppslaget av barn er beholdt. Tilhørende backend-støtte for opprettelse på vegne av barn, samtaletilgang og ruting må være ferdig og integrert før hele løsningen deployes. Testdata og scratch-oppsett erstatter ikke denne funksjonaliteten. Manglende støtte er markert med `ToDo(backend)` i koden.

`stoReplyContext` samler DTO-feltene, samtale- og avsenderoppslag, svarrett, svarmottaker og etiketter i samme klasse. Komponentene kaller `stoReplyContext.getReplyContext` direkte. Bare opprinnelig innsender kan svare eller avslutte STO-, STB- og BTO-samtaler fra innbyggersiden. Interne Nav-brukere beholder eksisterende arbeidsflyt. Reglene håndheves også i `stoReplyContext` før innsetting av meldinger og før avslutning av samtaler gjennom de tynne `stoMessageAccessHandler` og `stoThreadAccessHandler`; lesetilgang eller eldre Edit-shares gir ikke svarrett. Avslutning kontrolleres både når aktiv-flagget fjernes og når avslutningsdato settes. Backend-feil ved avslutning returneres til frontend.

DTO-typen er flyttet til `stoReplyContext`; Apex-kallere i repoet er oppdatert. De syv serialiserte feltene og metodeparametrene er uendret. De gamle svarrelaterte metodene i `stoHelperClass` og mottakerinngangen i `STO_RecordInfoController` er fjernet, ikke beholdt som videresendinger. Eventuelle Apex-kallere utenfor repoet må oppdateres før utrulling.

Opprinnelig innsender bestemmes av første innbyggermelding, sortert på sendt tidspunkt, opprettet tidspunkt og ID. Uten en slik melding brukes oppretterens kontakt, alternativt samtalens kontakt for eldre internt opprettede samtaler. En eksisterende opprinnelig melding uten avsender gir ikke automatisk svarrett til personen samtalen gjelder. Hendelsesmeldinger og oppdatering av lesestatus endres ikke.

Skriveskjemaet bruker `stoInboxHelper.getAccessibleOpenThreadsForPerson` til oppslag og formatering av åpne samtaler, filtrert på `category`, `threadType` og valgt person. Den eldre inngangen i `stoHelperClass` beholdes som delegat. `stoPersonContext.resolveAccountId` autoriserer egen personkonto eller et barn fra `getRepresentableChildren`. Oppslaget respekterer eksisterende Salesforce-deling og oppretter ingen nye delinger. Resultatet inneholder eksisterende uleststatus og avsenderetiketter. Ingen treff gir en tom liste, mens autorisasjons- og tjenestefeil fortsatt vises og blokkerer innsending.

`stoInboxHelper.getAccessibleInboxPage` og `getNextInboxPage` er feilkastende plassholdere med parametrene `representedAccountId`, `beforeThreadId` og `beforeNoteId`. Innboksen viser lastefeil inntil autorisert sidehenting er implementert; plassholderne returnerer ikke falske tomme sider. Backend må returnere `recent`, `older`, begge markører og `hasMore`.

`crmStoMessaging` kaller `stoReplyContext.getReplyRecipientFirstName` direkte. Metoden bruker samme tilgjengelige avsenderkontekst som `getReplyContext`, slik at svarhilsenen ikke automatisk bruker barnets fornavn. `STO_Experience`, `Skriv_til_Oss` og `Skriv_til_oss_Service_Cloud_tilgang` gir tilgang til den nye Apex-klassen; objekt-, felt- og recordtilgang utvides ikke. Skrivefeltet forblir utilgjengelig hvis mottakeren ikke kan hentes.

`stoPersonContext` eier brukeridentitet, personautorisasjon og felles aldersberegning. Innlogget bruker hentes én gang per aktør per transaksjon. `STO_RecordInfoController` beholder bare generiske postoppslag. `stoInboxHelper` henter og formaterer innboksen og bruker `stoReplyContext` til avsenderetiketter. Samtalekontekst caches ikke, slik at første innbyggermelding fortsatt kan endre avsendergrunnlaget i samme transaksjon. Triggerreglene henter samtalene samlet, mens innboksen bevisst skiller siste melding fra opprinnelig innsender.

Repoets faste agentføringer ligger i [`.github/copilot-instructions.md`](.github/copilot-instructions.md). Ferdighetene [Nav Salesforce development](.github/skills/nav-salesforce-development/SKILL.md) og [Nav Salesforce release runbook](.github/skills/nav-salesforce-release-runbook/SKILL.md) brukes ved relevante oppgaver. Miljøhandlinger krever ny godkjenning av eksakt mål og handling; produksjon er alltid NO GO for agenten. Se [runbooken](docs/runbooks/original-sender-permissions.md) for validering, ansvar og eventuell metadataopprydding.

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

Med `STO_Scratch_Fixtures` aktivert simuleres relasjonene i tabellen for den innloggede testpersonen. Den faste integrasjonsmocken inneholder opplysningene om Beate og Ola, men scratch-adapteren returnerer bare barna i vedkommendes familie. Beate og Ola får tom barneliste og dermed ingen nedtrekksliste for representasjon. Salesforce-deling og gradering kontrolleres fortsatt. Hvis et barn i familiefixturen mangler i det konfigurerte mocksvargrunnlaget, vises en feil i stedet for at barnets opplysninger hentes fra Salesforce.

Testpersonene får separate community-innlogginger, slik at man kan bytte mellom Far, Mor, Medmor og barna. Doktor bruker den ene medlemsbaserte Plus-lisensen; de øvrige bruker login-baserte Plus-lisenser. Alle får ordinær tilgang til innboksen, uten passord i kildekoden.

`scratchSetup.cls` og `scratchFamilySharing.cls` må kjøres i separate transaksjoner for å unngå `MIXED_DML_OPERATION`. Bruker-/permissionset-oppsett og Account/Person-shares er idempotente. Full `scratchSetup` kjører også den eksisterende generatoren av eksempelsamtaler; kjør bare de to skriptene ved oppdatering av eksisterende innlogginger/fixture-tilgang.

Familiedataene brukes til testpersoner, fixture-tilgang og den eksplisitt aktiverte scratch-familiesimuleringen. Simuleringen gjelder bare de fem syntetiske community-brukerne, ikke ekte foreldreansvar. Utenfor denne simuleringen må ansvar komme fra den ordinære backend-løsningen.

<!-- ToDo(backend): Complete production permissions and conversation sharing through the real backend. -->

Fixture-tilgang til testpersonpostene beholdes fordi syntetiske personer ikke allerede har den recordtilgangen som finnes i et ferdig miljø. Recordtilgang alene gir ikke foreldreansvar eller ekstra svarrett. De eksisterende kontrollene av alder, gradering, samtaletilgang og originale innsender beholdes.

### Integrasjonsmocker for community-brukere

Denne delen gjelder andre integrasjonskall, eller foreldreansvar når scratch-familiesimuleringen ikke er aktivert. Med `STO_Scratch_Fixtures` i en scratch org går `barn()` og `verifiser()` gjennom den lokale adapteren uten tjenestekall eller tjenestetoken. Adapteren leser de konfigurerte barneopplysningene direkte; `API_Controller_Mock_Settings__c` aktiverer ikke familiesimuleringen og endrer ikke relasjonene.

**Mock aktivert for den interne brukeren «User User» gjelder ikke automatisk i innboksen.** Ved **Log in to Experience as User** kjører forespørslene som den valgte community-brukeren, for eksempel Doktor eller Kari. `ApiController.setSystemContext()` velger tjenesteautentisering, men bytter ikke Salesforce-bruker.

`ApiController` leser først `API_Controller_Mock_Settings__c` for innlogget bruker. Bare hvis det ikke finnes en brukerbasert post, brukes innstillingen for brukerens profil. En brukerbasert post med `Use_Mock__c = false` overstyrer derfor en profil med mocks aktivert.

For testing av integrasjonsmocker i en godkjent scratch org må innstillingen gjelde de aktuelle community-brukerne, for eksempel **Doktor, Kari, Anne, Beate og Ola**, eller profilene deres. En scratch-administrator/testansvarlig kan opprette eller oppdatere brukerbaserte poster via **Setup → Custom Settings → API Controller Mock Settings → Manage**, med aktuell community-bruker som eier (`SetupOwnerId`) og disse verdiene:

| Felt | Verdi |
| --- | --- |
| `Use_Mock__c` | `true` |
| `Status_Code__c` | `200` |
| `Status__c` | `OK` |

Dette gjelder integrasjoner som bruker `ApiController` for de aktuelle brukerne, ikke bare foreldreansvar. Mocksvarene for `POST_FORELDREANSVAR_BARN` og `POST_FORELDREANSVAR_VERIFISER` må være deployet fra `crm-nks-integration`. `scratchSetup` og permissionsettet `STO_Scratch_Fixtures` aktiverer ikke disse integrasjonsmockene. Det eksisterende `post-scratch\activateMock.cls` aktiverer mocks for **alle profiler**, men endrer ikke brukerbaserte overstyringer.

Etter endringen kontrolleres verdiene på hver brukerbaserte post, og innboksen lastes på nytt som den aktuelle community-brukeren. Feilen `Trying to add blank service token to Authorization header.` betyr at kallet forsøkte å bruke et ekte tjenestetoken; kontroller mockinnstillingen for community-brukeren og eventuelle feil i mockkonfigurasjonen, ikke bare innstillingen for administratoren. Aktive integrasjonsmocker trenger ikke et ekte tjenestetoken. Ta vare på tidligere innstillinger før endringer, slik at de kan gjenopprettes når mocktestingen er ferdig. Denne fremgangsmåten gjelder bare scratch-testing, ikke produksjon.

### STO/BTO i verktøylinjen

`npm run scratchRoutingSetup` setter opp den interne scratch-brukerens Service Resource og ferdigheter, deployer eksisterende kø-/fordelingsregelmetadata og oppretter én navngitt STO/Familie og én BTO/Helse fixture med Case, Thread og Message for Doktor Proktor. `npm run scratchSetup` og testdatasteget i `npm run mac:build` bruker samme kommando.

Ruting av disse navngitte testpostene bruker vanlige assignment rules. Oppsettet synkroniserer `Case.NKS_Henvendelse_BehandlingsId__c` med `Thread.CRM_API_Reference__c` for både nye og eksisterende navngitte fixtures, slik at samtalene kan åpnes fra verktøylinjen. Gjentatte kjøringer dupliserer ikke dem eller åpner ferdige fixtures på nytt. Oppsettet flytter eller reparerer ikke ekte innsendinger eller andre eksisterende saker; backend må rute ekte STO/BTO. Skriptene avbryter utenfor scratch org.

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
