import 'package:meta/meta.dart';

/// Base event class for all Relay events
@immutable
abstract class RelayEvent {
  /// Timestamp when the event occurred
  final DateTime timestamp;

  /// Create a Relay event
  RelayEvent({DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.timestamp();

  @override
  String toString() => '$runtimeType(timestamp: $timestamp)';
}


// ============================================================================
// Task Lifecycle Events
// ============================================================================

/// Task type enumeration
enum TaskType {
  /// Passenger ride
  passengerRide('PASSENGER_RIDE'),

  /// Food delivery
  foodDelivery('FOOD_DELIVERY'),

  /// Package delivery
  packageDelivery('PACKAGE_DELIVERY'),

  /// Bulk delivery
  bulkDelivery('BULK_DELIVERY'),

  /// Errand
  errand('ERRAND');

  /// String value
  final String value;

  const TaskType(this.value);
}

/// Task status enumeration
enum TaskStatus {
  /// Pending assignment
  pending('PENDING'),

  /// Offered to riders
  offered('OFFERED'),

  /// Assigned to a rider
  assigned('ASSIGNED'),

  /// In progress
  inProgress('IN_PROGRESS'),

  /// Completed
  completed('COMPLETED'),

  /// Failed
  failed('FAILED'),

  /// Cancelled
  cancelled('CANCELLED'),

  /// Payment failed
  paymentFailed('PAYMENT_FAILED');

  /// String value
  final String value;

  const TaskStatus(this.value);
}

/// Task priority enumeration
enum Priority {
  /// Standard priority
  standard('STANDARD'),

  /// Urgent priority
  urgent('URGENT');

  /// String value
  final String value;

  const Priority(this.value);
}

/// Stage type enumeration
enum StageType {
  /// Pickup stage
  pickup('PICKUP'),

  /// Dropoff stage
  dropoff('DROPOFF');

  /// String value
  final String value;

  const StageType(this.value);
}

/// Stage status enumeration
enum StageStatus {
  /// Pending
  pending('PENDING'),

  /// In progress
  inProgress('IN_PROGRESS'),

  /// Completed
  completed('COMPLETED');

  /// String value
  final String value;

  const StageStatus(this.value);
}

/// Geographic location
@immutable
class Location {
  /// Latitude
  final double latitude;

  /// Longitude
  final double longitude;

  /// Optional bearing (degrees)
  final double? bearing;

  /// Optional speed (km/h)
  final double? speed;

  /// Optional accuracy (meters)
  final double? accuracy;

  /// Create a location
  const Location({
    required this.latitude,
    required this.longitude,
    this.bearing,
    this.speed,
    this.accuracy,
  });

  /// Create from JSON
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      bearing: json['bearing'] != null ? (json['bearing'] as num).toDouble() : null,
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (bearing != null) 'bearing': bearing,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
    };
  }

  @override
  String toString() => 'Location($latitude, $longitude)';
}

/// Task stage
@immutable
class Stage {
  /// Stage type
  final StageType type;

  /// Location
  final Location location;

  /// Optional contact name
  final String? contactName;

  /// Optional contact phone
  final String? contactPhone;

  /// Optional notes
  final String? notes;

  /// Stage status
  final StageStatus? status;

  /// Optional completion timestamp
  final DateTime? completedAt;

  /// Optional completion photo URL
  final String? completionPhoto;

  /// Create a stage
  const Stage({
    required this.type,
    required this.location,
    this.contactName,
    this.contactPhone,
    this.notes,
    this.status,
    this.completedAt,
    this.completionPhoto,
  });

  /// Create from JSON
  factory Stage.fromJson(Map<String, dynamic> json) {
    final statusValue = json['status'] as String?;

    return Stage(
      type: StageType.values.firstWhere((e) => e.value == json['type']),
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      contactName: json['contactName'] as String?,
      contactPhone: json['contactPhone'] as String?,
      notes: json['notes'] as String?,
      status: statusValue != null
          ? StageStatus.values.firstWhere((e) => e.value == statusValue)
          : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      completionPhoto: json['completionPhoto'] as String?,
    );
  }

