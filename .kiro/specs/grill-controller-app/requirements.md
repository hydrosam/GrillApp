# Requirements Document

## Introduction

The Grill Controller App is a cross-platform Flutter application that enables users to monitor and control wifi-connected charcoal grill fan systems. The app provides real-time temperature monitoring, automated fan control, cook programs, and social sharing capabilities. It supports Android, iOS, and Windows platforms, with responsive design for phones, tablets, and desktop computers.

## Glossary

- **App**: The Grill Controller Flutter application
- **Device**: A wifi-connected charcoal grill fan controller (e.g., iKamand)
- **Grill_Probe**: Temperature sensor measuring the grill's internal temperature
- **Food_Probe**: Temperature sensor measuring food temperature (up to 3 per device)
- **Fan_Controller**: Component that adjusts fan speed based on temperature readings
- **Cook_Program**: A multi-stage temperature control sequence with time and temperature targets
- **Grill_Open_Event**: A detected sharp temperature decline indicating the grill lid has been opened
- **Target_Temperature**: User-specified desired temperature for grill or food
- **Temperature_Delta**: The difference between current temperature and target temperature
- **Fan_Speed_Curve**: Algorithm that maps temperature delta to fan speed, varying by grill type and device type

## Requirements

### Requirement 1: Device Pairing and Network Configuration

**User Story:** As a user, I want to connect my grill device to my wifi network through the app, so that I can control it remotely.

#### Acceptance Criteria

1. WHEN a device is factory reset, THE Device SHALL enter Bluetooth pairing mode
2. WHEN the App detects a device in pairing mode, THE App SHALL establish a Bluetooth connection
3. WHEN Bluetooth connection is established, THE App SHALL transmit the current wifi network SSID and password to the Device
4. WHEN wifi credentials are received, THE Device SHALL attempt to connect to the specified wifi network
5. WHEN the Device successfully connects to wifi, THE App SHALL transition to wifi-based communication
6. THE App SHALL support pairing with iKamand devices as the initial target device

### Requirement 2: Temperature Monitoring

**User Story:** As a user, I want to monitor temperatures from multiple probes in real-time, so that I can track my cook progress.

#### Acceptance Criteria

1. THE App SHALL display temperature readings from one Grill_Probe and up to three Food_Probes simultaneously
2. WHEN temperature data is received from the Device, THE App SHALL update the display within 2 seconds
3. THE App SHALL maintain a historical record of all temperature readings with timestamps
4. THE App SHALL display a graph showing temperature history for all active probes over time
5. WHEN a probe is disconnected, THE App SHALL indicate the probe status as inactive
6. THE App SHALL refresh temperature readings at least once every 5 seconds

### Requirement 3: Temperature Control and Fan Management

**User Story:** As a user, I want to set target temperatures and have the fan automatically adjust, so that I can maintain consistent cooking temperatures.

#### Acceptance Criteria

1. WHEN a user sets a Target_Temperature for the grill, THE App SHALL store the target value
2. WHEN temperature readings are received, THE Fan_Controller SHALL calculate the Temperature_Delta
3. WHEN Temperature_Delta is calculated, THE Fan_Controller SHALL determine fan speed using the Fan_Speed_Curve
4. THE Fan_Speed_Curve SHALL vary based on the configured grill type
5. THE Fan_Speed_Curve SHALL vary based on the detected device type
6. WHEN fan speed is calculated, THE App SHALL transmit the fan speed command to the Device within 1 second
7. THE App SHALL allow users to manually override automatic fan control
8. THE App SHALL allow users to adjust the Fan_Speed_Curve for their device type and grill type combination

### Requirement 4: Cook Programs

**User Story:** As a user, I want to create multi-stage temperature programs, so that I can automate complex cooking processes.

#### Acceptance Criteria

1. THE App SHALL allow users to create Cook_Programs with multiple temperature stages
2. WHEN defining a stage, THE App SHALL accept a Target_Temperature and duration
3. WHEN a Cook_Program is started, THE App SHALL execute stages sequentially
4. WHEN a stage duration expires, THE App SHALL automatically transition to the next stage
5. WHEN a stage Target_Temperature is reached, THE App SHALL send an alert notification
6. THE App SHALL allow users to set cook timers with alert notifications
7. WHEN a timer expires, THE App SHALL send an alert notification to the user

