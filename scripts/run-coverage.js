#!/usr/bin/env node
/**
 * Node.js script to run tests and generate coverage reports
 * Replaces PowerShell scripts that used ExecutionPolicy Bypass
 */

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// ANSI colors for terminal output
const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m",
  red: "\x1b[31m",
};

console.log(
  `${colors.cyan}Running tests and generating coverage reports...${colors.reset}`,
);

try {
  // Run the tests
  console.log(
    `${colors.yellow}Running tests on the solution...${colors.reset}`,
  );
  execSync("dotnet test vv.Platform.sln", { stdio: "inherit" });
  console.log(`${colors.green}✅ Tests completed successfully${colors.reset}`);

  // Generate coverage report
  console.log(
    `${colors.yellow}Generating HTML coverage report...${colors.reset}`,
  );

  try {
    // Check if reportgenerator is installed
    try {
      execSync("reportgenerator -version", { stdio: "pipe" });
      console.log(
        `${colors.green}✅ ReportGenerator is already installed${colors.reset}`,
      );
    } catch (error) {
      console.log(
        `${colors.yellow}Installing ReportGenerator tool...${colors.reset}`,
      );
      execSync("dotnet tool install -g dotnet-reportgenerator-globaltool", {
        stdio: "inherit",
        shell: true,
      });
    }

    // Set up the report directory
    const reportDir = path.join("coverage-report");

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
    processAllCoverageFiles();

    // Run ReportGenerator on the processed files
    execSync(
      `reportgenerator "-reports:tests/**/TestResults/**/processed.coverage.cobertura.xml" "-targetdir:${reportDir}" "-reporttypes:Html" "-sourcedirs:${process.cwd()}" "-verbosity:Warning"`,
      {
        stdio: "inherit",
        shell: true,
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

// Helper function to process all coverage files and remove GitHub URLs
function processAllCoverageFiles() {
  // Find all coverage files (in a cross-platform way)
  let coverageFiles = [];

  if (process.platform === "win32") {
    // Windows
    const findCommand = `dir /s /b tests\\*coverage.cobertura.xml`;
    coverageFiles = execSync(findCommand, { encoding: "utf8", shell: true })
      .split("\r\n")
      .filter((file) => file.trim() !== "");
  } else {
    // Unix-based systems (Linux, macOS)
    const findCommand = `find tests -name "*coverage.cobertura.xml"`;
    coverageFiles = execSync(findCommand, { encoding: "utf8", shell: true })
      .split("\n")
      .filter((file) => file.trim() !== "");
  }

  console.log(
    `${colors.blue}Found ${coverageFiles.length} coverage files to process${colors.reset}`,
  );

  // Process each file
  coverageFiles.forEach((filePath) => {
    if (!filePath || !fs.existsSync(filePath)) return;

    // Read the coverage file
    const content = fs.readFileSync(filePath, "utf8");

    // Replace any GitHub URLs with local paths
    const processed = content.replace(
      /https:\/\/raw\.githubusercontent\.com\/[^"]+\/src\//g,
      "src/",
    );

    // Write to a new file
    const dir = path.dirname(filePath);
    const processedPath = path.join(dir, "processed.coverage.cobertura.xml");
    fs.writeFileSync(processedPath, processed);

    console.log(
      `${colors.blue}Processed: ${filePath} → ${processedPath}${colors.reset}`,
    );
  });
}
