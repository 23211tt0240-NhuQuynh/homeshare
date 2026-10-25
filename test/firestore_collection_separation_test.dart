import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/firestore_collections.dart';

void main() {
  test('kho phòng chủ trọ tách khỏi danh sách phòng công khai', () {
    expect(FirestoreCollections.publicRooms, 'rooms');
    expect(FirestoreCollections.hostRooms, 'host_rooms');
    expect(
      FirestoreCollections.hostRooms,
      isNot(FirestoreCollections.publicRooms),
    );
  });

  test('ảnh tin ở ghép lưu riêng, không nhúng vào roommate_posts', () {
    expect(FirestoreCollections.roommatePosts, 'roommate_posts');
    expect(FirestoreCollections.roommatePostImages, 'roommate_post_images');
    expect(
      FirestoreCollections.roommatePostImages,
      isNot(FirestoreCollections.roommatePosts),
    );
    expect(RoommatePostImageFields.postId, 'postId');
    expect(RoommatePostImageFields.imageUrl, 'imageUrl');
  });
}