  @override
  String toString() => 'Stage(type: $type, status: $status)';
}

/// Task created event
@immutable
class TaskCreatedEvent extends RelayEvent {
  /// Task ID
  final String taskId;

  /// Developer ID
  final String developerId;

  /// Task type
  final TaskType taskType;

  /// Priority
  final Priority priority;

  /// Delivery fee (in kobo)
  final int deliveryFee;

  /// Total fee (in kobo)
  final int totalFee;

  /// Stages
  final List<Stage> stages;

  /// Created timestamp
  final DateTime createdAt;

  /// Create task created event
  TaskCreatedEvent({
    required this.taskId,
    required this.developerId,
    required this.taskType,
    required this.priority,
    required this.deliveryFee,
    required this.totalFee,
    required this.stages,
    required this.createdAt,
    super.timestamp,
  });

  @override
  String toString() => 'TaskCreatedEvent(taskId: $taskId, status: CREATED)';
}

/// Task offered event
@immutable
class TaskOfferedEvent extends RelayEvent {
  /// Task ID
  final String taskId;

  /// Developer ID
  final String developerId;

  /// Task status
  final TaskStatus status;

  /// Offer tier
  final int tier;

  /// Number of riders offered in this tier
  final int ridersOffered;

  /// Offer timestamp
  final DateTime offeredAt;

  /// Create task offered event
  TaskOfferedEvent({
    required this.taskId,
    required this.developerId,
    required this.status,
    required this.tier,
    required this.ridersOffered,
    required this.offeredAt,
    super.timestamp,
  });

  @override
  String toString() => 'TaskOfferedEvent(taskId: $taskId)';
}

/// Task assigned event
@immutable
class TaskAssignedEvent extends RelayEvent {
  /// Task ID
  final String taskId;

  /// Rider ID
  final String riderId;

  /// Developer ID
  final String developerId;

  /// Task status
  final TaskStatus status;

  /// Assigned timestamp
  final DateTime assignedAt;

  /// Delivery fee (in kobo)
  final int deliveryFee;

  /// Current stage index
  final int currentStageIndex;

  /// Create task assigned event
  TaskAssignedEvent({
    required this.taskId,
    required this.riderId,
    required this.developerId,
    required this.status,
    required this.assignedAt,
    required this.deliveryFee,
    required this.currentStageIndex,
    super.timestamp,
  });

  @override
  String toString() => 'TaskAssignedEvent(taskId: $taskId, riderId: $riderId)';
}

/// Task in progress event
@immutable
class TaskInProgressEvent extends RelayEvent {
  /// Task ID
  final String taskId;

  /// Rider ID
  final String riderId;

  /// Developer ID
  final String developerId;

  /// Task status
  final TaskStatus status;

  /// Current stage index
  final int currentStageIndex;

  /// Task start timestamp
  final DateTime startedAt;

  /// Create task in progress event
  TaskInProgressEvent({
    required this.taskId,
    required this.riderId,
    required this.developerId,
    required this.status,
    required this.currentStageIndex,
    required this.startedAt,
    super.timestamp,
  });

  @override
  String toString() => 'TaskInProgressEvent(taskId: $taskId, stage: $currentStageIndex)';
}

/// Task completed event
@immutable
class TaskCompletedEvent extends RelayEvent {
  /// Task ID
  final String taskId;

  /// Rider ID
  final String riderId;

  /// Developer ID
  final String developerId;

  /// Task status
  final TaskStatus status;

  /// Completed timestamp
  final DateTime completedAt;

  /// Delivery fee (in kobo)
  final int deliveryFee;

  /// Payment status after completion
  final PaymentStatus? paymentStatus;

