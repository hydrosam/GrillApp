# Implementation Plan: Grill Controller App

## Overview

This implementation plan breaks down the Grill Controller App into discrete, incremental coding tasks. The approach follows clean architecture principles with clear separation between layers. Each task builds on previous work, with testing integrated throughout to validate functionality early. The implementation prioritizes core functionality first (device connection, temperature monitoring, fan control), followed by advanced features (cook programs, social sharing).

## Tasks

- [x] 1. Set up Flutter project structure and dependencies
  - Create Flutter project with Android, iOS, and Windows support
  - Add required dependencies to pubspec.yaml (flutter_bloc, hive, sqflite, flutter_blue_plus, http, fl_chart, etc.)
  - Configure platform-specific permissions (Bluetooth, wifi, network)
  - Set up folder structure following clean architecture (presentation, domain, data layers)
  - _Requirements: 8.1, 8.2, 8.3_

- [ ] 2. Implement core domain entities and interfaces
  - [x] 2.1 Create domain entities
    - Implement TemperatureReading, GrillDevice, Probe, FanStatus, CookProgram, CookSession entities
    - Add Equatable for value equality
    - Implement serialization methods (toJson/fromJson)
    - _Requirements: 2.1, 3.1, 4.1, 6.1_
  
  - [x] 2.2 Write property test for entity serialization
    - **Property 1: Temperature Reading Persistence Round-Trip**
    - **Validates: Requirements 2.3, 10.1, 10.3**
  
  - [x] 2.3 Define repository interfaces
    - Create DeviceRepository, TemperatureRepository, CookSessionRepository, CookProgramRepository interfaces
    - Define method signatures for all CRUD and streaming operations
    - _Requirements: 1.2, 2.2, 6.2, 4.1_

- [ ] 3. Implement local storage layer
  - [x] 3.1 Set up Hive for lightweight data storage
    - Initialize Hive with type adapters for DeviceModel, CookSessionModel
    - Create Hive boxes for devices, cook_sessions, preferences
    - _Requirements: 10.1, 10.2_
  
  - [x] 3.2 Set up SQLite for temperature readings
    - Create database schema for temperature_readings table
    - Implement database helper with CRUD operations
    - Add indexes for efficient time-series queries
    - _Requirements: 2.3, 10.1_
  
  - [x] 3.3 Write property test for preferences persistence
    - **Property 3: User Preferences Persistence Round-Trip**
    - **Validates: Requirements 10.2, 10.3**
  
  - [x] 3.4 Write property test for cook session persistence
    - **Property 2: Cook Session Data Round-Trip**
    - **Validates: Requirements 6.2, 6.3, 6.4, 10.1, 10.3**
  
  - [x] 3.5 Write unit tests for storage error handling
    - Test storage failure scenarios
    - Verify graceful degradation to in-memory operation
    - _Requirements: 10.5_

- [ ] 4. Implement device communication layer
  - [x] 4.1 Create Bluetooth service
    - Implement device discovery using flutter_blue_plus
    - Implement Bluetooth connection and credential transmission
    - Handle Bluetooth errors and disconnections
    - _Requirements: 1.2, 1.3, 9.1_
  
  - [x] 4.2 Create wifi/HTTP service for iKamand protocol
    - Implement IKamandStatus and IKamandCommand models
    - Create HTTP client for iKamand API endpoints
    - Implement status polling and command sending
    - Parse JSON responses according to iKamand protocol
    - _Requirements: 1.5, 9.2, 9.3_
  
  - [x] 4.3 Write property test for iKamand protocol formatting
    - **Property 24: iKamand Protocol Message Formatting**
    - **Validates: Requirements 9.3**
  
  - [x] 4.4 Write property test for device connection lifecycle
    - **Property 25: Device Connection Lifecycle**
    - **Validates: Requirements 1.2, 1.3, 1.5**
  
  - [x] 4.5 Implement automatic reconnection logic
    - Add exponential backoff for reconnection attempts
    - Implement retry limit (3 attempts) with user notification
    - _Requirements: 9.4, 9.5_
  
  - [x] 4.6 Write property test for automatic reconnection
    - **Property 26: Automatic Reconnection on Connection Loss**
    - **Validates: Requirements 9.4, 9.5**
  
  - [x] 4.7 Write unit tests for communication error handling
    - Test timeout scenarios
    - Test malformed response handling
    - Verify no crashes on errors
    - _Requirements: 9.7_

