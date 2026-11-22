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
// App đang mở vẫn hiện màn hình qua Firestore; thông báo này dành cho lúc app tắt hoặc ở nền.
exports.notifyIncomingCall = onDocumentCreated(
  { document: "calls/{callId}", region: "asia-southeast1" },
  async (event) => {
    const call = event.data?.data();
    // Bỏ qua cuộc gọi không còn ở trạng thái ringing.
    if (!call || call.status !== "ringing" || !call.calleeId) return;

    // fcmToken do app ghi vào users/{uid} lúc người nhận đăng nhập.
    const user = await admin.firestore().collection("users").doc(call.calleeId).get();
    const token = user.data()?.fcmToken;
    if (!token) return;

    const isVideo = call.type === "video";
    const callerName = call.callerName || "Người dùng";
    try {
      await admin.messaging().send({
        token,
        // Phần hệ thống tự hiện trên màn hình khi app không mở.
        notification: {
          title: isVideo ? "Cuộc gọi video" : "Cuộc gọi thoại",
          body: `${callerName} đang gọi cho bạn`,
        },
        // Phần app đọc khi người dùng bấm thông báo để mở đúng cuộc gọi.
        data: {
          type: "incoming_call",
          callId: event.params.callId,
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
    } catch (error) {
      const code = String(error.code || "");
      // Mã máy đã hết hạn hoặc không hợp lệ thì xóa, tránh gửi lại mã chết.
      if (code.includes("registration-token-not-registered") || code.includes("invalid-argument")) {
        await user.ref.set(
          { fcmToken: admin.firestore.FieldValue.delete() },
          { merge: true },
        );
        return;
      }
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

exports.prepareManagerEmailVerification = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Vui lòng đăng nhập.");
    }
    const email = String(request.auth.token.email || "").trim().toLowerCase();
    if (email !== "qnhu00181@gmail.com") {
      throw new HttpsError("permission-denied", "Chỉ tài khoản Manager mới được thực hiện thao tác này.");
    }
    await admin.auth().updateUser(request.auth.uid, { emailVerified: false });
    return { ok: true };
  },
);

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
    }
  },
);


