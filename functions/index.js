const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
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

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập.");
  }
  const email = String(request.auth.token.email || "").trim().toLowerCase();
  if (email !== "qnhu00181@gmail.com" || request.auth.token.email_verified !== true) {
    throw new HttpsError("permission-denied", "Chỉ Manager đã xác minh mới được quản lý uy tín và vi phạm.");
  }
  const actor = await admin.firestore().collection("users").doc(request.auth.uid).get();
  return {
    uid: request.auth.uid,
    email,
    name: String(actor.data()?.displayName || actor.data()?.fullName || "Manager"),
  };
}

exports.adjustUserReputation = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const actor = await requireAdmin(request);
    const userId = String(request.data?.userId || "").trim();
    const delta = Number(request.data?.delta);
    const reason = String(request.data?.reason || "").trim();
    if (!userId || !Number.isInteger(delta) || delta === 0 || Math.abs(delta) > 100 || !reason || reason.length > 1000) {
      throw new HttpsError("invalid-argument", "Thông tin điều chỉnh uy tín không hợp lệ.");
    }
    if (userId === actor.uid) {
      throw new HttpsError("failed-precondition", "Không thể tự điều chỉnh điểm uy tín của admin.");
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(userId);
    const auditRef = db.collection("audit_logs").doc();
    const result = await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new HttpsError("not-found", "Không tìm thấy người dùng.");
      const data = userSnap.data() || {};
      if (data.accountDeleted === true) {
        throw new HttpsError("failed-precondition", "Tài khoản này đã bị xóa.");
      }
      const oldScore = Number(data.reputationScore ?? data.diemUyTin ?? 100);
      const newScore = Math.max(0, Math.min(100, oldScore + delta));
      tx.set(userRef, {
        reputationScore: newScore,
        diemUyTin: newScore,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      tx.set(auditRef, {
        actorUid: actor.uid,
        actorEmail: actor.email,
        actorName: actor.name,
        action: delta < 0 ? "Trừ điểm uy tín" : "Cộng điểm uy tín",
        category: "nguoiDung",
        target: `User ${userId}`,
        details: `${oldScore} → ${newScore}. ${reason}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { oldScore, newScore };
    });
    return result;
  },
);

exports.recordUserViolation = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const actor = await requireAdmin(request);
    const userId = String(request.data?.userId || "").trim();
    const userName = String(request.data?.userName || "Người dùng").trim().slice(0, 120);
    const type = String(request.data?.type || "other");
    const reason = String(request.data?.reason || "").trim();
    const pointsDeducted = Number(request.data?.pointsDeducted);
    const reportId = String(request.data?.reportId || "").trim();
    const requestId = String(request.data?.requestId || "").trim();
    if (!userId || !["other", "scam"].includes(type) || !reason || reason.length > 1000 || !Number.isInteger(pointsDeducted) || pointsDeducted < 0 || pointsDeducted > 100) {
      throw new HttpsError("invalid-argument", "Thông tin vi phạm không hợp lệ.");
    }
    if (userId === actor.uid) {
      throw new HttpsError("failed-precondition", "Không thể ghi vi phạm cho chính admin.");
    }
    const rawId = reportId ? `report_${reportId}` : requestId;
    if (!rawId || !/^[A-Za-z0-9_-]{1,140}$/.test(rawId)) {
      throw new HttpsError("invalid-argument", "Thiếu mã yêu cầu ghi nhận vi phạm.");
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(userId);
    const violationRef = db.collection("violations").doc(rawId);
    const auditRef = db.collection("audit_logs").doc();
    const reportRef = reportId ? db.collection("reports").doc(reportId) : null;
    const now = new Date();
    const monthStart = now.getTime() - 30 * 24 * 60 * 60 * 1000;
    const quarterStart = now.getTime() - 90 * 24 * 60 * 60 * 1000;

    let authDisabledBeforeSanction = false;
    try {
      authDisabledBeforeSanction = (await admin.auth().getUser(userId)).disabled;
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
      authDisabledBeforeSanction = true;
    }

    const outcome = await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new HttpsError("not-found", "Không tìm thấy người dùng.");
      const userData = userSnap.data() || {};
      const existingSnap = await tx.get(violationRef);
      const historySnap = await tx.get(db.collection("violations").where("userId", "==", userId));
      let reportSnap = null;
      if (reportRef) reportSnap = await tx.get(reportRef);
      if (reportRef && (!reportSnap.exists || String(reportSnap.data()?.reportedUserId || reportSnap.data()?.targetUserId || "") !== userId)) {
        throw new HttpsError("failed-precondition", "Báo cáo không thuộc tài khoản này.");
      }

      let isNew = !existingSnap.exists;
      let violation = existingSnap.data() || {
        id: rawId,
        userId,
        userName,
        type,
        reason,
        pointsDeducted,
        confirmed: true,
        createdAt: admin.firestore.Timestamp.fromDate(now),
        confirmedByUid: actor.uid,
        confirmedByEmail: actor.email,
        reportId: reportId || null,
      };
      let existingRecords = historySnap.docs
        .filter((doc) => doc.id !== rawId && doc.data()?.confirmed === true)
        .map((doc) => doc.data());
      const records = [...existingRecords, violation].filter((item) => item.confirmed === true);
      const count30 = records.filter((item) => {
        const time = item.createdAt?.toDate?.()?.getTime?.();
        return Number.isFinite(time) && time >= monthStart && time <= now.getTime();
      }).length;
      const count90 = records.filter((item) => {
        const time = item.createdAt?.toDate?.()?.getTime?.();
        return Number.isFinite(time) && time >= quarterStart && time <= now.getTime();
      }).length;
      const isScam = violation.type === "scam";
      const accountDeleted = userData.accountDeleted === true || count90 >= 10;
      const shouldSuspend = !accountDeleted && (isScam || count30 >= 3);
      const suspendedUntil = shouldSuspend ? new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000) : null;

      if (isNew) {
        const oldScore = Number(userData.reputationScore ?? userData.diemUyTin ?? 100);
        const newScore = Math.max(0, Math.min(100, oldScore - pointsDeducted));
        tx.create(violationRef, violation);
        const patch = {
          reputationScore: newScore,
          diemUyTin: newScore,
          violationCount30d: count30,
          violationCount90d: count90,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (accountDeleted) {
          Object.assign(patch, {
            accountDeleted: true,
            accountDeletedAt: admin.firestore.FieldValue.serverTimestamp(),
            isBanned: true,
            statusId: 2,
            banReason: "Đạt ngưỡng 10 vi phạm đã xác nhận trong 90 ngày.",
          });
        } else if (shouldSuspend) {
          Object.assign(patch, {
            isBanned: true,
            statusId: 2,
            suspendedUntil: admin.firestore.Timestamp.fromDate(suspendedUntil),
            suspensionType: isScam ? "scam" : "reputation_threshold",
            statusIdBeforeSuspension: userData.suspensionType
              ? (userData.statusIdBeforeSuspension ?? 1)
              : (userData.statusId ?? 1),
            authDisabledBeforeSanction: userData.suspensionType
              ? (userData.authDisabledBeforeSanction ?? authDisabledBeforeSanction)
              : authDisabledBeforeSanction,
            banReasonBeforeSuspension: userData.suspensionType
              ? (userData.banReasonBeforeSuspension ?? "")
              : (userData.banReason ?? ""),
            banReason: isScam
              ? "Vi phạm lừa đảo đã được admin xác nhận."
              : "Đạt ngưỡng 3 vi phạm đã xác nhận trong 30 ngày.",
          });
        }
        tx.set(userRef, patch, { merge: true });
        tx.set(auditRef, {
          actorUid: actor.uid,
          actorEmail: actor.email,
          actorName: actor.name,
          action: "Xác nhận vi phạm người dùng",
          category: "nguoiDung",
          target: `User ${userId}`,
          details: `${type === "scam" ? "Lừa đảo" : "Vi phạm khác"}; trừ ${pointsDeducted} điểm. ${reason}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      if (reportRef) {
        tx.set(reportRef, {
          status: "resolved",
          resolution: "warned",
          violationType: violation.type,
          violationId: rawId,
          handledAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      return {
        violationId: rawId,
        count30,
        count90,
        accountDeleted,
        shouldSuspend,
        suspendedUntil: suspendedUntil ? suspendedUntil.toISOString() : null,
      };
    });

    if (outcome.shouldSuspend && !outcome.accountDeleted) {
      await admin.auth().updateUser(userId, { disabled: true });
    }

    if (outcome.accountDeleted) {
      try {
        await admin.auth().deleteUser(userId);
      } catch (error) {
        if (error.code !== "auth/user-not-found") throw error;
      }
      const userRef = db.collection("users").doc(userId);
      await userRef.set({
        accountDeleted: true,
        isBanned: true,
        statusId: 2,
        displayName: "Tài khoản đã xóa",
        fullName: "Tài khoản đã xóa",
        name: "Tài khoản đã xóa",
        email: admin.firestore.FieldValue.delete(),
        phone: admin.firestore.FieldValue.delete(),
        phoneNumber: admin.firestore.FieldValue.delete(),
        soDienThoai: admin.firestore.FieldValue.delete(),
        avatarUrl: admin.firestore.FieldValue.delete(),
        fcmToken: admin.firestore.FieldValue.delete(),
        fcmTokens: admin.firestore.FieldValue.delete(),
        bankAccountNumber: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    return outcome;
  },
);


// Re-enable only accounts whose temporary reputation sanction has expired.
exports.expireReputationSuspensions = onSchedule(
  {
    schedule: "every 5 minutes",
    region: "asia-southeast1",
    timeZone: "Asia/Ho_Chi_Minh",
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db.collection("users")
      .where("suspensionType", "in", ["scam", "reputation_threshold"])
      .get();

    for (const doc of snapshot.docs) {
      const data = doc.data() || {};
      if (data.accountDeleted === true) continue;
      const until = data.suspendedUntil?.toDate?.();
      if (!until || until.getTime() > now.toMillis()) continue;

      if (data.authDisabledBeforeSanction !== true) {
        try {
          await admin.auth().updateUser(doc.id, { disabled: false });
        } catch (error) {
          if (error.code !== "auth/user-not-found") throw error;
        }
      }

      await doc.ref.set({
        isBanned: data.isBannedBeforeSuspension === true,
        statusId: data.statusIdBeforeSuspension ?? 1,
        banReason: data.banReasonBeforeSuspension || admin.firestore.FieldValue.delete(),
        suspendedUntil: admin.firestore.FieldValue.delete(),
        suspensionType: admin.firestore.FieldValue.delete(),
        statusIdBeforeSuspension: admin.firestore.FieldValue.delete(),
        banReasonBeforeSuspension: admin.firestore.FieldValue.delete(),
        isBannedBeforeSuspension: admin.firestore.FieldValue.delete(),
        authDisabledBeforeSanction: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      await db.collection("audit_logs").add({
        actorUid: "system",
        actorEmail: "",
        actorName: "HomeShare System",
        action: "Tự động mở khóa tài khoản",
        category: "nguoiDung",
        target: `User ${doc.id}`,
        details: "Hết thời hạn khóa vi phạm 7 ngày.",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

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

