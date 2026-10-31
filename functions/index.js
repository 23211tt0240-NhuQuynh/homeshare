const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { RtcRole, RtcTokenBuilder } = require("agora-token");

admin.initializeApp();

const appCertificate = defineSecret("AGORA_APP_CERTIFICATE");
const APP_ID = "3844040c2d2244778f46467cc801e808";
const TOKEN_TTL_SECONDS = 60 * 60 * 2;

exports.createRtcToken = onCall(
  { region: "asia-southeast1", secrets: [appCertificate] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Dang nhap truoc khi goi.");
    }

    const channelName = String(request.data?.channelName || "").trim();
    if (!/^[A-Za-z0-9_-]{1,64}$/.test(channelName)) {
      throw new HttpsError("invalid-argument", "Ten kenh khong hop le.");
    }

    const snap = await admin.firestore().collection("calls").doc(channelName).get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Khong thay cuoc goi.");
    }

    const call = snap.data() || {};
    const uid = request.auth.uid;
    if (uid !== call.callerId && uid !== call.calleeId) {
      throw new HttpsError("permission-denied", "Ban khong thuoc cuoc goi nay.");
    }

    const expireAt = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      appCertificate.value(),
      channelName,
      0,
      RtcRole.PUBLISHER,
      expireAt,
      expireAt,
    );

    return { token, uid: 0, channelName };
  },
);

// Chạy khi có document mới trong calls/{callId}.
// Gửi thông báo ưu tiên cao tới máy người nhận nếu cuộc gọi đang đổ chuông.
// Hỗ trợ đa thiết bị: gửi multicast tới toàn bộ token qua getUserFcmTokens và dọn dẹp token lỗi qua pruneInvalidTokens.
exports.notifyIncomingCall = onDocumentCreated(
  { document: "calls/{callId}", region: "asia-southeast1" },
  async (event) => {
    const call = event.data?.data();
    // Bỏ qua cuộc gọi không còn ở trạng thái ringing.
    if (!call || call.status !== "ringing" || !call.calleeId) return;

    const tokens = await getUserFcmTokens(call.calleeId);
    if (!tokens || tokens.length === 0) return;

    const isVideo = call.type === "video";
    const callerName = call.callerName || "Người dùng";
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        // Phần hệ thống tự hiện trên màn hình khi app không mở.
        notification: {
          title: isVideo ? "Cuộc gọi video" : "Cuộc gọi thoại",
          body: `${callerName} đang gọi cho bạn`,
        },
        // Phần app đọc khi người dùng bấm thông báo để mở đúng cuộc gọi.
        data: {
          type: "incoming_call",
          callId: String(event.params.callId),
        },
        android: {
          priority: "high",
          notification: {
            // Trùng kênh "calls" đã tạo trong CallPushService.
            channelId: "calls",
            sound: "default",
            priority: "high",
            defaultSound: true,
            visibility: "PUBLIC",
          },
        },
      });

      if (response.failureCount > 0) {
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const code = String(resp.error?.code || "");
            if (
              code.includes("registration-token-not-registered") ||
              code.includes("invalid-argument") ||
              code.includes("invalid-registration-token")
            ) {
              invalidTokens.push(tokens[idx]);
            }
          }
        });
        if (invalidTokens.length > 0) {
          await pruneInvalidTokens(call.calleeId, invalidTokens);
        }
      }
    } catch (error) {
      console.error("[FCM] Lỗi khi gửi incoming call multicast:", error);
      throw error;
    }
  },
);

/**
 * Lấy tất cả token FCM hợp lệ của người dùng (hỗ trợ đa thiết bị)
 */
async function getUserFcmTokens(userId) {
  if (!userId) return [];
  const tokens = new Set();
  const db = admin.firestore();

  // 1. Đọc subcollection fcm_tokens (chuẩn đa thiết bị mới)
  try {
    const subSnap = await db.collection("users").doc(userId).collection("fcm_tokens").get();
    subSnap.forEach((doc) => {
      const data = doc.data();
      const token = data?.token || doc.id;
      if (token && typeof token === "string" && token.length > 20) {
        tokens.add(token.trim());
      }
    });
  } catch (err) {
    console.error("Lỗi đọc subcollection fcm_tokens:", err);
  }

  // 2. Đọc mảng fcmTokens và fcmToken đơn trên document user
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists) {
      const uData = userDoc.data() || {};
      if (Array.isArray(uData.fcmTokens)) {
        uData.fcmTokens.forEach((t) => {
          if (t && typeof t === "string" && t.length > 20) tokens.add(t.trim());
        });
      }
      if (uData.fcmToken && typeof uData.fcmToken === "string" && uData.fcmToken.length > 20) {
        tokens.add(uData.fcmToken.trim());
      }
    }
  } catch (err) {
    console.error("Lỗi đọc user doc:", err);
  }

  return Array.from(tokens);
}

