// Shared coverage-file helpers for scripts/coverage-report.js and
// scripts/run-coverage.js.
//
// These two scripts used to carry their own copies of this logic, which is how
// the same "vvPlatform.sln" typo survived in three files at once. Keep the
// discovery rules here so they cannot drift again.
const fs = require("fs");
const path = require("path");

// Recursively collect files whose basename matches exactly, anchored at `dir`.
// Exact match matters: a "*coverage.cobertura.xml" glob also matches the
// processed.coverage.cobertura.xml files written back alongside the originals,
// so a prefix glob reprocesses its own output on every run.
function findFilesNamed(dir, basename, found = []) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return found; // directory absent (no tests have run yet)
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      findFilesNamed(full, basename, found);
    } else if (entry.name === basename) {
      found.push(full);
    }
  }
  return found;
}

// Absolute paths to the raw cobertura files produced by the most recent run.
function findCoverageFiles(testsDir) {
  return findFilesNamed(testsDir, "coverage.cobertura.xml");
}

// `dotnet test` writes each run into a fresh TestResults/<guid>/ directory and
// never prunes. Without clearing, the report merges every historical run and
// coverage drifts toward stale data.
function clearPreviousTestResults(testsDir) {
  let projects;
  try {
    projects = fs.readdirSync(testsDir, { withFileTypes: true });
  } catch {
    return; // no tests directory
  }
  for (const project of projects) {
    if (!project.isDirectory()) continue;
    const resultsDir = path.join(testsDir, project.name, "TestResults");
    if (fs.existsSync(resultsDir)) {
      fs.rmSync(resultsDir, { recursive: true, force: true });
    }
  }
}

// Rewrite raw coverage files to strip GitHub raw URLs, so ReportGenerator
// resolves sources locally. Writes processed.coverage.cobertura.xml next to
// each original and returns how many were handled.
function processCoverageFiles(testsDir, log = console.log) {
  const coverageFiles = findCoverageFiles(testsDir);
  log(`Found ${coverageFiles.length} coverage files to process`);

  for (const filePath of coverageFiles) {
    const content = fs.readFileSync(filePath, "utf8");
    const processed = content.replace(
      /https:\/\/raw\.githubusercontent\.com\/[^"]+\/src\//g,
      "src/",
    );
    const processedPath = path.join(
      path.dirname(filePath),
      "processed.coverage.cobertura.xml",
    );
    fs.writeFileSync(processedPath, processed);
    log(`Processed: ${filePath} → ${processedPath}`);
  }

  return coverageFiles.length;
}

module.exports = {
  findCoverageFiles,
  clearPreviousTestResults,
  processCoverageFiles,
};
