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

async function retryFileOperation(label, operation, attempts = 5) {
    for (let attempt = 1; attempt <= attempts; attempt++) {
        try {
            operation();
            return;
        } catch (err) {
            if (attempt === attempts || !['EPERM', 'EACCES', 'EBUSY', 'ENOTEMPTY'].includes(err.code)) {
                throw new Error(
                    `${label} failed after ${attempt} attempt(s): ${err.code ? `${err.code}: ` : ''}${err.message}`,
                    { cause: err }
                );
            }
            await sleep(300 * attempt);
        }
    }
}

async function replaceDir(src, dest) {
    await retryFileOperation(`Removing destination directory: ${dest}`, () =>
        fs.rmSync(dest, { recursive: true, force: true })
    );
    await retryFileOperation(`Copying metadata: ${src} -> ${dest}`, () =>
        fs.cpSync(src, dest, { recursive: true, force: true })
    );
    try {
        await retryFileOperation(`Removing temporary directory: ${src}`, () =>
            fs.rmSync(src, { recursive: true, force: true })
        );
        return true;
    } catch (err) {
        console.error(`  Metadata saved, but cleanup failed: ${err.message}`);
        return false;
    }
}

async function retrievePackage(targetOrg, packageName) {
    // --package-name can't be combined with --output-dir, so it retrieves into a
    // root-level folder named after the package; move that into Packages/<name>.
    const tempDir = path.join(PROJECT_ROOT, packageName);
    await retryFileOperation(`Removing existing temporary directory: ${tempDir}`, () =>
        fs.rmSync(tempDir, { recursive: true, force: true })
    );

    await runSf(['project', 'retrieve', 'start', '--package-name', packageName, '--target-org', targetOrg]);

    if (!fs.existsSync(tempDir)) {
        throw new Error(`Expected retrieved metadata at "${packageName}", but it was not created.`);
    }

    const destDir = path.join(PACKAGES_DIR, packageName);
    return replaceDir(tempDir, destDir);
}

async function processPackage(targetOrg, packageName) {
    const startedAt = Date.now();

    try {
        const cleanupOk = await retrievePackage(targetOrg, packageName);
        const status = cleanupOk ? 'Completed' : 'Metadata saved, cleanup failed for';
        console.log(`  ${status} "${packageName}" in ${((Date.now() - startedAt) / 1000).toFixed(1)}s.`);
        return { packageName, ok: true, cleanupOk };
    } catch (err) {
        console.error(`  Failed to refresh "${packageName}": ${err.message}`);
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
    const cleanupFailures = [];
    let completed = 0;
    for (const [packageName, pinnedVersion] of deps) {
        console.log(`[${completed + 1}/${deps.size}] ${packageName} (pinned ${pinnedVersion})`);
        const result = await processPackage(targetOrg, packageName);
        completed++;
        if (!result.ok) {
            failures.push(result.packageName);
        } else if (!result.cleanupOk) {
            cleanupFailures.push(result.packageName);
        }
    }

    console.log(
        `Refreshed ${completed - failures.length}/${deps.size} packages in ${((Date.now() - startedAt) / 1000).toFixed(1)}s.`
    );
    if (failures.length) {
        console.error(`Failed to refresh: ${failures.join(', ')}`);
    }
    if (cleanupFailures.length) {
        console.error(`Metadata saved, but temporary directory cleanup failed for: ${cleanupFailures.join(', ')}`);
    }
    if (failures.length || cleanupFailures.length) {
        process.exitCode = 1;
    }
}

main().catch((err) => {
    console.error(`Package refresh failed: ${err.message}`);
    process.exitCode = 1;
});
