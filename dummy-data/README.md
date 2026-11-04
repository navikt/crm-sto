# How to use dummy data with SFDX

## STO scratch testing

These fixtures support manual testing of personal inboxes, messages written on behalf of a child, legacy shared read status, and internal STO/BTO handling. This guide explains the test scenarios and why their files are retained.

**Prerequisite:** Integrate the real backend support before deploying the whole project. Test setup supplies synthetic records and logins, not missing responsibility checks, conversation access, sender authorization or production routing.

Child selection retains the existing real `barn()` lookup. The service returns child identities, which are matched to accessible Person Accounts; displayed ages use the stored `Person__c.INT_DateOfBirth__c` birth dates, accounting for whether this year's birthday has occurred. Fixture relationships do not replace service responses.

Import `data\plan.json` followed by `sto\plan.json`. The family scenario contains three parents and two children:

| Person | Synthetic identifier | Expected backend responsibility |
| --- | --- | --- |
| Doktor Proktor (Far) | 12345678901 | Beate and Ola |
| Kari Normann (Mor) | 12345678902 | Beate and Ola |
| Anne Normann (Medmor) | 12345678903 | Beate only |
| Beate Normann | 12345678904 | Self only; born 2018-10-18 |
| Ola Normann | 12345678905 | Self only; born 2014-10-18 |

Check that Far/Mor can select both children, Medmor can select only Beate, and each child can use their own inbox without representation. When a child opens a conversation started by a parent, check that they see the same sender-on-behalf-of-child banner and open-conversation read-only notice as another parent. A child who started their own conversation keeps the ordinary reply view without a representation banner. Check original-sender-only replies/closure. Read status temporarily uses the existing shared `CRM_MessageHelperExperience.markAsRead` action when a conversation opens, so one reader can clear another reader's unread status. Per-reader tracking is deferred to a separate PR. Actual responsibility results, not the fixture family map, must control access.

Under both Helse and Familie, check that the pleiepenger-for-sykt-barn question is available when writing for yourself but absent when writing on behalf of a child. The child's message stays in the selected Helse/Familie topic, without a hidden or previously selected pleiepenger answer.

After opening a conversation, return to the inbox and check that refreshing shows the legacy unread count. Inbox refresh requests received during one request should be coalesced; switching person must ignore the old person's response, and leaving the component must cancel queued work. Request failures must remain visible.

### Automated child-selection coverage

The child-selection Apex tests use isolated synthetic Person Accounts and a community parent with explicit Read shares. Mocked HTTP responses exercise the real `barn()` call and eligibility query, including empty/error responses, duplicate or unmatched identities, non-person and unshared accounts, the 18th-birthday boundary, protected children, and future/missing birth dates. Existing name/age/identity formatting checks remain. These tests do not use a test-only eligibility bypass, scratch-family authorization, or live service responses; Salesforce rolls back their test records.

The fixture uses `STO Test Community Login Profile` from `force-app\test\profiles`, assigns `STO_Experience`, and adds a test-only permission set for Account/Person field reads and the fields needed to create a thread. The minimal custom profile declares only the Customer Community Plus Login license; test permissions are assigned separately. It is explicitly included by `.gitignore` and `.forceignore` and lives outside `scratch-org`, which the shared CI workflow deletes before deploying source. Deploy this profile together with the tests; the manual-testing scratch profiles are not test dependencies.

The test permission set grants Contact read access before Account read access to satisfy the Person Account permission dependency in fresh scratch orgs. It grants no View All access; explicit record shares remain necessary, and the protected-child test restores a revoked Person Read share only after removing protection. The negative business-account fixture selects a record type available to its owner, not merely an active one. User-level API settings supply required status fields while keeping `Use_Mock__c = false`, so `HttpCalloutMock` exercises the real service request path. Inbox retrieval tests insert viewer-owned thread/message fixtures directly rather than invoking unrelated parental verification.

Run `npm run scratchSetup` against the intended scratch org after deployment/import. The family has separate community logins; Doktor uses the single member-based Plus license and the other four use login-based Plus licenses. No password is stored in source.