- [x] 5. Checkpoint - Ensure device communication tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Implement repository implementations
  - [x] 6.1 Implement DeviceRepository
    - Create concrete implementation using Bluetooth and HTTP services
    - Implement device discovery, connection, and command sending
    - Add device type detection logic
    - _Requirements: 1.2, 1.3, 1.5, 9.6_
  
  - [x] 6.2 Implement TemperatureRepository
    - Create concrete implementation using SQLite
    - Implement temperature streaming from device
    - Add historical data queries with time range filtering
    - _Requirements: 2.2, 2.3, 2.6_
  
  - [x] 6.3 Implement CookSessionRepository
    - Create concrete implementation using Hive and SQLite
    - Implement session CRUD operations
    - Link sessions with temperature readings
    - _Requirements: 6.1, 6.2, 6.3, 6.4_
  
  - [x] 6.4 Implement CookProgramRepository
    - Create concrete implementation using Hive
    - Implement program CRUD operations
    - _Requirements: 4.1, 4.2_
  
  - [ ] 6.5 Write property test for device type detection
    - **Property 27: Device Type Detection**
    - **Validates: Requirements 9.6**

- [ ] 7. Implement fan control logic
  - [ ] 7.1 Create FanController with speed calculation algorithm
    - Implement temperature delta calculation
    - Create fan speed curve algorithm with grill type and device type parameters
    - Add manual override functionality
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.7_
  
  - [ ] 7.2 Write property test for temperature delta calculation
    - **Property 8: Temperature Delta Calculation**
    - **Validates: Requirements 3.2**
  
  - [ ] 7.3 Write property test for fan speed calculation
    - **Property 9: Fan Speed Calculation from Delta**
    - **Validates: Requirements 3.3**
  
  - [ ] 7.4 Write property test for grill type variation
    - **Property 10: Grill Type Fan Speed Variation**
    - **Validates: Requirements 3.4**
  
  - [ ] 7.5 Write property test for device type variation
    - **Property 11: Device Type Fan Speed Variation**
    - **Validates: Requirements 3.5**
  
  - [ ] 7.6 Write property test for fan control mode transitions
    - **Property 12: Fan Control Mode Transitions**
    - **Validates: Requirements 3.7, 5.3**
  
  - [ ] 7.7 Write unit tests for edge cases
    - Test delta = 0 (at target temperature)
    - Test extreme temperatures (32°F, 1000°F)
    - Test manual override behavior
    - _Requirements: 3.1, 3.7_

- [ ] 8. Implement grill-open detection logic
  - [ ] 8.1 Create GrillOpenDetector
    - Implement temperature drop detection (>5°F in 30 seconds)
    - Add automatic resume on temperature rise detection
    - Add manual resume functionality
    - _Requirements: 5.1, 5.4, 5.5_
  
  - [ ] 8.2 Write property test for grill-open detection
    - **Property 16: Grill-Open Event Detection**
    - **Validates: Requirements 5.1**
  
  - [ ] 8.3 Write property test for fan stop on grill-open
    - **Property 17: Fan Stop on Grill-Open**
    - **Validates: Requirements 5.2**
  
  - [ ] 8.4 Write property test for automatic resume
    - **Property 18: Automatic Fan Resume on Temperature Rise**
    - **Validates: Requirements 5.4**
  
  - [ ] 8.5 Write property test for manual resume
    - **Property 19: Manual Fan Resume**
    - **Validates: Requirements 5.5**
  
  - [ ] 8.6 Write unit tests for edge cases
    - Test false positive scenarios
    - Test rapid temperature fluctuations
    - _Requirements: 5.1_

