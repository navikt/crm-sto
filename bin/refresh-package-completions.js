#!/usr/bin/env node
'use strict';

// Populates the "Packages" package directory with the Apex classes of every
// dependency declared in sfdx-project.json, retrieved from the default org,
// so the Apex Language Server can suggest their symbols. Requires an authenticated
// default org ("sf config get target-org") that has these packages installed.
// Packages are retrieved sequentially.

const { execFile } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const path = require('path');

const execFileAsync = promisify(execFile);

const PROJECT_ROOT = path.resolve(__dirname, '..');
const SFDX_PROJECT_PATH = path.join(PROJECT_ROOT, 'sfdx-project.json');
const PACKAGES_DIR = path.join(PROJECT_ROOT, 'Packages');
const MAX_BUFFER = 20 * 1024 * 1024;

async function runSfJson(args) {
    const { stdout } = await execFileAsync('sf', [...args, '--json'], {
        cwd: PROJECT_ROOT,
        shell: true,
        maxBuffer: MAX_BUFFER
    });
    const parsed = JSON.parse(stdout);
    if (parsed.status !== 0) {
        throw new Error(parsed.message || `sf ${args.join(' ')} failed`);
    }
    return parsed.result;
}

async function runSf(args) {
    await execFileAsync('sf', args, {
        cwd: PROJECT_ROOT,
        shell: true,
        maxBuffer: MAX_BUFFER
    });
}

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

function getDependencies() {
    const project = JSON.parse(fs.readFileSync(SFDX_PROJECT_PATH, 'utf8'));
    const deps = new Map();
    for (const dir of project.packageDirectories || []) {
        for (const dep of dir.dependencies || []) {
            deps.set(dep.package, dep.versionNumber);
        }
    }
    return deps;
}

async function getDefaultOrg() {
    const result = await runSfJson(['config', 'get', 'target-org']);
    const entry = Array.isArray(result) ? result[0] : result;
    if (!entry || !entry.value) {
        throw new Error('No default org is set. Run "sf config set target-org=<alias>" (or "sf org login web") first.');
    }
    return entry.value;
}

async function replaceDir(src, dest, attempts = 5) {
    for (let attempt = 1; attempt <= attempts; attempt++) {
        try {
            fs.rmSync(dest, { recursive: true, force: true });
            fs.cpSync(src, dest, { recursive: true, force: true });
            fs.rmSync(src, { recursive: true, force: true });
            return;
        } catch (err) {
            // Can fail on Windows if something (e.g. OneDrive, antivirus) briefly locks
            // a just-created/removed directory. Retry the whole swap with a backoff.
            if (attempt === attempts) {
                throw err;
            }
            await sleep(300 * attempt);
        }
    }
}

async function retrievePackage(targetOrg, packageName) {
    // --package-name can't be combined with --output-dir, so it retrieves into a
    // root-level folder named after the package; move that into Packages/<name>.
    const tempDir = path.join(PROJECT_ROOT, packageName);
    fs.rmSync(tempDir, { recursive: true, force: true });

    await runSf(['project', 'retrieve', 'start', '--package-name', packageName, '--target-org', targetOrg]);

    if (!fs.existsSync(tempDir)) {
        throw new Error(`Expected retrieved metadata at "${packageName}", but it was not created.`);
    }

    const destDir = path.join(PACKAGES_DIR, packageName);
    console.log(`  Saving retrieved metadata to Packages/${packageName}...`);
    await replaceDir(tempDir, destDir);
}

async function processPackage(targetOrg, packageName, pinnedVersion) {
    const startedAt = Date.now();
    console.log(`  Pinned version: ${pinnedVersion}`);

    try {
        console.log(`  Retrieving metadata for "${packageName}"...`);
        await retrievePackage(targetOrg, packageName);
        console.log(`  Completed "${packageName}" in ${((Date.now() - startedAt) / 1000).toFixed(1)}s.`);
        return { packageName, ok: true };
    } catch (err) {
        console.error(`  Failed to retrieve "${packageName}": ${err.message}`);
        return { packageName, ok: false };
    }
}

async function main() {
    const startedAt = Date.now();
    const deps = getDependencies();
    if (deps.size === 0) {
        console.log('No dependencies found in sfdx-project.json.');
        return;
    }

    const targetOrg = await getDefaultOrg();
    console.log(`Using default org: ${targetOrg}`);

    fs.mkdirSync(PACKAGES_DIR, { recursive: true });

    console.log(`Refreshing ${deps.size} packages sequentially...`);
    const failures = [];
    let completed = 0;
    for (const [packageName, pinnedVersion] of deps) {
        console.log(`[${completed + 1}/${deps.size}] ${packageName}`);
        const result = await processPackage(targetOrg, packageName, pinnedVersion);
        completed++;
        console.log('');
        if (!result.ok) {
            failures.push(result.packageName);
        }
    }

    console.log(
        `Refreshed ${completed - failures.length}/${deps.size} packages in ${((Date.now() - startedAt) / 1000).toFixed(1)}s.`
    );
    if (failures.length) {
        console.log(`Done, with failures retrieving: ${failures.join(', ')}`);
        process.exitCode = 1;
    } else {
        console.log('Done.');
    }
}

main().catch((err) => {
    console.error(err.message);
    process.exitCode = 1;
});