  /// Create task completed event
  TaskCompletedEvent({
    required this.taskId,
    required this.riderId,
    required this.developerId,
    required this.status,
    required this.completedAt,
    required this.deliveryFee,
    this.paymentStatus,
    super.timestamp,
  });

  @override
  String toString() => 'TaskCompletedEvent(taskId: $taskId)';
}

/// Task failed event
@immutable
class TaskFailedEvent extends RelayEvent {
  /// Task ID
  final String taskId;

  /// Developer ID
  final String developerId;

  /// Task status
  final TaskStatus status;

  /// Failure reason
  final String reason;

  /// Failed timestamp
  final DateTime failedAt;

  /// Optional rider ID (if assigned before failure)
  final String? riderId;

  /// Whether refund/pre-auth reversal happened
  final bool refunded;

  /// Refund amount (kobo)
  final int refundAmount;

  /// Create task failed event
  TaskFailedEvent({
    required this.taskId,
    required this.developerId,
    required this.status,
    required this.reason,
    required this.failedAt,
    required this.refunded,
    required this.refundAmount,
    this.riderId,
    super.timestamp,
  });

  @override
  String toString() => 'TaskFailedEvent(taskId: $taskId, reason: $reason)';
}

/// Task cancelled event
@immutable
class TaskCancelledEvent extends RelayEvent {
  /// Task ID
  final String taskId;

  /// Developer ID
  final String developerId;

  /// Task status
  final TaskStatus status;

  /// Cancellation reason
  final String? reason;

  /// Cancelled timestamp
  final DateTime cancelledAt;

  /// Optional rider ID (if assigned before cancellation)
  final String? riderId;

  /// Create task cancelled event
  TaskCancelledEvent({
    required this.taskId,
    required this.developerId,
    required this.status,
    this.reason,
    required this.cancelledAt,
    this.riderId,
    super.timestamp,
  });

  @override
  String toString() => 'TaskCancelledEvent(taskId: $taskId, reason: $reason)';
}

/// Stage completed event
@immutable
class StageCompletedEvent extends RelayEvent {
  /// Task ID
  final String taskId;

  /// Rider ID
  final String riderId;

  /// Developer ID
  final String developerId;

  /// Stage index
  final int stageIndex;

  /// Stage type
  final StageType stageType;

  /// Completed timestamp
  final DateTime completedAt;

  /// Optional completion photo URL
  final String? completionPhoto;

  /// Optional notes
  final String? notes;

  /// Next stage index, if any
  final int? nextStageIndex;

  /// Total stage count
  final int totalStages;

  /// Create stage completed event
  StageCompletedEvent({
    required this.taskId,
    required this.riderId,
    required this.developerId,
    required this.stageIndex,
    required this.stageType,
    required this.completedAt,
    this.completionPhoto,
    this.notes,
    this.nextStageIndex,
    required this.totalStages,
    super.timestamp,
  });

  @override
  String toString() => 'StageCompletedEvent(taskId: $taskId, stage: $stageIndex)';
}

// ============================================================================
// Payment Events
// ============================================================================

/// Payment status enumeration
enum PaymentStatus {
  /// Pending release
  pending('PENDING'),

  /// Released to rider
  released('RELEASED'),

  /// Disputed
  disputed('DISPUTED'),

  /// Pending admin review
  pendingReview('PENDING_REVIEW'),

  /// Dispute resolved
  disputeResolved('DISPUTE_RESOLVED');

  /// String value
  final String value;

  const PaymentStatus(this.value);
}

/// Payment pending event
@immutable
class PaymentPendingEvent extends RelayEvent {
  /// Transaction ID
  final String transactionId;

  /// Task ID
  final String taskId;

  /// Developer ID
  final String developerId;

  /// Rider ID
  final String riderId;

  /// Amount (in kobo)
  final int amount;

  /// Payment status
  final PaymentStatus status;

