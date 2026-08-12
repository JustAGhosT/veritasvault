#!/usr/bin/env node
// Script to run tests and generate coverage reports
const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");
const {
  clearPreviousTestResults,
  processCoverageFiles,
} = require("./lib/coverage-files");

// Anchor every path to the repo root, not process.cwd(): this runs from a
// post-commit hook, which may fire from a subdirectory or a git worktree.
// This file lives in <repoRoot>/scripts/, so one level up is always the root.
const repoRoot = path.resolve(__dirname, "..");
const solutionPath = path.join(repoRoot, "vv.Platform.sln");
const testsDir = path.join(repoRoot, "tests");

try {
  if (!fs.existsSync(solutionPath)) {
    throw new Error(`Solution file not found: ${solutionPath}`);
  }

  // `dotnet test` writes each run into a fresh TestResults/<guid>/ directory
  // and never prunes. Without this, the report merges every historical run
  // and coverage drifts toward stale data.
  clearPreviousTestResults(testsDir);

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
    // Check if reportgenerator is installed. Probing with `reportgenerator
    // -version` does not work: it exits 1 with "No report files specified",
    // so the check always failed and every run took the install branch.
    const installedTools = execSync("dotnet tool list -g", {
      encoding: "utf8",
    });
    if (installedTools.includes("dotnet-reportgenerator-globaltool")) {
      console.log("ReportGenerator is already installed");
    } else {
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
    processCoverageFiles(testsDir);

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

    const indexPath = path.join(reportDir, "index.html");
    console.log(`Coverage report: ${indexPath}`);

    // This runs from post-commit, so opening a browser is off by default:
    // a tab per commit is the same "trains people to ignore it" problem as
    // the old red error line. Set COVERAGE_OPEN=1 to get the browser back.
    if (process.env.COVERAGE_OPEN === "1") {
      const { exec } = require("child_process");
      const platform = process.platform;
      if (platform === "win32") {
        exec(`start "" "${indexPath}"`);
      } else if (platform === "darwin") {
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
