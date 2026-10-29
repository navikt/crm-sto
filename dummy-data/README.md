# How to use dummy data with SFDX

## STO test persons and community login

<!-- TODO(backend-ready): KEEP these scratch-data instructions; REPLACE/REMOVE only retired fixture details, as listed in the root README lifecycle inventory. -->

`data/persons.json` contains three synthetic parents and two children. The scratch sharing/setup fixture in `stoPersonContext.scratchFamily()` models these relationships, but no longer authorizes child selections:

| Parent | Synthetic identifier | Foreldreansvar |
| --- | --- | --- |
| Doktor Proktor (Far) | 12345678901 | Felles ansvar for Beate and Ola |
| Kari Normann (Mor) | 12345678902 | Felles ansvar for Beate and Ola |
| Anne Normann (Medmor) | 12345678903 | Beate only |

Beate Normann (`12345678904`) was born 2018-10-18 and Ola Normann (`12345678905`) was born 2014-10-18. Dropdown labels contain only name and age, calculated from `Person__c.INT_DateOfBirth__c` (8 and 12 after 18 October 2026). Choices carry real Account IDs. Children aged 18 or above, kode 6/7 and any confidentiality other than `UGRADERT` are excluded by the resolver.

<!-- TODO(backend-ready): Retire the scratch sharing fixture when approved production sharing/revocation is available. -->

Both the inbox and registration form keep the existing `getRepresentableChildren` wire. The resolver calls `NKS_ForeldreansvarService.barn()` with the authenticated parent's Account identity, then matches returned child identities to existing accessible Accounts. Scratch domain, `STO_Scratch_Family` and the family map are not selection/registration authorization. The backend must return the fixture children for them to appear; local setup/shares alone are insufficient. `Deg` remains available without a callout. Names are display-only, never authorization. See the root README for deployment and API prerequisites. Apex tests mock `barn()` rather than relying on a live relationship service.

For scratch testing, deploy crm-sto's `stoForeldreansvarMock`, `stoPersonContext` and `STO_Foreldreansvar_Family.resource` together. The JSON resource defines the synthetic relationships and is also read by `scratchFamily()` for setup/sharing. No changes to crm-platform-base, ApiController or the integration's mock metadata are required. The local provider is used only on a scratch domain with the existing user/profile mock setting enabled at status 200 (user settings take precedence). Other environments, disabled mocks and other status codes keep using the integration. Doktor and Kari receive Beate (`12345678904`) and Ola (`12345678905`); Anne receives only Beate. Verification returns true for those five parent/child pairs and false for Anne/Ola or any unknown pair. Unknown parents receive no children, not blanket authorization. Run the unchanged `npm run activateFamilyMock` after user/sharing setup. This uses the existing `API_Controller_Mock_Settings__c` mechanism, scoped to the three parent logins, and is included in both scratch-setup entry points. No identifiers or credentials need changing. Account/Person sharing is still required in addition to the mocked responsibility response. These user-level settings affect other ApiController integrations for those users and must be disabled before live calls; the existing profile-level `deactivateMock.cls` does not override them.

Sending an STO uses the existing `resolveAccountId` / `resolveContactId` path and creates a real thread linked to the child's Account and Contact. Creator and message sender remain the active parent. The child and other fixture parents with Foreldreansvar get Read shares on newly created threads. Child-started STO/BTO threads also grant Read access to their responsible fixture parents: only the recipient parents need `STO_Scratch_Family`, not the child sender. Protected (kode 6/7) and adult children receive no new parent shares. Run `scratchFamilySharing.cls` to idempotently add missing Read shares to existing eligible child-owned STO/STB/BTO threads; it does not modify conversations or messages. Only the original sender can reply or close, including when the child started the thread. The first citizen message identifies the sender; account ownership alone never grants reply access. The viewer displays a representation banner and read-only information/link for other readers. `stoThreadAccess` is called by `stoMessageAccessHandler` / `stoThreadAccessHandler` in the existing `MyTriggers` framework with `MyTriggerSetting.STO_Original_Sender_Message` / `STO_Original_Sender_Close` to enforce this for existing mutation endpoints and old Edit shares too. Deploy these with `stoHelperClass`, `communityThreadViewer`, `stoInboxCloseItem` and `stoInboxInformation`. This is a scratch fixture, not production relationship authorization or revocation.