### Requirement 5: Grill-Open Detection and Fan Control

**User Story:** As a user, I want the fan to automatically stop when I open the grill lid, so that I don't waste fuel or create temperature spikes.

#### Acceptance Criteria

1. WHEN the Grill_Probe temperature decreases by more than 5°F within 30 seconds, THE App SHALL detect a Grill_Open_Event
2. WHEN a Grill_Open_Event is detected, THE Fan_Controller SHALL immediately set fan speed to zero
3. WHILE the grill is detected as open, THE Fan_Controller SHALL not resume automatic fan control
4. WHEN the Grill_Probe temperature begins increasing after a Grill_Open_Event, THE App SHALL automatically resume fan control
5. THE App SHALL allow users to manually resume fan control after a Grill_Open_Event

### Requirement 6: Cook Notes and History

**User Story:** As a user, I want to save notes about my cooks, so that I can remember what worked well for future reference.

#### Acceptance Criteria

1. THE App SHALL allow users to create text notes associated with a cook session
2. WHEN a cook session ends, THE App SHALL persist the notes to local storage
3. THE App SHALL allow users to view notes from previous cook sessions
4. THE App SHALL associate notes with temperature history and cook parameters
5. THE App SHALL allow users to edit or delete saved notes

### Requirement 7: Social Sharing

**User Story:** As a user, I want to share my cook results with attractive graphics, so that I can showcase my grilling achievements on social media.

#### Acceptance Criteria

1. THE App SHALL generate graphics displaying temperature data in a visually appealing format, including at least one version of the graphics which is transparent so it can be overlayed on top of a photo or video
2. WHEN generating graphics, THE App SHALL include temperature curves for all active probes
3. THE App SHALL allow users to overlay temperature data on food photos
4. WHEN a graphic is generated, THE App SHALL include cook duration and target temperatures
5. THE App SHALL provide a share function that exports graphics to the device's native sharing interface
6. THE App SHALL support sharing to common social media platforms through the native share interface

### Requirement 8: Cross-Platform Support

**User Story:** As a user, I want to use the app on my phone, tablet, or desktop computer, so that I can monitor my grill from any device.

#### Acceptance Criteria

1. THE App SHALL run on Android devices with Android 8.0 or higher
2. THE App SHALL run on iOS devices with iOS 12.0 or higher
3. THE App SHALL run on Windows devices with Windows 10 or higher
4. WHEN running on different screen sizes, THE App SHALL adapt its layout responsively
5. THE App SHALL provide optimized layouts for phone, tablet, and desktop form factors
6. WHEN switching between devices, THE App SHALL maintain consistent functionality across platforms

### Requirement 9: Device Communication

**User Story:** As a developer, I want reliable communication protocols with grill devices, so that the app can control various device models.

#### Acceptance Criteria

1. THE App SHALL communicate with devices via Bluetooth during initial pairing
2. THE App SHALL communicate with devices via wifi for ongoing control and monitoring
3. THE App SHALL implement the iKamand HTTP protocol for iKamand devices
4. WHEN a device connection is lost, THE App SHALL attempt to reconnect automatically
5. WHEN reconnection fails after 3 attempts, THE App SHALL notify the user
6. THE App SHALL detect device type and capabilities during initial connection
7. THE App SHALL handle communication errors gracefully without crashing

### Requirement 10: Data Persistence

**User Story:** As a user, I want my cook history and settings to be saved locally, so that I can access them even without internet connectivity.

#### Acceptance Criteria

1. THE App SHALL store cook history in local device storage
2. THE App SHALL store user preferences and grill configurations in local device storage
3. WHEN the App starts, THE App SHALL load previously saved data from local storage
4. THE App SHALL persist temperature readings at least once per minute during active cooks
5. WHEN storage operations fail, THE App SHALL notify the user and continue operating with in-memory data
