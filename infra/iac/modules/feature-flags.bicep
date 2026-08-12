// Feature Flags Module
// This module provides a mechanism to control which resources are deployed based on feature flags

@description('Feature flags to control which resources are deployed')
param featureFlags object = {
  enableAdvancedAnalytics: false
  enableMultiRegion: false
  enableEnhancedSecurity: false
  enableBlockchainIndexers: true
  enableContainerApps: false
  enableAzureSentinel: false
  enableConfidentialComputing: false
}

@description('Environment name (dev, test, prod)')
param environmentName string

// This module doesn't deploy any resources directly
// It's used to control which resources are deployed in other modules

// Output the feature flags for use in other modules
output flags object = featureFlags

// Helper outputs for conditional deployment
output deployAdvancedAnalytics bool = featureFlags.enableAdvancedAnalytics
output deployMultiRegion bool = featureFlags.enableMultiRegion
output deployEnhancedSecurity bool = featureFlags.enableEnhancedSecurity
output deployBlockchainIndexers bool = featureFlags.enableBlockchainIndexers
output deployContainerApps bool = featureFlags.enableContainerApps
output deployAzureSentinel bool = featureFlags.enableAzureSentinel
output deployConfidentialComputing bool = featureFlags.enableConfidentialComputing

// Production-specific overrides - certain features must be enabled in production
output effectiveFlags object = environmentName == 'prod'
  ? union(featureFlags, {
      enableEnhancedSecurity: true // Always enable enhanced security in production
    })
  : featureFlags
