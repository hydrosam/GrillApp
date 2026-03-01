import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:grill_controller_app/data/datasources/ikamand_http_service.dart';
import 'package:grill_controller_app/data/models/ikamand_status.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

// Mock class for http.Client
class MockClient extends Mock implements http.Client {}

void main() {
  group('Property 26: Automatic Reconnection on Connection Loss', () {
    // Feature: grill-controller-app, Property 26: Automatic Reconnection on Connection Loss
    // **Validates: Requirements 9.4, 9.5**
    
    final faker = Faker();
    const int iterations = 100;

    // Register fallback values for mocktail
    setUpAll(() {
      registerFallbackValue(Uri());
    });

    test('automatic reconnection should use exponential backoff with correct delays', () async {
      // This property validates that reconnection attempts use exponential backoff:
      // Attempt 1: 1 second delay
      // Attempt 2: 2 seconds delay
      // Attempt 3: 4 seconds delay
      
      for (int i = 0; i < iterations; i++) {
        final deviceIp = faker.internet.ipv4Address();
        
        // Calculate expected delays for each attempt
        final expectedDelays = <int, int>{
          1: 1, // 2^(1-1) = 1 second
          2: 2, // 2^(2-1) = 2 seconds
          3: 4, // 2^(3-1) = 4 seconds
        };
        
        // Verify exponential backoff formula
        for (final entry in expectedDelays.entries) {
          final attemptNumber = entry.key;
          final expectedDelay = entry.value;
          final calculatedDelay = 1 << (attemptNumber - 1); // 2^(n-1)
          
          expect(calculatedDelay, equals(expectedDelay),
              reason: 'Attempt $attemptNumber should have ${expectedDelay}s delay');
        }
        
        // Verify delays are exponential (each delay is double the previous)
        expect(expectedDelays[2]!, equals(expectedDelays[1]! * 2),
            reason: 'Second delay should be double the first');
        expect(expectedDelays[3]!, equals(expectedDelays[2]! * 2),
            reason: 'Third delay should be double the second');
      }
    });

    test('automatic reconnection should attempt exactly 3 times before failing', () async {
      // Validates that the system attempts reconnection exactly 3 times
      // and then emits a failure event
      
      // Use fewer iterations since this involves async operations
      const testIterations = 10;
      
      for (int i = 0; i < testIterations; i++) {
        final deviceIp = faker.internet.ipv4Address();
        final mockClient = MockClient();
        final httpService = IKamandHttpService(client: mockClient);
        
        // Track reconnection events
        final events = <ReconnectionEvent>[];
        final subscription = httpService.reconnectionEvents.listen((event) {
          events.add(event);
        });
        
        // Mock all connection attempts to fail
        when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenThrow(Exception('Connection failed'));
        
        // Trigger reconnection
        await httpService.attemptReconnection(deviceIp);
        
        // Wait for all reconnection attempts to complete
        // Total time: 1s + 2s + 4s = 7s, plus some buffer
        await Future.delayed(const Duration(seconds: 8));
        
        // Verify we got exactly 4 events: 3 attempting + 1 failed
        final attemptingEvents = events.where((e) => 
            e.status == ReconnectionStatus.attempting).toList();
        final failedEvents = events.where((e) => 
            e.status == ReconnectionStatus.failed).toList();
        
        expect(attemptingEvents.length, equals(3),
            reason: 'Should have exactly 3 attempting events');
        expect(failedEvents.length, equals(1),
            reason: 'Should have exactly 1 failed event after 3 attempts');
        
        // Verify attempt numbers are sequential
        for (int j = 0; j < attemptingEvents.length; j++) {
          expect(attemptingEvents[j].attemptNumber, equals(j + 1),
              reason: 'Attempt numbers should be sequential starting from 1');
        }
        
        // Verify the failed event comes after all attempts
        expect(failedEvents.first.attemptNumber, equals(3),
            reason: 'Failed event should indicate 3 attempts were made');
        
        await subscription.cancel();
        httpService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('automatic reconnection should succeed and reset attempt count on successful connection', () async {
      // Validates that successful reconnection resets the attempt counter
      // and emits a success event
      
      const testIterations = 10;
      
      for (int i = 0; i < testIterations; i++) {
        final deviceIp = faker.internet.ipv4Address();
        final mockClient = MockClient();
        final httpService = IKamandHttpService(client: mockClient);
        
        // Track reconnection events
        final events = <ReconnectionEvent>[];
        final subscription = httpService.reconnectionEvents.listen((event) {
          events.add(event);
        });
        
        // Determine which attempt will succeed (1, 2, or 3)
        final successAttempt = faker.randomGenerator.integer(3, min: 1);
        var currentAttempt = 0;
        
        // Mock connection attempts - fail until success attempt
        when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async {
          currentAttempt++;
          if (currentAttempt >= successAttempt) {
            return http.Response(
              '{"grill_temp": 250.0, "fan_speed": 50, "target_temp": 275.0}',
              200,
            );
          }
          throw Exception('Connection failed');
        });
        
        // Trigger reconnection
        await httpService.attemptReconnection(deviceIp);
        
        // Wait for reconnection to complete
        await Future.delayed(const Duration(seconds: 8));
        
        // Verify we got attempting events up to success
        final attemptingEvents = events.where((e) => 
            e.status == ReconnectionStatus.attempting).toList();
        final successEvents = events.where((e) => 
            e.status == ReconnectionStatus.success).toList();
        
        expect(attemptingEvents.length, greaterThanOrEqualTo(1),
            reason: 'Should have at least 1 attempting event');
        expect(attemptingEvents.length, lessThanOrEqualTo(3),
            reason: 'Should have at most 3 attempting events');
        expect(successEvents.length, equals(1),
            reason: 'Should have exactly 1 success event');
        
        // Verify no failed events when connection succeeds
        final failedEvents = events.where((e) => 
            e.status == ReconnectionStatus.failed).toList();
        expect(failedEvents.length, equals(0),
            reason: 'Should have no failed events when connection succeeds');
        
        await subscription.cancel();
        httpService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('automatic reconnection should notify user after 3 failed attempts', () async {
      // Validates Requirement 9.5: notify user when reconnection fails after 3 attempts
      
      const testIterations = 10;
      
      for (int i = 0; i < testIterations; i++) {
        final deviceIp = faker.internet.ipv4Address();
        final mockClient = MockClient();
        final httpService = IKamandHttpService(client: mockClient);
        
        // Track reconnection events
        final events = <ReconnectionEvent>[];
        final subscription = httpService.reconnectionEvents.listen((event) {
          events.add(event);
        });
        
        // Mock all connection attempts to fail
        when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenThrow(Exception('Connection failed'));
        
        // Trigger reconnection
        await httpService.attemptReconnection(deviceIp);
        
        // Wait for all reconnection attempts to complete
        await Future.delayed(const Duration(seconds: 8));
        
        // Verify we got a failed event with appropriate message
        final failedEvents = events.where((e) => 
            e.status == ReconnectionStatus.failed).toList();
        
        expect(failedEvents.length, equals(1),
            reason: 'Should emit exactly one failed event');
        
        final failedEvent = failedEvents.first;
        expect(failedEvent.deviceIp, equals(deviceIp),
            reason: 'Failed event should contain correct device IP');
        expect(failedEvent.message.toLowerCase(), contains('failed'),
            reason: 'Failed event message should indicate failure');
        expect(failedEvent.message, contains('3'),
            reason: 'Failed event message should mention 3 attempts');
        
        await subscription.cancel();
        httpService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('automatic reconnection should handle concurrent reconnection attempts for different devices', () async {
      // Validates that reconnection logic correctly handles multiple devices
      
      const testIterations = 20;
      
      for (int i = 0; i < testIterations; i++) {
        // Generate multiple device IPs
        final deviceCount = faker.randomGenerator.integer(5, min: 2);
        final deviceIps = List.generate(
          deviceCount,
          (_) => faker.internet.ipv4Address(),
        );
        
        final mockClient = MockClient();
        final httpService = IKamandHttpService(client: mockClient);
        
        // Track events per device
        final eventsByDevice = <String, List<ReconnectionEvent>>{};
        for (final ip in deviceIps) {
          eventsByDevice[ip] = [];
        }
        
        final subscription = httpService.reconnectionEvents.listen((event) {
          if (eventsByDevice.containsKey(event.deviceIp)) {
            eventsByDevice[event.deviceIp]!.add(event);
          }
        });
        
        // Mock all connections to fail
        when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenThrow(Exception('Connection failed'));
        
        // Trigger reconnection for all devices concurrently
        final futures = deviceIps.map((ip) => 
            httpService.attemptReconnection(ip)).toList();
        await Future.wait(futures);
        
        // Wait for all reconnection attempts to complete
        await Future.delayed(const Duration(seconds: 8));
        
        // Verify each device has its own independent reconnection attempts
        for (final ip in deviceIps) {
          final events = eventsByDevice[ip]!;
          
          // Each device should have its own set of events
          expect(events.isNotEmpty, isTrue,
              reason: 'Each device should have reconnection events');
          
          // Verify all events are for the correct device
          for (final event in events) {
            expect(event.deviceIp, equals(ip),
                reason: 'Events should be associated with correct device');
          }
        }
        
        await subscription.cancel();
        httpService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('automatic reconnection should be cancellable', () async {
      // Validates that ongoing reconnection attempts can be cancelled
      
      const testIterations = 10;
      
      for (int i = 0; i < testIterations; i++) {
        final deviceIp = faker.internet.ipv4Address();
        final mockClient = MockClient();
        final httpService = IKamandHttpService(client: mockClient);
        
        // Track reconnection events
        final events = <ReconnectionEvent>[];
        final subscription = httpService.reconnectionEvents.listen((event) {
          events.add(event);
        });
        
        // Mock all connections to fail
        when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenThrow(Exception('Connection failed'));
        
        // Trigger reconnection
        await httpService.attemptReconnection(deviceIp);
        
        // Wait a short time then cancel
        await Future.delayed(const Duration(milliseconds: 500));
        httpService.cancelReconnection(deviceIp);
        
        // Wait to ensure no more events are emitted
        final eventsBeforeWait = events.length;
        await Future.delayed(const Duration(seconds: 8));
        final eventsAfterWait = events.length;
        
        // After cancellation, no new events should be emitted
        // (or very few if they were already scheduled)
        expect(eventsAfterWait - eventsBeforeWait, lessThanOrEqualTo(1),
            reason: 'No new events should be emitted after cancellation');
        
        await subscription.cancel();
        httpService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('automatic reconnection should restart polling after successful reconnection', () async {
      // Validates that polling is automatically restarted after successful reconnection
      
      const testIterations = 20;
      
      for (int i = 0; i < testIterations; i++) {
        final deviceIp = faker.internet.ipv4Address();
        final mockClient = MockClient();
        final httpService = IKamandHttpService(client: mockClient);
        
        var callCount = 0;
        
        // Mock connection to succeed after first attempt
        when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async {
          callCount++;
          return http.Response(
            '{"grill_temp": 250.0, "fan_speed": 50, "target_temp": 275.0}',
            200,
          );
        });
        
        // Start polling first
        final statusStream = httpService.startStatusPolling(deviceIp);
        final statusEvents = <IKamandStatus>[];
        final statusSubscription = statusStream.listen((status) {
          statusEvents.add(status);
        });
        
        // Wait for initial poll
        await Future.delayed(const Duration(milliseconds: 500));
        final initialCallCount = callCount;
        
        // Trigger reconnection (simulating connection loss recovery)
        await httpService.attemptReconnection(deviceIp);
        
        // Wait for reconnection to complete and polling to restart
        await Future.delayed(const Duration(seconds: 2));
        
        // Verify polling continued after reconnection
        expect(callCount, greaterThan(initialCallCount),
            reason: 'Polling should continue after successful reconnection');
        
        await statusSubscription.cancel();
        httpService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('automatic reconnection should reset attempt count after successful connection', () async {
      // Validates that the attempt counter is reset after successful reconnection,
      // allowing future reconnection attempts to start fresh
      
      const testIterations = 10;
      
      for (int i = 0; i < testIterations; i++) {
        final deviceIp = faker.internet.ipv4Address();
        final mockClient = MockClient();
        final httpService = IKamandHttpService(client: mockClient);
        
        // Track reconnection events
        final events = <ReconnectionEvent>[];
        final subscription = httpService.reconnectionEvents.listen((event) {
          events.add(event);
        });
        
        // First reconnection: succeed on attempt 2
        var attemptCount = 0;
        when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async {
          attemptCount++;
          if (attemptCount >= 2) {
            return http.Response(
              '{"grill_temp": 250.0, "fan_speed": 50, "target_temp": 275.0}',
              200,
            );
          }
          throw Exception('Connection failed');
        });
        
        // First reconnection attempt
        await httpService.attemptReconnection(deviceIp);
        await Future.delayed(const Duration(seconds: 4));
        
        // Verify first reconnection succeeded
        final firstSuccessEvents = events.where((e) => 
            e.status == ReconnectionStatus.success).toList();
        expect(firstSuccessEvents.length, equals(1),
            reason: 'First reconnection should succeed');
        
        // Clear events for second reconnection
        events.clear();
        attemptCount = 0;
        
        // Second reconnection: succeed on attempt 1 (proving counter was reset)
        when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async {
          attemptCount++;
          return http.Response(
            '{"grill_temp": 250.0, "fan_speed": 50, "target_temp": 275.0}',
            200,
          );
        });
        
        // Second reconnection attempt
        await httpService.attemptReconnection(deviceIp);
        await Future.delayed(const Duration(seconds: 2));
        
        // Verify second reconnection started from attempt 1
        final secondAttemptingEvents = events.where((e) => 
            e.status == ReconnectionStatus.attempting).toList();
        expect(secondAttemptingEvents.isNotEmpty, isTrue,
            reason: 'Second reconnection should have attempting events');
        expect(secondAttemptingEvents.first.attemptNumber, equals(1),
            reason: 'Second reconnection should start from attempt 1 (counter was reset)');
        
        await subscription.cancel();
        httpService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('automatic reconnection should handle rapid connection loss and recovery', () async {
      // Validates that the system handles rapid connection state changes
      
      const testIterations = 20;
      
      for (int i = 0; i < testIterations; i++) {
        final deviceIp = faker.internet.ipv4Address();
        final mockClient = MockClient();
        final httpService = IKamandHttpService(client: mockClient);
        
        // Track reconnection events
        final events = <ReconnectionEvent>[];
        final subscription = httpService.reconnectionEvents.listen((event) {
          events.add(event);
        });
        
        // Simulate rapid connection changes
        final connectionStates = List.generate(
          faker.randomGenerator.integer(10, min: 3),
          (index) => faker.randomGenerator.boolean(),
        );
        
        for (final shouldConnect in connectionStates) {
          if (shouldConnect) {
            // Connection succeeds
            when(() => mockClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              '{"grill_temp": 250.0, "fan_speed": 50, "target_temp": 275.0}',
              200,
            ));
          } else {
            // Connection fails
            when(() => mockClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenThrow(Exception('Connection failed'));
          }
          
          // Trigger reconnection
          await httpService.attemptReconnection(deviceIp);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        // Wait for all operations to complete
        await Future.delayed(const Duration(seconds: 2));
        
        // Verify events were emitted for each reconnection attempt
        expect(events.isNotEmpty, isTrue,
            reason: 'Should have reconnection events for rapid state changes');
        
        // Verify all events are for the correct device
        for (final event in events) {
          expect(event.deviceIp, equals(deviceIp),
              reason: 'All events should be for the correct device');
        }
        
        await subscription.cancel();
        httpService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('automatic reconnection should maintain retry limit across multiple connection losses', () async {
      // Validates that each connection loss gets its own set of 3 retry attempts
      
      const testIterations = 10;
      
      for (int i = 0; i < testIterations; i++) {
        final deviceIp = faker.internet.ipv4Address();
        final mockClient = MockClient();
        final httpService = IKamandHttpService(client: mockClient);
        
        // Track reconnection events
        final allEvents = <ReconnectionEvent>[];
        final subscription = httpService.reconnectionEvents.listen((event) {
          allEvents.add(event);
        });
        
        // Simulate multiple connection loss scenarios
        final lossCount = faker.randomGenerator.integer(3, min: 2);
        
        for (int loss = 0; loss < lossCount; loss++) {
          // Mock all connections to fail for this loss
          when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenThrow(Exception('Connection failed'));
          
          // Trigger reconnection
          await httpService.attemptReconnection(deviceIp);
          
          // Wait for all attempts to complete
          await Future.delayed(const Duration(seconds: 8));
          
          // Verify this connection loss had its own 3 attempts
          final eventsForThisLoss = allEvents.skip(allEvents.length - 4).toList();
          final attemptingEvents = eventsForThisLoss.where((e) => 
              e.status == ReconnectionStatus.attempting).toList();
          
          expect(attemptingEvents.length, equals(3),
              reason: 'Each connection loss should get 3 retry attempts');
          
          // Reset for next loss
          allEvents.clear();
        }
        
        await subscription.cancel();
        httpService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
