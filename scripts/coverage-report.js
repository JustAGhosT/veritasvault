#!/usr/bin/env node
// Script to run tests and generate coverage reports
const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");

// Anchor every path to the repo root, not process.cwd(): this runs from a
// post-commit hook, which may fire from a subdirectory or a git worktree.
// This file lives in <repoRoot>/scripts/, so one level up is always the root.
const repoRoot = path.resolve(__dirname, "..");
const solutionPath = path.join(repoRoot, "vv.Platform.sln");

try {
  if (!fs.existsSync(solutionPath)) {
    throw new Error(`Solution file not found: ${solutionPath}`);
  }

  // Run from repoRoot with a bare filename so a repo path containing spaces
  // never has to survive shell quoting.
  console.log("Running tests on the solution...");
  execSync("dotnet test vv.Platform.sln", {
    stdio: "inherit",
    cwd: repoRoot,
  });
  console.log("Tests completed successfully");

  // Generate the HTML coverage report
  console.log("Generating HTML coverage report...");

  try {
    // Check if reportgenerator is installed
    try {
      execSync("reportgenerator -version", { stdio: "pipe" });
      console.log("ReportGenerator is already installed");
    } catch (error) {
      console.log("Installing ReportGenerator tool...");
      execSync("dotnet tool install -g dotnet-reportgenerator-globaltool", {
        stdio: "inherit",
        shell: true,
      });
    }

    // Generate the report using coverage files from ALL test projects
    const reportDir = path.join(repoRoot, "coverage-report");

    // Clear existing coverage reports
    if (fs.existsSync(reportDir)) {
      console.log("Clearing existing coverage reports...");
      fs.rmSync(reportDir, { recursive: true, force: true });
    }

    // Create fresh directory
    console.log("Creating new coverage report directory...");
    fs.mkdirSync(reportDir, { recursive: true });

    // Process the coverage files to remove GitHub URLs
    console.log("Pre-processing coverage files to remove GitHub URLs...");
    processAllCoverageFiles();

    // Run ReportGenerator on the processed files
    const processedGlob = path.join(
      repoRoot,
      "tests",
      "**",
      "TestResults",
      "**",
      "processed.coverage.cobertura.xml",
    );
    execSync(
      `reportgenerator "-reports:${processedGlob}" "-targetdir:${reportDir}" "-reporttypes:Html" "-sourcedirs:${repoRoot}" "-verbosity:Warning"`,
      {
        stdio: "inherit",
        shell: true,
        cwd: repoRoot,
      },
    );

    // Open the report in browser (cross-platform)
    const indexPath = path.join(reportDir, "index.html");
    try {
      // Use the 'open' package for cross-platform browser opening
      require('open')(indexPath);
    } catch (err) {
      // Fallback: try platform-specific commands
      const { exec } = require('child_process');
      const platform = process.platform;
      if (platform === 'win32') {
        exec(`start "" "${indexPath}"`);
      } else if (platform === 'darwin') {
        exec(`open "${indexPath}"`);
      } else {
        exec(`xdg-open "${indexPath}"`);
      }
    }
  } catch (reportError) {
    console.error("Error generating coverage reports:", reportError.message);
  }
} catch (error) {
  // Report the real cause: this used to print a bare "Tests failed" even when
  // the tests never ran (e.g. a missing solution file).
  console.error("Tests failed:", error.message);
}

// Recursively collect files whose basename matches, anchored at `dir`.
// Replaces a `glob` require that was never declared in package.json and so
// threw "Cannot find module 'glob'" on every run.
function findFiles(dir, basename, found = []) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return found; // directory absent (no tests have run yet)
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      findFiles(full, basename, found);
    } else if (entry.name === basename) {
      found.push(full);
    }
  }
  return found;
}

// Helper function to process all coverage files and remove GitHub URLs
function processAllCoverageFiles() {
  // Exact-basename match, so the processed.* files written below are not
  // picked up and reprocessed on the next run.
  const coverageFiles = findFiles(
    path.join(repoRoot, "tests"),
    "coverage.cobertura.xml",
  );

  console.log(`Found ${coverageFiles.length} coverage files to process`);

  // Process each file
  coverageFiles.forEach((filePath) => {
    if (!filePath || !fs.existsSync(filePath)) return;

    // Read the coverage file
    const content = fs.readFileSync(filePath, "utf8");

    // Replace any GitHub URLs with local paths
    const processed = content.replace(
      /https:\/\/raw\.githubusercontent\.com\/[^\"]+\/src\//g,
      'src/'
    );

    // Write to a new file
    const dir = path.dirname(filePath);
    const processedPath = path.join(dir, "processed.coverage.cobertura.xml");
    fs.writeFileSync(processedPath, processed);
    console.log(`Processed: ${filePath} → ${processedPath}`);
  });
}