Import `data/plan.json` before running `npm run scratchSetup`. The crm-platform-base `PersonHandler` creates a Person Account and contact for each imported person. `post-scratch/scratchSetup.cls` creates missing community users for all five people and assigns `STO_experience`. Only the three parents receive the `STO_Scratch_Family` permission set, including the custom permission, Account identity/Person lookup read access and read access to Person birth date/confidentiality. Each parent gets Account and Person shares only for their children. Account sharing alone does not expose the Person relationship to a community user. Doktor Proktor uses `Scratch Community Profile` (Customer Community Plus); Mor, Medmor and the children use `Scratch Community Login Profile` (Customer Community Plus Login) because the scratch org has only one member-based Plus license.

In an existing scratch org, deploy the crm-nks-integration foreldreansvar service/metadata, `stoPersonContext`, `stoHelperClass`, their tests, the LWCs, updated `STO_Experience`, the scratch profiles, the `STO_Scratch_Family` custom permission, and both `STO_Scratch_Family` and `STO_Thread_Representation_Label` permission sets. Import only missing person records, then run `sf apex run --file post-scratch/scratchSetup.cls` followed by `sf apex run --file post-scratch/scratchFamilySharing.cls`. User/permission DML and record-share DML require separate transactions (`MIXED_DML_OPERATION` otherwise). Both setup steps are idempotent; data-tree import is not. The npm and mac setup entry points run both steps in order. When updating an existing org, run just these two scripts rather than regenerating the existing sample conversations. Publish the Experience site after LWC deployment. Do not weaken the scratch-only sharing gates to enable fixture shares in a sandbox or production.

After activating and publishing the Experience site as described in the root README, open any of the five Person Accounts and choose **Log in to Experience as User**. No password is stored in the repository. `GenerateData.apex` keeps linking imported sample conversations to Doktor Proktor's existing Person Account and contact, and creates another sample conversation for him. Child selections fetch real account-scoped threads through Apex; there is no client-side mock fallback.

## Retained fixture dependencies

<!-- TODO(backend-ready): KEEP these import dependencies while the demo exists; JSON does not support inline TODO comments. See root README for exact paths. -->
The import plans retain data used by the existing scratch scenarios:

-   `GenerateData.apex` creates its sample case with Doktor Proktor's Person Account and contact, rather than selecting an arbitrary existing case. A separate case import is no longer needed.
-   `data/pushtopics.json` supplies `Thread_New_Message`, subscribed to by the crm-henvendelse thread viewers.
-   `common_codes/plan.json` supplies the code sets queried by STO and task handling. SSDX discovers this plan through its configured `dummy-data` location.
-   `sto/plan.json` supplies sample threads and messages identifying Doktor Proktor. After importing `data/plan.json` and `sto/plan.json`, run `sf apex run --file dummy-data/GenerateData.apex` (also included in `npm run scratchSetup` and `npm run mac:build`) to resolve their `CRM_Account__c` and `CRM_Contact__c` to his Person Account. This avoids a duplicate Account import and reliance on the importing user's default Account record type.

The standalone Ola Hansen, Kari Larsen and Frode Johnsen account fixtures have been removed. The old sample threads incorrectly linked Doktor Proktor's external identity to Ola Hansen's account. Existing account and conversation records are not deleted or automatically reassigned; the setup only links matching imported threads whose account is empty.

## Exporting with record types

Always add `RecordType.DeveloperName` to your SOQL query when exporting, if you want to keep the record type intact. A plugin is fixing the record type ID before it is imported to the new scratch org, so you won't have to do a single thing.