User/permission setup and Account/Person sharing run in separate transactions to avoid `MIXED_DML_OPERATION`. They are idempotent. In an existing org, import only missing people and run just those two setup scripts when updating logins/fixture record access. Full setup also creates another generic sample conversation.

Activate/publish the Experience site as described in the root README, then use **Log in to Experience as User** from the selected test Person Account. For internal handling, use **Skriv til oss > Hent ny melding** to retrieve the named STO/Familie and BTO/Helse samples.

### Why the dummy-data files exist

Paths in this table are relative to `dummy-data`. JSON does not allow explanatory comments, so the purpose of every retained data/import file is recorded here instead of adding invalid JSON properties.

| File | Functionality covered / why it exists |
| --- | --- |
| `data\persons.json` | The five synthetic people, including children's birth dates and confidentiality. They provide real Person Accounts/contacts for separate parent/child login and age/access scenarios. |
| `data\pushtopics.json` | The existing `Thread_New_Message` notification for newly inserted messages, so message-view refresh behavior can be exercised. |
| `data\plan.json` | Imports people and message notifications before login creation and conversation linking. It is the first fixture import, not a production migration. |
| `sto\threads.json` | Existing chat/STO conversations across topics, giving the inbox recent/history content and links to open. Their owner/person references are completed after the person import. |
| `sto\messages.json` | Sample citizen messages with read/unread legacy flags, linked to the imported threads. It supplies message text and historical read scenarios, not personal read receipts. |
| `sto\plan.json` | Imports threads before messages and resolves each message's thread reference. This order preserves actual relationships between fixtures. |
| `common_codes\theme_groups.json` | Parent topic groups used to organize/categorize test cases and tasks. |
| `common_codes\themes.json` | Topic names/codes linked to those groups, so theme selection and categorization have representative data. |
| `common_codes\subthemes.json` | Processing subtopics linked to their parent topics, covering hierarchical categorization. |
| `common_codes\tasktypes.json` | Available task/action types for internal handling of the synthetic enquiries. |
| `common_codes\plan.json` | Imports the shared code sets in dependency order and resolves parent-code references. SSDX discovers this plan through the dummy-data location. |
| `GenerateData.apex` | Links the imported conversations to Doktor's generated Account/contact and creates the existing generic Case/Thread/Message sample. Separate tree imports cannot reference auto-generated records; this script fills that fixture-only gap. |

Legacy `data\cases.json` and `sto\accounts.json` were replaced by deterministic sample-case creation and automatic Person Account creation. Keeping them would duplicate Accounts and preserve the old mismatch between Doktor's identity and Ola Hansen's Account. No existing org records are deleted.

### Why the scratch setup files exist

Paths below are relative to the repository root.

| File | Functionality covered / why it exists |
| --- | --- |
| `post-scratch\scratchSetup.cls` | Creates missing logins for the five people and assigns ordinary inbox access. It is setup-record DML only, so it must be separate from record sharing. |
| `post-scratch\scratchFamilySharing.cls` | Gives the synthetic parents Read access to their fixture children's Account/Person records, and each child access to their own Person details. Those records need initial Salesforce access; this does not grant responsibility or share conversations. |
| `post-scratch\serviceResource.cls` | Makes the internal scratch agent available with the existing routing skills, so the normal message-retrieval workflow can be tested. |
| `post-scratch\scratchRoutingData.cls` | Creates one named STO/Familie and BTO/Helse Case/Thread/Message through ordinary assignment rules. Re-running does not duplicate/reopen them; real/community-owned submissions are never repaired or re-routed. |
| `post-scratch\activateMock.cls` | Existing optional switch enabling integration mock settings for all profiles. It does not implement responses or parental authorization, and is not automatically run for this family scenario. |
| `post-scratch\deactivateMock.cls` | Existing optional switch disabling those profile-level integration mocks for real-call testing. User-level overrides must be handled separately. |
| `bin\install-scratch.sh` | Creates the disposable test environment, installs dependencies, deploys metadata and runs the same data/setup workflow. Its cleanup step deletes the configured scratch org; choose steps deliberately. |
| `package.json` | Provides the npm commands for complete setup or the narrower routing-only scenario. |
| `sfdx-project.json` | Declares the environment's package dependencies and metadata API version; required backend support must be integrated before whole-project deployment. |
| `config\project-scratch-def.json` | Enables the community licenses, Person Accounts, service/console features and Omni-Channel settings needed by these scenarios. |
| `config\ssdx-config.json` | Tells SSDX where fixture/user/environment metadata lives and which existing internal-test permissions to assign. |
| `config\users\user.json` | Creates the separate Standard User integration fixture used by the existing SSDX environment setup, without a stored password. It is not one of the family logins. |

