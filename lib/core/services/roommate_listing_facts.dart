import '../../data/models/booking_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/roommate_post_model.dart';
import '../utils/vietnam_address_parser.dart';
import 'booking_service.dart';
import 'room_service.dart';

/// Dữ liệu phòng và đơn thuê gắn với tin ở ghép, đọc từ Firebase.
class RoommateListingFacts {
  final RoomModel? room;
  final BookingRequestModel? booking;
  final List<RoommateExtraFee> extraFees;

  const RoommateListingFacts({
    this.room,
    this.booking,
    this.extraFees = const [],
  });

  String get address {
    return VietnamAddressParser.pickBest([
      room?.address.trim() ?? '',
      VietnamAddressParser.composeParts(
        street: room?.address ?? '',
        district: room?.district ?? '',
        city: room?.city ?? '',
      ),
      booking?.roomAddress.trim() ?? '',
    ]);
  }

  double get deposit {
    if ((room?.deposit ?? 0) > 0) return room!.deposit;
    if ((booking?.deposit ?? 0) > 0) return booking!.deposit;
    return 0;
  }

  DateTime? get moveInDate => booking?.moveInDate;

  double get area {
    if ((room?.area ?? 0) > 0) return room!.area;
    return 0;
  }

  int get capacity => (room?.capacity ?? 0) > 0 ? room!.capacity : 0;

  List<String> get amenities {
    final fromRoom = room?.amenities ?? const <String>[];
    return fromRoom.where((item) => item.trim().isNotEmpty).toList();
  }

  static Future<RoommateListingFacts> resolve({
    required RoommatePostModel post,
    required RoomService rooms,
    required BookingService bookings,
  }) async {
    BookingRequestModel? booking;
    if (post.bookingId.trim().isNotEmpty) {
      booking = await bookings.getBookingById(post.bookingId.trim());
    }
    if (booking == null && post.hasRoom && post.authorId.trim().isNotEmpty) {
      booking = await bookings.findActiveBookingForRenter(post.authorId.trim());
    }

    final room = await rooms.resolveRentedRoom(
      roomId: post.roomId.trim().isNotEmpty
          ? post.roomId.trim()
          : (booking?.roomId.trim() ?? ''),
      hostId: booking?.hostId.trim() ?? '',
      roomCode: booking?.roomCode.trim() ?? '',
      title: booking?.roomTitle.trim() ?? '',
      price: booking?.roomPrice ?? 0,
    );

    var fees = room == null ? const <RoommateExtraFee>[] : RoommateExtraFee.fromRoom(room);
    if (fees.isEmpty) {
      fees = post.extraFees
          .where((fee) => fee.name.isNotEmpty && fee.amount > 0)
          .toList();
    }

    return RoommateListingFacts(
      room: room,
      booking: booking,
      extraFees: fees,
    );
  }
}