## Exporting data from an org

For exporting with lookups, the easiest method is to export the parent and use relationship queries. (e.g., `SELECT Name, RecordType.DeveloperName, (SELECT LastName FROM Contacts) FROM Account`). This command will export your query:

```java
sfdx force:data:tree:export --query "SELECT [fields] FROM [sObject]" --outputdir dummy-data/[name] --plan
```

Use a name for the feature this data is suitable for, OR the name of the object.

Sometimes, you'll need to export from the child with numerous parents (many lookups).

-   For the child records
    -   `sfdx force:data:tree:export --query "SELECT [fields] FROM [child sObject]" --outputdir dummy-data/[name] --plan`
-   For the parents
    -   `sfdx force:data:tree:export --query "SELECT [fields] FROM [parent sObject 1]" --outputdir dummy-data/[name]` (remove --plan)
    -   `sfdx force:data:tree:export --query "SELECT [fields] FROM [parent sObject 2]" --outputdir dummy-data/[name]` (remove --plan)
    -   `sfdx force:data:tree:export --query "SELECT [fields] FROM [parent sObject 3]" --outputdir dummy-data/[name]` (remove --plan)

You'll then **_rename_** `dummy-data/[name]/[Child sObject]s-plan.json` to **ONLY be plan.json** (in the same folder). Then edit the file, and make sure each json file containing data is present in the plan. The plan.json file is the plan for what is imported.

```json
[
    {
        "sobject": "[Parent sObject]",
        "saveRefs": true,
        "resolveRefs": false,
        "files": ["[Parent sObject]s.json"]
    },
    {
        "sobject": "[Child sObject]",
        "saveRefs": false,
        "resolveRefs": true,
        "files": ["[Child sObject]s.json"]
    }
]
```

Because the json file containing data for the parent contains a `referenceId`, `saveRefs` is set to true for the parent above and `resolveRefs` is true for the child, you can have lookup relationships without actual IDs.

That means you'll have to edit `[Child sObject]s.json` (the data for the child records) to include the lookup by having `"[Parent sObject]": "@[Parent sObject]RefX"` (example below). Because `resolveRefs` is set to true on the child sObject, the SFDX import function automatically creates the lookup.

Example `myFeature-plan.json`:

```json
[
    {
        "sobject": "Account",
        "saveRefs": true,
        "resolveRefs": false,
        "files": ["myFeature-Accounts.json"]
    },
    {
        "sobject": "Case",
        "saveRefs": false,
        "resolveRefs": true,
        "files": ["myFeature-Cases.json"]
    }
]
```

Example `myFeature-Accounts.json`:

```json
{
    "records": [
        {
            "attributes": {
                "type": "Account",
                "referenceId": "AccountRef1"
            },
            "BillingState": "Wyoming",
            "ShippingState": "Wyoming",
            "BillingCity": "Cheyenne",
            "ShippingCity": "Cheyenne",
            "Name": "Yadel"
        }
    ]
}
```

Example `myFeature-Cases.json`:

```json
{
    "records": [
        {
            "attributes": {
                "type": "Case",
                "referenceId": "CaseRef1"
            },
            "Account": "@AccountRef1",
            "Name": "My first case"
        }
    ]
}
```

## File and folder structure

**ALWAYS** have dummy-data self-contained in its own folder, both for readability and avoiding overwriting existing data. If you want ALL scratch orgs to have your dummy data, add the data as `dummy-data/[name]/`, which contains ONE `plan.json` file and one or more `[sObjects].json` files, which are also referenced in the plan.sjon.

The init scripts for scratch org creation automatically find these `plan.sjon` files and imports them for you. If you don't want auto importing, have the `plan.sjon` file renamed to anything else, and it won't be imported.

## Importing dummy data

All data is automatically imported using the init scripts for macOS or Windows, as long as they follow the folder structures defined above. See `./scripts/mac/createScratchOrg.command` and `./scripts/windows/createScratchOrg.sh`.
