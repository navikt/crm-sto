# crm-sto

Metadata supporting the general STO functionality at NAV. This includes components both for external and internal handling of sending and receiving messages through the thread-message solution

[![Build](https://github.com/navikt/crm-sto/workflows/%5BPUSH%5D%20Create%20Package/badge.svg)](https://github.com/navikt/crm-sto/actions?query=workflow%3Acreate)
[![GitHub version](https://badgen.net/github/release/navikt/crm-sto/stable)](https://github.com/navikt/crm-sto)
[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://github.com/navikt/crm-sto/blob/master/LICENSE)

## Funksjonalitet

**Skriv til oss (STO)** lar innbyggeren sende spørsmål til Nav og følge opp svaret i samme samtale. **Beskjed til oss (BTO)** brukes til å melde fra om endringer, trekke en søknad eller gi en bestemt beskjed. Temaet i inngangslenken avgjør hvilket skjema brukeren får.

Innboksen samler siste og tidligere meldinger. Der personvalget er tilgjengelig, kan brukeren velge seg selv eller et barn vedkommende kan representere. Se [Sider i innboksen](#sider-i-innboksen) for URL-er og eksempler på STO/BTO-innganger.

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

Åpne samtaler viser om brukeren kan svare eller bare lese. Avsluttede samtaler kan fortsatt leses, og brukeren får en lenke til å starte en ny melding.

Listen over aktive samtaler før en ny melding bruker de samme kortene som innboksen. Begge viser hvem som startet samtalen når det er en annen enn den innloggede brukeren.

**Status for foreldreansvar:** Første melding lagrer den innloggede forelderen som avsender, mens samtalen gjelder barnet. `barn()` avgjør hvilke barn den innloggede kan representere. Apex deler deretter barnets tråder og samtalereferater med denne brukeren gjennom Salesforce-deling før frontend henter innboksen. Bare den originale innsenderen kan svare eller avslutte en samtale.

To set up the "innboks" experience you need to go through a couple of easy steps.

1. Importer testdata fra `dummy-data/data/plan.json` og deretter `dummy-data/sto/plan.json` hvis dette ikke allerede er gjort ved opprettelse av scratch org. `GenerateData.apex`, som kjøres av neste steg, kobler eksempeltrådene til Doktor Proktors eksisterende personkonto og kontakt.
1. Kjør `npm run scratchSetup`. Dette oppretter community-brukere for testfamilien og gjør STO/BTO klare til henting i verktøylinjens «Skriv til oss».
1. Aktiver community
    1. Gå til Setup -> All Sites -> Workspaces -> Administration
    1. I settings så trykk Activate
    1. I members legg til Permissionsettet Skriv til Oss - Experience Cloud Access
    1. Gå tilbake til All Sites og åpne builderen
    1. Publish siden
1. Gå til personkontoen Doktor Proktor, Beate Normann eller Ola Normann og velg **Log in to Experience as User** for å logge inn i innboksen som denne personen.

Personvalgene krever nå at `NKS_ForeldreansvarService.barn()` returnerer barnet. Tabellen nedenfor beskriver bare scratch-delingsoppsettet, ikke en lokal autorisasjonskilde.

| Testperson     | Syntetisk personident | Innboksvalg                 |
| -------------- | --------------------- | --------------------------- |
| Doktor Proktor (Far) | 12345678901      | Deg, Beate og Ola (Felles ansvar) |
| Kari Normann (Mor) | 12345678902       | Deg, Beate og Ola (Felles ansvar) |
| Anne Normann (Medmor) | 12345678903    | Deg og Beate (Foreldreansvar) |
| Beate Normann  | 12345678904           | Barnets faktiske Account-ID |
| Ola Normann    | 12345678905           | Barnets faktiske Account-ID |

`PersonHandler` fra crm-platform-base oppretter personkonto og kontakt automatisk når `Person__c`-testdata importeres. Brukernavn blir `<fornavn>.<etternavn>@<org-domene>`. Doktor Proktor beholder `Scratch Community Profile`. Mor, Medmor og barna bruker `Scratch Community Login Profile` med `Customer Community Plus Login`, siden scratch org bare har én medlemsbasert `Customer Community Plus`-lisens. Alle fem får `STO_experience`, uten passord i kildekoden. De tre foreldrene får også permissionsettet `STO_Scratch_Family`, med den eksplisitte custom permission og lesetilgang til `Account.INT_PersonIdent__c`.

Foreldrene får også begrenset lesetilgang til barnets `Person__c`-post og felt for fødselsdato/gradering. Account shares alene er ikke nok til at community-brukeren kan lese `CRM_Person__r`; uten denne tilgangen blir personlisten tom. Oppsettet deler bare Person-postene som hører til foreldreansvaret.

For en eksisterende scratch org: deploy scratch-profilene, importer bare manglende personposter, og kjør først `sf apex run --file post-scratch/scratchSetup.cls`, deretter `sf apex run --file post-scratch/scratchFamilySharing.cls`. Brukere/tillatelser og record shares må kjøres i separate transaksjoner for å unngå `MIXED_DML_OPERATION`. Begge skriptene er idempotente. `npm run scratchSetup` og `npm run mac:build` kjører dem i riktig rekkefølge; full scratchSetup lager også de eksisterende eksempelsamtalene.

### STO/BTO i verktøylinjen

`npm run scratchSetup` og testdatasteget i `npm run mac:build` kjører også `npm run scratchRoutingSetup`. Dette setter opp en aktiv Service Resource med tjeneste-/STO-/BTO-ferdigheter for den interne testbrukeren `User User`, deployer køene og den aktive fordelingsregelen fra `unpackaged`, og lager én STO (Familie) og én BTO (Helse) med samtale og melding for Doktor Proktor. Disse kan hentes via «Hent ny melding» i «Skriv til oss».

For å reparere bare rutingen i en eksisterende scratch org, kjør `npm run scratchRoutingSetup` med riktig scratch org som CLI-ens standardorg. Kommandoen kan kjøres flere ganger uten dupliserte ressurser, ferdigheter eller eksempelsamtaler. Den fordeler også nye, ubehandlede STO/BTO for den syntetiske familien som fortsatt eies av en community-bruker. Saker under behandling eller ferdigstilte saker flyttes ikke, og ferdige eksempelsamtaler åpnes ikke på nytt. Oppsettet avbryter utenfor scratch org og bruker vanlige kø-/fordelingsregler; det lager ikke rutingsposter manuelt og krever ingen endring i produksjonskoden.

### Personvalg og foreldreansvar

`stoPersonContext` bruker `NKS_ForeldreansvarService.barn()` fra crm-nks-integration for personvalget i innboksen og registreringsskjemaet. Forelderidenten leses fra den innloggede brukerens egen personkonto, aldri fra klienten. Bare identene i API-ets `barn`-liste kan matches mot eksisterende, delte personkontoer. Ved reelle kall gir verken scratch-domene, `STO_Scratch_Family` eller fixture-data noen ekstra autorisasjon; den eksplisitt aktiverte lokale scratch-mocken er beskrevet nedenfor. API-resultatet gjenbrukes bare i samme Apex-transaksjon og per innlogget bruker. Ved oppretting valideres personvalget gjennom samme resolver før verifisering av foreldreansvar.

Tom `barn`-liste, 204 og 404 gir ingen barn. Andre API-feil og ugyldige svar vises som hentefeil, ikke som en tom vellykket liste. Egen innboks (`Deg`) trenger ikke foreldreansvarskall for personvalget. API-navn og -fødselsdato kan være null; visningsnavn/alder og eksisterende alder-/graderingsfilter kommer fortsatt fra Salesforce. Ingen konto opprettes automatisk for API-barn som mangler lokalt eller ikke er delt.

Når den innloggede brukerens registrerte fødselsdato viser at brukeren er under 18 år, hentes ikke foreldreansvar. Brukeren skriver som seg selv, uten personvelger eller feilvarsel fra foreldreansvarstjenesten, også når scratch-mock er deaktivert. Fra og med 18-årsdagen brukes vanlig oppslag; manglende fødselsdato behandles ikke som et kjent barn. Reelle hentefeil vises med Aksel InlineMessage (`dsAlert`), tydelig feilfarge og avstand til ingress og øvrig innhold.

Registreringsskjemaet bruker foreldreansvar-branchens eksisterende oppretting av samtaler, med valgt barns personident eller `null` for egen sending. Det er ingen separat opprettingsflyt for frontend. Personvalget bruker fortsatt Account-ID ved innbokshenting. Manglende ident for valgt barn stopper innsending i skjemaet, i stedet for å sende som innlogget person.

Ved innsending på vegne av barn verifiseres den innloggede forelderen og valgt barn. Bare et gyldig svar med `kanRepresentere: true` tillater oppretting; avslag og feil blokkerer sending. I scratch brukes den eksisterende lokale mocken når den er aktivert som beskrevet nedenfor. Egen sending krever ikke foreldreansvarskall. Første melding bruker den innloggede brukerens kontakt som avsender, ikke barnets kontakt, slik at innsender kan svare og avslutte. Eksisterende meldinger med feil avsender endres ikke automatisk. Innledende deling til innsender bruker `Edit`, ikke `Write`, og oppretter ingen ekstra deling hvis innsender allerede eier samtalen. Barnets aktive community-innlogginger får Read-tilgang til den nye samtalen.

`stoInboxHelper.getAccessibleInboxPage` og `stoHelperClass.getAccessibleOpenThreadsForPerson` er imperative frontend-endepunkter: de autoriserer først valgt Account gjennom `stoPersonContext`/`barn()`, lar `stoThreadSharing` opprette manglende `Thread__Share`- og `Conversation_Note__Share`-poster, og kjører deretter de eksisterende personavgrensede spørringene med delingskontroll. Tilgangen omfatter alle barnets tråder og samtalereferater, også andre innsenderes samtaler og avsluttede tråder. Deling skjer for den innloggede forelderen når innboksen åpnes eller oppdateres, ikke ved å utlede alle medforeldre fra en testfamilie. Read-deling bruker Apex sharing reason `STO_Family_Read__c`, er idempotent og overlever eierskifte. Feil vises som hentefeil, aldri som en tom innboks. Account-/Person-tilgang er fortsatt en forutsetning; automatisk tilbakekalling av tidligere delinger ved endret ansvar må håndteres separat.

Delingen følger de eksisterende innboksfiltrene: STO/STB/BTO/CHAT og samtalereferater med registrert innsenderident. Andre interne trådtyper og upubliserte referater eksponeres ikke. Leseren trenger ikke Edit-tilgang for å markere et referat som lest: etter kontroll av record-/kontotilgang oppdaterer en avgrenset backend-hjelper bare de eksisterende globale leseflaggene, aldri referatteksten.

Deploy `stoPersonContext`, testene og oppdatert `STO_Experience` med en crm-nks-integration-versjon som inneholder `NKS_ForeldreansvarService` og `FORELDREANSVAR_API`/`POST_FORELDREANSVAR_BARN`-metadata. `STO_Experience` gir tilgang til integrasjonsklassen og lesing av `Account.INT_PersonIdent__c`, Person-oppslaget og fødselsdato/gradering på delte Person-poster, uten redigering eller View All. Følg integrasjonens `force-app\foreldreansvar\.doc\README.md` for saas-proxy, systemtoken, named credential og Remote Site Settings. Deaktiver `API_Controller_Mock_Settings__c` for brukeren/profilen ved reelle kall. Eksisterende Account-/Person-deling er fortsatt nødvendig; `barn()` gir ikke automatisk Salesforce-deling.

Scratch-oppsettet deler begge barna med Far og Mor, og bare Beate med Medmor. De vises bare hvis `barn()` også returnerer dem. Alle får også `Deg`. Personvelgeren i innboksen og registreringsskjemaet bruker fortsatt Apex-wiren og faktiske Account-ID-er, ikke lokale mock-lister. Navn og beregnet alder vises uten rolle/ident; myndige og barn med kode 6/7 eller annen gradering enn `UGRADERT` utelates. Fødselsdato og gradering hentes fra `CRM_Person__r`, siden `Account.PersonBirthdate` ikke fylles av de eksisterende testdataene.

For lokal testing ligger mocken bare i crm-sto: deploy `stoForeldreansvarMock`, `stoPersonContext` og `STO_Foreldreansvar_Family.resource` sammen. Ingen endring i crm-platform-base, ApiController, integrasjonsklassen eller integrasjonens mock-metadata kreves. Den lokale mocken brukes bare på et `.scratch.my.salesforce.com`-domene når eksisterende bruker-/profilinnstilling har `Use_Mock__c = true` og status 200; brukerinnstilling har prioritet. Uten dette brukes integrasjonen som før, også for andre mockstatuser. Familieforholdene ligger i JSON-ressursen, som også brukes av `scratchFamily()` ved fixture-oppsett. Barn-mocken returnerer Beate (`12345678904`) og Ola (`12345678905`) for Doktor/Kari, bare Beate for Anne og en tom liste for Beate, Ola og ukjente foreldre. Barna kan dermed skrive som seg selv uten personvalg eller varsel om feil ved henting av foreldreansvar. Verifiser-mocken tillater bare de fem tilsvarende forelder/barn-parene; Anne/Ola gir false selv om Salesforce-deling skulle finnes. Kjør `npm run activateFamilyMock` etter bruker-/delingsoppsettet; dette inngår også i `npm run scratchSetup` og `npm run mac:build`. Innstillingen aktiveres for alle fem testbrukerne og gjelder fortsatt andre ApiController-integrasjoner for disse brukerne. Barna får ikke `STO_Scratch_Family` eller rett til å representere andre. Eksisterende Account-/Person-deling er nødvendig i tillegg til mockansvaret. Mocken modellerer bare den syntetiske familien, ikke ekte PDL-ansvar. Før reelle kall må de brukerbaserte mock-innstillingene deaktiveres; `deactivateMock.cls` endrer bare profilinnstillinger.

Informasjon om representasjon vises bare i personvalgsteget. Etter «Neste» bruker meldingsskjemaet vanlig ingress for valgt rute/tema, uavhengig av om personen valgte `Deg` eller et barn. Personbanneret og det separate lese-/utloggingsvarselet beholdes.

`scratchFamilySharing.cls` gir testfamilien Account-/Person-tilgang og kan fortsatt legge til eldre fixture-delinger uten å flytte eller endre samtalene. Den er ikke autorisasjonskilde for frontend. Innboksen og registreringssiden bruker de nye tilgangsforberedende Apex-endepunktene; nye referater og tråder deles ved neste innbokshenting. Se `dummy-data\README.md` for testoppsett.

<!-- TODO(backend-ready): Keep this ownership/query contract and revalidate sharing when the production backend is connected. -->

Ved sending på vegne av et barn skal samtalen gjelde barnet, mens forelderen beholdes som originale innsender. Personvalget skal hente samtaler for samme barn, og barnet skal kunne finne dem i egen innboks. Produksjonsdeling og tilbakekalling må fortsatt ferdigstilles i backend.

<!-- TODO(backend-ready): Retain these regressions and replace the scratch-profile integration fixture when production integration is available. -->
<!-- TODO(backend-ready): Preserve the reply owner's perspective when replacing inferred sender/owner context with verified backend context. -->

`stoHelperClass.getReplyContext` bruker den første innbyggermeldingens kontakt som originale innsender, ikke trådeieren eller den som sist svarte. Mangler den første eksterne meldingen avsenderkontakt, gis ingen innbygger skriverett; en senere melding kan ikke overta rollen som originale innsender. Før første innbyggermelding brukes oppretterens kontakt; eldre internt opprettede samtaler uten innbyggermelding beholder egenkontakt som mottaker/svarer. Andre foreldre og barnet får kun lesevisning, også når barnet startet samtalen. I samtaler startet på vegne av barnet viser representasjonsbanneret barnets navn og alder fra `Person__c`, for eksempel «Gjelder: Beate Normann (8 år)», uten relasjon som datter/sønn. Banneret skjules når barnet selv leser egen samtale, også når en forelder startet den og når den er avsluttet. Ukjent dato utledes ikke fra navn. Scratch-oppsettet gir alle fem familiemedlemmene et separat, skrivebeskyttet felt-/objektsett for denne etiketten. Foreldre deler fortsatt bare ansvarsbarnas `Person__c`-poster; hvert barn får bare egen `Person__c`-post delt. Under meldingene vises informasjonen «Bare den personen som har startet samtalen kan svare» med lenke til ny melding. Feil ved henting av svarkontekst skjuler svar-/avslutningskontrollene og vises eksplisitt.

Bannerteksten avhenger av hvem som leser: forelderen som startet samtalen ser «Gjelder: Beate Normann (8 år)». Andre med foreldreansvar ser originale innsender og barnet, for eksempel «Kari Normann på vegne av Beate Normann», uten alder eller relasjonsbetegnelse. Barnet selv ser ikke banneret. Samme perspektiv beholdes etter avslutning; visningen endrer ikke hvem som kan svare eller avslutte.

Saksbehandlerens svarmal i `crmStoMessaging` bruker fornavnet til originale innsender, ikke personen som kontoen/saken gjelder. En samtale Anne startet på vegne av Beate får derfor «Hei, Anne» / «Hi, Anne». Både Case- og Thread-visning bruker `STO_RecordInfoController.getReplyRecipientFirstName` og samme innsenderregel i `stoThreadAccess`; senere meldinger bytter ikke mottaker. Egne samtaler og eldre internt opprettede tråder uten innbyggermelding beholder egenkontakt som mottaker. Ukjent original avsender gir en nøytral hilsen uten navn; hentefeil vises eksplisitt og svarfeltet venter på mottakeren. Saksbehandlernavn/enhet i signaturen og kontoeierskap er uendret. Endringen gjelder nye svarutkast, ikke teksten i historiske sendte meldinger.

`stoThreadAccess` brukes av `stoMessageAccessHandler` og `stoThreadAccessHandler` i eksisterende `MyTriggers` via `MyTriggerSetting.STO_Original_Sender_Message` og `MyTriggerSetting.STO_Original_Sender_Close` (ingen tillatt bruker-bypass). Den håndhever samme regel ved innsetting av meldinger og avslutning av STO/STB/BTO. Dette dekker også direkte kall til eksisterende `CRM_MessageHelperExperience.createThreadMessage`, `stoHelperClass.closeThread` og eldre klienter. Eksisterende Edit shares gir ikke unntak. Interne saksbehandlerflyter og backendens markering som lest er uendret. Deploy tilgangsklassen og begge handlerne med metadataregistreringene, `stoHelperClass`, `communityThreadViewer`, `stoInboxCloseItem` og `stoInboxInformation` samlet. Kategorifilteret har egen toppmarg, også når personvelgeren ikke vises.

### Ulest for hver innlogget leser

STO/STB/BTO bruker nå varig lesestatus per innlogget bruker og tråd, også mellom enheter. `STO_Thread_Read_State__c` har én post per faktisk åpnet `(User, Thread)`, med unik External ID `Reader_Thread_Key__c = UserId:ThreadId`. `Reader__c` bestemmes alltid fra `UserInfo.getUserId()`, aldri fra klienten. `stoThreadReadState` validerer både tråddeling, konto via `stoPersonContext` og at den viste meldingen tilhører tråden. Objektet er privat; `STO_Experience` gir klasse-/lesetilgang, men ingen direkte oppretting, endring eller sletting av kvitteringer.

Leseposisjonen er `(Message__c.CreatedDate, Message__c.Id)`, valgt fra meldingene klienten faktisk har hentet, ikke fra tidspunktet for lesekallet. Opprettelsestid er stabil selv om sendt-dato korrigeres; ID bryter likhet ved samme tidspunkt. `crm-henvendelse` sin `CRM_MessageHelperExperience.getGroupedMessagesFromThread` returnerer derfor også `CreatedDate`. Det kreves ingen ny trigger, sekvens eller oppdatering/lås på den delte tråden ved innkommende meldinger. Bare leserens eksisterende kvittering låses ved oppdatering; eldre/identisk posisjon gir ingen DML. Første oppretting bruker insert med unik nøkkel i stedet for blind upsert, som ellers kunne overskrive en nyere posisjon ved samtidige førstegangslesinger. Klienten forsøker en duplikat-/låskonflikt én gang til, og viser deretter feil eksplisitt.

`numberOfUnreadMessages` er for STO/STB/BTO en **0/1-indikator**, ikke et globalt antall. Den beregnes fra nyeste `Message`/`Info` som ikke er sendt av innlogget kontakt. Egen siste melding skjuler dermed ikke en eldre ulest innkommende melding. Samme indikator styrer både merket `Ulest` og seksjonen: åpen eller ulest gir **Siste meldinger**, avsluttet og lest gir **Tidligere meldinger**. Chat og samtalereferat beholder sine globale regler. Eksisterende `markAsRead`, `CRM_Read__c` og `CRM_Read_Datetime__c` beholdes for rapportering/arbeidsflyter etter at den personlige kvitteringen er lagret, men brukes ikke som personlige kvitteringer.

**Migrering:** Ingen kvitteringer fabrikeres fra gamle globale flagg eller nettleserlagring. Uten personlig kvittering regnes innkommende meldinger som uleste, også for trådeieren, til personen åpner tråden. Tidligere leste avsluttede samtaler kan derfor først vises under Siste meldinger. Dette er et bevisst, konservativt engangsskifte; et globalt flagg kan ikke bevise hvem som leste. `stoReadState` bruker ikke lenger `localStorage`; gamle nøkler er ubrukte og inneholder ingen migrerbare bevis.

**Volum:** `getInboxPage` henter maksimalt 50 tråder og 50 samtalereferat per side, med én ekstra rad for å avgjøre om mer finnes. Keyset-cursor bruker siste meldings-/registreringsdato og ID, også ved like/null datoer; ingen OFFSET og ingen SOQL i løkker. Forespørsler avgrenses med konto-/tråd-/leseroppslag eller unik ekstern nøkkel. Per tråd hentes bare siste forhåndsvisning, siste innkommende melding og første innbyggermelding; hele meldingshistorikken hentes ikke av innbokskort. Forhåndsvisninger begrenses til 500 tegn for tråder og 1000 tegn for samtalereferat; full lagret tekst endres ikke. Antall SOQL er fast uavhengig av tråd-/meldingsvolum (sju toppnivåspørringer på første egeninnboksside, inntil to ekstra cursor-oppslag og eksisterende autorisasjonsoppslag for representasjon). «Last inn flere meldinger» gjør eldre innhold tilgjengelig uten en ubegrenset innlasting. Kategorifilter gjelder innlastede sider. Nye meldinger mens man blar kan endre sorteringen; returbesøk/fokus/oppfrisking starter på nytt fra første side. Klienten avdupliserer ID-er ved sideinnlasting.

Kvitteringslagring vokser med **åpnede bruker-tråd-par**, ikke antall meldinger. Eksempel: 1000 nye åpnede tråder daglig med tre lesere gir omtrent 1,1 millioner kvitteringer årlig (omtrent 2,2 GB ved Salesforces normale 2 KB per custom-object-post, før øvrig overhead). Avklar oppbevaring/arkivering før produksjonsutrulling. Lookup til tråd bruker SetNull for å unngå ny master-detail-låsing; sletting av tråd kan etterlate en kvittering uten tråd. En godkjent vedlikeholdsjobb må rydde slike foreldreløse poster og eventuelt utløpte kvitteringer; ingen automatisk sletting/retensjon er lagt til uten en vedtatt policy. Query-planer og samtidighet bør belastningstestes med produksjonslignende datamengder; enhetsregresjoner er ikke en full kapasitetstest.

Deploy objekt/felt, `stoThreadReadState`, `stoInboxHelper`, `stoThreadAccess`, `STO_Experience`, de berørte LWC-ene og `CRM_MessageHelperExperience`-endringen fra søsterrepoet samlet. Innboksen oppfriskes ved retur til Home, pageshow, fokus/synlig fane og etter personlig lesekvittering; avslutning beholder eksisterende sidelasting. Feil ved lagring eller sideinnlasting vises eksplisitt.

Personlig kvittering og globale rapporteringsflagg lagres nå i samme `markThreadRead`-transaksjon. En medforelder med bare Read-deling skal ikke kalle `CRM_MessageHelperExperience.markAsRead` direkte: den gamle metoden krever oppdateringstilgang til meldingen. Etter kontroll av tråd-/kontotilgang og vist melding oppdaterer en privat, avgrenset `without sharing`-hjelper bare `CRM_Read__c` og `CRM_Read_Datetime__c` på denne trådens uleste meldinger. Ingen ekstra skriverett deles ut, og eksisterende svar-/avslutningskontroller beholdes. Reelle oppdateringsfeil ruller tilbake transaksjonen og vises; eksisterende personlig posisjon hindrer ikke reparasjon av manglende rapporteringsflagg. Feilvarsler i trådvisningen bruker Aksel-fargen `danger` (rød), ikke den ugyldige fargen `error`.

Datatilgang angis eksplisitt, også med Apex API 67: tråd og vist melding kontrolleres i `USER_MODE`, mens serverstyrte kvitteringer leses/skrives i `SYSTEM_MODE` med innlogget leser og nøkkel som avgrensning. Klienten får fortsatt ingen direkte skriverett til kvitteringsobjektet. Rapporteringens begrensede feltoppdatering bruker også eksplisitt systemmodus etter autorisasjonskontrollen.

Kjør `post-scratch\scratchSetup.cls` og deretter `post-scratch\scratchFamilySharing.cls` i scratch org etter metadata-deploy. Det gir nødvendige innlogginger/tillatelser og konto-/Person-tilgang uten å slå av `with sharing`. Ingen eksisterende tråder flyttes. `stoPersonContextTest`, `stoHelperClass_Test` og `stoInboxHelperTest` dekker opprettelse, avsender, personavgrensning, trådgrenser og barnets egen innlogging. Innloggingstesten bruker profilen til en eksisterende aktiv Plus-community-bruker, og forutsetter at community-oppsettet er utført.

## Backend-ready lifecycle: what to keep, replace or remove

<!-- TODO(backend-ready): KEEP this inventory current while replacing scratch sharing; REMOVE only entries for confirmed retired artifacts. -->

`TODO(backend-ready)` marks integration follow-up, **not** a request to delete the surrounding file. KEEP means retain and revalidate; REPLACE means change the named temporary implementation; REMOVE means retire only that fixture/artifact after its consumers are removed. Child selection and account/contact authorization use `NKS_ForeldreansvarService.barn()`. Read sharing for authorized inbox access uses Apex-managed shares for threads and conversation notes; automatic revocation of existing grants remains separate work. Scratch setup remains separate from authorization.

All paths below are relative to the repository root:

| Decision | Paths | Purpose / backend-ready action |
| --- | --- | --- |
| KEEP | `force-app\main\default\classes\stoPersonContext.cls` and `stoPersonContext.cls-meta.xml` | Shared `barn()` selection/resolution API, self resolution, server-side account validation and `with sharing`. `scratchFamily()` remains only for scratch sharing/setup consumers. |
| KEEP / REPLACE fixture | `force-app\main\default\classes\stoPersonContextTest.cls` and `stoPersonContextTest.cls-meta.xml` | Ownership, creator/sender, limits, denial and citizen-login regressions plus mocked `barn()` contract, errors, empty results, per-actor caching and sharing checks. Test-only account injection isolates unrelated ownership tests. Scratch sharing/profile fixtures remain separate from API authorization. |
| KEEP | `force-app\main\default\classes\stoHelperClass.cls`, `force-app\main\default\classes\stoInboxHelper.cls`, `force-app\main\default\classes\stoThreadSharing.cls`; `STO_Family_Read__c` sharing reasons on Thread and Conversation Note | Creation preserves the authenticated sender; imperative person-scoped endpoints authorize before granting Salesforce Read access and querying the inbox. Reply context and mutation checks remain server-owned. |
| KEEP | `force-app\main\default\classes\stoThreadReadState.cls`, `stoThreadReadStateTest.cls` and descriptors; `force-app\main\default\objects\STO_Thread_Read_State__c`; `force-app\main\default\lwc\stoReadState` | Persistent private per-user/thread positions, concurrency/authorization and bounded query regressions. No local-storage receipts or per-message receipt records. Retain the `CreatedDate` projection in sibling `crm-henvendelse`'s `CRM_MessageHelperExperience`. Define approved retention/orphan cleanup before production. |
| KEEP / REPLACE inference | `force-app\main\default\lwc\communityThreadViewer\communityThreadViewer.js` and `.html` | Keep complete reply notices. Replace owner/actor/first-message inference with explicit verified representation context when available. |
| KEEP | `force-app\main\default\lwc\stoMessageInbox\stoMessageInbox.js`, `.html`, `.css`; `force-app\main\default\lwc\stoRegisterThread\stoRegisterThread.js`, `registerThreadTemplate.html` | Keep real account selections/queries, conditional dropdown, explicit errors with self availability, spacing and complete notices. No client-side mock provider. |
| KEEP | `force-app\main\default\permissionsets\STO_Experience.permissionset-meta.xml` | Keep resolver/read-state API access and read-only receipt permissions; this is separate from scratch fixture permission. Never grant clients direct receipt writes. |
| REMOVE when fixture retired | `force-app\main\default\customPermissions\STO_Scratch_Family.customPermission-meta.xml`; `force-app\main\default\permissionsets\STO_Scratch_Family.permissionset-meta.xml`; fixture grants in `force-app\scratch-org\profiles\Scratch Community Profile.profile-meta.xml` | Retire with the remaining scratch sharing/map, parent grants and co-parent Read shares, never grant as production parental authorization. Keep the rest of the profile. |
| KEEP while demo exists | `force-app\scratch-org\profiles\Scratch Community Login Profile.profile-meta.xml`; `post-scratch\scratchSetup.cls`; `post-scratch\scratchFamilySharing.cls` | Login-license profile and idempotent user/permission setup followed by a separate record-sharing transaction. REMOVE fixture grants/shares when replacing the provider; production access/revocation needs an approved implementation. Do not remove unrelated setup. |
| KEEP while demo exists | `bin\install-scratch.sh`; `dummy-data\GenerateData.apex`; `dummy-data\data\persons.json`, `dummy-data\data\plan.json`; `dummy-data\sto\plan.json`, `dummy-data\sto\threads.json` | Scratch import ordering, synthetic people and deterministic sample account/contact linking. Not a production migration. JSON cannot contain TODO comments; this inventory covers its fixture lifecycle. Deleted legacy `dummy-data\data\cases.json` and `dummy-data\sto\accounts.json` were replaced by deterministic setup/PersonHandler, not failed output; do not recreate duplicate accounts/cases. |
| KEEP | `README.md`; `dummy-data\README.md` | Existing project/setup documentation, updated in place. No extra README was generated for this fix. Revise fixture instructions when retiring the provider. |

<!-- TODO(backend-ready): REMOVE candidate sfp.cmd only after owner confirmation; it is not part of the backend implementation. -->

`sfp.cmd` is an **untracked, nonfunctional REMOVE candidate**, not a project dependency or valid sfp launcher: it contains only a machine-specific PATH assignment ending in `--version\PATH.txt`. Git has no tracked version/history for it; its creator cannot be established from this checkout. It has been left unchanged pending confirmation. Do not run it or confuse it with installed CLI shims outside this repository.

<!-- TODO(backend-ready): KEEP Apex regression coverage when replacing the provider; LWC tests were removed at user request. -->

Earlier task-added component Jest tests and their dedicated presentation stubs were removed at user request. Apex regression tests cover the three-parent fixture, ownership and responsibility exclusions. `stoThreadReadStateTest` covers bounded multi-page retrieval with 121 threads/968 messages, cursor monotonicity, own-message exclusion and denial. `stoPersonContextTest` covers independent receipts for two parents and a child, including global read marking not clearing someone else's unread state. `stoReadState` has isolated Jest coverage for displayed-position selection, server writes and bounded conflict retry without presentation stubs or Jest configuration changes. No client-side family mock is used.

The bulk fixture disables only the unrelated `MessageCacheHandler` while creating its messages: that existing integration handler repeats a user lookup per message when the Modia integration user is absent. No runtime bypass or change to that handler is included. The inbox query bounds are therefore covered, but the test does not establish end-to-end ingestion throughput for every installed integration.

Innbokskortene viser originale innsender over tittelen uten å endre bakgrunnsfargen: «Kari Normann startet samtalen» når en annen person startet tråden. Den innloggede som selv startet tråden ser ingen avsendertekst, også når samtalen gjelder et barn. Dette er separat fra representasjonsbanneret inne i samtalen; innbokskort bruker aldri «på vegne av». Foreldre som leser en samtale barnet startet selv ser «Beate Normann startet samtalen». Dette gjelder både siste og tidligere meldinger, med eksisterende person-/kategorifilter. Avsenderetikett og lesestatus returneres nå samlet i tråd-DTO-en. Kortet har ingen egne Apex-/UI API-wirer; feil i sidehentingen vises på innboksnivå.

Personvelgeren i innboksen starter på innlogget bruker (`Deg`) ved et nytt besøk uten returkontekst. Valget lagres ikke i nettleserlagring. Ved valg av barn lagres bare Account-ID i sidens URL-state (`c__inboxPerson`), slik at nettleserens tilbakeknapp beholder valget. Trådlenker og «Innboks»-brødsmulen tar med samme returkontekst. En vanlig inngang til innboksen uten denne parameteren velger `Deg`, også når komponenten gjenbrukes. Returnert Account-ID valideres alltid mot nyhentet foreldreansvar før innhold vises.

## Sider i innboksen

`{BASE_URL}` er adressen til innboksen i valgt miljø, uten avsluttende skråstrek. I produksjon er den `https://innboks.nav.no/s`; i en scratch org er den for eksempel `https://<org>.scratch.my.site.com/Innboks/s`. Sidene krever innlogging.

| Funksjon | URL | Beskrivelse |
| --- | --- | --- |
| Innboksen | `{BASE_URL}` | Se siste og tidligere meldinger. |
| Skriv ny STO | `{BASE_URL}/skriv-til-oss?category=<tema>` | Still et spørsmål innen valgt tema. |
| Meld fra om endring (BTO) | `{BASE_URL}/beskjed-til-oss?category=endring-<tema>` | Meld fra om en endring som gjelder en ytelse eller situasjon. |
| Trekk en søknad (BTO) | `{BASE_URL}/beskjed-til-oss?category=trekke-soknad-<tema>` | Gi beskjed om at en søknad skal trekkes. |
| Gi beskjed (BTO) | `{BASE_URL}/beskjed-til-oss?category=beskjed-<tema>` | Send en beskjed for et av de støttede formålene. |
| Vis en STO/STB | `{BASE_URL}/skriv-til-oss/<id>` | Åpne en eksisterende samtale. `<id>` er samtalens ID. |
| Vis en BTO | `{BASE_URL}/beskjed-til-oss/visning?samtale=<id>` | Åpne en tidligere innsendt beskjed. `<id>` er samtalens ID. |
| Vis en chat | `{BASE_URL}/chat/<id>` | Åpne en chat. |
| Vis et samtalereferat | `{BASE_URL}/samtalereferat/<id>` | Åpne et samtalereferat. |

### Temaer for STO

Bruk verdien fra tabellen som `category`, for eksempel `{BASE_URL}/skriv-til-oss?category=familie`.

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

Sett sammen prefikset og et tema fra samme rad. For eksempel blir `endring-` og `aap` til `category=endring-aap`. Det er ikke nok å bruke et STO-tema alene i en BTO-lenke.

| Formål | Prefiks | Støttede temaer |
| --- | --- | --- |
| Meld fra om endring | `endring-` | `dagpenger`, `tiltakspenger`, `ventelonn`, `grunn-og-hjelpestonad`, `yrkesskadetrygd`, `omsorg-fosterhjem`, `arbeidsevne`, `enslig`, `barnetrygd`, `kontantstotte`, `bidrag`, `uforetrygd`, `tilleggsstonader`, `aap`, `foreldre`, `sykdom-familien`, `afp-offentlig`, `supplerende-stonad-flyktninger`, `supplerende-stonad-over-67`, `alderspensjon`, `gjenlevende`, `sykepenger`, `utland`, `yrkesskade` |
| Trekk en søknad | `trekke-soknad-` | `arbeid`, `helse`, `utland`, `familie`, `pensjon`, `hjelpemidler`, `ufor` |
| Gi beskjed | `beskjed-` | `trygdeavgift`, `sykepenger`, `menerstatning`, `afp-offentlig`, `afp-privat`, `kontor`, `fullmakt-lege`, `klage`, `taushetsplikt` |

Eksempler:

- `{BASE_URL}/beskjed-til-oss?category=endring-aap`: meld fra om endring for arbeidsavklaringspenger.
- `{BASE_URL}/beskjed-til-oss?category=trekke-soknad-familie`: trekk en søknad innen familie og barn.
- `{BASE_URL}/beskjed-til-oss?category=beskjed-kontor`: avtal eller endre time på Nav-kontor.

`category` må ha en støttet verdi. En manglende eller ukjent verdi viser en feilside i stedet for meldingsskjemaet.