- [ ] 9. Checkpoint - Ensure fan control and grill-open detection tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Implement BLoC components for state management
  - [ ] 10.1 Create DeviceConnectionBloc
    - Implement events: StartDiscovery, ConnectBluetooth, SendWifiCredentials, Disconnect
    - Implement states: Discovering, BluetoothConnected, WifiConnected, Disconnected, Error
    - Wire to DeviceRepository
    - _Requirements: 1.2, 1.3, 1.5_
  
  - [ ] 10.2 Create TemperatureMonitorBloc
    - Implement events: StartMonitoring, StopMonitoring, UpdateReading
    - Implement states: Monitoring, Idle, Error
    - Wire to TemperatureRepository
    - Add stream subscription for real-time updates
    - _Requirements: 2.2, 2.6_
  
  - [ ] 10.3 Create FanControlBloc
    - Implement events: SetTargetTemperature, SetManualSpeed, EnableAutomatic, DisableAutomatic
    - Implement states: Automatic, Manual, GrillOpen, Error
    - Wire to FanController and DeviceRepository
    - _Requirements: 3.1, 3.2, 3.3, 3.7_
  
  - [ ] 10.4 Create GrillOpenDetectionBloc
    - Implement events: TemperatureUpdate, ManualResume
    - Implement states: Closed, Open, Resuming
    - Wire to GrillOpenDetector
    - _Requirements: 5.1, 5.4, 5.5_
  
  - [ ] 10.5 Create CookProgramBloc
    - Implement events: StartProgram, PauseProgram, ResumeProgram, StopProgram, StageComplete
    - Implement states: Idle, Running, Paused, Completed
    - Wire to CookProgramRepository
    - Add timer logic for stage transitions
    - _Requirements: 4.3, 4.4_
  
  - [ ] 10.6 Write bloc tests for each BLoC component
    - Use bloc_test package for testing state transitions
    - Test all event-state combinations
    - _Requirements: All related to each BLoC_

- [ ] 11. Implement cook program execution logic
  - [ ] 11.1 Create CookProgramExecutor
    - Implement sequential stage execution
    - Add stage transition logic based on duration
    - Implement alert generation for stage completion and target reached
    - Add timer functionality with alerts
    - _Requirements: 4.3, 4.4, 4.5, 4.6, 4.7_
  
  - [ ] 11.2 Write property test for stage creation
    - **Property 13: Cook Program Stage Creation**
    - **Validates: Requirements 4.1, 4.2**
  
  - [ ] 11.3 Write property test for sequential execution
    - **Property 14: Cook Program Sequential Execution**
    - **Validates: Requirements 4.3**
  
  - [ ] 11.4 Write property test for alert generation
    - **Property 15: Alert Generation for Events**
    - **Validates: Requirements 4.5, 4.6, 4.7**
  
  - [ ] 11.5 Write unit tests for cook program edge cases
    - Test single-stage program
    - Test program with zero-duration stage
    - Test program pause and resume
    - _Requirements: 4.1, 4.3_

- [ ] 12. Implement UI presentation layer - Device connection screens
  - [ ] 12.1 Create device discovery screen
    - Build UI for Bluetooth device scanning
    - Display list of discovered devices
    - Add connect button for each device
    - Wire to DeviceConnectionBloc
    - _Requirements: 1.2_
  
  - [ ] 12.2 Create wifi credential input screen
    - Build form for SSID and password input
    - Add validation for credentials
    - Wire to DeviceConnectionBloc for credential transmission
    - _Requirements: 1.3_
  
  - [ ] 12.3 Create connection status screen
    - Display connection progress (Bluetooth → Wifi transition)
    - Show error messages for connection failures
    - Add retry functionality
    - _Requirements: 1.5, 9.4, 9.5_
  
  - [ ] 12.4 Write widget tests for connection screens
    - Test device list rendering
    - Test form validation
    - Test error state display
    - _Requirements: 1.2, 1.3, 1.5_

- [ ] 13. Implement UI presentation layer - Temperature monitoring screens
  - [ ] 13.1 Create main temperature dashboard
    - Display current temperature for all active probes
    - Show probe status (active/inactive)
    - Display target temperature
    - Add real-time update handling
    - Wire to TemperatureMonitorBloc
    - _Requirements: 2.1, 2.2, 2.5_
  
  - [ ] 13.2 Write property test for multi-probe display
    - **Property 4: Multi-Probe Display Completeness**
    - **Validates: Requirements 2.1**
  
  - [ ] 13.3 Write property test for probe status tracking
    - **Property 5: Probe Status Tracking**
    - **Validates: Requirements 2.5**
  
  - [ ] 13.4 Create temperature history graph screen
    - Implement graph using fl_chart
    - Display all active probe curves
    - Add time range selection
    - Implement data downsampling for performance
    - _Requirements: 2.4_
  
  - [ ] 13.5 Write property test for graph data
    - **Property 6: Temperature History Graph Data**
    - **Validates: Requirements 2.4**
  
  - [ ] 13.6 Write widget tests for temperature screens
    - Test probe display rendering
    - Test graph rendering with mock data
    - Test real-time update behavior
    - _Requirements: 2.1, 2.4_

