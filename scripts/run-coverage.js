#!/usr/bin/env node
/**
 * Node.js script to run tests and generate coverage reports
 * Replaces PowerShell scripts that used ExecutionPolicy Bypass
 */

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const {
  clearPreviousTestResults,
  processCoverageFiles,
} = require("./lib/coverage-files");

// ANSI colors for terminal output
const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m",
  red: "\x1b[31m",
};

// Anchor every path to the repo root rather than process.cwd(), so this works
// from a subdirectory or a git worktree. This file lives in <repoRoot>/scripts/.
const repoRoot = path.resolve(__dirname, "..");
const testsDir = path.join(repoRoot, "tests");

console.log(
  `${colors.cyan}Running tests and generating coverage reports...${colors.reset}`,
);

try {
  // Run the tests
  console.log(
    `${colors.yellow}Running tests on the solution...${colors.reset}`,
  );
  const solutionPath = path.join(repoRoot, "vv.Platform.sln");
  if (!fs.existsSync(solutionPath)) {
    throw new Error(`Solution file not found: ${solutionPath}`);
  }
  clearPreviousTestResults(testsDir);
  // Bare filename + cwd, so a repo path containing spaces never has to survive
  // shell quoting.
  execSync("dotnet test vv.Platform.sln", { stdio: "inherit", cwd: repoRoot });
  console.log(`${colors.green}✅ Tests completed successfully${colors.reset}`);

  // Generate coverage report
  console.log(
    `${colors.yellow}Generating HTML coverage report...${colors.reset}`,
  );

  try {
    // Check if reportgenerator is installed. Probing with `reportgenerator
    // -version` does not work: it exits 1 with "No report files specified",
    // so the check always failed and every run took the install branch.
    const installedTools = execSync("dotnet tool list -g", {
      encoding: "utf8",
    });
    if (installedTools.includes("dotnet-reportgenerator-globaltool")) {
      console.log(
        `${colors.green}✅ ReportGenerator is already installed${colors.reset}`,
      );
    } else {
      console.log(
        `${colors.yellow}Installing ReportGenerator tool...${colors.reset}`,
      );
      execSync("dotnet tool install -g dotnet-reportgenerator-globaltool", {
        stdio: "inherit",
        shell: true,
      });
    }

    // Set up the report directory
    const reportDir = path.join(repoRoot, "coverage-report");

    // Clear existing coverage reports
    if (fs.existsSync(reportDir)) {
      console.log(
        `${colors.yellow}Clearing existing coverage reports...${colors.reset}`,
      );
      fs.rmSync(reportDir, { recursive: true, force: true });
    }

    // Create fresh directory
    console.log(
      `${colors.yellow}Creating new coverage report directory...${colors.reset}`,
    );
    fs.mkdirSync(reportDir, { recursive: true });

    // Process the coverage files to remove GitHub URLs
    console.log(
      `${colors.yellow}Pre-processing coverage files to remove GitHub URLs...${colors.reset}`,
    );
    processCoverageFiles(testsDir, (msg) =>
      console.log(`${colors.blue}${msg}${colors.reset}`),
    );

    // Run ReportGenerator on the processed files
    execSync(
      `reportgenerator "-reports:tests/**/TestResults/**/processed.coverage.cobertura.xml" "-targetdir:${reportDir}" "-reporttypes:Html" "-sourcedirs:${repoRoot}" "-verbosity:Warning"`,
      {
        stdio: "inherit",
        shell: true,
        cwd: repoRoot,
      },
    );

    // Open the report in browser based on platform
    console.log(
      `${colors.green}✅ Coverage report generated at: ${reportDir}${colors.reset}`,
    );
    console.log(`${colors.yellow}Opening report in browser...${colors.reset}`);

    // Use cross-platform command to open the browser
    const openCommand =
      process.platform === "win32"
        ? `start "" "${reportDir}\\index.html"`
        : process.platform === "darwin"
          ? `open "${reportDir}/index.html"`
          : `xdg-open "${reportDir}/index.html"`;

    execSync(openCommand, { stdio: "inherit", shell: true });
  } catch (reportError) {
    console.error(
      `${colors.red}❌ Error generating coverage reports: ${reportError.message}${colors.reset}`,
    );
    process.exit(1);
  }
} catch (error) {
  console.error(
    `${colors.red}❌ Tests failed: ${error.message}${colors.reset}`,
  );
  process.exit(1);
}