### Why the scratch metadata exists

The following paths are relative to `force-app\scratch-org`. Older generated login/password/profile scaffolding is unchanged and outside these STO-specific scenarios.

| File | Functionality covered / why it exists |
| --- | --- |
| `profiles\Scratch Community Profile.profile-meta.xml` | Member-based community login for Doktor, retaining the original scratch access. It does not grant parental responsibility. |
| `profiles\Scratch Community Login Profile.profile-meta.xml` | Login-based licenses for the other four family members, avoiding the scratch org's single member-based Plus-license limit. |
| `staticresources\STO_Foreldreansvar_Family.resource` | A JSON roster describing only synthetic relationships for Account/Person setup. It cannot authorize child selection or supply integration responses. |
| `staticresources\STO_Foreldreansvar_Family.resource-meta.xml` | Registers that JSON fixture as a private static resource, making it available to the scratch setup scripts. |
| `applications\STO.app-meta.xml` | The internal test console where testers inspect people, cases and threads and retrieve work from the STO utility. |
| `flexipages\Account_Record_Page.flexipage-meta.xml` | The console's person-account inspection view, including the actions used to enter a test person's community session. |
| `flexipages\Case_Record_Page.flexipage-meta.xml` | The existing case inspection/reply view retained for the console's smaller-screen case override. |
| `flexipages\Thread_Record_Page1.flexipage-meta.xml` | The existing generic thread inspection/reply page retained alongside the dedicated scratch thread view. |
| `flexipages\SCRATCH_STO_Case_Record_Page.flexipage-meta.xml` | The dedicated scratch case view for inspecting the synthetic person's information, conversation and reply workflow. |
| `flexipages\SCRATCH_STO_Thread_Record_Page.flexipage-meta.xml` | The dedicated scratch thread view for checking the conversation's person association and internal response workflow. |
| `flexipages\STO_UtilityBar.flexipage-meta.xml` | Adds the internal message-retrieval tool used for the named routing scenarios. |
| `community\networks\Innboks.network-meta.xml` | Makes the scratch inbox community available to the configured members and provides its community URL/membership settings. |
| `community\sites\Innboks.site-meta.xml` | Configures the underlying scratch site and its existing login/error handling so community sessions can open the inbox. |
| `layouts\PersonAccount-Person Account Layout.layout-meta.xml` | Standard scratch person-account details/actions for inspecting imported people before logging in as them. |
| `objects\Account\listViews\All_person_accounts.listView-meta.xml` | A list of person-linked accounts, helping testers find the synthetic family. |
| `permissionsets\Scratch_Permissions.permissionset-meta.xml` | Existing internal-test rights for the STO console, sample cases and FAQ records, separate from citizen/parent access. |
| `settings\BusinessHours.settings-meta.xml` | The default and STO calendars required to exercise the existing case/service timing setup in the scratch environment. |

`unpackaged\queues\*.queue-meta.xml` defines the existing topic-specific STO/BTO queues and protected/closed-case variants. `unpackaged\assignmentRules\Case.assignmentRules-meta.xml` assigns cases to those queues by origin/topic. They are deployed for the routing scenario, not replaced by custom fixture routing.

<!-- ToDo(backend): Supply real responsibility checks/responses, permissions, conversation access, sender rules and production routing. Test fixtures must not reproduce these functions. -->

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