  /// Release timestamp
  final DateTime releaseAt;

  /// Dispute window (hours)
  final int disputeWindowHours;

  /// Create payment pending event
  PaymentPendingEvent({
    required this.transactionId,
    required this.taskId,
    required this.developerId,
    required this.riderId,
    required this.amount,
    required this.status,
    required this.releaseAt,
    required this.disputeWindowHours,
    super.timestamp,
  });

  @override
  String toString() => 'PaymentPendingEvent(taskId: $taskId, amount: $amount)';
}

/// Payment released event
@immutable
class PaymentReleasedEvent extends RelayEvent {
  /// Transaction ID
  final String transactionId;

  /// Task ID
  final String taskId;

  /// Developer ID
  final String developerId;

  /// Rider ID
  final String riderId;

  /// Amount (in kobo)
  final int amount;

  /// Payment status
  final PaymentStatus status;

  /// Released timestamp
  final DateTime releasedAt;

  /// Create payment released event
  PaymentReleasedEvent({
    required this.transactionId,
    required this.taskId,
    required this.developerId,
    required this.riderId,
    required this.amount,
    required this.status,
    required this.releasedAt,
    super.timestamp,
  });

  @override
  String toString() => 'PaymentReleasedEvent(taskId: $taskId, amount: $amount)';
}

/// Payment disputed event
@immutable
class PaymentDisputedEvent extends RelayEvent {
  /// Dispute ID
  final String disputeId;

  /// Transaction ID
  final String transactionId;

  /// Task ID
  final String taskId;

  /// Developer ID
  final String developerId;

  /// Rider ID
  final String riderId;

  /// Amount (in kobo)
  final int amount;

  /// Payment status
  final PaymentStatus status;

  /// Dispute reason
  final String reason;

  /// Dispute description
  final String description;

  /// Disputed timestamp
  final DateTime disputedAt;

  /// Create payment disputed event
  PaymentDisputedEvent({
    required this.disputeId,
    required this.transactionId,
    required this.taskId,
    required this.developerId,
    required this.riderId,
    required this.amount,
    required this.status,
    required this.reason,
    required this.description,
    required this.disputedAt,
    super.timestamp,
  });

  @override
  String toString() => 'PaymentDisputedEvent(taskId: $taskId, reason: $reason)';
}

/// Payment dispute resolved event
@immutable
class PaymentDisputeResolvedEvent extends RelayEvent {
  /// Dispute ID
  final String disputeId;

  /// Transaction ID
  final String transactionId;

  /// Task ID
  final String taskId;

  /// Developer ID
  final String developerId;

  /// Rider ID
  final String? riderId;

  /// Resolution: DEVELOPER | RIDER | SPLIT
  final String resolution;

  /// Refund amount (kobo)
  final int refundAmount;

  /// Rider payment amount (kobo)
  final int riderPayment;

  /// Resolved timestamp
  final DateTime resolvedAt;

  /// Admin that resolved the dispute
  final String resolvedBy;

  /// Optional notes
  final String? notes;

  /// Create payment dispute resolved event
  PaymentDisputeResolvedEvent({
    required this.disputeId,
    required this.transactionId,
    required this.taskId,
    required this.developerId,
    this.riderId,
    required this.resolution,
    required this.refundAmount,
    required this.riderPayment,
    required this.resolvedAt,
    required this.resolvedBy,
    this.notes,
    super.timestamp,
  });

  @override
  String toString() => 'PaymentDisputeResolvedEvent(taskId: $taskId)';
}

// ============================================================================
// Real-time Events
// ============================================================================

/// Rider location update event
@immutable
class RiderLocationUpdateEvent extends RelayEvent {
  /// Rider ID
  final String riderId;

  /// Task ID
  final String taskId;

  /// Location
  final Location location;

  /// Create rider location update event
  RiderLocationUpdateEvent({
    required this.riderId,
    required this.taskId,
    required this.location,
    super.timestamp,
  });

