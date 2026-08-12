#!/usr/bin/env node
// Script to run tests and generate coverage reports
const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");

try {
  // Run the tests
  console.log("Running tests on the solution...");
  execSync("dotnet test " + path.join("vv.Platform.sln"), {
    stdio: "inherit",
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
    const reportDir = path.join("coverage-report");

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
      "tests",
      "**",
      "TestResults",
      "**",
      "processed.coverage.cobertura.xml",
    );
    execSync(
      `reportgenerator "-reports:${processedGlob}" "-targetdir:${reportDir}" "-reporttypes:Html" "-sourcedirs:${process.cwd()}" "-verbosity:Warning"`,
      {
        stdio: "inherit",
        shell: true,
      },
    );

    // Open the report in browser (cross-platform)
    const indexPath = path.join(reportDir, "index.html");
    try {
      // Use the 'open' package for cross-platform browser opening
      require("open")(indexPath);
    } catch (err) {
      // Fallback: try platform-specific commands
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
  console.error("Tests failed");
}

// Helper function to process all coverage files and remove GitHub URLs
function processAllCoverageFiles() {
  // Find all coverage files
  const glob = require("glob");
  const coverageFiles = glob.sync("tests/**/coverage.cobertura.xml", {
    absolute: true,
  });

  console.log(`Found ${coverageFiles.length} coverage files to process`);

  // Process each file
  coverageFiles.forEach((filePath) => {
    if (!filePath || !fs.existsSync(filePath)) return;

    // Read the coverage file
    const content = fs.readFileSync(filePath, "utf8");

    // Replace any GitHub URLs with local paths
    const processed = content.replace(
      /https:\/\/raw\.githubusercontent\.com\/[^\"]+\/src\//g,
      "src/",
    );

    // Write to a new file
    const dir = path.dirname(filePath);
    const processedPath = path.join(dir, "processed.coverage.cobertura.xml");
    fs.writeFileSync(processedPath, processed);
    console.log(`Processed: ${filePath} → ${processedPath}`);
  });
}