- [ ] 14. Checkpoint - Ensure core UI tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 15. Implement UI presentation layer - Fan control screens
  - [ ] 15.1 Create fan control screen
    - Display current fan speed
    - Add target temperature input
    - Add manual/automatic mode toggle
    - Display grill-open status
    - Wire to FanControlBloc and GrillOpenDetectionBloc
    - _Requirements: 3.1, 3.7, 5.2, 5.5_
  
  - [ ] 15.2 Write property test for target temperature storage
    - **Property 7: Target Temperature Storage**
    - **Validates: Requirements 3.1**
  
  - [ ] 15.3 Write widget tests for fan control screen
    - Test mode toggle behavior
    - Test target temperature input validation
    - Test grill-open status display
    - _Requirements: 3.1, 3.7, 5.2_

- [ ] 16. Implement UI presentation layer - Cook program screens
  - [ ] 16.1 Create cook program list screen
    - Display saved cook programs
    - Add create/edit/delete buttons
    - Wire to CookProgramBloc
    - _Requirements: 4.1_
  
  - [ ] 16.2 Create cook program editor screen
    - Build form for program name and stages
    - Add stage editor with temperature and duration inputs
    - Implement stage reordering
    - Add validation for stage parameters
    - _Requirements: 4.1, 4.2_
  
  - [ ] 16.3 Create cook program execution screen
    - Display current stage and progress
    - Show time remaining for current stage
    - Add pause/resume/stop controls
    - Display alerts for stage completion
    - Wire to CookProgramBloc
    - _Requirements: 4.3, 4.4, 4.5_
  
  - [ ] 16.4 Create timer screen
    - Add timer creation interface
    - Display active timers with countdown
    - Implement alert notifications
    - _Requirements: 4.6, 4.7_
  
  - [ ] 16.5 Write widget tests for cook program screens
    - Test program list rendering
    - Test stage editor validation
    - Test execution screen state updates
    - _Requirements: 4.1, 4.2, 4.3_

- [ ] 17. Implement UI presentation layer - Cook notes and history
  - [ ] 17.1 Create cook session history screen
    - Display list of past cook sessions
    - Show session date, duration, and notes preview
    - Add detail view navigation
    - Wire to CookSessionRepository
    - _Requirements: 6.3_
  
  - [ ] 17.2 Create cook session detail screen
    - Display full session information
    - Show temperature graph for session
    - Display and edit notes
    - Add delete session functionality
    - _Requirements: 6.3, 6.4, 6.5_
  
  - [ ] 17.3 Create notes editor
    - Build text input for notes
    - Add save/cancel buttons
    - Wire to CookSessionRepository
    - _Requirements: 6.1, 6.5_
  
  - [ ] 17.4 Write property test for notes CRUD operations
    - **Property 20: Cook Notes CRUD Operations**
    - **Validates: Requirements 6.1, 6.5**
  
  - [ ] 17.5 Write widget tests for notes screens
    - Test notes editor functionality
    - Test session history list rendering
    - Test detail screen display
    - _Requirements: 6.1, 6.3, 6.5_

- [ ] 18. Implement social sharing functionality
  - [ ] 18.1 Create share graphic generator
    - Implement graphic generation with temperature curves
    - Add cook duration and target temperature overlays
    - Support photo overlay functionality
    - Use Canvas API for rendering
    - _Requirements: 7.2, 7.3, 7.4_
  
  - [ ] 18.2 Write property test for graphic data completeness
    - **Property 21: Share Graphic Data Completeness**
    - **Validates: Requirements 7.2, 7.4**
  
  - [ ] 18.3 Implement native share integration
    - Use share_plus package for native sharing
    - Export graphic as image file
    - Trigger native share sheet
    - _Requirements: 7.5_
  
  - [ ] 18.4 Write unit tests for share functionality
    - Test graphic generation with various data
    - Test photo overlay rendering
    - Test share invocation
    - _Requirements: 7.2, 7.3, 7.5_

