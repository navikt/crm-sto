# How to use dummy data with SFDX

## STO test persons and community login

<!-- TODO(backend-ready): KEEP these scratch-data instructions; REPLACE/REMOVE only retired fixture details, as listed in the root README lifecycle inventory. -->

`data/persons.json` contains Doktor Proktor (`12345678901`) and the two children from the LWC mock data: Beate Normann (`12345678904`, `mock-child-1`) and Ola Normann (`12345678905`, `mock-child-2`). All identifiers are synthetic test values. The children's birth dates match the mock labels (8 and 12 years old in October 2026); the labels are static.

Import `data/plan.json` before running `npm run scratchSetup`. The crm-platform-base `PersonHandler` creates a Person Account and contact for each imported person. `post-scratch/scratchSetup.cls` then creates any missing community users and assigns `STO_experience`. Doktor Proktor uses `Scratch Community Profile` (Customer Community Plus); the children use the custom `Scratch Community Login Profile` (Customer Community Plus Login) to avoid exhausting the single member-based Plus license in a scratch org. `CustomerCommunityPlusLogin` is already enabled in the scratch definition. Deploy the new profile from `force-app/scratch-org/profiles` before running setup in an existing org. The setup can be rerun without duplicating users or permission assignments. The data-tree import itself is not idempotent: in an existing org, import only missing person records before rerunning that script.

After activating and publishing the Experience site as described in the root README, open any of the three Person Accounts and choose **Log in to Experience as User**. No password is stored in the repository. `GenerateData.apex` links imported sample conversations to Doktor Proktor's existing Person Account and contact, and creates another sample conversation for him. The inbox no longer uses static child conversations: child selections fetch actual account-scoped threads through Apex.

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