  @override
  String toString() => 'RiderLocationUpdateEvent(riderId: $riderId, taskId: $taskId)';
}

/// New task offer event
@immutable
class NewTaskOfferEvent extends RelayEvent {
  /// Task ID
  final String taskId;

  /// Offer tier
  final int tier;

  /// Task type
  final TaskType taskType;

  /// Priority
  final Priority priority;

  /// Delivery fee (in kobo)
  final int deliveryFee;

  /// Pickup location
  final Location pickupLocation;

  /// Dropoff location
  final Location dropoffLocation;

  /// Offer expires at
  final DateTime expiresAt;

  /// Offer timeout in seconds
  final int offerTimeoutSeconds;

  /// Optional estimated distance in km
  final double? estimatedDistance;

  /// Optional estimated duration in minutes
  final int? estimatedDuration;

  /// Create new task offer event
  NewTaskOfferEvent({
    required this.taskId,
    required this.tier,
    required this.taskType,
    required this.priority,
    required this.deliveryFee,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.expiresAt,
    required this.offerTimeoutSeconds,
    this.estimatedDistance,
    this.estimatedDuration,
    super.timestamp,
  });

  @override
  String toString() => 'NewTaskOfferEvent(taskId: $taskId)';
}

// ============================================================================
// Connection Events
// ============================================================================

/// Connection state enumeration
enum ConnectionState {
  /// Connecting
  connecting('connecting'),

  /// Connected
  connected('connected'),

  /// Disconnecting
  disconnecting('disconnecting'),

  /// Disconnected
  disconnected('disconnected'),

  /// Reconnecting
  reconnecting('reconnecting');

  /// String value
  final String value;

  const ConnectionState(this.value);
}

/// Connection open event
@immutable
class ConnectionOpenEvent extends RelayEvent {
  /// Connection state
  final ConnectionState state;

  /// Create connection open event
  ConnectionOpenEvent({
    this.state = ConnectionState.connected,
    super.timestamp,
  });

  @override
  String toString() => 'ConnectionOpenEvent(state: $state)';
}

/// Connection close event
@immutable
class ConnectionCloseEvent extends RelayEvent {
  /// Connection state
  final ConnectionState state;

  /// Optional close code
  final int? code;

  /// Optional close reason
  final String? reason;

  /// Create connection close event
  ConnectionCloseEvent({
    this.state = ConnectionState.disconnected,
    this.code,
    this.reason,
    super.timestamp,
  });

  @override
  String toString() => 'ConnectionCloseEvent(code: $code, reason: $reason)';
}

/// Connection error event
@immutable
class ConnectionErrorEvent extends RelayEvent {
  /// Error message
  final String error;

  /// Create connection error event
  ConnectionErrorEvent({
    required this.error,
    super.timestamp,
  });

  @override
  String toString() => 'ConnectionErrorEvent(error: $error)';
}

/// Connection reconnecting event
@immutable
class ConnectionReconnectingEvent extends RelayEvent {
  /// Reconnection attempt number
  final int attempt;

  /// Delay before next attempt (milliseconds)
  final int delay;

  /// Create connection reconnecting event
  ConnectionReconnectingEvent({
    required this.attempt,
    required this.delay,
    super.timestamp,
  });

  @override
  String toString() => 'ConnectionReconnectingEvent(attempt: $attempt, delay: ${delay}ms)';
}

/// Token expiring event
@immutable
class TokenExpiringEvent extends RelayEvent {
  /// Expiration timestamp
  final DateTime expiresAt;

  /// Warning duration before expiration
  final Duration warningDuration;

  /// Create token expiring event
  TokenExpiringEvent({
    required this.expiresAt,
    required this.warningDuration,
    super.timestamp,
  });

  @override
  String toString() => 'TokenExpiringEvent(expiresAt: $expiresAt)';
}