- [ ] 19. Implement responsive layouts for multiple form factors
  - [ ] 19.1 Create responsive layout framework
    - Implement breakpoint detection (phone, tablet, desktop)
    - Create adaptive layout widgets
    - Use responsive_framework package
    - _Requirements: 8.4, 8.5_
  
  - [ ] 19.2 Adapt all screens for tablet layout
    - Use split-view layouts where appropriate
    - Optimize spacing and sizing for tablets
    - _Requirements: 8.5_
  
  - [ ] 19.3 Adapt all screens for desktop layout
    - Use multi-column layouts
    - Add desktop-specific navigation (sidebar)
    - Optimize for mouse and keyboard input
    - _Requirements: 8.5_
  
  - [ ] 19.4 Write property test for responsive layout adaptation
    - **Property 22: Responsive Layout Adaptation**
    - **Validates: Requirements 8.4, 8.5**
  
  - [ ] 19.5 Write widget tests for responsive layouts
    - Test layout changes at different breakpoints
    - Test all screens on phone, tablet, desktop sizes
    - _Requirements: 8.4, 8.5_

- [ ] 20. Checkpoint - Ensure all UI and feature tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 21. Implement platform-specific configurations
  - [ ] 21.1 Configure Android platform
    - Set minimum SDK to 26 (Android 8.0)
    - Add Bluetooth and wifi permissions to AndroidManifest.xml
    - Configure app icons and splash screen
    - _Requirements: 8.1_
  
  - [ ] 21.2 Configure iOS platform
    - Set minimum version to iOS 12.0
    - Add Bluetooth and network usage descriptions to Info.plist
    - Configure app icons and launch screen
    - _Requirements: 8.2_
  
  - [ ] 21.3 Configure Windows platform
    - Set minimum version to Windows 10 build 17763
    - Add network permissions to app manifest
    - Configure app icons
    - _Requirements: 8.3_
  
  - [ ] 21.4 Write property test for cross-platform consistency
    - **Property 23: Cross-Platform Functional Consistency**
    - **Validates: Requirements 8.6**

- [ ] 22. Implement error handling and user notifications
  - [ ] 22.1 Create error handling middleware
    - Implement global error handler
    - Add error logging
    - Create user-friendly error messages
    - _Requirements: 9.7, 10.5_
  
  - [ ] 22.2 Implement notification system
    - Add local notifications for alerts
    - Implement in-app notification display
    - Handle notification permissions
    - _Requirements: 4.5, 4.7_
  
  - [ ] 22.3 Write property test for communication error handling
    - **Property 28: Communication Error Handling**
    - **Validates: Requirements 9.7**
  
  - [ ] 22.4 Write property test for storage failure handling
    - **Property 29: Storage Failure Graceful Degradation**
    - **Validates: Requirements 10.5**
  
  - [ ] 22.5 Write unit tests for error scenarios
    - Test all error categories from design
    - Verify no crashes on errors
    - Test user notification display
    - _Requirements: 9.7, 10.5_

- [ ] 23. Implement app settings and preferences
  - [ ] 23.1 Create settings screen
    - Add grill type configuration
    - Add temperature unit preference (°F/°C)
    - Add data management options (clear cache, export data)
    - Add about/version information
    - _Requirements: 3.4, 10.2_
  
  - [ ] 23.2 Wire settings to repositories
    - Load preferences on app start
    - Save preferences on change
    - Apply preferences to fan control algorithm
    - _Requirements: 10.2, 10.3_
  
  - [ ] 23.3 Write widget tests for settings screen
    - Test preference changes
    - Test data management actions
    - _Requirements: 10.2_

- [ ] 24. Integration and final wiring
  - [ ] 24.1 Wire all BLoCs to UI
    - Set up BlocProvider hierarchy in main.dart
    - Ensure proper dependency injection
    - Add BlocListener for side effects (navigation, notifications)
    - _Requirements: All_
  
  - [ ] 24.2 Implement app initialization
    - Load saved data on app start
    - Initialize Hive and SQLite
    - Set up error handling
    - _Requirements: 10.3_
  
  - [ ] 24.3 Add app lifecycle management
    - Handle app pause/resume
    - Manage device connections on lifecycle changes
    - Save state on app termination
    - _Requirements: 10.1, 10.3_
  
  - [ ] 24.4 Write integration tests for critical flows
    - Test complete device pairing flow
    - Test complete cook session with program
    - Test temperature monitoring with real-time updates
    - _Requirements: 1.2, 1.3, 1.5, 2.2, 4.3_

- [ ] 25. Final checkpoint - Run all tests and verify functionality
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation throughout development
- Property tests validate universal correctness properties with 100+ iterations
- Unit tests validate specific examples, edge cases, and error conditions
- Integration tests validate end-to-end user flows
- The implementation follows clean architecture with clear layer separation
- BLoC pattern ensures testable, reactive state management
- Platform-specific code is isolated to enable cross-platform consistency