/**
 * Xóa các token không còn hợp lệ hoặc đã gỡ ứng dụng
 */
async function pruneInvalidTokens(userId, invalidTokens) {
  if (!userId || !invalidTokens || invalidTokens.length === 0) return;
  const db = admin.firestore();

  try {
    const batch = db.batch();
    for (const token of invalidTokens) {
      const docRef = db.collection("users").doc(userId).collection("fcm_tokens").doc(token);
      batch.delete(docRef);
    }
    await batch.commit();

    await db.collection("users").doc(userId).set(
      {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      },
      { merge: true },
    );

    const userSnap = await db.collection("users").doc(userId).get();
    const currentMain = userSnap.data()?.fcmToken;
    if (currentMain && invalidTokens.includes(currentMain)) {
      await db.collection("users").doc(userId).set(
        { fcmToken: admin.firestore.FieldValue.delete() },
        { merge: true },
      );
    }
  } catch (err) {
    console.error("Lỗi dọn dẹp invalid tokens:", err);
  }
}

/**
 * Trigger tự động gửi FCM Push Notification khi có tài liệu mới trong notifications/{notificationId}
 */
exports.notifyOnFirestoreNotification = onDocumentCreated(
  { document: "notifications/{notificationId}", region: "asia-southeast1" },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const notificationId = event.params.notificationId || data.id || "";
    const recipientId = (data.recipientId || data.receiverId || data.nguoiNhanId || data.userId || "").trim();
    const senderId = (data.senderId || data.nguoiGuiId || data.creatorId || "").trim();

    // 1. Không gửi thông báo cho chính người tạo hành động
    if (!recipientId || (senderId && recipientId === senderId)) {
      return;
    }

    // 2. Lấy danh sách token FCM của người nhận (đa thiết bị)
    const tokens = await getUserFcmTokens(recipientId);
    if (!tokens || tokens.length === 0) {
      console.log(`[FCM] Người dùng ${recipientId} chưa có FCM token đăng ký.`);
      return;
    }

    // 3. Chuẩn hóa tiêu đề và nội dung
    const title = (data.title || data.tieuDe || "HomeShare").trim();
    const body = (data.message || data.noiDung || data.body || "Bạn có thông báo mới.").trim();

    // 4. Chuẩn hóa loại thông báo (type) & targetId
    let type = (data.type || data.notificationType || "").trim();
    const targetId = (data.targetId || data.bookingId || data.roomId || data.postId || data.chatId || "").trim();
    const route = (data.route || "").trim();

    const status = (data.status || data.statusId || "").toLowerCase();
    if (type === "booking" || data.bookingId) {
      if (status === "approved" || status === "deposited") {
        type = "booking_approved";
      } else if (status === "rejected" || status === "cancelled") {
        type = "booking_rejected";
      } else {
        type = "booking_created";
      }
    } else if (type === "post" || data.roomId) {
      if (status === "rejected") {
        type = "post_rejected";
      } else {
        type = "post_approved";
      }
    } else if (type === "roommate" || data.actionType === "roommate_approval") {
      type = "roommate_message";
    } else if (![
      "chat_message",
      "booking_created",
      "booking_approved",
      "booking_rejected",
      "post_approved",
      "post_rejected",
      "roommate_message",
      "system",
    ].includes(type)) {
      type = "system";
    }

    // 5. Gửi multicast FCM
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title,
          body,
        },
        data: {
          type: String(type),
          targetId: String(targetId),
          senderId: String(senderId),
          notificationId: String(notificationId),
          route: String(route),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "homeshare_general_channel",
            sound: "default",
            defaultSound: true,
            priority: "high",
            visibility: "PUBLIC",
          },
        },
      });

      console.log(`[FCM] Đã gửi thông báo tới ${recipientId}: ${response.successCount} thành công, ${response.failureCount} thất bại.`);

      // 6. Dọn dẹp token không còn hợp lệ
      if (response.failureCount > 0) {
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const code = resp.error?.code || "";
            if (
              code.includes("registration-token-not-registered") ||
              code.includes("invalid-argument") ||
              code.includes("invalid-registration-token")
            ) {
              invalidTokens.push(tokens[idx]);
            }
          }
        });
        if (invalidTokens.length > 0) {
          await pruneInvalidTokens(recipientId, invalidTokens);
        }
      }
    } catch (err) {
      console.error("[FCM] Lỗi khi gửi FCM multicast:", err);
    }
  },
);

