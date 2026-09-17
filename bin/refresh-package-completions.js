#!/usr/bin/env node
'use strict';

// Populates the "Packages" package directory with the Apex classes of every
// dependency declared in sfdx-project.json, retrieved from the default org,
// so the Apex Language Server can suggest their symbols. Requires an authenticated
// default org ("sf config get target-org") that has these packages installed.
// If a default Dev Hub is also set, its newest released version per package is
// logged for comparison (informational only).

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const SFDX_PROJECT_PATH = path.join(PROJECT_ROOT, 'sfdx-project.json');
const PACKAGES_DIR = path.join(PROJECT_ROOT, 'Packages');

function runSfJson(args) {
    const output = execFileSync('sf', [...args, '--json'], {
        cwd: PROJECT_ROOT,
        encoding: 'utf8',
        shell: true
    });
    const parsed = JSON.parse(output);
    if (parsed.status !== 0) {
        throw new Error(parsed.message || `sf ${args.join(' ')} failed`);
    }
    return parsed.result;
}

function runSf(args) {
    execFileSync('sf', args, {
        cwd: PROJECT_ROOT,
        stdio: 'inherit',
        shell: true
    });
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

function getDefaultOrg() {
    const result = runSfJson(['config', 'get', 'target-org']);
    const entry = Array.isArray(result) ? result[0] : result;
    if (!entry || !entry.value) {
        throw new Error('No default org is set. Run "sf config set target-org=<alias>" (or "sf org login web") first.');
    }
    return entry.value;
}

function getDefaultDevHub() {
    try {
        const result = runSfJson(['config', 'get', 'target-dev-hub']);
        const entry = Array.isArray(result) ? result[0] : result;
        return entry && entry.value ? entry.value : null;
    } catch (err) {
        return null;
    }
}

function getLatestReleasedVersion(devHub, packageName) {
    let versions;
    try {
        versions = runSfJson([
            'package',
            'version',
            'list',
            '--packages',
            packageName,
            '--released',
            '--target-dev-hub',
            devHub
        ]);
    } catch (err) {
        return null;
    }
    if (!versions || versions.length === 0) {
        return null;
    }
    return versions.reduce((latest, current) => {
        const a = [current.MajorVersion, current.MinorVersion, current.PatchVersion, current.BuildNumber];
        const b = [latest.MajorVersion, latest.MinorVersion, latest.PatchVersion, latest.BuildNumber];
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) {
                return a[i] > b[i] ? current : latest;
            }
        }
        return latest;
    });
}

function sleepSync(ms) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function moveDir(src, dest, attempts = 5) {
    for (let attempt = 1; attempt <= attempts; attempt++) {
        try {
            fs.renameSync(src, dest);
            return;
        } catch (err) {
            if (err.code !== 'EPERM' && err.code !== 'EXDEV' && err.code !== 'EBUSY') {
                throw err;
            }
            // Rename can fail on Windows if something (e.g. OneDrive, antivirus) briefly
            // locks a just-created directory. Fall back to copy + remove, retrying a bit.
            try {
                fs.cpSync(src, dest, { recursive: true });
                fs.rmSync(src, { recursive: true, force: true });
                return;
            } catch (copyErr) {
                if (attempt === attempts) {
                    throw copyErr;
                }
                sleepSync(300 * attempt);
            }
        }
    }
}

function retrievePackage(targetOrg, packageName) {
    // --package-name can't be combined with --output-dir, so it retrieves into a
    // root-level folder named after the package; move that into Packages/<name>.
    const tempDir = path.join(PROJECT_ROOT, packageName);
    fs.rmSync(tempDir, { recursive: true, force: true });

    runSf(['project', 'retrieve', 'start', '--package-name', packageName, '--target-org', targetOrg]);

    if (!fs.existsSync(tempDir)) {
        throw new Error(`Expected retrieved metadata at "${packageName}", but it was not created.`);
    }

    const destDir = path.join(PACKAGES_DIR, packageName);
    fs.rmSync(destDir, { recursive: true, force: true });
    moveDir(tempDir, destDir);
}

function main() {
    const deps = getDependencies();
    if (deps.size === 0) {
        console.log('No dependencies found in sfdx-project.json.');
        return;
    }

    const targetOrg = getDefaultOrg();
    console.log(`Using default org: ${targetOrg}`);

    const devHub = getDefaultDevHub();
    if (devHub) {
        console.log(`Using default Dev Hub for version check: ${devHub}\n`);
    } else {
        console.log('No default Dev Hub set - skipping newest released version check.\n');
    }

    fs.mkdirSync(PACKAGES_DIR, { recursive: true });

    const failures = [];
    for (const [packageName, pinnedVersion] of deps) {
        if (devHub) {
            const latest = getLatestReleasedVersion(devHub, packageName);
            const latestLabel = latest
                ? `${latest.MajorVersion}.${latest.MinorVersion}.${latest.PatchVersion}.${latest.BuildNumber}`
                : 'no released version found on Dev Hub';
            console.log(`${packageName}: pinned ${pinnedVersion} -> latest released ${latestLabel}`);
        } else {
            console.log(`${packageName}: pinned ${pinnedVersion}`);
        }

        try {
            retrievePackage(targetOrg, packageName);
        } catch (err) {
            console.warn(`  Failed to retrieve "${packageName}": ${err.message}`);
            failures.push(packageName);
        }
        console.log('');
    }

    if (failures.length) {
        console.log(`Done, with failures retrieving: ${failures.join(', ')}`);
        process.exitCode = 1;
    } else {
        console.log('Done.');
    }
}

main();
